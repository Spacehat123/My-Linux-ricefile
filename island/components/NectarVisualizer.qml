import QtQuick
import ".." as Island

Item {
    id: root

    property bool isPlaying: false
    property color barColor: "#ffffff"
    property real barHeight: 16
    property var levels: Island.IslandHub ? Island.IslandHub.levels : [0, 0, 0, 0]

    implicitWidth: 26
    implicitHeight: barHeight

    readonly property var rawData: {
        if (!isPlaying || !levels) return [0.18, 0.18, 0.18, 0.18, 0.18];
        let l0 = levels[0] || 0;
        let l1 = levels[1] || 0;
        let l2 = levels[2] || 0;
        let l3 = levels[3] || 0;
        if (l0 === 0 && l1 === 0 && l2 === 0 && l3 === 0)
            return [0.18, 0.18, 0.18, 0.18, 0.18];
        return [
            Math.max(0.18, Math.min(1.0, l0)),
            Math.max(0.18, Math.min(1.0, (l0 + l1) * 0.55)),
            Math.max(0.18, Math.min(1.0, l1)),
            Math.max(0.18, Math.min(1.0, (l1 + l2) * 0.55)),
            Math.max(0.18, Math.min(1.0, l2))
        ];
    }

    Row {
        anchors.centerIn: parent
        spacing: 2.5

        Repeater {
            model: 5

            Rectangle {
                id: bar
                required property int index

                width: 3
                radius: 1.5
                color: root.barColor
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.isPlaying ? 0.95 : 0.45

                height: root.isPlaying
                    ? Math.max(3, Math.round(root.rawData[index] * root.barHeight))
                    : 3

                Behavior on height {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.15
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        }
    }
}
