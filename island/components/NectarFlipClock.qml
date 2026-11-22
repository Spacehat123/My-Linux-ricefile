import QtQuick
import Quickshell.Services.UPower
import ".." as Island

Item {
    id: root

    property bool showTimer: Island.TimerState ? (Island.TimerState.hasActive || Island.TimerState.completionHold) : false
    property string timerText: Island.TimerState ? Island.TimerState.compactText : ""
    property bool timerDone: Island.TimerState ? Island.TimerState.completionHold : false

    // UPower battery integration
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery ? (battery.ready && battery.percentage >= 0) : false
    readonly property int batteryPercent: battery ? Math.round(battery.percentage * 100) : 100
    readonly property bool isCharging: battery ? (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged) : false
    readonly property string weatherTemp: (Island.WeatherState && Island.WeatherState.tempC !== "") ? (String(Island.WeatherState.tempC).replace(/°/g, "").trim() + "°C") : "--°C"

    // Carousel mode: 0 = Time, 1 = Weather & Temp, 2 = Battery info
    property int carouselMode: 0

    implicitWidth: Math.max(clockLabel.implicitWidth, timerLabel.implicitWidth, weatherRow.implicitWidth, batRow.implicitWidth) + 8
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

    // Periodically (every 11s) flips between Time, Weather, and Battery
    Timer {
        id: carouselTimer
        interval: 11000
        running: !root.showTimer
        repeat: true
        onTriggered: {
            if (!root.showTimer) {
                flipTransition.restart();
            }
        }
    }

    SequentialAnimation {
        id: flipTransition
        NumberAnimation {
            target: rotFlip
            property: "angle"
            to: 90
            duration: 180
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                root.carouselMode = (root.carouselMode + 1) % (root.hasBattery ? 3 : 2);
                rotFlip.angle = -90;
            }
        }
        NumberAnimation {
            target: rotFlip
            property: "angle"
            to: 0
            duration: 240
            easing.type: Easing.OutBack
            easing.overshoot: 1.25
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

        // Side A: Ambient Carousel (Time -> Weather -> Battery) (Angle 0)
        Item {
            id: sideAContainer
            anchors.fill: parent
            opacity: rotX.angle < 90 ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            transform: Rotation {
                id: rotFlip
                origin.x: sideAContainer.width / 2
                origin.y: sideAContainer.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: 0
            }

            // Carousel Item 0: Time
            Text {
                id: clockLabel
                anchors.centerIn: parent
                visible: root.carouselMode === 0
                text: root.currentTimeString
                font.family: Island.Theme ? Island.Theme.fontFamily : "Inter"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: "#ffffff"
            }

            // Carousel Item 1: Weather & Temp
            Row {
                id: weatherRow
                anchors.centerIn: parent
                visible: root.carouselMode === 1
                spacing: 4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰖐"
                    font.family: Island.Theme ? Island.Theme.iconFontFamily : "JetBrainsMonoNL Nerd Font"
                    font.pixelSize: 11
                    color: Island.Theme ? Island.Theme.primary : "#e8799e"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.weatherTemp
                    font.family: Island.Theme ? Island.Theme.fontFamily : "Inter"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: "#ffffff"
                }
            }

            // Carousel Item 2: Battery Info
            Row {
                id: batRow
                anchors.centerIn: parent
                visible: root.carouselMode === 2
                spacing: 4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.isCharging ? "󰂄" : (root.batteryPercent > 20 ? "󰁹" : "󰂃")
                    font.family: Island.Theme ? Island.Theme.iconFontFamily : "JetBrainsMonoNL Nerd Font"
                    font.pixelSize: 11
                    color: root.batteryPercent <= 20 ? "#ff453a" : (Island.Theme ? Island.Theme.green : "#32D74B")
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batteryPercent + "%"
                    font.family: Island.Theme ? Island.Theme.fontFamily : "Inter"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: "#ffffff"
                }
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
