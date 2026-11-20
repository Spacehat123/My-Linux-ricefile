import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../island" as Island

PanelWindow {
    id: root

    property var screen: null
    property var desktopState: null
    property bool open: false

    // Center coordinates of the radial wheel (spawned at cursor)
    property real ringX: 960
    property real ringY: 540

    // Geometry parameters matching user's radial pie marking menu sketch
    readonly property real outerRadius: 145
    readonly property real innerRadius: 42
    readonly property real ringDiameter: outerRadius * 2
    readonly property real holeDiameter: innerRadius * 2

    // Current targeted sector:
    // -1 = Deadzone (center hole)
    //  0 = North (Screen Lens: OCR & QR)
    //  1 = East  (Quick Stash: File Pocket)
    //  2 = South (Clipboard History)
    //  3 = West  (Voice Note: Dictate)
    property int selectedSector: -1
    property real currentAngle: 0
    property real currentDist: 0

    // Full screen overlay
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: open || wheelContainer.opacity > 0.01
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: open

    WlrLayershell.namespace: "pranc-shell-radial-hub"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Mask captures fullscreen input while radial menu is active; click-through when closed
    mask: Region {
        item: root.open ? fullMouseArea : null
    }

    // =========================================================================
    // Deadzone Timeout Timer: Dismiss in 1/2 sec if mouse never leaves deadzone
    // =========================================================================
    Timer {
        id: deadzoneTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (root.selectedSector === -1) {
                root.open = false;
            }
        }
    }

    // =========================================================================
    // Cursor Position Query via hyprctl
    // =========================================================================
    Process {
        id: cursorPosProc
        command: ["hyprctl", "cursorpos", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const pos = JSON.parse(text.trim());
                    const screenW = root.screen ? root.screen.width : 1920;
                    const screenH = root.screen ? root.screen.height : 1080;
                    // Clamp center so the radial wheel always fits on screen
                    root.ringX = Math.max(root.outerRadius + 24, Math.min(screenW - root.outerRadius - 24, pos.x));
                    root.ringY = Math.max(root.outerRadius + 24, Math.min(screenH - root.outerRadius - 24, pos.y));
                } catch(e) {}
            }
        }
    }

    function executeOption(index) {
        root.open = false;
        switch (index) {
            case 0: // North: Screen Lens (OCR text capture / QR reader)
                Quickshell.execDetached(["sh", "-c", "sleep 0.18; " + Quickshell.shellPath("island/scripts/screen-lens.sh")]);
                break;
            case 1: // East: Quick Stash (Drop Pocket in the top bar)
                Island.ShellState.show("shelf", "");
                break;
            case 2: // South: Clipboard History
                Island.ShellState.show("clipboard", "");
                break;
            case 3: // West: Voice Note / Dictation
                Quickshell.execDetached(["bash", Quickshell.shellPath("island/scripts/voice-note.sh")]);
                break;
        }
    }

    function triggerChoice() {
        if (root.selectedSector >= 0) {
            root.executeOption(root.selectedSector);
        } else {
            root.open = false;
        }
    }

    function updateMousePosition(mx, my) {
        const dx = mx - root.ringX;
        const dy = my - root.ringY;
        const dist = Math.sqrt(dx * dx + dy * dy);
        root.currentDist = dist;

        if (dist < root.innerRadius) {
            root.selectedSector = -1;
            // Mouse is in deadzone center hole
        } else {
            // User moved mouse towards an option: CANCEL the 1/2 sec timeout!
            deadzoneTimer.stop();

            const angleRad = Math.atan2(dy, dx);
            let angleDeg = angleRad * 180 / Math.PI;
            root.currentAngle = angleDeg;

            // Quadrant mapping:
            // East  (-45° to +45°):  Index 1 (Quick Stash)
            // South (45° to 135°):   Index 2 (Clipboard)
            // North (-135° to -45°): Index 0 (Screen Lens)
            // West  (outside):       Index 3 (Voice Note)
            if (angleDeg >= -45 && angleDeg < 45) {
                root.selectedSector = 1;
            } else if (angleDeg >= 45 && angleDeg < 135) {
                root.selectedSector = 2;
            } else if (angleDeg >= -135 && angleDeg < -45) {
                root.selectedSector = 0;
            } else {
                root.selectedSector = 3;
            }
        }
    }

    function toggle() {
        if (root.open) {
            root.open = false;
        } else {
            root.openWheel();
        }
    }

    function openWheel() {
        root.selectedSector = -1;
        root.currentDist = 0;
        cursorPosProc.exec(["hyprctl", "cursorpos", "-j"]);
        root.open = true;
        deadzoneTimer.restart();
    }

    Connections {
        target: typeof shellRoot !== "undefined" ? shellRoot : null
        function onToggleActionHub() {
            root.toggle();
        }
        function onOpenActionHub() {
            root.openWheel();
        }
        function onReleaseActionHub() {
            if (root.open) {
                root.triggerChoice();
            }
        }
        function onCloseActionHub() {
            root.open = false;
        }
    }

    // Keyboard controls
    Item {
        focus: root.open
        Keys.onEscapePressed: root.open = false
        Keys.onSpacePressed: root.triggerChoice()
        Keys.onReturnPressed: root.triggerChoice()
        Keys.onUpPressed: { root.selectedSector = 0; deadzoneTimer.stop(); }
        Keys.onRightPressed: { root.selectedSector = 1; deadzoneTimer.stop(); }
        Keys.onDownPressed: { root.selectedSector = 2; deadzoneTimer.stop(); }
        Keys.onLeftPressed: { root.selectedSector = 3; deadzoneTimer.stop(); }
    }

    // =========================================================================
    // Fullscreen Mouse Area: Tracks pointer drag and fires action on unclick
    // =========================================================================
    MouseArea {
        id: fullMouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons

        onPositionChanged: (mouse) => {
            root.updateMousePosition(mouse.x, mouse.y);
        }

        onPressed: (mouse) => {
            root.updateMousePosition(mouse.x, mouse.y);
        }

        // UNCLICKING / RELEASING CHOOSES THAT OPTION
        onReleased: (mouse) => {
            root.triggerChoice();
        }

        onClicked: (mouse) => {
            root.triggerChoice();
        }
    }

    // =========================================================================
    // RADIAL PIE MARKING MENU WHEEL
    // Centered exactly around the mouse cursor position
    // =========================================================================
    Item {
        id: wheelContainer
        x: root.ringX - root.outerRadius
        y: root.ringY - root.outerRadius
        width: root.ringDiameter
        height: root.ringDiameter

        opacity: root.open ? 1.0 : 0.0
        scale: root.open ? 1.0 : 0.85
        transformOrigin: Item.Center

        Behavior on opacity {
            NumberAnimation { duration: root.open ? 110 : 160; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: root.open ? 110 : 160; easing.type: Easing.OutBack; easing.overshoot: 1.12 }
        }

        // 1. Outer Glass Disc
        Rectangle {
            anchors.fill: parent
            radius: root.outerRadius
            // 20% transparency frosted theme background
            color: Qt.rgba(Island.Theme.bg0.r, Island.Theme.bg0.g, Island.Theme.bg0.b, 0.82)
            border.color: Island.Theme.glassBorder
            border.width: 1.5
            clip: true

            // Refractive Inner Caustic Rim
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1.5
                radius: root.outerRadius - 1.5
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
            }

            // 2. Active Sector Wedge Highlight (Mathematically exact circular quadrant wedge)
            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4
                visible: root.selectedSector >= 0

                // North Highlight (Screen Lens: Index 0)
                ShapePath {
                    fillColor: root.selectedSector === 0 
                        ? Qt.rgba(Island.Theme.cyan.r, Island.Theme.cyan.g, Island.Theme.cyan.b, 0.28) 
                        : "transparent"
                    strokeColor: "transparent"
                    startX: 145; startY: 145
                    PathLine { x: 42.47; y: 42.47 }
                    PathArc { x: 247.53; y: 42.47; radiusX: 145; radiusY: 145; direction: PathArc.Clockwise }
                    PathLine { x: 145; y: 145 }
                }

                // East Highlight (Quick Stash: Index 1)
                ShapePath {
                    fillColor: root.selectedSector === 1 
                        ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.28) 
                        : "transparent"
                    strokeColor: "transparent"
                    startX: 145; startY: 145
                    PathLine { x: 247.53; y: 42.47 }
                    PathArc { x: 247.53; y: 247.53; radiusX: 145; radiusY: 145; direction: PathArc.Clockwise }
                    PathLine { x: 145; y: 145 }
                }

                // South Highlight (Clipboard: Index 2)
                ShapePath {
                    fillColor: root.selectedSector === 2 
                        ? Qt.rgba(Island.Theme.purple.r, Island.Theme.purple.g, Island.Theme.purple.b, 0.28) 
                        : "transparent"
                    strokeColor: "transparent"
                    startX: 145; startY: 145
                    PathLine { x: 247.53; y: 247.53 }
                    PathArc { x: 42.47; y: 247.53; radiusX: 145; radiusY: 145; direction: PathArc.Clockwise }
                    PathLine { x: 145; y: 145 }
                }

                // West Highlight (Voice Note: Index 3)
                ShapePath {
                    fillColor: root.selectedSector === 3 
                        ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.28) 
                        : "transparent"
                    strokeColor: "transparent"
                    startX: 145; startY: 145
                    PathLine { x: 42.47; y: 247.53 }
                    PathArc { x: 42.47; y: 42.47; radiusX: 145; radiusY: 145; direction: PathArc.Clockwise }
                    PathLine { x: 145; y: 145 }
                }
            }

            // 3. Radial Spoke Divider Lines (matching user's sketch)
            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    strokeColor: Island.Theme.glassBorderSubtle
                    strokeWidth: 1.5
                    fillColor: "transparent"
                    startX: 42.47; startY: 42.47
                    PathLine { x: 247.53; y: 247.53 }
                }

                ShapePath {
                    strokeColor: Island.Theme.glassBorderSubtle
                    strokeWidth: 1.5
                    fillColor: "transparent"
                    startX: 247.53; startY: 42.47
                    PathLine { x: 42.47; y: 247.53 }
                }
            }
        }

        // =====================================================================
        // 4 SECTOR OPTION BADGES (North, East, South, West)
        // =====================================================================

        // A. NORTH (Screen Lens: OCR & QR)
        Item {
            anchors.top: parent.top
            anchors.topMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            width: 120
            height: 60
            scale: root.selectedSector === 0 ? 1.10 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

            Column {
                anchors.centerIn: parent
                spacing: 3

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 38
                    height: 38
                    radius: 19
                    color: root.selectedSector === 0 
                        ? Island.Theme.cyan 
                        : Qt.rgba(Island.Theme.cyan.r, Island.Theme.cyan.g, Island.Theme.cyan.b, 0.20)
                    border.color: Island.Theme.cyan
                    border.width: root.selectedSector === 0 ? 2 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰄀"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 18
                        color: root.selectedSector === 0 ? "#0a0a0f" : Island.Theme.cyan
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Screen Lens"
                    font.family: Island.Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.selectedSector === 0 ? Island.Theme.cyan : Island.Theme.foreground
                }
            }
        }

        // B. EAST (Quick Stash Pocket)
        Item {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 100
            height: 60
            scale: root.selectedSector === 1 ? 1.10 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

            Column {
                anchors.centerIn: parent
                spacing: 3

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 38
                    height: 38
                    radius: 19
                    color: root.selectedSector === 1 
                        ? Island.Theme.primary 
                        : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.20)
                    border.color: Island.Theme.primary
                    border.width: root.selectedSector === 1 ? 2 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰈔"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 18
                        color: root.selectedSector === 1 ? "#0a0a0f" : Island.Theme.primary
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Quick Stash"
                    font.family: Island.Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.selectedSector === 1 ? Island.Theme.primary : Island.Theme.foreground
                }
            }
        }

        // C. SOUTH (Clipboard History)
        Item {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            width: 120
            height: 60
            scale: root.selectedSector === 2 ? 1.10 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

            Column {
                anchors.centerIn: parent
                spacing: 3

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Clipboard"
                    font.family: Island.Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.selectedSector === 2 ? Island.Theme.purple : Island.Theme.foreground
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 38
                    height: 38
                    radius: 19
                    color: root.selectedSector === 2 
                        ? Island.Theme.purple 
                        : Qt.rgba(Island.Theme.purple.r, Island.Theme.purple.g, Island.Theme.purple.b, 0.20)
                    border.color: Island.Theme.purple
                    border.width: root.selectedSector === 2 ? 2 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰉓"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 18
                        color: root.selectedSector === 2 ? "#ffffff" : Island.Theme.purple
                    }
                }
            }
        }

        // D. WEST (Voice Note Dictation)
        Item {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 100
            height: 60
            scale: root.selectedSector === 3 ? 1.10 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

            Column {
                anchors.centerIn: parent
                spacing: 3

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 38
                    height: 38
                    radius: 19
                    color: root.selectedSector === 3 
                        ? Island.Theme.red 
                        : Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.20)
                    border.color: Island.Theme.red
                    border.width: root.selectedSector === 3 ? 2 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰍬"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 18
                        color: root.selectedSector === 3 ? "#ffffff" : Island.Theme.red
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Voice Note"
                    font.family: Island.Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.selectedSector === 3 ? Island.Theme.red : Island.Theme.foreground
                }
            }
        }

        // =====================================================================
        // CENTER DEADZONE HOLE (Where the mouse pointer starts!)
        // =====================================================================
        Rectangle {
            anchors.centerIn: parent
            width: root.holeDiameter
            height: root.holeDiameter
            radius: root.innerRadius
            color: Qt.rgba(Island.Theme.bg0.r, Island.Theme.bg0.g, Island.Theme.bg0.b, 0.94)
            border.color: root.selectedSector >= 0 ? Island.Theme.primary : Island.Theme.glassBorder
            border.width: root.selectedSector >= 0 ? 2 : 1.5

            Behavior on border.color { ColorAnimation { duration: 90 } }

            // Inner directional cursor reticle indicator
            Item {
                anchors.fill: parent

                // Centered cursor icon when in deadzone
                Text {
                    anchors.centerIn: parent
                    text: "󰆤"
                    font.family: Island.Theme.iconFontFamily
                    font.pixelSize: 18
                    color: Island.Theme.muted
                    visible: root.selectedSector === -1
                }

                // Dynamic pointing chevron indicating the aimed direction
                Text {
                    anchors.centerIn: parent
                    text: {
                        switch (root.selectedSector) {
                            case 0: return "󰁝"; // Up
                            case 1: return "󰁔"; // Right
                            case 2: return "󰁅"; // Down
                            case 3: return "󰁍"; // Left
                            default: return "";
                        }
                    }
                    font.family: Island.Theme.iconFontFamily
                    font.pixelSize: 22
                    font.bold: true
                    color: {
                        switch (root.selectedSector) {
                            case 0: return Island.Theme.cyan;
                            case 1: return Island.Theme.primary;
                            case 2: return Island.Theme.purple;
                            case 3: return Island.Theme.red;
                            default: return Island.Theme.foreground;
                        }
                    }
                    visible: root.selectedSector >= 0
                }
            }
        }
    }
}
