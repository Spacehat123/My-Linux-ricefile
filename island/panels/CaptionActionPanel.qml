import QtQuick
import ".."
import "../components"

FocusScope {
    id: root

    implicitWidth: 420
    implicitHeight: content.implicitHeight

    function takeInitialFocus() {
        if (CaptionState.isVideo) {
            embedBtn.forceActiveFocus(Qt.TabFocusReason);
        } else {
            captionOnlyBtn.forceActiveFocus(Qt.TabFocusReason);
        }
    }

    Column {
        id: content
        width: parent.width
        spacing: 8

        PanelHeader {
            title: CaptionState.isAudio ? "Audio Detected" : "Media Detected"
            onCloseRequested: CaptionState.cancel()
        }

        // Media Info Card
        Rectangle {
            width: parent.width
            height: 46
            radius: Theme.radiusSmall
            color: Theme.bg0
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                    anchors.verticalCenter: parent.verticalCenter

                    ShellText {
                        anchors.centerIn: parent
                        text: CaptionState.isAudio ? "󰎆" : "󰈫"
                        color: Theme.primary
                        font.pixelSize: 14
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 110
                    spacing: 1

                    ShellText {
                        width: parent.width
                        elide: Text.ElideMiddle
                        text: CaptionState.pendingFileName || "Media File"
                        color: Theme.foreground
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    ShellText {
                        width: parent.width
                        elide: Text.ElideMiddle
                        text: CaptionState.pendingFile || ""
                        color: Theme.mutedDark
                        font.pixelSize: 9
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20
                    width: badgeText.implicitWidth + 14
                    radius: 10
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)

                    ShellText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: CaptionState.isAudio ? "AUDIO" : "VIDEO"
                        color: Theme.primary
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }
            }
        }

        // Action choices
        Column {
            width: parent.width
            spacing: 6

            // Option 1: Embed in Video (Only for video files)
            Rectangle {
                id: embedBtn
                visible: CaptionState.isVideo
                width: parent.width
                height: 42
                radius: Theme.radiusSmall
                color: embedHover.containsMouse ? Theme.bg1 : Theme.bg0
                border.width: 1
                border.color: embedHover.containsMouse ? Theme.primary : Qt.rgba(0.83, 0.78, 0.67, 0.12)
                scale: embedHover.pressed ? 0.98 : (embedHover.containsMouse ? 1.01 : 1.0)

                Behavior on scale { NumberAnimation { duration: Theme.animationFast; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.animationFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.animationFast } }

                MouseArea {
                    id: embedHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CaptionState.startCaption("embed")
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🎬"
                        font.pixelSize: 14
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 100
                        spacing: 1

                        ShellText {
                            text: "Embed in Video"
                            color: Theme.foreground
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        ShellText {
                            text: "Subtitled video + ~/Music/caption_extracts"
                            color: Theme.mutedDark
                            font.pixelSize: 9
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 18
                        width: 58
                        radius: 9
                        color: Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.18)

                        ShellText {
                            anchors.centerIn: parent
                            text: "Fast GPU"
                            color: Theme.green
                            font.pixelSize: 8
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            // Option 2: Caption File Only (.srt in video dir + ~/Music/caption_extracts)
            Rectangle {
                id: captionOnlyBtn
                width: parent.width
                height: 42
                radius: Theme.radiusSmall
                color: srtHover.containsMouse ? Theme.bg1 : Theme.bg0
                border.width: 1
                border.color: srtHover.containsMouse ? Theme.primary : Qt.rgba(0.83, 0.78, 0.67, 0.12)
                scale: srtHover.pressed ? 0.98 : (srtHover.containsMouse ? 1.01 : 1.0)

                Behavior on scale { NumberAnimation { duration: Theme.animationFast; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.animationFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.animationFast } }

                MouseArea {
                    id: srtHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CaptionState.startCaption("file_only")
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "📝"
                        font.pixelSize: 14
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 90
                        spacing: 1

                        ShellText {
                            text: CaptionState.isAudio ? "Generate Caption File (.srt)" : "Caption File Only (.srt)"
                            color: Theme.foreground
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        ShellText {
                            text: "Extract / transcribe into ~/Music/caption_extracts"
                            color: Theme.mutedDark
                            font.pixelSize: 9
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 18
                        width: 46
                        radius: 9
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)

                        ShellText {
                            anchors.centerIn: parent
                            text: ".SRT"
                            color: Theme.primary
                            font.pixelSize: 8
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            // Option 3: Stash in Pocket (Regular Shelf stash)
            Rectangle {
                width: parent.width
                height: 42
                radius: Theme.radiusSmall
                color: stashHover.containsMouse ? Theme.bg1 : Theme.bg0
                border.width: 1
                border.color: stashHover.containsMouse ? Theme.primary : Qt.rgba(0.83, 0.78, 0.67, 0.12)
                scale: stashHover.pressed ? 0.98 : (stashHover.containsMouse ? 1.01 : 1.0)

                Behavior on scale { NumberAnimation { duration: Theme.animationFast; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.animationFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.animationFast } }

                MouseArea {
                    id: stashHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CaptionState.stash()
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰏫"
                        color: Theme.muted
                        font.pixelSize: 15
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        ShellText {
                            text: "Stash in Pocket"
                            color: Theme.foreground
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        ShellText {
                            text: "Save to Drop Pocket shelf without captioning"
                            color: Theme.mutedDark
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }
    }
}
