import QtQuick
import "../island" as Island

Item {
    id: root

    property string edge: "bottom"
    property alias triggerWidth: root.width
    property alias triggerHeight: root.height
    readonly property bool active: mouseArea.containsMouse
    property color debugColor: Island.Theme.primary

    signal activated()
    signal deactivated()

    width: 100
    height: 3

    anchors {
        left: (edge === "left" || edge === "bottom-left" || edge === "top-left") ? (parent ? parent.left : undefined) : undefined
        right: (edge === "right" || edge === "bottom-right" || edge === "top-right") ? (parent ? parent.right : undefined) : undefined
        top: (edge === "top" || edge === "top-left" || edge === "top-right") ? (parent ? parent.top : undefined) : undefined
        bottom: (edge === "bottom" || edge === "bottom-left" || edge === "bottom-right" || edge === "bottom-center") ? (parent ? parent.bottom : undefined) : undefined
        horizontalCenter: (edge === "bottom-center" || edge === "top-center") ? (parent ? parent.horizontalCenter : undefined) : undefined
        verticalCenter: (edge === "left" || edge === "right") ? (parent ? parent.verticalCenter : undefined) : undefined
    }

    // Modern ambient pill glow indicator (0 FPS cost when idle)
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.debugColor
        opacity: root.active ? 0.7 : 0.0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onEntered: root.activated()
        onExited: root.deactivated()
    }
}
