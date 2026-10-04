import QtQuick
import Quickshell
import Quickshell.Wayland
import "../island" as Island
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
    readonly property bool hovered: mouseArea.containsMouse || (todayCenter && todayCenter.hovered)

    anchors {
        top: true
        bottom: true
        right: true
    }
    margins {
        top: 12
        bottom: 12
        right: 12
    }

    implicitWidth: 400
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
            x: 420
        }

        // =====================================================================
        // FLOATING SMOKED GLASS DRAWER BODY
        // =====================================================================
        Rectangle {
            anchors.fill: parent
            radius: Island.Theme.radiusWindow
            color: Island.Theme.glassBackground
            border.color: Island.Theme.glassBorder
            border.width: Island.Theme.glassBorderWidth
            clip: true

            // Personal Daily Dashboard & Today Hub
            TodayCenter {
                id: todayCenter
                anchors.fill: parent
                anchors.margins: 16
                desktopModel: root.desktopModel
                surfaceModel: root.surfaceModel
                interactionModel: root.interactionModel
                screen: root.screen
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: contentTranslate
            property: "x"
            to: 0
            duration: 240
            easing.type: Easing.OutBack
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 1.0
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: contentTranslate
            property: "x"
            to: 420
            duration: 180
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 0.0
            duration: 180
            easing.type: Easing.InCubic
        }
    }

    onOpenChanged: {
        if (open) {
            closeAnim.stop();
            openAnim.start();
        } else {
            openAnim.stop();
            closeAnim.start();
        }
    }
}