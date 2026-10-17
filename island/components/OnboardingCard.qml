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
            "desc": "The Dynamic Island at the top morphs to display live track progress, synced lyrics, study timers, and system alerts. Hover to preview or click to expand."
        },
        {
            "icon": "󰍉",
            "title": "Smart Launcher & Quick Tools",
            "desc": "Tap Super to open the launcher. Search apps, evaluate math expressions, prefix 'file:' to find documents, or jump to Clipboard, Notes, Tasks, and AI Studio."
        },
        {
            "icon": "󰕾",
            "title": "Edge Drawers & Control Center",
            "desc": "Hover the bottom-left edge for the Control Center & System Modes, bottom-center for the Workspace Dock, or bottom-right for Today & Notifications."
        },
        {
            "icon": "󰆾",
            "title": "Spatial & Bird's-Eye Overviews",
            "desc": "Press Super+Tab for the 3D Spatial Workspace Map or Super+R for the Bird's-Eye window canvas with live thumbnails and instant type-to-filter search."
        },
        {
            "icon": "󰄀",
            "title": "Screen Lens & Phone Bridge",
            "desc": "Press Super+Shift+S to extract OCR text, QR codes, or hex colors with Kokoro voice readout, and Super+Alt+P to mirror your Android phone wirelessly."
        }
    ]

    width: 360
    height: 204
    radius: Theme.radius
    color: Theme.bg1
    border.width: 1
    border.color: Theme.primary

    // Top specular highlight
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 28
        height: 1
        color: Theme.glassSpecularTop
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Row {
            width: parent.width
            spacing: 10

            Rectangle {
                width: 38
                height: 38
                radius: 19
                color: Theme.primaryContainer
                border.width: 1
                border.color: Theme.glassBorderActive

                ShellText {
                    anchors.centerIn: parent
                    text: root.steps[root.currentStep].icon
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 18
                    color: Theme.primary
                }
            }

            Column {
                width: parent.width - 86
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

            Rectangle {
                width: 28
                height: 24
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: skipHover.hovered ? Theme.bg2 : "transparent"

                ShellText {
                    anchors.centerIn: parent
                    text: "Skip"
                    font.pixelSize: 10
                    color: skipHover.hovered ? Theme.foreground : Theme.muted
                }

                HoverHandler { id: skipHover }
                TapHandler {
                    onTapped: root.finished()
                }
            }
        }

        ShellText {
            width: parent.width
            height: 64
            text: root.steps[root.currentStep].desc
            font.pixelSize: 11
            color: Theme.foreground
            wrapMode: Text.WordWrap
            maximumLineCount: 4
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

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    visible: root.currentStep > 0
                    width: 64
                    height: 28
                    radius: 14
                    color: prevMouse.containsMouse ? Theme.bg3 : Theme.bg2
                    border.width: 1
                    border.color: Theme.glassBorderSubtle

                    ShellText {
                        anchors.centerIn: parent
                        text: "Back"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.foreground
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.currentStep > 0)
                                root.currentStep -= 1;
                        }
                    }
                }

                Rectangle {
                    width: 84
                    height: 28
                    radius: 14
                    color: Theme.primary

                    ShellText {
                        anchors.centerIn: parent
                        text: root.currentStep === root.steps.length - 1 ? "Finish" : "Next"
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
}
