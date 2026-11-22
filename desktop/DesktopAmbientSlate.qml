import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Networking
import "../island" as Island

Item {
    id: root

    property bool active: true
    implicitWidth: 540
    implicitHeight: 180

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

    // Gentle 4-second polling timer for hardware telemetry
    Timer {
        interval: 4000
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

    // WiFi Integration
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var wifiDevice: Networking.devices.values.find((device) => device && device.type === "wifi")
    readonly property bool wifiConnected: {
        if (!wifiDevice || !wifiDevice.networks) return false;
        const nets = wifiDevice.networks.values;
        for (let i = 0; i < nets.length; ++i) {
            if (nets[i] && nets[i].connected) return true;
        }
        return false;
    }

    // Bluetooth Integration
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    readonly property bool btConnected: {
        if (!btAdapter || !btAdapter.devices) return false;
        const devs = btAdapter.devices.values;
        for (let i = 0; i < devs.length; ++i) {
            if (devs[i] && devs[i].connected) return true;
        }
        return false;
    }

    // Battery Icon Helper
    function getBatteryIcon(pct, charging) {
        if (charging) return "󰂄";
        if (pct >= 90) return "󰁹";
        if (pct >= 70) return "󰂀";
        if (pct >= 50) return "󰁾";
        if (pct >= 30) return "󰁼";
        if (pct >= 15) return "󰁻";
        return "󰂃";
    }

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
    // FLOATING BORDERLESS ARCHITECTURAL CLOCK + WEATHER + UNIFIED VITALS HUD
    // (ZERO CARDS, PURE ETHEREAL SURFACE)
    // =========================================================================
    Column {
        anchors.fill: parent
        spacing: 12

        // TOP ROW: Huge Architectural Timer + Small Weather Beside It
        Row {
            spacing: 28
            anchors.left: parent.left

            // 1. Huge Architectural Clock
            Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    spacing: 2

                    Text {
                        text: Qt.formatDateTime(sysClock.date, "hh")
                        font.pixelSize: 88
                        font.bold: true
                        font.letterSpacing: -1.0
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                    }

                    Text {
                        id: colonText
                        text: ":"
                        font.pixelSize: 82
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.active && root.visible
                            NumberAnimation { to: 0.25; duration: 1000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.00; duration: 1000; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        text: Qt.formatDateTime(sysClock.date, "mm")
                        font.pixelSize: 88
                        font.bold: true
                        font.letterSpacing: -1.0
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                    }
                }

                Text {
                    text: Qt.formatDateTime(sysClock.date, "dddd, dd MMMM yyyy").toUpperCase()
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2.2
                    font.family: Island.Theme.fontFamily
                    color: Island.Theme.muted
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                }
            }

            // 2. Small Weather Beside Clock (No Card Box, Floating Beside Clock)
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Row {
                    spacing: 8
                    anchors.left: parent.left

                    Text {
                        text: root.getWeatherIcon(Island.WeatherState ? Island.WeatherState.condition : "")
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 26
                        color: Island.Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: (Island.WeatherState && Island.WeatherState.tempC)
                            ? (String(Island.WeatherState.tempC).replace(/°/g, "") + "°C")
                            : "27°C"
                        font.pixelSize: 22
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: (Island.WeatherState && Island.WeatherState.condition) 
                        ? Island.WeatherState.condition 
                        : "Atmospheric Sync"
                    font.pixelSize: 11
                    font.family: Island.Theme.fontFamily
                    color: Island.Theme.foreground
                    opacity: 0.85
                }

                Text {
                    text: (Island.WeatherState && Island.WeatherState.area) 
                        ? Island.WeatherState.area 
                        : "Bangalore"
                    font.pixelSize: 10
                    font.family: Island.Theme.fontFamily
                    color: Island.Theme.muted
                }
            }
        }

        // BOTTOM ROW: Unified Vitals Chip ("battery/wifi/bluethooth/cpu/gpu/ram usage all bugged into one single good looking small icon")
        Rectangle {
            height: 28
            width: vitalsRow.implicitWidth + 24
            radius: 14
            color: Qt.rgba(14/255, 15/255, 24/255, 0.65)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            // Subtle inner glow
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
            }

            Row {
                id: vitalsRow
                anchors.centerIn: parent
                spacing: 10

                // Battery Glyph & Pct
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: root.getBatteryIcon(root.batteryPercent, root.isCharging)
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 12
                        color: root.isCharging ? Island.Theme.green : (root.batteryPercent <= 20 ? Island.Theme.red : Island.Theme.primary)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.batteryPercent + "%"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: root.isCharging ? Island.Theme.green : Island.Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Divider
                Rectangle {
                    width: 1
                    height: 10
                    color: Qt.rgba(1, 1, 1, 0.14)
                    anchors.verticalCenter: parent.verticalCenter
                }

                // WiFi Glyph
                Row {
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: root.wifiConnected ? "󰤨" : (root.wifiOn ? "󰤩" : "󰤭")
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 11
                        color: root.wifiConnected ? Island.Theme.primary : Island.Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Bluetooth Glyph
                Row {
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: root.btConnected ? "󰂱" : (root.btOn ? "󰂯" : "󰂲")
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 11
                        color: root.btConnected ? Island.Theme.primary : (root.btOn ? Island.Theme.foreground : Island.Theme.muted)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Divider
                Rectangle {
                    width: 1
                    height: 10
                    color: Qt.rgba(1, 1, 1, 0.14)
                    anchors.verticalCenter: parent.verticalCenter
                }

                // CPU
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "󰍛"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 11
                        color: Island.Theme.cyan
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.cpuPercent + "%"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // GPU / Temp
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "󰢮"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 11
                        color: Island.Theme.green
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: (root.tempC > 0 ? (root.tempC + "°C") : "GPU")
                        font.pixelSize: 10
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // RAM
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "󰘚"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 11
                        color: Island.Theme.purple
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.ramPercent + "%"
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
