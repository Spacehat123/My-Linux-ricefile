import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../components"

PanelWindow {
    id: root

    property bool open: false
    visible: open || closeAnim.running

    // Injected authoritative models
    property var desktopModel: null
    property var surfaceModel: null
    property var interactionModel: null

    // Dual-layer hover guard ensuring unbreakable hover continuity
    readonly property bool hovered: mouseArea.containsMouse || (appOverview && appOverview.hovered)

    Theme {
        id: theme
    }

    anchors {
        top: true
        bottom: true
        right: true
    }

    implicitWidth: 320
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
            x: 40
        }

        PanelSurface {
            anchors.fill: parent

            PanelContent {
                anchors.fill: parent
                orientation: Qt.Vertical

                // Integrated live Application Surface Overview HUD
                ApplicationOverview {
                    id: appOverview
                    anchors.fill: parent
                    desktopModel: root.desktopModel
                    surfaceModel: root.surfaceModel
                    interactionModel: root.interactionModel
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

        onEntered: console.log("[pranc-shell] RightSidebar mouse ENTERED")
        onExited: console.log("[pranc-shell] RightSidebar mouse EXITED")
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: contentTranslate
            property: "x"
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
            property: "x"
            to: 40
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