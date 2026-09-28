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
            title: "Shelf"
            onCloseRequested: ShellState.close()
        }

        ShellText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Drag files onto the island to shelve them. Paths only; originals are never moved."
            color: Theme.muted
            font.pixelSize: 11
        }

        ShellText {
            visible: ShelfState.hasActiveDownload
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Downloading: " + ShelfState.compactText
            color: Theme.primary
            font.pixelSize: 12
        }

        Repeater {
            model: ShelfState.activeDownloads
            delegate: Row {
                required property var modelData
                width: content.width
                spacing: 8

                ShellText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "↓ " + modelData.name + " — " + modelData.sizeMB + " MB" + (Number(modelData.rateMBs) > 0 ? " @ " + modelData.rateMBs + " MB/s" : "")
                    color: Theme.muted
                    font.pixelSize: 11
                }
            }
        }

        ShellText {
            visible: !ShelfState.hasFiles
            width: parent.width
            text: "Shelf is empty."
            color: Theme.muted
            font.pixelSize: 12
        }

        Repeater {
            model: ShelfState.files
            delegate: Row {
                required property var modelData
                required property int index
                width: content.width
                spacing: 6

                ShellText {
                    width: parent.width - 130
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: modelData.name
                    font.pixelSize: 12
                }

                Rectangle {
                    width: 60
                    height: 28
                    radius: 14
                    color: openMouse.containsMouse ? Theme.primaryContainer : Theme.bg1

                    ShellText {
                        anchors.centerIn: parent
                        text: "Open"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: openMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShelfState.openFile(modelData.path)
                    }
                }

                Rectangle {
                    width: 58
                    height: 28
                    radius: 14
                    color: rmMouse.containsMouse ? Theme.red : Theme.bg1

                    ShellText {
                        anchors.centerIn: parent
                        text: "Drop"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: rmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShelfState.removeFile(index)
                    }
                }
            }
        }

        Rectangle {
            id: clearButton
            visible: ShelfState.hasFiles
            width: parent.width
            height: 30
            radius: 15
            color: clrMouse.containsMouse ? Theme.primaryContainer : Theme.bg1

            ShellText {
                anchors.centerIn: parent
                text: "Clear shelf"
                font.pixelSize: 12
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
