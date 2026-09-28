import QtQuick
import ".."

// Header row with arrows to step between island panels.
// Fixed order for the requested set: launcher <-> theme <-> wallpaper <-> power.
Row {
    id: root

    property string title: ""
    property string panel: ""

    readonly property var order: ["launcher", "theme", "wallpaper", "power"]

    function go(offset) {
        let i = order.indexOf(root.panel);
        if (i === -1)
            i = 0;
        ShellState.show(order[(i + offset + order.length) % order.length]);
    }

    height: 30
    spacing: 8

    IconButton {
        width: 30
        height: 30
        anchors.verticalCenter: parent.verticalCenter
        icon: "‹"
        accessibleName: "Previous panel"
        onClicked: root.go(-1)
    }

    ShellText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        font.pixelSize: 15
        font.weight: Font.Bold
    }

    IconButton {
        width: 30
        height: 30
        anchors.verticalCenter: parent.verticalCenter
        icon: "›"
        accessibleName: "Next panel"
        onClicked: root.go(1)
    }
}
