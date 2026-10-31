import QtQuick
import ".." as Island

Item {
    id: root

    property bool showTimer: Island.TimerState ? (Island.TimerState.hasActive || Island.TimerState.completionHold) : false
    property string timerText: Island.TimerState ? Island.TimerState.compactText : ""
    property bool timerDone: Island.TimerState ? Island.TimerState.completionHold : false

    implicitWidth: Math.max(clockLabel.implicitWidth, timerLabel.implicitWidth) + 6
    implicitHeight: 20

    property string currentTimeString: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let d = new Date();
            let h = d.getHours();
            let m = String(d.getMinutes()).padStart(2, '0');
            root.currentTimeString = (h < 10 ? "0" + h : h) + ":" + m;
        }
    }

    Item {
        id: container
        anchors.fill: parent
        transformOrigin: Item.Center

        transform: Rotation {
            id: rotX
            origin.x: container.width / 2
            origin.y: container.height / 2
            axis { x: 1; y: 0; z: 0 }
            angle: root.showTimer ? 180 : 0

            Behavior on angle {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.25
                }
            }
        }

        // Side A: Digital Clock (Angle 0)
        Text {
            id: clockLabel
            anchors.centerIn: parent
            text: root.currentTimeString
            font.family: Island.Theme ? Island.Theme.fontFamily : "Inter"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: "#ffffff"
            opacity: rotX.angle < 90 ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        // Side B: Timer / Focus Readout (Angle 180, flipped upside down to appear upright)
        Item {
            anchors.fill: parent
            opacity: rotX.angle >= 90 ? 1.0 : 0.0
            visible: opacity > 0.01
            rotation: 180
            transformOrigin: Item.Center

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            Text {
                id: timerLabel
                anchors.centerIn: parent
                text: root.timerText !== "" ? root.timerText : "00:00"
                font.family: Island.Theme ? Island.Theme.fontFamily : "Inter"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: root.timerDone ? "#ff453a" : (Island.Theme ? Island.Theme.primary : "#32D74B")

                SequentialAnimation on scale {
                    running: root.timerDone
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.15; duration: 400; easing.type: Easing.OutCubic }
                    NumberAnimation { from: 1.15; to: 1.0; duration: 400; easing.type: Easing.InCubic }
                }
            }
        }
    }
}
