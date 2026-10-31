import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property int level: 100
    property bool charging: false
    property int lowThreshold: 20

    implicitWidth: 20
    implicitHeight: 12

    readonly property real clampedPct: Math.max(0, Math.min(100, level))
    readonly property color fillColor: charging
        ? "#32D74B"
        : (clampedPct <= lowThreshold ? "#FF453A" : "#ffffff")

    // Battery Body Shell
    Rectangle {
        id: shell
        x: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 15
        height: 9.5
        radius: 2.6
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.38)
        border.width: 1.1

        // Inner Fill
        Rectangle {
            id: fillRect
            x: 1.5
            anchors.verticalCenter: parent.verticalCenter
            height: 5.5
            radius: 1.2
            color: root.fillColor
            width: Math.max(1, (clampedPct / 100.0) * (shell.width - 3))

            Behavior on width {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
        }

        // Centered Charging Lightning Bolt
        Shape {
            anchors.centerIn: parent
            width: 7
            height: 9
            visible: root.charging

            ShapePath {
                fillColor: "#ffffff"
                strokeColor: "transparent"
                startX: 4
                startY: 0

                PathLine { x: 0; y: 5 }
                PathLine { x: 3; y: 5 }
                PathLine { x: 2; y: 9 }
                PathLine { x: 7; y: 3.5 }
                PathLine { x: 4; y: 3.5 }
                PathLine { x: 4.8; y: 0 }
                PathLine { x: 4; y: 0 }
            }
        }
    }

    // Battery Positive Anode Tip
    Rectangle {
        anchors.left: shell.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 1.5
        height: 4
        radius: 0.75
        color: Qt.rgba(1, 1, 1, 0.45)
    }
}
