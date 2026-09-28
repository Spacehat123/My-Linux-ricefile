import QtQuick
import "components"

// Collapsed pill content: extremely compact live-activity status. No clock.
// Props are fed by Notch (single screen instance each). Shows at most:
// [unread bubble] [primary label] [mic dot] [cam dot], all elided to fit.
Item {
    id: root

    property int unread: 0
    property string label: ""
    property bool micActive: false
    property bool camActive: false
    property bool recActive: false
    property int shelfCount: 0
    property string weatherMini: ""

    implicitHeight: 24

    Row {
        anchors.centerIn: parent
        spacing: 5

        // Unread bubble: only when unread exist.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 9
            visible: root.unread > 0
            color: Theme.primary

            ShellText {
                anchors.centerIn: parent
                text: root.unread > 9 ? "9+" : String(root.unread)
                font.pixelSize: 10
                font.weight: Font.Bold
                color: "#000000"
            }
        }

        // Recording dot.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            visible: root.recActive
            color: Theme.red
        }

        // Primary activity label (single slot; shrinks when weather shares the pill).
        ShellText {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            width: Math.min(implicitWidth, root.weatherMini !== "" ? 68 : 104)
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.label
            color: root.recActive ? Theme.red : Theme.shellForeground
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        // Shelf count: only when idle (no primary label).
        ShellText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label === "" && root.shelfCount > 0
            text: "⧉ " + root.shelfCount
            color: Theme.muted
            font.pixelSize: 11
        }

        // Pinned weather: right side, alongside the label when one is shown.
        ShellText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.weatherMini !== ""
            text: root.weatherMini
            color: Theme.muted
            font.pixelSize: 11
        }

        // Mic: small YELLOW indicator, only while capturing.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            visible: root.micActive
            color: "#e5c535"
        }

        // Camera: small PURPLE indicator, only while held.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            visible: root.camActive
            color: "#c678dd"
        }
    }
}
