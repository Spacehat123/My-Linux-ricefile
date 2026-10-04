import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../island" as Island

PanelWindow {
    id: root

    // =========================================================================
    // Injected Presentation State Context
    // =========================================================================
    property var desktopState: null
    readonly property bool active: desktopState ? desktopState.workspaceTransitioning : false

    // Resource discipline: completely unmaps layer-surface when inactive
    visible: active || enterExitAnim.running

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Layer-shell configuration
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    WlrLayershell.namespace: "pranc-shell-transition"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Absolute pointer click-through
    mask: Region {}

    Theme {
        id: theme
    }

    onActiveChanged: {
        if (active) {
            enterExitAnim.restart();
        }
    }

    // Master visual lifecycle envelope (280ms duration)
    ParallelAnimation {
        id: enterExitAnim

        SequentialAnimation {
            NumberAnimation {
                target: hudContainer
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 50
                easing.type: Easing.OutCubic
            }
            PauseAnimation { duration: 130 }
            NumberAnimation {
                target: hudContainer
                property: "opacity"
                to: 0.0
                duration: 100
                easing.type: Easing.InQuad
            }
        }

        // Outgoing workspace translation & fade
        NumberAnimation {
            target: prevWorkspaceSlot
            property: "x"
            from: 0
            to: (desktopState ? -desktopState.workspaceTransitionDirectionSign : -1) * theme.spatialTransitionOffset
            duration: 260
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: prevWorkspaceSlot
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 200
            easing.type: Easing.OutCubic
        }

        // Incoming workspace translation & fade
        NumberAnimation {
            target: currWorkspaceSlot
            property: "x"
            from: (desktopState ? desktopState.workspaceTransitionDirectionSign : 1) * theme.spatialTransitionOffset
            to: 0
            duration: 280
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: currWorkspaceSlot
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    // Central Floating Glass Transition Pill HUD
    Item {
        id: hudContainer
        anchors.centerIn: parent
        width: 280
        height: 50
        opacity: 0.0

        // Backdrop floating glass capsule
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Island.Theme.glassBackground
            border.color: Island.Theme.glassBorder
            border.width: Island.Theme.glassBorderWidth
        }

        Row {
            anchors.centerIn: parent
            spacing: 14

            // Origin Workspace Slot
            Item {
                id: prevWorkspaceSlot
                width: 40
                height: 32
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "FROM"
                        font.pixelSize: 8
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.mutedDark
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            const id = desktopState ? desktopState.previousWorkspaceId : -1;
                            if (id < 0) return "--";
                            return id < 10 ? "0" + id : String(id);
                        }
                        font.pixelSize: 16
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.muted
                    }
                }
            }

            // Directional Vector Arrow
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const sign = desktopState ? desktopState.workspaceTransitionDirectionSign : 1;
                    return sign >= 0 ? "󰁔" : "󰁍";
                }
                font.pixelSize: 18
                font.family: Island.Theme.iconFontFamily
                color: Island.Theme.primary
            }

            // Destination Workspace Slot
            Item {
                id: currWorkspaceSlot
                width: 40
                height: 32
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "DEST"
                        font.pixelSize: 8
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.primary
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            const id = desktopState ? desktopState.currentWorkspaceId : -1;
                            if (id < 0) return "--";
                            return id < 10 ? "0" + id : String(id);
                        }
                        font.pixelSize: 16
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                    }
                }
            }

            // Telemetry Status Divider
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22
                color: Island.Theme.glassBorderSubtle
            }

            // Context Telemetry Badges
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: {
                        const count = desktopState ? desktopState.currentSurfaceCount : 0;
                        if (count === 0) return "Empty";
                        return count === 1 ? "1 Window" : count + " Windows";
                    }
                    font.pixelSize: 10
                    font.bold: true
                    font.family: Island.Theme.fontFamily
                    color: Island.Theme.foreground
                }

                Row {
                    spacing: 4
                    Rectangle {
                        visible: desktopState ? desktopState.currentWorkspaceHasFullscreen : false
                        height: 14
                        implicitWidth: fsText.implicitWidth + 8
                        radius: 4
                        color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.2)
                        border.color: Island.Theme.primary
                        border.width: 1
                        Text {
                            id: fsText
                            anchors.centerIn: parent
                            text: "FULL"
                            font.pixelSize: 8
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.primary
                        }
                    }

                    Rectangle {
                        visible: desktopState ? desktopState.currentWorkspaceIsUrgent : false
                        height: 14
                        implicitWidth: critText.implicitWidth + 8
                        radius: 4
                        color: Qt.rgba(1, 0.3, 0.3, 0.2)
                        border.color: "#ff5555"
                        border.width: 1
                        Text {
                            id: critText
                            anchors.centerIn: parent
                            text: "ALERT"
                            font.pixelSize: 8
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: "#ff5555"
                        }
                    }
                }
            }
        }
    }
}
