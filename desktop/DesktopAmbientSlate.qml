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
    property string template: AmbientConfig.template
    implicitWidth: mainRow.implicitWidth
    implicitHeight: mainRow.implicitHeight

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

        // LEFT COLUMN: Clock + Date + Telemetry Elements
        Column {
            id: leftCol
            spacing: 12

            // 1A. Template "pranc": Horizontal Clock (Hours | Minutes with 0.5 alpha line)
            Row {
                id: clockRow
                visible: root.template === "pranc"
                spacing: 20

                // Hours
                Text {
                    text: Qt.formatDateTime(sysClock.date, "hh")
                    font.pixelSize: 220
                    font.bold: true
                    font.letterSpacing: -4.0
                    font.family: "Geom"
                    color: Island.Theme.foreground
                    renderType: Text.QtRendering
                }

                // Separator Line (0.5 Alpha)
                Rectangle {
                    id: separatorLine
                    width: 2
                    height: 140
                    radius: 1
                    color: Island.Theme.foreground
                    opacity: 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 8
                }

                // Minutes
                Text {
                    text: Qt.formatDateTime(sysClock.date, "mm")
                    font.pixelSize: 220
                    font.bold: true
                    font.letterSpacing: -4.0
                    font.family: "Geom"
                    color: Island.Theme.foreground
                    renderType: Text.QtRendering
                }
            }

            // 1B. Template "default": Classic Clean Vertical Stacked Clock (18 over 33)
            Column {
                id: stackedClockCol
                visible: root.template === "default"
                spacing: -22

                Text {
                    text: Qt.formatDateTime(sysClock.date, "hh")
                    font.pixelSize: 180
                    font.bold: true
                    font.letterSpacing: -4.0
                    font.family: "Geom"
                    color: Island.Theme.foreground
                    renderType: Text.QtRendering
                }

                Text {
                    text: Qt.formatDateTime(sysClock.date, "mm")
                    font.pixelSize: 180
                    font.bold: true
                    font.letterSpacing: -4.0
                    font.family: "Geom"
                    color: Island.Theme.foreground
                    renderType: Text.QtRendering
                }
            }

            // 1C. Template "minimal": Sleek Horizontal Single-Line Clock (HH:MM)
            Row {
                id: minimalClockRow
                visible: root.template === "minimal"
                spacing: 14

                Text {
                    text: Qt.formatDateTime(sysClock.date, "hh:mm")
                    font.pixelSize: 110
                    font.bold: true
                    font.letterSpacing: -3.0
                    font.family: "Geom"
                    color: Island.Theme.foreground
                    renderType: Text.QtRendering
                }
            }

            // Date Subtitle
            Text {
                text: Qt.formatDateTime(sysClock.date, "ddd, dd MMM yyyy").toUpperCase()
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 2.0
                font.family: Island.Theme.fontFamily
                color: Island.Theme.muted
                anchors.left: parent.left
                anchors.leftMargin: 2
                renderType: Text.QtRendering
            }

            // 2A. Template "default": Modern Horizontal Telemetry Chips Row
            Row {
                id: telemetryChipsRow
                visible: root.template === "default"
                spacing: 8

                // GPU Chip
                Rectangle {
                    height: 26
                    width: gpuText.implicitWidth + 24
                    radius: 13
                    color: Island.Theme.glassCard
                    border.color: Island.Theme.glassBorderSubtle
                    border.width: 1
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Rectangle { width: 6; height: 6; radius: 3; color: "#10b981"; anchors.verticalCenter: parent.verticalCenter }
                        Text { id: gpuText; text: "GPU " + root.gpuPercent + "%"; font.pixelSize: 10; font.bold: true; font.family: Island.Theme.fontFamily; color: Island.Theme.foreground }
                    }
                }

                // CPU Chip
                Rectangle {
                    height: 26
                    width: cpuText.implicitWidth + 24
                    radius: 13
                    color: Island.Theme.glassCard
                    border.color: Island.Theme.glassBorderSubtle
                    border.width: 1
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Rectangle { width: 6; height: 6; radius: 3; color: "#06b6d4"; anchors.verticalCenter: parent.verticalCenter }
                        Text { id: cpuText; text: "CPU " + root.cpuPercent + "%"; font.pixelSize: 10; font.bold: true; font.family: Island.Theme.fontFamily; color: Island.Theme.foreground }
                    }
                }

                // RAM Chip
                Rectangle {
                    height: 26
                    width: ramText.implicitWidth + 24
                    radius: 13
                    color: Island.Theme.glassCard
                    border.color: Island.Theme.glassBorderSubtle
                    border.width: 1
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Rectangle { width: 6; height: 6; radius: 3; color: "#a855f7"; anchors.verticalCenter: parent.verticalCenter }
                        Text { id: ramText; text: "RAM " + root.ramPercent + "%"; font.pixelSize: 10; font.bold: true; font.family: Island.Theme.fontFamily; color: Island.Theme.foreground }
                    }
                }

                // BAT Chip
                Rectangle {
                    height: 26
                    width: batText.implicitWidth + 24
                    radius: 13
                    color: Island.Theme.glassCard
                    border.color: Island.Theme.glassBorderSubtle
                    border.width: 1
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Rectangle { width: 6; height: 6; radius: 3; color: root.isCharging ? "#10b981" : (root.batteryPercent <= 20 ? "#ef4444" : "#3b82f6"); anchors.verticalCenter: parent.verticalCenter }
                        Text { id: batText; text: "BAT " + root.batteryPercent + "%"; font.pixelSize: 10; font.bold: true; font.family: Island.Theme.fontFamily; color: Island.Theme.foreground }
                    }
                }
            }

            // 2B. Template "minimal": Compact Inline Telemetry Pill
            Row {
                id: minimalTelemetryRow
                visible: root.template === "minimal"
                spacing: 10
                Text {
                    text: ((Island.WeatherState && Island.WeatherState.area) ? Island.WeatherState.area : "Bangalore") + " • " +
                          ((Island.WeatherState && Island.WeatherState.tempC) ? (String(Island.WeatherState.tempC).replace(/°/g, "") + "°C") : "28°C") + " • " +
                          "BAT " + root.batteryPercent + "%" + (root.isCharging ? " ⚡" : "")
                    font.pixelSize: 11
                    font.family: Island.Theme.fontFamily
                    color: Island.Theme.muted
                }
            }

            // 2C. Template "pranc": Bottom-Left Radial Telemetry Ring (4 Separated Small Lines)
            Item {
                id: radialVitalsDial
                visible: root.template === "pranc"
                width: 80
                height: 80
                anchors.left: parent.left
                anchors.leftMargin: 2

                HoverHandler {
                    id: dialHover
                }

                // 4 Quadrant Segmented Thin Arc Lines with distinct physical separation
                // Center: (40, 40), Radius: 30px, Small Line Stroke: 3px
                // 70-degree span per line with 20-degree clear open gap between lines
                Shape {
                    id: radialGauges
                    anchors.fill: parent
                    layer.enabled: true
                    layer.samples: 4
                    layer.smooth: true

                    // ── TOP LINE: GPU (Emerald Green) ────────────────────────
                    // Track line (start: 235, sweep: 70)
                    ShapePath {
                        strokeWidth: 3
                        strokeColor: Qt.rgba(255, 255, 255, 0.16)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 40; centerY: 40
                            radiusX: 30; radiusY: 30
                            startAngle: 235
                            sweepAngle: 70
                        }
                    }
                    // Active Fill Line
                    ShapePath {
                        strokeWidth: 3
                        strokeColor: "#10b981"
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 40; centerY: 40
                            radiusX: 30; radiusY: 30
                            startAngle: 235
                            sweepAngle: Math.max(3, (root.gpuPercent / 100.0) * 70)
                        }
                    }

                    // ── RIGHT LINE: CPU (Cyan) ───────────────────────────────
                    // Track line (start: 325, sweep: 70)
                    ShapePath {
                        strokeWidth: 3
                        strokeColor: Qt.rgba(255, 255, 255, 0.16)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 40; centerY: 40
                            radiusX: 30; radiusY: 30
                            startAngle: 325
                            sweepAngle: 70
                        }
                    }
                    // Active Fill Line
                    ShapePath {
                        strokeWidth: 3
                        strokeColor: "#06b6d4"
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 40; centerY: 40
                            radiusX: 30; radiusY: 30
                            startAngle: 325
                            sweepAngle: Math.max(3, (root.cpuPercent / 100.0) * 70)
                        }
                    }

                    // ── BOTTOM LINE: BATTERY (Emerald / Blue / Red) ───────────
                    // Track line (start: 55, sweep: 70)
                    ShapePath {
                        strokeWidth: 3
                        strokeColor: Qt.rgba(255, 255, 255, 0.16)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 40; centerY: 40
                            radiusX: 30; radiusY: 30
                            startAngle: 55
                            sweepAngle: 70
                        }
                    }
                    // Active Fill Line
                    ShapePath {
                        strokeWidth: 3
                        strokeColor: root.isCharging ? "#10b981" : (root.batteryPercent <= 20 ? "#ef4444" : "#3b82f6")
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 40; centerY: 40
                            radiusX: 30; radiusY: 30
                            startAngle: 55
                            sweepAngle: Math.max(3, (root.batteryPercent / 100.0) * 70)
                        }
                    }

                    // ── LEFT LINE: RAM (Purple) ──────────────────────────────
                    // Track line (start: 145, sweep: 70)
                    ShapePath {
                        strokeWidth: 3
                        strokeColor: Qt.rgba(255, 255, 255, 0.16)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 40; centerY: 40
                            radiusX: 30; radiusY: 30
                            startAngle: 145
                            sweepAngle: 70
                        }
                    }
                    // Active Fill Line
                    ShapePath {
                        strokeWidth: 3
                        strokeColor: "#a855f7"
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 40; centerY: 40
                            radiusX: 30; radiusY: 30
                            startAngle: 145
                            sweepAngle: Math.max(3, (root.ramPercent / 100.0) * 70)
                        }
                    }
                }

                // ── CENTER CORE HUB: BLUETOOTH (TOP) & WIFI (BOTTOM) ─────────
                Rectangle {
                    anchors.centerIn: parent
                    width: 38
                    height: 38
                    radius: 19
                    color: Qt.rgba(14/255, 15/255, 24/255, 0.65)
                    border.color: Qt.rgba(255, 255, 255, 0.12)
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        // Bluetooth Symbol
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.btConnected ? "󰂱" : (root.btOn ? "󰂯" : "󰂲")
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 12
                            color: root.btConnected ? Island.Theme.primary : (root.btOn ? Island.Theme.foreground : Island.Theme.muted)
                            renderType: Text.QtRendering
                        }

                        // Wi-Fi Symbol
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.wifiConnected ? "󰤨" : (root.wifiOn ? "󰤩" : "󰤭")
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 11
                            color: root.wifiConnected ? Island.Theme.primary : (root.wifiOn ? Island.Theme.foreground : Island.Theme.muted)
                            renderType: Text.QtRendering
                        }
                    }
                }

                // Hover Telemetry HUD Card (Appears smoothly on dial hover)
                Rectangle {
                    id: hoverTooltip
                    anchors.left: parent.right
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 152
                    height: 100
                    radius: 12
                    color: Qt.rgba(16/255, 14/255, 22/255, 0.94)
                    border.color: Qt.rgba(255, 255, 255, 0.16)
                    border.width: 1
                    opacity: dialHover.hovered ? 1.0 : 0.0
                    visible: opacity > 0.0
                    z: 10

                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 4

                        Row {
                            spacing: 6
                            Rectangle { width: 6; height: 6; radius: 3; color: "#10b981"; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: "GPU: " + root.gpuPercent + "% " + (root.tempC > 0 ? ("(" + root.tempC + "°C)") : "")
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                color: Island.Theme.foreground
                                renderType: Text.QtRendering
                            }
                        }
                        Row {
                            spacing: 6
                            Rectangle { width: 6; height: 6; radius: 3; color: "#06b6d4"; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: "CPU: " + root.cpuPercent + "%"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                color: Island.Theme.foreground
                                renderType: Text.QtRendering
                            }
                        }
                        Row {
                            spacing: 6
                            Rectangle { width: 6; height: 6; radius: 3; color: "#a855f7"; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: "RAM: " + root.ramPercent + "%"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                color: Island.Theme.foreground
                                renderType: Text.QtRendering
                            }
                        }
                        Row {
                            spacing: 6
                            Rectangle { width: 6; height: 6; radius: 3; color: root.isCharging ? "#10b981" : Island.Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: "BAT: " + root.batteryPercent + "% " + (root.isCharging ? "⚡" : "")
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                color: Island.Theme.foreground
                                renderType: Text.QtRendering
                            }
                        }
                        Text {
                            text: "NET: " + (root.wifiConnected ? root.wifiSsid : (root.wifiOn ? "Disconnected" : "Off"))
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 9
                            color: Island.Theme.muted
                            elide: Text.ElideRight
                            width: parent.width
                            renderType: Text.QtRendering
                        }
                    }
                }
            }
        }

        // RIGHT COLUMN: Weather on the Top-Right of the Clock
        Column {
            id: rightCol
            visible: root.template !== "minimal"
            anchors.top: parent.top
            anchors.topMargin: 16
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
                    renderType: Text.QtRendering
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
                    renderType: Text.QtRendering
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
                renderType: Text.QtRendering
            }

            // Location
            Text {
                text: (Island.WeatherState && Island.WeatherState.area) 
                    ? Island.WeatherState.area 
                    : "Bangalore"
                font.pixelSize: 11
                font.family: Island.Theme.fontFamily
                color: Island.Theme.muted
                renderType: Text.QtRendering
            }
        }
    }
}
