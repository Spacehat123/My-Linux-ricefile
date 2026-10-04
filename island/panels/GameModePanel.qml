import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitWidth: 300
    implicitHeight: 84

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Header with status
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Text {
                text: "󰊴"
                font.family: Theme.iconFontFamily
                font.pixelSize: 16
                color: Theme.red
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "Game Mode Active"
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                color: Theme.foreground
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                implicitWidth: killedText.implicitWidth + 10
                radius: 9
                color: Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.2)
                border.color: Theme.red
                border.width: 1

                Text {
                    id: killedText
                    anchors.centerIn: parent
                    text: "Max FPS"
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                    color: Theme.red
                }
            }
        }

        // Sole Action Button: Turn Game Mode Off
        Rectangle {
            id: exitButton
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 16
            height: 36
            radius: 18
            color: exitMouse.containsMouse 
                ? Theme.red 
                : Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.22)
            border.color: Theme.red
            border.width: 1.5
            scale: exitMouse.pressed ? 0.95 : 1.0

            Behavior on scale { NumberAnimation { duration: 80 } }
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "󰈆"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 14
                    color: exitMouse.containsMouse ? "#0a0a0f" : Theme.red
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Turn Game Mode Off"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: exitMouse.containsMouse ? "#0a0a0f" : Theme.foreground
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: exitMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    ShellState.toggleGameMode();
                }
            }
        }
    }
}
