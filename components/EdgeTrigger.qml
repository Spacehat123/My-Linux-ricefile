import QtQuick

Item {
    id: root

    property string edge: "bottom"
    property alias triggerWidth: root.width
    property alias triggerHeight: root.height
    readonly property bool active: mouseArea.containsMouse
    property color debugColor: "#80ffffff"

    signal activated()
    signal deactivated()

    width: 100
    height: 2

    anchors {
        left: (edge === "left" || edge === "bottom-left" || edge === "top-left") ? (parent ? parent.left : undefined) : undefined
        right: (edge === "right" || edge === "bottom-right" || edge === "top-right") ? (parent ? parent.right : undefined) : undefined
        top: (edge === "top" || edge === "top-left" || edge === "top-right") ? (parent ? parent.top : undefined) : undefined
        bottom: (edge === "bottom" || edge === "bottom-left" || edge === "bottom-right" || edge === "bottom-center") ? (parent ? parent.bottom : undefined) : undefined
        horizontalCenter: (edge === "bottom-center" || edge === "top-center") ? (parent ? parent.horizontalCenter : undefined) : undefined
        verticalCenter: (edge === "left" || edge === "right") ? (parent ? parent.verticalCenter : undefined) : undefined
    }

    // Temporary visual debug indication when active
    Rectangle {
        anchors.fill: parent
        color: root.active ? root.debugColor : "transparent"
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
