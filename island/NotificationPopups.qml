import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    property var activeToasts: []

    function showToast(notification) {
        if (!notification)
            return;
        let list = (activeToasts || []).slice();
        // Avoid duplicate toasts for the same notification id
        list = list.filter(n => n && n.id !== notification.id);
        list.push(notification);
        activeToasts = list;
    }

    function dismissToast(id) {
        let list = (activeToasts || []).slice();
        activeToasts = list.filter(n => n && n.id !== id);
    }

    implicitWidth: 390
    implicitHeight: screen ? screen.height - 28 : popupStack.implicitHeight
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    visible: !IslandHub.dnd && activeToasts.length > 0
    WlrLayershell.namespace: "vyeos-notifications"

    anchors {
        top: true
        right: true
    }

    margins {
        top: 14
        right: 14
    }

    Column {
        id: popupStack

        width: parent.width
        spacing: 8

        Repeater {
            model: window.activeToasts

            delegate: NotificationCard {
                required property var modelData

                width: popupStack.width
                notification: modelData
                isPopup: true
                onDismissToastRequested: {
                    window.dismissToast(modelData.id);
                }
            }
        }
    }

    mask: Region {
        item: popupStack
    }
}
