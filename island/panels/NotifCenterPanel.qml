import QtQuick
import Quickshell
import ".."
import "../components"

// Notification center: persistent tracked notifications with dismiss-all.
// Opened from the Dynamic Island; notifications remain until explicitly dismissed.
FocusScope {
    id: root

    property var notificationModel: IslandHub.notifModel

    function takeInitialFocus() {
        if (notifRepeater.count > 0) {
            clearButton.forceActiveFocus(Qt.TabFocusReason);
        }
    }

    implicitWidth: 365
    implicitHeight: Math.min(420, Math.max(80, content.implicitHeight))

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

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
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "No notifications"
                color: Theme.muted
                font.pixelSize: 12
                topPadding: 10
                bottomPadding: 10
            }

            Repeater {
                id: notifRepeater
                model: root.notificationModel
                delegate: NotificationCard {
                    required property var modelData
                    width: content.width
                    notification: modelData
                    isPopup: false
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
                        const tracked = root.notificationModel && root.notificationModel.values ? root.notificationModel.values : [];
                        for (let i = tracked.length - 1; i >= 0; --i) {
                            try {
                                if (tracked[i] && tracked[i].dismiss)
                                    tracked[i].dismiss();
                            } catch (e) {}
                        }
                        for (let i = notifRepeater.count - 1; i >= 0; --i) {
                            try {
                                const delegate = notifRepeater.itemAt(i);
                                if (delegate && delegate.notification && delegate.notification.dismiss)
                                    delegate.notification.dismiss();
                            } catch (e) {}
                        }
                        gc();
                        IslandHub.markSeen();
                    }
                }
            }
        }
    }
}
