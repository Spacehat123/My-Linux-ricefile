import QtQuick
import Quickshell
import ".."
import "../components"

// Notification center: tracked notifications with dismiss-all.
// Opened from the island; opening marks the unread bubble as seen.
FocusScope {
    id: root

    property var notificationModel: IslandHub.notifModel

    function takeInitialFocus() {
        clearButton.forceActiveFocus(Qt.TabFocusReason);
    }

    implicitWidth: 337
    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 8

        PanelHeader {
            title: "Notifications"
            onCloseRequested: ShellState.close()
        }

        ShellText {
            visible: notifRepeater.count === 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: "No notifications."
            color: Theme.muted
            font.pixelSize: 12
        }

        Repeater {
            id: notifRepeater
            model: root.notificationModel
            delegate: NotificationCard {
                required property var modelData
                width: content.width
                notification: modelData
            }
        }

        Rectangle {
            id: clearButton
            visible: notifRepeater.count > 0
            width: parent.width
            height: 32
            radius: 16
            color: clearMouse.containsMouse ? Theme.primaryContainer : Theme.bg1

            ShellText {
                anchors.centerIn: parent
                text: "Dismiss all"
                font.pixelSize: 12
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    for (let i = notifRepeater.count - 1; i >= 0; --i) {
                        try {
                            const delegate = notifRepeater.itemAt(i);
                            if (delegate && delegate.notification)
                                delegate.notification.dismiss();
                        } catch (e) {
                        }
                    }
                    IslandHub.markSeen();
                }
            }
        }
    }
}
