import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

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

    // Central Tactical Transition Reticle
    Item {
        id: hudContainer
        anchors.centerIn: parent
        width: theme.spatialTransitionReticleWidth
        height: theme.spatialTransitionReticleHeight
        opacity: 0.0

        // Backdrop capsule
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: theme.panelBackground
            border.color: theme.spatialTransitionBorder
            border.width: 1
            opacity: 0.95
        }

        // Hairline boundary brackets
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2
            color: theme.spatialTransitionBorder
        }
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2
            color: theme.spatialTransitionBorder
        }

        Row {
            anchors.centerIn: parent
            spacing: 12

            // Origin Workspace Slot
            Item {
                id: prevWorkspaceSlot
                width: 44
                height: 32
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    anchors.centerIn: parent
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "FROM"
                        font.pixelSize: 7
                        font.bold: true
                        font.family: "monospace"
                        color: theme.workspaceHudMutedText
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            const id = desktopState ? desktopState.previousWorkspaceId : -1;
                            if (id < 0) return "--";
                            return id < 10 ? "0" + id : String(id);
                        }
                        font.pixelSize: 15
                        font.bold: true
                        font.family: "monospace"
                        color: theme.workspaceOccupiedText
                    }
                }
            }

            // Directional Vector Indicator
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const sign = desktopState ? desktopState.workspaceTransitionDirectionSign : 1;
                        return sign >= 0 ? "──►" : "◄──";
                    }
                    font.pixelSize: 12
                    font.bold: true
                    font.family: "monospace"
                    color: theme.spatialTransitionBorder
                }
            }

            // Destination Workspace Slot
            Item {
                id: currWorkspaceSlot
                width: 44
                height: 32
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    anchors.centerIn: parent
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "DEST"
                        font.pixelSize: 7
                        font.bold: true
                        font.family: "monospace"
                        color: theme.workspaceHudLabelText
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            const id = desktopState ? desktopState.currentWorkspaceId : -1;
                            if (id < 0) return "--";
                            return id < 10 ? "0" + id : String(id);
                        }
                        font.pixelSize: 15
                        font.bold: true
                        font.family: "monospace"
                        color: theme.spatialTransitionBorder
                    }
                }
            }

            // Telemetry Status Divider
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 20
                color: theme.surfaceDividerColor
            }

            // Context Telemetry Badges
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: {
                        const count = desktopState ? desktopState.currentSurfaceCount : 0;
                        if (count === 0) return "EMPTY";
                        return count === 1 ? "1 SURFACE" : count + " SURFACES";
                    }
                    font.pixelSize: 9
                    font.bold: true
                    font.family: "monospace"
                    color: theme.workspaceHudValueText
                }

                Row {
                    spacing: 4
                    Rectangle {
                        visible: desktopState ? desktopState.currentWorkspaceHasFullscreen : false
                        width: 22
                        height: 11
                        radius: 2
                        color: theme.workspaceHudFullscreenBackground
                        border.color: theme.workspaceHudFullscreenBadge
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "FS"
                            font.pixelSize: 7
                            font.bold: true
                            font.family: "monospace"
                            color: theme.workspaceHudFullscreenBadge
                        }
                    }

                    Rectangle {
                        visible: desktopState ? desktopState.currentWorkspaceIsUrgent : false
                        width: 26
                        height: 11
                        radius: 2
                        color: theme.workspaceHudUrgentBackground
                        border.color: theme.workspaceHudUrgentBadge
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "CRIT"
                            font.pixelSize: 7
                            font.bold: true
                            font.family: "monospace"
                            color: theme.workspaceHudUrgentBadge
                        }
                    }
                }
            }
        }
    }
}
