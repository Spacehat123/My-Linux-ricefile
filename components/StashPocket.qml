import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../island" as Island

Scope {
    id: root

    property var screen: null
    property var surfaceModel: null
    property var workspaceManager: null
    property var compositorActionLayer: null

    readonly property real screenW: root.screen ? root.screen.width : 1920
    readonly property real screenH: root.screen ? root.screen.height : 1080

    // Current workspace ID
    readonly property int activeWorkspaceId: {
        if (workspaceManager && workspaceManager.focusedWorkspaceId !== undefined) {
            return workspaceManager.focusedWorkspaceId;
        }
        return 1;
    }

    // Windows stashed in special:stash
    readonly property var stashedSurfaces: {
        if (!surfaceModel || !surfaceModel.surfaces) return [];
        return surfaceModel.surfaces.filter(s => {
            if (!s) return false;
            const wName = (s.workspaceName || "").toLowerCase();
            return wName === "special:stash" || (wName.indexOf("stash") !== -1);
        });
    }

    readonly property int stashedCount: stashedSurfaces.length
    readonly property bool hasStashed: stashedCount > 0
    readonly property var topStashed: hasStashed ? stashedSurfaces[0] : null

    // Open state for the drawer
    property bool open: false
    property bool justAbsorbed: false
    readonly property bool hovered: pocketWindow ? Boolean(pocketWindow.windowHovered) : false

    function stashActiveWindow() {
        justAbsorbed = true;
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = 'special:stash', silent = true })"]);
        absorbedResetTimer.restart();
    }

    function toggleStashWorkspace() {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('stash')"]);
    }

    function restoreWindow(addr) {
        if (!addr) return;
        const cleanAddr = addr.toString().replace(/^0x/i, "");
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = " + activeWorkspaceId + ", window = 'address:0x" + cleanAddr + "' })"]);
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = 'address:0x" + cleanAddr + "' })"]);
    }

    Timer {
        id: absorbedResetTimer
        interval: 1200
        repeat: false
        onTriggered: root.justAbsorbed = false
    }

    // =========================================================================
    // FIXED-DIMENSION LAYER SHELL SURFACE (NO DYNAMIC WAYLAND RESIZE JITTER)
    // =========================================================================
    PanelWindow {
        id: pocketWindow
        screen: root.screen
        // Unmaps completely when closed and no windows are stashed (0 pixels blocked)
        visible: (root.open || root.hasStashed || closeAnim.running) && !Island.ShellState.gameMode

        anchors {
            right: true
            top: true
        }
        margins {
            right: 0
            // Positioned at top 16% (completely clear of middle-right MediaWidget)
            top: Math.round(root.screenH * 0.16)
        }

        // Fixed dimensions prevent compositor configure storms
        implicitWidth: 300
        implicitHeight: 380
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: false
        color: "transparent"

        WlrLayershell.namespace: "cool-shell-stash-pocket"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Input region strictly masked to the visible drawer when open, or only the 28px indicator pill when closed
        mask: Region {
            item: root.open ? drawer : (root.hasStashed ? closedPill : null)
            topLeftRadius: root.open ? drawer.topLeftRadius : (root.hasStashed ? closedPill.topLeftRadius : 0)
            bottomLeftRadius: root.open ? drawer.bottomLeftRadius : (root.hasStashed ? closedPill.bottomLeftRadius : 0)
        }

        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: drawerTranslate
                property: "x"
                to: 0
                duration: 220
                easing.type: Easing.OutBack
            }
            NumberAnimation {
                target: drawer
                property: "opacity"
                to: 1.0
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            id: closeAnim
            NumberAnimation {
                target: drawerTranslate
                property: "x"
                to: 295
                duration: 180
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: drawer
                property: "opacity"
                to: 0.0
                duration: 160
                easing.type: Easing.InQuad
            }
        }

        readonly property bool windowHovered: Boolean((drawerHover && drawerHover.hovered) || (closedPillHover && closedPillHover.hovered))

        Connections {
            target: root
            function onOpenChanged() {
                if (root.open) {
                    closeAnim.stop();
                    openAnim.start();
                } else {
                    openAnim.stop();
                    closeAnim.start();
                }
            }
        }

        // Mini Indicator Pill (only visible when windows are stashed)
        Rectangle {
            id: closedPill
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 90
            topLeftRadius: 14
            bottomLeftRadius: 14
            color: "#d00e131d"
            border.color: Island.Theme.primary
            border.width: 1
            visible: root.hasStashed && !root.open
            opacity: root.hasStashed && !root.open ? 1.0 : 0.0

            Behavior on opacity { NumberAnimation { duration: 200 } }

            HoverHandler {
                id: closedPillHover
                onHoveredChanged: {
                    if (hovered) {
                        root.open = true;
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.toggleStashWorkspace();
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 18
                    height: 18
                    radius: 5
                    color: "#20ffffff"

                    Image {
                        anchors.centerIn: parent
                        width: 13
                        height: 13
                        sourceSize: Qt.size(13, 13)
                        source: root.topStashed ? Quickshell.iconPath(root.topStashed.appId || root.topStashed.windowClass || "", "application-x-executable") : ""
                        fillMode: Image.PreserveAspectFit
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 16
                    height: 16
                    radius: 8
                    color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.3)
                    border.color: Island.Theme.primary
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: String(root.stashedCount)
                        color: Island.Theme.primary
                        font.pixelSize: 8
                        font.bold: true
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "‹"
                    color: Island.Theme.primary
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }

        // Sliding Internal Drawer (Fixed Window, Smooth Hardware Translation)
        Rectangle {
            id: drawer
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 285
            topLeftRadius: 20
            bottomLeftRadius: 20
            color: Island.Theme.surfaceOpaque
            border.color: Island.Theme.primary
            border.width: 1.5
            clip: true
            opacity: 0.0

            transform: Translate {
                id: drawerTranslate
                x: 295
            }

            HoverHandler {
                id: drawerHover
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // --- Drawer Header ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 10
                        color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25)
                        border.color: Island.Theme.primary
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "📥"
                            font.pixelSize: 16
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "STASH POCKET"
                            color: Island.Theme.primary
                            font.pixelSize: 13
                            font.bold: true
                            font.letterSpacing: 1.1
                        }

                        Text {
                            text: root.hasStashed ? (root.stashedCount + " window" + (root.stashedCount === 1 ? "" : "s") + " stored") : "Drop or click to hide app"
                            color: Island.Theme.muted
                            font.pixelSize: 10
                        }
                    }

                    Rectangle {
                        height: 20
                        radius: 10
                        color: root.hasStashed ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25) : "#15ffffff"
                        implicitWidth: headerBadgeText.implicitWidth + 12
                        visible: root.hasStashed

                        Text {
                            id: headerBadgeText
                            anchors.centerIn: parent
                            text: root.stashedCount + " STASHED"
                            color: Island.Theme.primary
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                }

                // --- Action Button: Stash Active Window ---
                Rectangle {
                    Layout.fillWidth: true
                    height: 64
                    radius: 14
                    color: root.justAbsorbed ? "#3000ff99" : (stashBtnHover.hovered ? "#22ffffff" : "#12ffffff")
                    border.color: root.justAbsorbed ? "#00ff99" : (stashBtnHover.hovered ? Island.Theme.primary : Island.Theme.glassBorder)
                    border.width: 1.5

                    Behavior on color { ColorAnimation { duration: 150 } }

                    HoverHandler { id: stashBtnHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Rectangle {
                            width: 38
                            height: 38
                            radius: 19
                            color: root.justAbsorbed ? "#00ff99" : (stashBtnHover.hovered ? Island.Theme.primary : "#20ffffff")

                            Text {
                                anchors.centerIn: parent
                                text: root.justAbsorbed ? "✓" : "📥"
                                color: root.justAbsorbed || stashBtnHover.hovered ? "#000000" : Island.Theme.foreground
                                font.pixelSize: 18
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: root.justAbsorbed ? "Window Stashed!" : "Stash Current Window"
                                color: root.justAbsorbed ? "#00ff99" : (stashBtnHover.hovered ? Island.Theme.primary : Island.Theme.foreground)
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Text {
                                text: root.justAbsorbed ? "Stored in background" : "Click to tuck active window away"
                                color: Island.Theme.muted
                                font.pixelSize: 10
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.stashActiveWindow();
                        }
                    }
                }

                // --- Stashed Windows Section ---
                Text {
                    text: "STASHED WINDOWS"
                    color: Island.Theme.muted
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1.2
                    visible: root.hasStashed
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6
                    clip: true
                    model: root.stashedSurfaces
                    visible: root.hasStashed

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        height: 44
                        radius: 10
                        color: itemHover.hovered ? "#24ffffff" : "#10ffffff"
                        border.color: itemHover.hovered ? Island.Theme.primary : Island.Theme.glassBorder
                        border.width: 1

                        HoverHandler { id: itemHover }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 7
                                color: "#18ffffff"

                                Image {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    sourceSize: Qt.size(18, 18)
                                    source: (modelData && modelData.appId) ? Quickshell.iconPath(modelData.appId, "application-x-executable") : ""
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData ? (modelData.appName || "App") : "App"
                                    color: Island.Theme.foreground
                                    font.pixelSize: 11
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData ? (modelData.title || "") : ""
                                    color: Island.Theme.muted
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                }
                            }

                            // Restore Button (↩)
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                color: restoreHover.hovered ? Island.Theme.primary : "#1cffffff"

                                Text {
                                    anchors.centerIn: parent
                                    text: "↩"
                                    color: restoreHover.hovered ? "#000000" : Island.Theme.foreground
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                HoverHandler { id: restoreHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.restoreWindow(modelData.address);
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.restoreWindow(modelData.address);
                            }
                        }
                    }
                }

                // Empty state if nothing stashed
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: "#0a000000"
                    border.color: "#12ffffff"
                    border.width: 1
                    visible: !root.hasStashed

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "📭"
                            font.pixelSize: 28
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Pocket is empty"
                            color: Island.Theme.foreground
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Move your mouse to this edge\nto tuck apps away anytime"
                            color: Island.Theme.muted
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // --- Footer Toggle Workspace Button ---
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 16
                    color: toggleHover.hovered ? Island.Theme.primary : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.18)
                    border.color: Island.Theme.primary
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Toggle Stash Overlay [SUPER + S]"
                        color: toggleHover.hovered ? "#000000" : Island.Theme.primary
                        font.pixelSize: 10
                        font.bold: true
                    }

                    HoverHandler { id: toggleHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.toggleStashWorkspace();
                        }
                    }
                }
            }
        }
    }
}
