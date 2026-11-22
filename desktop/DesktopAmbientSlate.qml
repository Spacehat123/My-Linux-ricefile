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
    implicitWidth: 320
    implicitHeight: 320

    // Architectural Clock Reference
    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    // Telemetry State
    property int cpuPercent: 0
    property int ramPercent: 0
    property int tempC: 0
    property int gpuPercent: 0

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

    Process {
        id: gpuProc
        command: [
            "sh", "-c",
            "cat /sys/class/drm/card1/device/gpu_busy_percent 2>/dev/null || echo 0"
        ]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const val = parseInt(data.trim()) || 0;
                root.gpuPercent = Math.max(0, Math.min(100, val));
            }
        }
    }

    // Gentle 3-second polling timer for hardware telemetry
    Timer {
        interval: 3000
        running: root.active && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!sysinfoProc.running) sysinfoProc.running = true;
            if (!gpuProc.running) gpuProc.running = true;
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
    readonly property string wifiSsid: {
        if (!wifiDevice || !wifiDevice.networks) return "Wi-Fi";
        const nets = wifiDevice.networks.values;
        for (let i = 0; i < nets.length; ++i) {
            if (nets[i] && nets[i].connected) return nets[i].name || "Connected";
        }
        return wifiOn ? "Disconnected" : "Off";
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
    // ARCHITECTURAL HUD LAYOUT
    // - Huge Vertical Stacked Clock (14: on top, 43 on bottom)
    // - Weather on the Top-Right of the clock
    // - Hand-Drawn Radial Vitals Ring on the Bottom-Left of the clock
    // =========================================================================
    Row {
        id: mainRow
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: 20

        // LEFT COLUMN: Stacked Clock + Date + Bottom-Left Radial Telemetry Dial
        Column {
            id: leftCol
            spacing: 12

            // 1. Stacked Vertical Clock (Hours + Colon on top, Minutes below)
            Column {
                id: clockStack
                spacing: -14

                // Top Line: Hours + Colon (14:)
                Row {
                    spacing: 2
                    Text {
                        text: Qt.formatDateTime(sysClock.date, "hh")
                        font.pixelSize: 84
                        font.bold: true
                        font.letterSpacing: -1.0
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                    }

                    Text {
                        id: colonText
                        text: ":"
                        font.pixelSize: 80
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
                }

                // Bottom Line: Minutes (43)
                Text {
                    text: Qt.formatDateTime(sysClock.date, "mm")
                    font.pixelSize: 84
                    font.bold: true
                    font.letterSpacing: -1.0
                    font.family: Island.Theme.fontFamily
                    color: Island.Theme.foreground
                }
            }

            // Date Subtitle
            Text {
                text: Qt.formatDateTime(sysClock.date, "ddd, dd MMM yyyy").toUpperCase()
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 2.0
                font.family: Island.Theme.fontFamily
                color: Island.Theme.muted
                anchors.left: parent.left
                anchors.leftMargin: 2
            }

            // 2. Bottom-Left Radial Telemetry Ring (Hand-Drawn Sketch Implementation)
            Item {
                id: radialVitalsDial
                width: 72
                height: 72
                anchors.left: parent.left
                anchors.leftMargin: 2

                HoverHandler {
                    id: dialHover
                }

                // Background soft halo
                Rectangle {
                    anchors.centerIn: parent
                    width: 64
                    height: 64
                    radius: 32
                    color: Qt.rgba(14/255, 15/255, 24/255, 0.45)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                }

                // 4 Quadrant Segmented Circular Gauges
                // Circle Center: (36, 36), Radius: 28px, Stroke: 4px
                Shape {
                    id: radialGauges
                    anchors.fill: parent
                    layer.enabled: true
                    layer.smooth: true

                    // ── TOP ARC: GPU ─────────────────────────────────────────
                    // Track (80 degree span centered at top: 230 to 310)
                    ShapePath {
                        strokeWidth: 4
                        strokeColor: Qt.rgba(1, 1, 1, 0.14)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 36; centerY: 36
                            radiusX: 28; radiusY: 28
                            startAngle: 230
                            sweepAngle: 80
                        }
                    }
                    // Fill
                    ShapePath {
                        strokeWidth: 4
                        strokeColor: Island.Theme.green
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 36; centerY: 36
                            radiusX: 28; radiusY: 28
                            startAngle: 230
                            sweepAngle: Math.max(3, (root.gpuPercent / 100.0) * 80)
                        }
                    }

                    // ── RIGHT ARC: CPU ───────────────────────────────────────
                    // Track (80 degree span centered at right: -40 to 40)
                    ShapePath {
                        strokeWidth: 4
                        strokeColor: Qt.rgba(1, 1, 1, 0.14)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 36; centerY: 36
                            radiusX: 28; radiusY: 28
                            startAngle: -40
                            sweepAngle: 80
                        }
                    }
                    // Fill
                    ShapePath {
                        strokeWidth: 4
                        strokeColor: Island.Theme.cyan
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 36; centerY: 36
                            radiusX: 28; radiusY: 28
                            startAngle: -40
                            sweepAngle: Math.max(3, (root.cpuPercent / 100.0) * 80)
                        }
                    }

                    // ── BOTTOM ARC: BATTERY ──────────────────────────────────
                    // Track (80 degree span centered at bottom: 50 to 130)
                    ShapePath {
                        strokeWidth: 4
                        strokeColor: Qt.rgba(1, 1, 1, 0.14)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 36; centerY: 36
                            radiusX: 28; radiusY: 28
                            startAngle: 50
                            sweepAngle: 80
                        }
                    }
                    // Fill
                    ShapePath {
                        strokeWidth: 4
                        strokeColor: root.isCharging ? Island.Theme.green : (root.batteryPercent <= 20 ? Island.Theme.red : Island.Theme.primary)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 36; centerY: 36
                            radiusX: 28; radiusY: 28
                            startAngle: 50
                            sweepAngle: Math.max(3, (root.batteryPercent / 100.0) * 80)
                        }
                    }

                    // ── LEFT ARC: RAM ────────────────────────────────────────
                    // Track (80 degree span centered at left: 140 to 220)
                    ShapePath {
                        strokeWidth: 4
                        strokeColor: Qt.rgba(1, 1, 1, 0.14)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 36; centerY: 36
                            radiusX: 28; radiusY: 28
                            startAngle: 140
                            sweepAngle: 80
                        }
                    }
                    // Fill
                    ShapePath {
                        strokeWidth: 4
                        strokeColor: Island.Theme.purple
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 36; centerY: 36
                            radiusX: 28; radiusY: 28
                            startAngle: 140
                            sweepAngle: Math.max(3, (root.ramPercent / 100.0) * 80)
                        }
                    }
                }

                // ── CENTER OF RING: BLUETOOTH (TOP) & WIFI (BOTTOM) ─────────
                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    // Bluetooth Symbol
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.btConnected ? "󰂱" : (root.btOn ? "󰂯" : "󰂲")
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 13
                        color: root.btConnected ? Island.Theme.primary : (root.btOn ? Island.Theme.foreground : Island.Theme.muted)
                    }

                    // Wi-Fi Symbol
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.wifiConnected ? "󰤨" : (root.wifiOn ? "󰤩" : "󰤭")
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 12
                        color: root.wifiConnected ? Island.Theme.primary : (root.wifiOn ? Island.Theme.foreground : Island.Theme.muted)
                    }
                }

                // Hover Telemetry HUD Card (Appears smoothly on dial hover)
                Rectangle {
                    id: hoverTooltip
                    anchors.left: parent.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 140
                    height: 94
                    radius: 12
                    color: Qt.rgba(14/255, 15/255, 24/255, 0.88)
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1
                    opacity: dialHover.hovered ? 1.0 : 0.0
                    visible: opacity > 0.0
                    z: 10

                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 3

                        Text {
                            text: "GPU: " + root.gpuPercent + "% " + (root.tempC > 0 ? ("(" + root.tempC + "°C)") : "")
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: Island.Theme.green
                        }
                        Text {
                            text: "CPU: " + root.cpuPercent + "%"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: Island.Theme.cyan
                        }
                        Text {
                            text: "RAM: " + root.ramPercent + "%"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: Island.Theme.purple
                        }
                        Text {
                            text: "BAT: " + root.batteryPercent + "% " + (root.isCharging ? "⚡" : "")
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.isCharging ? Island.Theme.green : Island.Theme.primary
                        }
                        Text {
                            text: "NET: " + (root.wifiConnected ? root.wifiSsid : (root.wifiOn ? "Disconnected" : "Off"))
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 9
                            color: Island.Theme.muted
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }
            }
        }

        // RIGHT COLUMN: Weather on the Top-Right of the Clock
        Column {
            id: rightCol
            anchors.top: leftCol.top
            anchors.topMargin: 4
            spacing: 4

            // Temperature Row
            Row {
                spacing: 6
                Text {
                    text: root.getWeatherIcon(Island.WeatherState ? Island.WeatherState.condition : "")
                    font.family: Island.Theme.iconFontFamily
                    font.pixelSize: 22
                    color: Island.Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: (Island.WeatherState && Island.WeatherState.tempC)
                        ? (String(Island.WeatherState.tempC).replace(/°/g, "") + "°C")
                        : "28°C"
                    font.pixelSize: 24
                    font.bold: true
                    font.family: Island.Theme.fontFamily
                    color: Island.Theme.foreground
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Condition Tag
            Text {
                text: (Island.WeatherState && Island.WeatherState.condition) 
                    ? Island.WeatherState.condition 
                    : "Smoky haze"
                font.pixelSize: 12
                font.family: Island.Theme.fontFamily
                color: Island.Theme.foreground
                opacity: 0.85
            }

            // Location
            Text {
                text: (Island.WeatherState && Island.WeatherState.area) 
                    ? Island.WeatherState.area 
                    : "Bangalore"
                font.pixelSize: 11
                font.family: Island.Theme.fontFamily
                color: Island.Theme.muted
            }
        }
    }
}
