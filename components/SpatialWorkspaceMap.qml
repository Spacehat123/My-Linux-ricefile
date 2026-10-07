import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../island" as Island

PanelWindow {
    id: root

    property bool open: false
    property var workspaceModel: null
    property var surfaceModel: null
    property var compositorActionLayer: null
    property var desktopState: null
    property string wallpaperSource: ""

    property int currentIndex: 0
    property real animatedIndex: 0.0
    property int thumbEpoch: 0

    signal closeRequested()

    visible: open

    WlrLayershell.namespace: "cool-shell-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    focusable: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property var workspaceList: {
        if (!workspaceModel || !workspaceModel.workspaces) return [];
        return workspaceModel.workspaces;
    }

    readonly property int totalCount: workspaceList.length

    onCurrentIndexChanged: {
        animatedIndex = currentIndex;
    }

    readonly property string captureHelper: Quickshell.shellPath("island/scripts/capture-windows.py").toString().replace(/^file:\/\//, "")

    Process {
        id: captureProcess
        command: ["python3", root.captureHelper]
        onExited: {
            root.thumbEpoch++;
        }
    }

    // Sync current index when overview opens
    onOpenChanged: {
        if (open) {
            let activeIdx = 0;
            const focusedId = (workspaceModel && workspaceModel.workspaceManager) ? workspaceModel.workspaceManager.focusedWorkspaceId : -1;
            for (let i = 0; i < workspaceList.length; ++i) {
                if (workspaceList[i] && (workspaceList[i].focused || workspaceList[i].id === focusedId)) {
                    activeIdx = i;
                    break;
                }
            }
            currentIndex = activeIdx;
            animatedIndex = activeIdx;
            root.forceActiveFocus();
            if (!captureProcess.running) {
                captureProcess.running = true;
            }
        }
    }

    // Smooth physical spring driver for carousel navigation
    Behavior on animatedIndex {
        SpringAnimation {
            spring: 4.8
            damping: 0.36
            epsilon: 0.005
        }
    }

    function warpToCurrent() {
        if (currentIndex >= 0 && currentIndex < workspaceList.length) {
            const target = workspaceList[currentIndex];
            if (target && compositorActionLayer) {
                compositorActionLayer.switchWorkspace(target.id);
            }
        }
        root.closeRequested();
    }

    function getSurfacesForWorkspaceId(wsId) {
        if (root.surfaceModel && root.surfaceModel.surfacesByWorkspace && root.surfaceModel.surfacesByWorkspace[wsId]) {
            return root.surfaceModel.surfacesByWorkspace[wsId];
        }
        return [];
    }

    function getSurfaceCountForWorkspaceId(wsId) {
        return getSurfacesForWorkspaceId(wsId).length;
    }

    function nextWorkspace() {
        if (currentIndex < workspaceList.length - 1) {
            currentIndex++;
        }
    }

    function prevWorkspace() {
        if (currentIndex > 0) {
            currentIndex--;
        }
    }

    function jumpToWorkspaceId(id) {
        for (let i = 0; i < workspaceList.length; ++i) {
            if (workspaceList[i] && workspaceList[i].id === id) {
                currentIndex = i;
                return;
            }
        }
        // If workspace doesn't exist yet, switch directly via compositor
        if (compositorActionLayer) {
            compositorActionLayer.switchWorkspace(id);
        }
        root.closeRequested();
    }

    // =========================================================================
    // Backdrop Frosted Glass
    // =========================================================================
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0.03, 0.03, 0.05, 0.86)
        opacity: root.open ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    // =========================================================================
    // Full Keyboard Capture Layer
    // =========================================================================
    Item {
        focus: root.open
        anchors.fill: parent

        Keys.onEscapePressed: (event) => {
            root.closeRequested();
            event.accepted = true;
        }

        Keys.onReturnPressed: (event) => {
            root.warpToCurrent();
            event.accepted = true;
        }

        Keys.onSpacePressed: (event) => {
            root.warpToCurrent();
            event.accepted = true;
        }

        Keys.onLeftPressed: (event) => {
            root.prevWorkspace();
            event.accepted = true;
        }

        Keys.onRightPressed: (event) => {
            root.nextWorkspace();
            event.accepted = true;
        }

        Keys.onPressed: (event) => {
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                const targetId = event.key - Qt.Key_0;
                root.jumpToWorkspaceId(targetId);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Tab) {
                if (event.modifiers & Qt.ShiftModifier) {
                    root.prevWorkspace();
                } else {
                    root.nextWorkspace();
                }
                event.accepted = true;
                return;
            }
        }
    }

    // =========================================================================
    // Main Viewport Container
    // =========================================================================
    Item {
        id: mainViewport
        anchors.fill: parent
        opacity: root.open ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        readonly property real screenW: root.screen ? root.screen.width : 1920
        readonly property real screenH: root.screen ? root.screen.height : 1080

        // Cinematic 16:9 Central Card Dimensions (~64% of screen width)
        readonly property real cardW: Math.min(1240, Math.max(760, Math.round(screenW * 0.63)))
        readonly property real cardH: Math.round(cardW * (9.0 / 16.0))

        // Inter-card spacing: spacing between centers so adjacent cards peek in ~140px
        readonly property real cardSpacing: cardW * 0.86 + 32

        // ---------------------------------------------------------------------
        // Top Floating Control Bar
        // ---------------------------------------------------------------------
        Rectangle {
            id: topBar
            anchors.top: parent.top
            anchors.topMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            height: 48
            radius: 24
            color: Island.Theme.glassBackground
            border.color: Island.Theme.glassBorder
            border.width: 1
            implicitWidth: topBarRow.implicitWidth + 32

            RowLayout {
                id: topBarRow
                anchors.centerIn: parent
                spacing: 16

                // Active Workspace Tag
                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: Island.Theme.primary
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (root.currentIndex >= 0 && root.currentIndex < root.workspaceList.length) {
                                    return root.workspaceList[root.currentIndex].id;
                                }
                                return "1";
                            }
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: Island.Theme.bg0
                        }
                    }

                    Text {
                        text: {
                            if (root.currentIndex >= 0 && root.currentIndex < root.workspaceList.length) {
                                const ws = root.workspaceList[root.currentIndex];
                                const name = ws.name && ws.name !== String(ws.id) ? ws.name : ("Workspace " + ws.id);
                                const surfCount = root.getSurfaceCountForWorkspaceId(ws.id);
                                return name + " (" + (surfCount === 0 ? "Empty" : (surfCount === 1 ? "1 window" : surfCount + " windows")) + ")";
                            }
                            return "Workspaces";
                        }
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: Island.Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    width: 1
                    height: 22
                    color: Island.Theme.glassBorder
                    Layout.alignment: Qt.AlignVCenter
                }

                // Workspace Mini Indicator Pills
                Row {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: root.workspaceList

                        delegate: Rectangle {
                            id: wsDot
                            required property var modelData
                            required property int index

                            width: root.currentIndex === index ? 32 : 18
                            height: 20
                            radius: 10
                            color: root.currentIndex === index
                                ? Island.Theme.primary
                                : (dotMouse.containsMouse ? Island.Theme.glassCardHover : Island.Theme.bg1)
                            border.color: root.currentIndex === index ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                            border.width: 1

                            Behavior on width {
                                SpringAnimation { spring: 4.5; damping: 0.35 }
                            }

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.id
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: root.currentIndex === index ? Island.Theme.bg0 : Island.Theme.muted
                            }

                            MouseArea {
                                id: dotMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentIndex = index
                            }
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: 22
                    color: Island.Theme.glassBorder
                    Layout.alignment: Qt.AlignVCenter
                }

                // Keyboard Hints
                Row {
                    spacing: 10
                    Layout.alignment: Qt.AlignVCenter

                    Row {
                        spacing: 4
                        Rectangle {
                            width: 28
                            height: 18
                            radius: 4
                            color: Island.Theme.bg1
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: "←/→"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: Island.Theme.muted
                            }
                        }
                        Text {
                            text: "Slide"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 10
                            color: Island.Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: 4
                        Rectangle {
                            width: 34
                            height: 18
                            radius: 4
                            color: Island.Theme.bg1
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: "Enter"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: Island.Theme.muted
                            }
                        }
                        Text {
                            text: "Warp"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 10
                            color: Island.Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: 4
                        Rectangle {
                            width: 26
                            height: 18
                            radius: 4
                            color: Island.Theme.bg1
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: "Esc"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: Island.Theme.muted
                            }
                        }
                        Text {
                            text: "Exit"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 10
                            color: Island.Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Close Button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeMouse.containsMouse ? Island.Theme.primaryContainer : Island.Theme.bg1
                    border.color: Island.Theme.glassBorder
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 13
                        color: closeMouse.containsMouse ? Island.Theme.primary : Island.Theme.foreground
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // Cover Flow Carousel Deck Stage
        // ---------------------------------------------------------------------
        Item {
            id: carouselStage
            anchors.fill: parent
            anchors.topMargin: 80
            anchors.bottomMargin: 50
            clip: true

            // Mouse Wheel Navigation over Stage
            MouseArea {
                id: wheelCapture
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton

                property int _wheelAccum: 0
                onWheel: (wheel) => {
                    let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                    if (delta === 0) return;
                    _wheelAccum += delta;
                    if (Math.abs(_wheelAccum) >= 60) {
                        if (_wheelAccum > 0) root.prevWorkspace();
                        else root.nextWorkspace();
                        _wheelAccum = 0;
                    }
                    wheel.accepted = true;
                }
            }

            // Carousel Workspace Cards
            Repeater {
                model: root.workspaceList

                delegate: Item {
                    id: cardWrapper
                    required property var modelData
                    required property int index

                    // Math for cover-flow spatial offset relative to animatedIndex
                    readonly property real offset: index - root.animatedIndex
                    readonly property real absOffset: Math.abs(offset)

                    // Card positioning & geometry
                    width: mainViewport.cardW
                    height: mainViewport.cardH

                    anchors.verticalCenter: parent.verticalCenter
                    x: (parent.width / 2) + offset * mainViewport.cardSpacing - (width / 2)

                    // Center focus card is 1.0 scale and 100% opaque.
                    // Adjacent cards scale to 0.82 and dim to 40% opacity.
                    scale: Math.max(0.72, 1.0 - Math.min(1.0, absOffset) * 0.18)
                    opacity: Math.max(0.0, 1.0 - Math.min(1.0, absOffset) * 0.58)
                    z: Math.round(100 - absOffset * 10)

                    visible: absOffset <= 2.2

                    // Card Canvas Container
                    Rectangle {
                        id: cardCanvas
                        anchors.fill: parent
                        radius: 18
                        color: Qt.rgba(0.08, 0.08, 0.12, 0.95)
                        border.color: {
                            if (root.currentIndex === cardWrapper.index) {
                                return Island.Theme.primary;
                            }
                            if (cardHover.containsMouse) {
                                return Island.Theme.primaryContainer;
                            }
                            return Island.Theme.glassBorder;
                        }
                        border.width: root.currentIndex === cardWrapper.index ? 2 : 1
                        clip: true

                        Behavior on border.color {
                            ColorAnimation { duration: 140 }
                        }

                        // Subtle outer glow for centered card
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: 22
                            color: "transparent"
                            border.color: Island.Theme.primary
                            border.width: 2
                            opacity: (root.currentIndex === cardWrapper.index && cardWrapper.absOffset < 0.25) ? 0.35 : 0.0
                            z: -1

                            Behavior on opacity {
                                NumberAnimation { duration: 180 }
                            }
                        }

                        // -----------------------------------------------------
                        // Wallpaper Backdrop (Authentic Desktop Foundation)
                        // -----------------------------------------------------
                        Image {
                            id: cardWallpaper
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: root.wallpaperSource || ""
                            opacity: 0.75
                            visible: source !== ""
                        }

                        // Ambient theme gradient overlay when no wallpaper image
                        Rectangle {
                            anchors.fill: parent
                            visible: cardWallpaper.status !== Image.Ready
                            gradient: Gradient {
                                orientation: Gradient.Diagonal
                                GradientStop { position: 0.0; color: Island.Theme.bg0 }
                                GradientStop { position: 0.5; color: Island.Theme.bg1 }
                                GradientStop { position: 1.0; color: Island.Theme.bg2 }
                            }
                        }

                        // Desktop Grid Lines Texture (subtle architectural grid)
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            opacity: 0.15
                            border.color: Island.Theme.glassBorderSubtle
                            border.width: 1
                        }

                        // -----------------------------------------------------
                        // Header Bar inside the Workspace Card
                        // -----------------------------------------------------
                        Rectangle {
                            id: cardInnerHeader
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 38
                            color: Qt.rgba(0.04, 0.04, 0.06, 0.65)
                            z: 20

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Row {
                                    spacing: 8
                                    Layout.alignment: Qt.AlignVCenter

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: modelData.focused ? Island.Theme.primary : Island.Theme.bg2
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.id
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: modelData.focused ? Island.Theme.bg0 : Island.Theme.foreground
                                        }
                                    }

                                    Text {
                                        text: modelData.name && modelData.name !== String(modelData.id) ? ("Workspace " + modelData.name) : ("Workspace " + modelData.id)
                                        font.family: Island.Theme.fontFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: Island.Theme.foreground
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Rectangle {
                                        visible: modelData.focused
                                        width: 52
                                        height: 18
                                        radius: 9
                                        color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25)
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: "ACTIVE"
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 8
                                            font.bold: true
                                            color: Island.Theme.primary
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: {
                                        const c = root.getSurfaceCountForWorkspaceId(modelData.id);
                                        return c === 0 ? "Empty Desktop" : (c === 1 ? "1 Window Open" : c + " Windows Open");
                                    }
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Island.Theme.muted
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }

                        // -----------------------------------------------------
                        // Spatial Live Windows Canvas Area
                        // -----------------------------------------------------
                        Item {
                            id: desktopSurfaceArea
                            z: 10
                            anchors.top: cardInnerHeader.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom

                            // Empty workspace placeholder
                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: root.getSurfaceCountForWorkspaceId(modelData.id) === 0

                                Text {
                                    text: "󰇄"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 36
                                    color: Island.Theme.mutedDark
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: "Clean Desktop"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Island.Theme.muted
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            // Real Spatial Window Miniatures
                            Repeater {
                                model: root.getSurfacesForWorkspaceId(modelData.id)

                                delegate: Item {
                                    id: liveWindowTile
                                    required property var modelData

                                    // Extract real monitor resolution for coordinate mapping
                                    readonly property real monW: mainViewport.screenW
                                    readonly property real monH: mainViewport.screenH

                                    // Exact on-screen geometry normalized to this card's canvas
                                    x: Math.max(4, Math.min(desktopSurfaceArea.width - width - 4, ((modelData.geomX || 0) / monW) * desktopSurfaceArea.width))
                                    y: Math.max(4, Math.min(desktopSurfaceArea.height - height - 4, ((modelData.geomY || 0) / monH) * desktopSurfaceArea.height))
                                    width: Math.max(110, Math.min(desktopSurfaceArea.width, ((modelData.geomWidth || monW) / monW) * desktopSurfaceArea.width))
                                    height: Math.max(80, Math.min(desktopSurfaceArea.height, ((modelData.geomHeight || monH) / monH) * desktopSurfaceArea.height))

                                    z: winMouse.containsMouse ? 30 : (modelData.activated ? 20 : 10)

                                    // High-Fidelity Window Replica Surface
                                    Rectangle {
                                        id: windowFrame
                                        anchors.fill: parent
                                        radius: 10
                                        color: isTerminal ? Qt.rgba(0.06, 0.07, 0.10, 0.78) : Qt.rgba(0.12, 0.13, 0.17, 0.94)
                                        border.color: (modelData.activated || winMouse.containsMouse)
                                            ? Island.Theme.primary
                                            : Qt.rgba(255, 255, 255, 0.16)
                                        border.width: (modelData.activated || winMouse.containsMouse) ? 2 : 1
                                        clip: true

                                        scale: winMouse.containsMouse ? 1.03 : 1.0

                                        Behavior on scale {
                                            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                                        }

                                        readonly property bool isTerminal: {
                                            const cls = (modelData.windowClass || modelData.appId || "").toLowerCase();
                                            return cls.includes("kitty") || cls.includes("term") || cls.includes("foot") || cls.includes("console");
                                        }

                                        readonly property bool isBrowser: {
                                            const cls = (modelData.windowClass || modelData.appId || "").toLowerCase();
                                            return cls.includes("brave") || cls.includes("chrome") || cls.includes("firefox");
                                        }

                                        // Real Live Window Snapshot Image (from Wayland toplevel buffer)
                                        Image {
                                            id: winSnapshot
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            source: modelData.stableId ? ("file:///tmp/cool-shell-thumbs/" + modelData.stableId + ".jpg?v=" + root.thumbEpoch) : ""
                                            cache: false
                                            asynchronous: true
                                            visible: status === Image.Ready
                                            z: 5
                                        }

                                        // Fallback Placeholder when thumbnail loading or unavailable
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Qt.rgba(0.08, 0.09, 0.13, 0.95)
                                            visible: !winSnapshot.visible
                                            z: 1

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 6

                                                IconImage {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: 32
                                                    height: 32
                                                    source: modelData.appId ? Quickshell.iconPath(modelData.appId) : ""
                                                    opacity: 0.7
                                                }

                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: modelData.appName || modelData.title || "Window"
                                                    font.family: Island.Theme.fontFamily
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: Island.Theme.muted
                                                }
                                            }
                                        }

                                        // Floating Glass Title Badge (Top Left)
                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.margins: 8
                                            height: 22
                                            radius: 11
                                            color: Qt.rgba(0.03, 0.03, 0.06, 0.88)
                                            border.color: Qt.rgba(255, 255, 255, 0.18)
                                            border.width: 1
                                            z: 15
                                            implicitWidth: badgeRow.implicitWidth + 16

                                            RowLayout {
                                                id: badgeRow
                                                anchors.centerIn: parent
                                                spacing: 6

                                                IconImage {
                                                    Layout.preferredWidth: 13
                                                    Layout.preferredHeight: 13
                                                    Layout.alignment: Qt.AlignVCenter
                                                    source: modelData.appId ? Quickshell.iconPath(modelData.appId) : ""
                                                    visible: source !== ""
                                                }

                                                Text {
                                                    text: modelData.appName || modelData.title || "Window"
                                                    font.family: Island.Theme.fontFamily
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: Island.Theme.foreground
                                                    Layout.alignment: Qt.AlignVCenter
                                                }
                                            }
                                        }

                                        // Floating Close Button (Top Right, revealed on hover)
                                        Rectangle {
                                            visible: winMouse.containsMouse
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.margins: 8
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: Qt.rgba(0.9, 0.2, 0.2, 0.9)
                                            z: 20

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰅖"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 10
                                                color: "white"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.compositorActionLayer && modelData.address) {
                                                        root.compositorActionLayer.closeSurface(modelData.address);
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Window Click -> Focus that window & Warp
                                    MouseArea {
                                        id: winMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.currentIndex !== cardWrapper.index) {
                                                root.currentIndex = cardWrapper.index;
                                                return;
                                            }
                                            if (root.compositorActionLayer) {
                                                if (modelData.address) {
                                                    root.compositorActionLayer.focusSurface(modelData.address);
                                                } else {
                                                    root.compositorActionLayer.switchWorkspace(modelData.workspaceId);
                                                }
                                            }
                                            root.closeRequested();
                                        }
                                    }
                                }
                            }
                        }

                        // Full Card Click:
                        // - If centered: warps to this workspace!
                        // - If on left or right: slides it into center!
                        MouseArea {
                            id: cardHover
                            z: 1
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            propagateComposedEvents: true

                            onClicked: (mouse) => {
                                if (root.currentIndex === cardWrapper.index) {
                                    root.warpToCurrent();
                                } else {
                                    root.currentIndex = cardWrapper.index;
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // Bottom Navigation Bar (Prev / Next Arrows + Indicators)
        // ---------------------------------------------------------------------
        RowLayout {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            // Previous Button
            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: prevMouse.containsMouse ? Island.Theme.primaryContainer : Island.Theme.bg1
                border.color: Island.Theme.glassBorder
                border.width: 1
                opacity: root.currentIndex > 0 ? 1.0 : 0.35

                Text {
                    anchors.centerIn: parent
                    text: "󰅁"
                    font.family: Island.Theme.iconFontFamily
                    font.pixelSize: 16
                    color: prevMouse.containsMouse ? Island.Theme.primary : Island.Theme.foreground
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.currentIndex > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.prevWorkspace()
                }
            }

            // Center Deck Page Indicator
            Text {
                text: (root.currentIndex + 1) + " / " + Math.max(1, root.totalCount)
                font.family: Island.Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
                color: Island.Theme.muted
                Layout.alignment: Qt.AlignVCenter
            }

            // Next Button
            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: nextMouse.containsMouse ? Island.Theme.primaryContainer : Island.Theme.bg1
                border.color: Island.Theme.glassBorder
                border.width: 1
                opacity: root.currentIndex < root.totalCount - 1 ? 1.0 : 0.35

                Text {
                    anchors.centerIn: parent
                    text: "󰅂"
                    font.family: Island.Theme.iconFontFamily
                    font.pixelSize: 16
                    color: nextMouse.containsMouse ? Island.Theme.primary : Island.Theme.foreground
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.currentIndex < root.totalCount - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.nextWorkspace()
                }
            }
        }
    }
}
