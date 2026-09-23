import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    property bool open: false
    visible: open || closeAnim.running

    readonly property bool hovered: mouseArea.containsMouse

    Theme {
        id: theme
    }

    anchors {
        bottom: true
    }

    implicitWidth: 520
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

        // Translucent dark placeholder background with subtle outline and rounded corners
        Rectangle {
            anchors.fill: parent
            radius: theme.panelCornerRadius
            color: theme.panelBackground
            border.color: theme.panelBorder
            border.width: theme.panelBorderWidth

            // Temporary verification label
            Text {
                anchors.centerIn: parent
                text: "BOTTOM BAR"
                color: theme.mutedTextColor
                font.pixelSize: 16
                font.bold: true
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