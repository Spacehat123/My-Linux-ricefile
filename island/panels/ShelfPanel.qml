import QtQuick
import ".."
import "../components"

// File shelf: dropped files stay as stored paths (originals never moved).
// Also surfaces best-effort download progress (partial files in ~/Downloads).
FocusScope {
    id: root

    function takeInitialFocus() {
        clearButton.forceActiveFocus(Qt.TabFocusReason);
    }

    implicitWidth: 392
    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 8

        PanelHeader {
            title: "Drop Pocket"
            onCloseRequested: ShellState.close()
        }

        // Active downloads indicator
        Rectangle {
            visible: ShelfState.hasActiveDownload
            width: parent.width
            height: 38
            radius: Theme.radiusSmall
            color: Qt.rgba(0.0, 0.8, 0.6, 0.12)
            border.width: 1
            border.color: Qt.rgba(0.0, 0.8, 0.6, 0.3)

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↓"
                    color: Theme.primary
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 25
                    elide: Text.ElideRight
                    text: "Downloading: " + ShelfState.compactText
                    color: Theme.foreground
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }

        // Empty state: tactile card container
        Rectangle {
            visible: !ShelfState.hasFiles && !ShelfState.hasActiveDownload
            width: parent.width
            height: 94
            radius: Theme.radius
            color: Theme.bg0
            border.width: 1
            border.color: Qt.rgba(0.83, 0.78, 0.67, 0.1)

            Column {
                anchors.centerIn: parent
                spacing: 6

                ShellText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰏫"
                    color: Theme.mutedDark
                    font.pixelSize: 22
                }

                ShellText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Drop Pocket is empty"
                    color: Theme.foreground
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                ShellText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Drag files onto the island to stash across workspaces"
                    color: Theme.muted
                    font.pixelSize: 10
                }
            }
        }

        // Shelved files list
        Repeater {
            model: ShelfState.files
            delegate: Rectangle {
                id: fileCard
                required property var modelData
                required property int index
                width: content.width
                height: 44
                radius: Theme.radiusSmall
                color: itemHover.containsMouse ? Theme.bg1 : Theme.bg0
                border.width: 1
                border.color: itemHover.containsMouse ? Qt.rgba(0.83, 0.78, 0.67, 0.18) : Qt.rgba(0.83, 0.78, 0.67, 0.08)

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast }
                }

                MouseArea {
                    id: itemHover
                    anchors.fill: parent
                    hoverEnabled: true
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰈔"
                        color: Theme.primary
                        font.pixelSize: 16
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 150
                        spacing: 1

                        ShellText {
                            width: parent.width
                            elide: Text.ElideMiddle
                            text: fileCard.modelData.name
                            color: Theme.foreground
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        ShellText {
                            width: parent.width
                            elide: Text.ElideMiddle
                            text: fileCard.modelData.path
                            color: Theme.mutedDark
                            font.pixelSize: 9
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Rectangle {
                            width: 52
                            height: 26
                            radius: 13
                            color: openMouse.containsMouse ? Theme.primaryContainer : Theme.bg1
                            border.width: 1
                            border.color: openMouse.containsMouse ? Theme.primary : Qt.rgba(0.83, 0.78, 0.67, 0.15)

                            ShellText {
                                anchors.centerIn: parent
                                text: "Open"
                                color: openMouse.containsMouse ? Theme.foreground : Theme.muted
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: openMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ShelfState.openFile(fileCard.modelData.path)
                            }
                        }

                        Rectangle {
                            width: 32
                            height: 26
                            radius: 13
                            color: rmMouse.containsMouse ? Qt.rgba(0.9, 0.3, 0.3, 0.2) : Theme.bg1
                            border.width: 1
                            border.color: rmMouse.containsMouse ? Theme.red : Qt.rgba(0.83, 0.78, 0.67, 0.15)

                            ShellText {
                                anchors.centerIn: parent
                                text: "✕"
                                color: rmMouse.containsMouse ? Theme.red : Theme.mutedDark
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: rmMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ShelfState.removeFile(fileCard.index)
                            }
                        }
                    }
                }
            }
        }

        // Action controls when files exist
        Row {
            visible: ShelfState.hasFiles
            width: parent.width
            height: 32
            spacing: 8

            Rectangle {
                width: (parent.width - 8) / 2
                height: parent.height
                radius: Theme.radiusSmall
                color: openAllMouse.containsMouse ? Theme.primaryContainer : Theme.bg0
                border.width: 1
                border.color: openAllMouse.containsMouse ? Theme.primary : Qt.rgba(0.83, 0.78, 0.67, 0.12)

                ShellText {
                    anchors.centerIn: parent
                    text: "Open All"
                    color: Theme.foreground
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: openAllMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShelfState.openAllFiles()
                }
            }

            Rectangle {
                id: clearButton
                width: (parent.width - 8) / 2
                height: parent.height
                radius: Theme.radiusSmall
                color: clrMouse.containsMouse ? Qt.rgba(0.9, 0.3, 0.3, 0.15) : Theme.bg0
                border.width: 1
                border.color: clrMouse.containsMouse ? Theme.red : Qt.rgba(0.83, 0.78, 0.67, 0.12)

                ShellText {
                    anchors.centerIn: parent
                    text: "Clear Pocket"
                    color: clrMouse.containsMouse ? Theme.red : Theme.muted
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: clrMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShelfState.clear()
                }
            }
        }
    }
}
