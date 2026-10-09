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

    // Transient drop action states
    property bool dropTargetHovered: false
    property bool justAbsorbed: false

    function stashActiveWindow() {
        justAbsorbed = true;
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = 'special:stash', silent = true })"]);
        dropDebounce.restart();
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
        id: dropDebounce
        interval: 800
        repeat: false
        onTriggered: {
            root.justAbsorbed = false;
        }
    }

    // =========================================================================
    // STASH POCKET & DROP TARGET PANEL WINDOW
    // =========================================================================
    PanelWindow {
        id: pocketWindow
        screen: root.screen
        visible: !Island.ShellState.gameMode

        anchors {
            right: true
            top: true
        }
        margins {
            right: 0
            // Positioned at top 18% to avoid the middle-right MediaWidget
            top: Math.round(root.screenH * 0.18)
        }

        // Width dynamically adapts:
        // 1. If hovered during drag / drop: expands to 160px Drop Zone
        // 2. If hovering existing stashed pocket: expands to 220px Drawer
        // 3. If idle with stashed windows: collapsed to 34px Pill
        // 4. If idle with zero stashed windows: 12px invisible sensor strip
        implicitWidth: {
            if (root.dropTargetHovered) return 160;
            if (root.hasStashed) return pocketHover.hovered ? 220 : 34;
            return 12; // Invisible edge sensor
        }
        implicitHeight: root.dropTargetHovered ? 230 : (root.hasStashed ? (pocketHover.hovered ? Math.min(320, 110 + root.stashedCount * 44) : 180) : 220)

        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: false
        color: "transparent"

        WlrLayershell.namespace: "cool-shell-stash-pocket"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Behavior on implicitWidth {
            SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.5 }
        }
        Behavior on implicitHeight {
            SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.5 }
        }

        HoverHandler {
            id: pocketHover
            onHoveredChanged: {
                if (hovered && !root.hasStashed) {
                    root.dropTargetHovered = true;
                } else if (!hovered) {
                    root.dropTargetHovered = false;
                }
            }
        }

        // ---------------------------------------------------------------------
        // Visual Presentation Container
        // ---------------------------------------------------------------------
        Rectangle {
            id: pocketBody
            anchors.fill: parent
            topLeftRadius: 18
            bottomLeftRadius: 18
            clip: true

            // When idle with nothing stashed: 100% invisible!
            color: {
                if (root.justAbsorbed) return "#e000ff99";
                if (root.dropTargetHovered) return "#ea0c121e";
                if (root.hasStashed) return pocketHover.hovered ? "#ea0a0e16" : "#b8080c14";
                return "transparent";
            }
            border.color: {
                if (root.justAbsorbed) return "#00ff99";
                if (root.dropTargetHovered) return Island.Theme.primary;
                if (root.hasStashed) return pocketHover.hovered ? Island.Theme.primary : "#4033ccff";
                return "transparent";
            }
            border.width: (root.dropTargetHovered || root.justAbsorbed) ? 2 : (root.hasStashed ? 1 : 0)

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on border.color { ColorAnimation { duration: 180 } }

            // Neon breathing edge line on bezel
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3
                color: root.justAbsorbed ? "#00ff99" : Island.Theme.primary
                visible: root.hasStashed || root.dropTargetHovered || root.justAbsorbed
            }

            // =================================================================
            // VIEW A: DROP TARGET MODE (When dragging window or hovering edge sensor)
            // =================================================================
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                visible: root.dropTargetHovered && !root.hasStashed

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 44
                    height: 44
                    radius: 22
                    color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25)
                    border.color: Island.Theme.primary
                    border.width: 1.5

                    Text {
                        anchors.centerIn: parent
                        text: "📥"
                        font.pixelSize: 22
                        scale: targetPulse.running ? 1.15 : 1.0

                        SequentialAnimation on scale {
                            id: targetPulse
                            loops: Animation.Infinite
                            running: root.dropTargetHovered
                            NumberAnimation { to: 1.2; duration: 450; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 450; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "DROP TO STASH"
                    color: Island.Theme.primary
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 1.1
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    text: "Release window here\nto tuck into pocket"
                    color: Island.Theme.muted
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    height: 22
                    radius: 11
                    color: "#20ffffff"
                    implicitWidth: dropLabel.implicitWidth + 14

                    Text {
                        id: dropLabel
                        anchors.centerIn: parent
                        text: "Click to Stash Active"
                        color: Island.Theme.foreground
                        font.pixelSize: 9
                        font.bold: true
                    }
                }
            }

            // =================================================================
            // VIEW B: COLLAPSED POCKET PILL (When windows are stashed & idle)
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.hasStashed && !pocketHover.hovered && !root.dropTargetHovered

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 24
                        height: 24
                        radius: 8
                        color: "#20ffffff"

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            sourceSize: Qt.size(16, 16)
                            source: root.topStashed ? Quickshell.iconPath(root.topStashed.appId || root.topStashed.windowClass || "", "application-x-executable") : ""
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    // Count Badge
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 18
                        height: 18
                        radius: 9
                        color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.3)
                        border.color: Island.Theme.primary
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: String(root.stashedCount)
                            color: Island.Theme.primary
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "›"
                        color: Island.Theme.primary
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
            }

            // =================================================================
            // VIEW C: EXPANDED POCKET DRAWER (When hovering pocket with stashed windows)
            // =================================================================
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                visible: root.hasStashed && pocketHover.hovered

                // Drawer Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "STASH POCKET"
                        color: Island.Theme.primary
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.1
                    }

                    Rectangle {
                        height: 16
                        radius: 8
                        color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25)
                        implicitWidth: drawerCountText.implicitWidth + 10
                        Text {
                            id: drawerCountText
                            anchors.centerIn: parent
                            text: root.stashedCount + " App" + (root.stashedCount === 1 ? "" : "s")
                            color: Island.Theme.primary
                            font.pixelSize: 8
                            font.bold: true
                        }
                    }
                }

                // Stashed Items List
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6
                    clip: true
                    model: root.stashedSurfaces

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        height: 38
                        radius: 10
                        color: itemHover.hovered ? "#25ffffff" : "#12ffffff"
                        border.color: itemHover.hovered ? Island.Theme.primary : Island.Theme.glassBorder
                        border.width: 1

                        HoverHandler { id: itemHover }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 6
                                color: "#18ffffff"
                                Image {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    sourceSize: Qt.size(16, 16)
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

                            // Restore Action Button
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: restoreHover.hovered ? Island.Theme.primary : "#20ffffff"

                                Text {
                                    anchors.centerIn: parent
                                    text: "↩"
                                    color: restoreHover.hovered ? "#000000" : Island.Theme.foreground
                                    font.pixelSize: 11
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

                // Bottom Action Footer
                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: 13
                    color: toggleHover.hovered ? Island.Theme.primary : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.2)
                    border.color: Island.Theme.primary
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Toggle Overlay Workspace"
                        color: toggleHover.hovered ? "#000000" : Island.Theme.primary
                        font.pixelSize: 9
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

            // Click handling for Drop Zone & Collapsed Pocket
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                visible: !pocketHover.hovered || !root.hasStashed
                onClicked: {
                    if (root.dropTargetHovered && !root.hasStashed) {
                        root.stashActiveWindow();
                    } else if (root.hasStashed) {
                        root.toggleStashWorkspace();
                    }
                }
            }
        }
    }
}
