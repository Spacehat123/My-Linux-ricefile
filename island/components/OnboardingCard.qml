import QtQuick
import ".."

Rectangle {
    id: root

    signal finished()

    property int currentStep: 0
    readonly property var steps: [
        {
            "icon": "󰮯",
            "title": "Welcome to Cool-Shell",
            "desc": "The Dynamic Island at the top expands dynamically to show track progress, notifications, and status."
        },
        {
            "icon": "󰍉",
            "title": "Smart Launcher",
            "desc": "Launch apps, solve math expressions instantly, or prefix queries with 'file:' to find documents."
        },
        {
            "icon": "󰕾",
            "title": "Live Control Center",
            "desc": "Click the island anytime to adjust volume, switch devices, control per-app streams, and manage Wi-Fi."
        }
    ]

    width: 320
    height: 180
    radius: Theme.radius
    color: Theme.bg1
    border.width: 1
    border.color: Theme.primary

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Row {
            width: parent.width
            spacing: 10

            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: Theme.primaryContainer

                ShellText {
                    anchors.centerIn: parent
                    text: root.steps[root.currentStep].icon
                    font.pixelSize: 18
                    color: Theme.primary
                }
            }

            Column {
                width: parent.width - 46
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                ShellText {
                    width: parent.width
                    text: root.steps[root.currentStep].title
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Theme.foreground
                    elide: Text.ElideRight
                }

                ShellText {
                    text: "Step " + (root.currentStep + 1) + " of " + root.steps.length
                    font.pixelSize: 10
                    color: Theme.muted
                }
            }
        }

        ShellText {
            width: parent.width
            text: root.steps[root.currentStep].desc
            font.pixelSize: 11
            color: Theme.foreground
            wrapMode: Text.WordWrap
            maximumLineCount: 3
        }

        Item {
            width: parent.width
            height: 32

            // Step dots
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: root.steps.length
                    delegate: Rectangle {
                        width: index === root.currentStep ? 16 : 6
                        height: 6
                        radius: 3
                        color: index === root.currentStep ? Theme.primary : Theme.bg2

                        Behavior on width {
                            NumberAnimation { duration: Theme.animationFast }
                        }
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 80
                height: 28
                radius: 14
                color: Theme.primary

                ShellText {
                    anchors.centerIn: parent
                    text: root.currentStep === root.steps.length - 1 ? "Got it!" : "Next"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: Theme.bgDim
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.currentStep < root.steps.length - 1) {
                            root.currentStep += 1;
                        } else {
                            root.finished();
                        }
                    }
                }
            }
        }
    }
}
