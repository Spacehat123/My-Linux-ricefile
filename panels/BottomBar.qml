import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../components"

PanelWindow {
    id: root

    property bool open: false
    visible: open || closeAnim.running

    // Injected desktop composition model
    property var desktopModel: null
    property var interactionModel: null
    property var desktopState: null

    // Dual-layer hover guard ensuring unbreakable hover continuity
    readonly property bool hovered: mouseArea.containsMouse || (workspaceNav && workspaceNav.hovered)

    Theme {
        id: theme
    }

    anchors {
        bottom: true
    }

    implicitWidth: Math.max(540, (workspaceNav ? workspaceNav.implicitWidth : 0) + theme.panelPadding * 2)
    implicitHeight: 64
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    WlrLayershell.namespace: "pranc-shell"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
        id: content
        anchors.fill: parent
        opacity: 0.0

        transform: Translate {
            id: contentTranslate
            y: 24
        }

        PanelSurface {
            anchors.fill: parent
            radius: theme.panelCornerRadius
            border.color: theme.panelBorder

            PanelContent {
                anchors.fill: parent
                orientation: Qt.Horizontal

                // Reusable Workspace Navigator HUD
                WorkspaceNavigator {
                    id: workspaceNav
                    anchors.centerIn: parent
                    desktopModel: root.desktopModel
                    interactionModel: root.interactionModel
                    desktopState: root.desktopState
                    screen: root.screen
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onEntered: console.log("[pranc-shell] BottomBar mouse ENTERED")
        onExited: console.log("[pranc-shell] BottomBar mouse EXITED")
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: contentTranslate
            property: "y"
            to: 0
            duration: theme.animDurationOpen
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 1.0
            duration: theme.animDurationOpen
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: contentTranslate
            property: "y"
            to: 24
            duration: theme.animDurationClose
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 0.0
            duration: theme.animDurationClose
            easing.type: Easing.InCubic
        }
    }

    onOpenChanged: {
        if (open) {
            closeAnim.stop()
            openAnim.start()
        } else {
            openAnim.stop()
            closeAnim.start()
        }
    }
}