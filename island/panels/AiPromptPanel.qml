import QtQuick
import Quickshell
import ".."
import "../components"

FocusScope {
    id: root

    implicitHeight: 110
    width: parent ? parent.width : 540

    function takeInitialFocus() {
        promptInput.forceActiveFocus(Qt.TabFocusReason);
        promptInput.selectAll();
        IslandHub.preloadAiDaemon();
    }

    function submitPrompt() {
        const text = promptInput.text.trim();
        if (text.length === 0) return;
        promptInput.text = "";
        ShellState.close();
        IslandHub.triggerAiGeneration(text);
    }

    Column {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 8

        // Header: Studio branding + Mode badges
        Item {
            width: parent.width
            height: 24

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: Qt.rgba(Theme.purple.r, Theme.purple.g, Theme.purple.b, 0.2)
                    anchors.verticalCenter: parent.verticalCenter

                    ShellText {
                        anchors.centerIn: parent
                        text: "󱨊"
                        color: Theme.purple
                        font.pixelSize: 13
                    }
                }

                ShellText {
                    text: "AI Image Studio"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.foreground
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    height: 18
                    width: loraBadgeText.implicitWidth + 12
                    radius: 9
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    anchors.verticalCenter: parent.verticalCenter

                    ShellText {
                        id: loraBadgeText
                        anchors.centerIn: parent
                        text: "Realistic Vision v5.1 + LCM"
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: Theme.primary
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                width: resBadgeText.implicitWidth + 12
                radius: 9
                color: Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.15)

                ShellText {
                    id: resBadgeText
                    anchors.centerIn: parent
                    text: "512×512 Native"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: Theme.green
                }
            }
        }

        // Text input field box
        Rectangle {
            id: inputContainer
            width: parent.width
            height: 38
            radius: Theme.radiusSmall
            color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
            border.color: promptInput.activeFocus ? Theme.glassBorderActive : Theme.glassBorder
            border.width: promptInput.activeFocus ? 1.5 : 1

            Behavior on border.color {
                ColorAnimation { duration: Theme.animationFast }
            }

            TextInput {
                id: promptInput
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                activeFocusOnTab: true

                Keys.onReturnPressed: root.submitPrompt()
                Keys.onEnterPressed: root.submitPrompt()
                Keys.onEscapePressed: {
                    promptInput.text = "";
                    ShellState.close();
                }

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Describe the image you want to generate..."
                    color: Theme.mutedDark
                    font.pixelSize: 13
                    visible: !promptInput.text
                }
            }
        }

        // Footer: Action hints & Generate button
        Item {
            width: parent.width
            height: 24

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        height: 16
                        width: 44
                        radius: 4
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
                        anchors.verticalCenter: parent.verticalCenter

                        ShellText {
                            anchors.centerIn: parent
                            text: "Enter ↵"
                            font.pixelSize: 9
                            color: Theme.muted
                        }
                    }

                    ShellText {
                        text: "Generate"
                        font.pixelSize: 10
                        color: Theme.mutedDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        height: 16
                        width: 32
                        radius: 4
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
                        anchors.verticalCenter: parent.verticalCenter

                        ShellText {
                            anchors.centerIn: parent
                            text: "Esc"
                            font.pixelSize: 9
                            color: Theme.muted
                        }
                    }

                    ShellText {
                        text: "Cancel"
                        font.pixelSize: 10
                        color: Theme.mutedDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Rectangle {
                id: genButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                width: genBtnRow.implicitWidth + 16
                radius: 12
                color: genMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.9) : Theme.primary

                Row {
                    id: genBtnRow
                    anchors.centerIn: parent
                    spacing: 5

                    ShellText {
                        text: "󱨊"
                        font.pixelSize: 11
                        color: "#000000"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ShellText {
                        text: "Generate"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: "#000000"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: genMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submitPrompt()
                }
            }
        }
    }
}
