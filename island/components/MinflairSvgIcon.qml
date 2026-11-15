import QtQuick
import QtQuick.Effects
import Quickshell
import ".." as Island

Item {
    id: root

    property string icon: ""
    property color iconColor: Island.Theme ? Island.Theme.foreground : "#ffffff"
    property int iconSize: 16

    implicitWidth: iconSize
    implicitHeight: iconSize
    width: iconSize
    height: iconSize

    Image {
        id: iconImg
        anchors.fill: parent
        source: {
            if (!root.icon) return "";
            if (root.icon.startsWith("file://") || root.icon.startsWith("/") || root.icon.startsWith("qrc:"))
                return root.icon;
            return "file:///home/pranc/.config/quickshell/cool-shell/assets/minflair/" + root.icon + ".svg";
        }
        sourceSize.width: root.iconSize * 2
        sourceSize.height: root.iconSize * 2
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: iconImg
        source: iconImg
        contrast: -1
        brightness: 0.5
        colorization: 1
        colorizationColor: Qt.rgba(root.iconColor.r, root.iconColor.g, root.iconColor.b, 1)
        opacity: root.iconColor.a
        visible: iconImg.status === Image.Ready
    }
}
