import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../island" as Island

Item {
    id: root

    property bool active: true
    implicitWidth: 500
    implicitHeight: 260

    // Architectural Clock Reference
    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    // Telemetry State
    property int cpuPercent: 0
    property int ramPercent: 0
    property int tempC: 0

    Process {
        id: sysinfoProc
        command: [Quickshell.shellPath("island/scripts/sysinfo.sh")]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const obj = JSON.parse(data.trim());
                    if (obj.cpu !== undefined) root.cpuPercent = obj.cpu;
                    if (obj.ram !== undefined) root.ramPercent = obj.ram;
                    if (obj.temp !== undefined) root.tempC = obj.temp;
                } catch(e) {}
            }
        }
    }

    // Gentle 5-second polling timer for hardware telemetry dots
    Timer {
        interval: 5000
        running: root.active && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!sysinfoProc.running)
                sysinfoProc.running = true;
        }
    }

    // Battery Integration from UPower
    readonly property var batteryDevice: UPower.displayDevice
    readonly property int batteryPercent: batteryDevice ? Math.round(batteryDevice.percentage * 100) : 100
    readonly property bool isCharging: batteryDevice ? (!UPower.onBattery || batteryDevice.state === UPowerDeviceState.Charging || batteryDevice.state === UPowerDeviceState.FullyCharged) : false

    // Weather Icon Resolution
    function getWeatherIcon(cond) {
        if (!cond) return "󰖐";
        const c = cond.toLowerCase();
        if (c.includes("sun") || c.includes("clear")) return "󰖙";
        if (c.includes("rain") || c.includes("drizzle") || c.includes("shower")) return "󰖗";
        if (c.includes("thunder") || c.includes("storm")) return "󰖓";
        if (c.includes("snow") || c.includes("ice") || c.includes("sleet")) return "󰖘";
        if (c.includes("fog") || c.includes("mist") || c.includes("haze")) return "󰖑";
        return "󰖐";
    }

    // =========================================================================
    // SLATE BODY: Frosted Glass Plate with Inner Caustic Rim
    // =========================================================================
    Rectangle {
        id: slatePlate
        anchors.fill: parent
        radius: 38
        // Translucent midnight glass (30% more transparent, preserving frosted glass blur)
        color: Qt.rgba(Island.Theme.bg0.r, Island.Theme.bg0.g, Island.Theme.bg0.b, 0.38)
        border.color: Island.Theme.glassBorder
        border.width: 0
        clip: true

        // Inner 1px Refractive Rim
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 37
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            z: 1
        }

        // Top Specular Highlight Strip
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 1
            height: 1
            color: Qt.rgba(1, 1, 1, 0.12)
            z: 2
        }

        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // TOP ROW: Architectural Clock Typography & Live Weather
            Row {
                width: parent.width
                height: 110
                spacing: 20

                // 1. Clock Block
                Column {
                    width: parent.width - 180
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Row {
                        spacing: 2
                        Text {
                            text: Qt.formatDateTime(sysClock.date, "hh")
                            font.pixelSize: 62
                            font.bold: true
                            font.letterSpacing: 1.5
                            font.family: Island.Theme.fontFamily
                            width: 80
                            horizontalAlignment: Text.AlignHCenter
                            color: Island.Theme.foreground
                        }

                        Text {
                            id: colonText
                            text: ":"
                            font.pixelSize: 58
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: root.active && root.visible
                                NumberAnimation { to: 0.28; duration: 1000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.00; duration: 1000; easing.type: Easing.InOutSine }
                            }
                        }

                        Text {
                            text: Qt.formatDateTime(sysClock.date, "mm")
                            font.pixelSize: 62
                            font.bold: true
                            font.letterSpacing: 1.5
                            font.family: Island.Theme.fontFamily
                            width: 80
                            horizontalAlignment: Text.AlignHCenter
                            color: Island.Theme.foreground
                        }
                    }

                    Text {
                        text: Qt.formatDateTime(sysClock.date, "dddd, dd MMMM yyyy").toUpperCase()
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 2.0
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.muted
                    }
                }

                // 2. Weather Condition Card
                Rectangle {
                    width: 160
                    height: 104
                    radius: 28
                    color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.10)
                    border.color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25)
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        Row {
                            spacing: 8
                            anchors.horizontalCenter: parent.horizontalCenter

                            Text {
                                text: root.getWeatherIcon(Island.WeatherState ? Island.WeatherState.condition : "")
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 28
                                color: Island.Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: (Island.WeatherState && Island.WeatherState.tempC)
                                    ? (String(Island.WeatherState.tempC).replace(/°/g, "") + "°C")
                                    : "24°C"
                                font.pixelSize: 22
                                font.bold: true
                                font.family: Island.Theme.fontFamily
                                color: Island.Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Weather Condition & Area Tag
                        Rectangle {
                            width: parent.width
                            height: 22
                            radius: 11
                            color: Qt.rgba(1, 1, 1, 0.08)
                            anchors.horizontalCenter: parent.horizontalCenter

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 12
                                text: (Island.WeatherState && Island.WeatherState.condition) 
                                    ? (Island.WeatherState.condition) 
                                    : "Atmospheric Sync"
                                font.pixelSize: 9
                                font.bold: true
                                font.family: Island.Theme.fontFamily
                                color: Island.Theme.muted
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        // Precipitation / Area Pill
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (Island.WeatherState && Island.WeatherState.area) ? Island.WeatherState.area : "Local Radar"
                            font.pixelSize: 9
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.muted
                            opacity: 1
                            elide: Text.ElideRight
                        }
                    }
                }
            }



            // BOTTOM ROW: Battery Charge Ring & Mini Hardware Telemetry Dots
            Row {
                width: parent.width
                height: 52
                spacing: 16

                // Battery Ring Section
                Row {
                    spacing: 12
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width: 44
                        height: 44
                        anchors.verticalCenter: parent.verticalCenter

                        Shape {
                            id: batteryShape
                            anchors.fill: parent
                            layer.enabled: true
                            layer.smooth: true

                            // Track
                            ShapePath {
                                strokeWidth: 3.5
                                strokeColor: Qt.rgba(1, 1, 1, 0.12)
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap

                                PathAngleArc {
                                    centerX: batteryShape.width / 2
                                    centerY: batteryShape.height / 2
                                    radiusX: (batteryShape.width - 4) / 2
                                    radiusY: (batteryShape.height - 4) / 2
                                    startAngle: 0
                                    sweepAngle: 360
                                }
                            }

                            // Active Charge Arc
                            ShapePath {
                                strokeWidth: 3.5
                                strokeColor: root.batteryPercent <= 20 
                                    ? Island.Theme.red 
                                    : (root.isCharging ? Island.Theme.green : Island.Theme.primary)
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap

                                PathAngleArc {
                                    centerX: batteryShape.width / 2
                                    centerY: batteryShape.height / 2
                                    radiusX: (batteryShape.width - 4) / 2
                                    radiusY: (batteryShape.height - 4) / 2
                                    startAngle: -90
                                    sweepAngle: Math.max(0.1, Math.min(360, (root.batteryPercent / 100.0) * 360))
                                }
                            }
                        }

                        // Centered Glyph
                        Text {
                            anchors.centerIn: parent
                            text: root.isCharging ? "󱐋" : (root.batteryPercent + "%")
                            font.pixelSize: root.isCharging ? 16 : 9
                            font.bold: true
                            font.family: root.isCharging ? Island.Theme.iconFontFamily : Island.Theme.fontFamily
                            color: root.isCharging ? Island.Theme.green : Island.Theme.foreground
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: root.isCharging ? "Charging" : (root.batteryPercent + "% Battery")
                            font.pixelSize: 11
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                        }
                        Text {
                            text: root.isCharging ? "AC Power Connected" : "On Battery"
                            font.pixelSize: 9
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.muted
                        }
                    }
                }



                // Mini Hardware Telemetry Dots
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

                    // CPU Metric
                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: Island.Theme.cyan
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.cpuPercent + "% CPU"
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // RAM Metric
                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: Island.Theme.purple
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.ramPercent + "% RAM"
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Thermal Metric
                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: Island.Theme.yellow
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.tempC + "°C"
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
