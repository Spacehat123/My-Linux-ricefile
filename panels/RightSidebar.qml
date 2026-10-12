import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "../island" as Island
import "../components"

PanelWindow {
    id: root

    property bool open: false
    visible: open || closeAnim.running

    // Injected authoritative models
    property var desktopModel: null
    property var surfaceModel: null
    property var interactionModel: null
    property var compositorActionLayer: null

    // Navigation Tab state: 0 = Glance, 1 = Spaces, 2 = System
    property int currentTab: 0

    // Action signals
    signal toggleOverview()

    // Dual-layer hover continuity system
    property bool hoverLatching: false

    Timer {
        id: sidebarGraceTimer
        interval: 600
        repeat: false
        onTriggered: {
            hoverLatching = false;
        }
    }

    Timer {
        id: openGraceTimer
        interval: 4000
        repeat: false
        onTriggered: {
            if (!mouseArea.containsMouse && !rootHover.hovered) {
                hoverLatching = false;
            }
        }
    }

    function pingHover() {
        hoverLatching = true;
        openGraceTimer.stop();
        sidebarGraceTimer.stop();
    }

    function releaseHover() {
        sidebarGraceTimer.restart();
    }

    readonly property bool hovered: mouseArea.containsMouse
        || rootHover.hovered
        || hoverLatching
        || (todayCenter && todayCenter.hovered)

    IpcHandler {
        target: "rightsidebar"

        function setTab(index: int): string {
            root.currentTab = Math.max(0, Math.min(2, index));
            if (root.currentTab === 2 && !sysStatsProc.running) sysStatsProc.running = true;
            return JSON.stringify({ success: true, tab: root.currentTab });
        }

        function getTab(): string {
            return JSON.stringify({ success: true, tab: root.currentTab });
        }
    }

    anchors {
        top: true
        bottom: true
        right: true
    }
    margins {
        top: 14
        bottom: 14
        right: 14
    }

    implicitWidth: 430
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    WlrLayershell.namespace: "pranc-shell"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    HoverHandler {
        id: rootHover
        onHoveredChanged: {
            if (hovered) pingHover();
            else releaseHover();
        }
    }

    // Live PipeWire Sink binding
    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property bool audioMuted: sinkAudio ? sinkAudio.muted : false
    readonly property real audioVolume: sinkAudio ? Math.max(0.0, Math.min(1.0, sinkAudio.volume)) : 0.0
    readonly property string sinkName: Pipewire.defaultAudioSink ? (Pipewire.defaultAudioSink.description || "Default Audio Output") : "Default Audio Sink"

    // Live Battery Telemetry
    property var bat: UPower.displayDevice
    property bool batReady: bat ? bat.ready : false
    property real batPct: batReady ? (bat.percentage * 100.0) : -1
    readonly property bool batCharging: bat ? (!UPower.onBattery || bat.state === 1) : false

    // Hardware Telemetry (CPU, GPU & RAM) - only polled when on System tab and open
    property real memUsedGb: 0.0
    property real memTotalGb: 0.0
    property int memPct: 0
    property int cpuPct: 0
    property int cpuTemp: 0
    property var prevCpuIdle: 0
    property var prevCpuTotal: 0
    property int gpuPct: 0
    property int gpuTemp: 0
    property int gpuMemUsedMb: 0
    property int gpuMemTotalMb: 0

    Process {
        id: sysStatsProc
        command: [
            "sh", "-c",
            "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"MEM %.2f %.2f %d\\n\", (t-a)/1048576, t/1048576, int((t-a)*100/t)}' /proc/meminfo; " +
            "cpu_temp=0; for h in /sys/class/hwmon/hwmon*; do if [ -f \"$h/name\" ] && grep -qE \"k10temp|coretemp|cpu\" \"$h/name\" 2>/dev/null; then cpu_temp=$(awk '{printf \"%d\", $1/1000}' \"$h/temp1_input\" 2>/dev/null); break; fi; done; " +
            "awk -v temp=\"$cpu_temp\" '/^cpu /{print \"CPU\", $2+$3+$4+$5+$6+$7+$8, $5, temp}' /proc/stat; " +
            "nv_out=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | awk -F', ' '{print $1, $2, $3, $4}'); " +
            "if [ -n \"$nv_out\" ]; then echo \"GPU $nv_out\"; elif [ -f /sys/class/drm/card1/device/gpu_busy_percent ]; then echo \"GPU $(cat /sys/class/drm/card1/device/gpu_busy_percent 2>/dev/null || echo 0) 0 0 0\"; else echo \"GPU 0 0 0 0\"; fi"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line || line.trim() === "") return;
                const parts = line.trim().split(/\s+/);
                if (parts[0] === "MEM" && parts.length >= 4) {
                    root.memUsedGb = parseFloat(parts[1]);
                    root.memTotalGb = parseFloat(parts[2]);
                    root.memPct = parseInt(parts[3]);
                } else if (parts[0] === "CPU" && parts.length >= 3) {
                    const total = parseInt(parts[1]);
                    const idle = parseInt(parts[2]);
                    if (root.prevCpuTotal > 0) {
                        const totalDiff = total - root.prevCpuTotal;
                        const idleDiff = idle - root.prevCpuIdle;
                        if (totalDiff > 0) {
                            root.cpuPct = Math.max(0, Math.min(100, Math.round((1 - idleDiff / totalDiff) * 100)));
                        }
                    }
                    root.prevCpuTotal = total;
                    root.prevCpuIdle = idle;
                    if (parts.length >= 4) {
                        root.cpuTemp = parseInt(parts[3]) || 0;
                    }
                } else if (parts[0] === "GPU" && parts.length >= 5) {
                    root.gpuPct = Math.max(0, Math.min(100, parseInt(parts[1]) || 0));
                    root.gpuTemp = parseInt(parts[2]) || 0;
                    root.gpuMemUsedMb = parseInt(parts[3]) || 0;
                    root.gpuMemTotalMb = parseInt(parts[4]) || 0;
                }
            }
        }
    }

    Timer {
        id: sysStatsTimer
        interval: 1500
        repeat: true
        running: root.open && root.currentTab === 2
        onTriggered: {
            if (!sysStatsProc.running) sysStatsProc.running = true;
        }
    }

    // Helper: App Icon Resolution
    function getAppIcon(rawAppId, rawClass) {
        const id = (rawClass || rawAppId || "").toLowerCase();
        if (id.indexOf("code") !== -1) return "󰨞";
        if (id.indexOf("kitty") !== -1 || id.indexOf("terminal") !== -1 || id.indexOf("alacritty") !== -1 || id.indexOf("wezterm") !== -1 || id.indexOf("ghostty") !== -1) return "󰄛";
        if (id.indexOf("firefox") !== -1 || id.indexOf("chrome") !== -1 || id.indexOf("brave") !== -1 || id.indexOf("browser") !== -1) return "󰖟";
        if (id.indexOf("spotify") !== -1) return "󰓇";
        if (id.indexOf("discord") !== -1 || id.indexOf("vesktop") !== -1) return "󰙯";
        if (id.indexOf("file") !== -1 || id.indexOf("nautilus") !== -1 || id.indexOf("dolphin") !== -1 || id.indexOf("thunar") !== -1) return "󰉋";
        if (id.indexOf("pavucontrol") !== -1 || id.indexOf("volume") !== -1) return "󰕾";
        if (id.indexOf("mpv") !== -1 || id.indexOf("vlc") !== -1 || id.indexOf("video") !== -1) return "󰕧";
        if (id.indexOf("steam") !== -1) return "󰓓";
        if (id.indexOf("settings") !== -1) return "󰒓";
        return "󰍹";
    }

    // Active Surfaces filtering
    readonly property var activeSurfaces: {
        if (!root.surfaceModel || !root.surfaceModel.surfaces) return [];
        return root.surfaceModel.surfaces.filter(s => {
            if (!s) return false;
            const wName = (s.workspaceName || "").toLowerCase();
            return wName !== "special:stash" && wName.indexOf("stash") === -1;
        });
    }

    readonly property var stashedSurfaces: {
        if (!root.surfaceModel || !root.surfaceModel.surfaces) return [];
        return root.surfaceModel.surfaces.filter(s => {
            if (!s) return false;
            const wName = (s.workspaceName || "").toLowerCase();
            return wName === "special:stash" || (wName.indexOf("stash") !== -1);
        });
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0.0

        transform: Translate {
            id: contentTranslate
            x: 450
        }

        // =====================================================================
        // FLOATING SMOKED LIQUID GLASS DRAWER
        // =====================================================================
        // =====================================================================
        // ATMOSPHERIC OBSIDIAN COMMAND DECK (ZERO-PILL ARCHITECTURAL SURFACE)
        // =====================================================================
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "#08070b"
            border.color: Qt.rgba(1, 1, 1, 0.09)
            border.width: 1
            clip: true

            // Multi-stop Vertical Atmospheric Light Dispersion
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.18) }
                    GradientStop { position: 0.18; color: Qt.rgba(Island.Theme.primary.r * 0.4, Island.Theme.primary.g * 0.4, Island.Theme.primary.b * 0.4, 0.06) }
                    GradientStop { position: 0.55; color: "#060509" }
                    GradientStop { position: 1.0; color: "#040306" }
                }
            }

            // Top Specular Refraction Hairline
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                height: 1
                color: Qt.rgba(1, 1, 1, 0.16)
            }

            // Cybernetic Left Optical Laser Rail
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 18
                anchors.bottomMargin: 18
                width: 2
                radius: 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.3) }
                    GradientStop { position: 0.12; color: Island.Theme.primary }
                    GradientStop { position: 0.50; color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.5) }
                    GradientStop { position: 0.85; color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.15) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                // =============================================================
                // 1. ARCHITECTURAL HEADER & CONTROLS (NON-PILL BRANDING)
                // =============================================================
                Item {
                    width: parent.width
                    height: 40

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        // Precision Technical Emblem Chip
                        Rectangle {
                            width: 30
                            height: 30
                            radius: 4
                            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.12)
                            border.color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.45)
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "◈"
                                font.pixelSize: 12
                                color: Island.Theme.primary
                            }
                        }

                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                spacing: 8
                                Text {
                                    text: "V A L E N C E"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.letterSpacing: 3.5
                                    color: Island.Theme.foreground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // Square LED Status Indicator (No generic pill)
                                Row {
                                    spacing: 5
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 1
                                        color: Island.Theme.green
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "LIVE"
                                        font.family: Island.Theme.fontFamily
                                        font.pixelSize: 8
                                        font.bold: true
                                        font.letterSpacing: 1.2
                                        color: Island.Theme.green
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            Text {
                                text: "SURFACE DECK // " + (root.desktopModel && root.desktopModel.focusedWorkspaceName ? ("WORKSPACE " + root.desktopModel.focusedWorkspaceName) : "ACTIVE")
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 8
                                font.letterSpacing: 1.0
                                color: Island.Theme.mutedDark
                            }
                        }
                    }

                    // Header Right: Architectural Datum & Precision Close Trigger
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        // Architectural Datum Tag with Left Bar Indicator
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Rectangle {
                                width: 2
                                height: 12
                                radius: 1
                                color: Island.Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: Qt.formatDateTime(new Date(), "ddd, d MMM").toUpperCase() + (Island.WeatherState.tempC !== "" ? (" // " + Island.WeatherState.tempC) : "")
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 1.0
                                color: Island.Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Precision Square Close Trigger (No generic circle pill)
                        Rectangle {
                            width: 26
                            height: 26
                            radius: 4
                            color: closeBtnMouse.containsMouse ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.22) : Qt.rgba(1, 1, 1, 0.04)
                            border.color: closeBtnMouse.containsMouse ? Island.Theme.red : Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 10
                                color: closeBtnMouse.containsMouse ? Island.Theme.red : Island.Theme.muted
                            }

                            MouseArea {
                                id: closeBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.desktopState) root.desktopState.setRightSidebarOpen(false);
                                    else root.open = false;
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // 2. ARCHITECTURAL STUDIO LASER RAIL (ZERO-PILL CHANNEL SELECTOR)
                // =============================================================
                Item {
                    id: tabRail
                    width: parent.width
                    height: 36

                    // Subtle Base Guide Rail Hairline
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // Sliding Precision Laser Runner (Underline Indicator)
                    Item {
                        id: laserRunner
                        width: tabRail.width / 3
                        height: 2
                        anchors.bottom: parent.bottom
                        x: root.currentTab * width

                        Behavior on x {
                            NumberAnimation {
                                duration: 240
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Ambient Laser Glow Halo
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.75
                            height: 6
                            radius: 3
                            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.45)
                        }

                        // Razor Laser Line
                        Rectangle {
                            anchors.fill: parent
                            radius: 1
                            color: Island.Theme.primary
                        }
                    }

                    Row {
                        anchors.fill: parent

                        // Tab 0: Chrono
                        Item {
                            width: parent.width / 3
                            height: parent.height

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 4
                                color: tab0Mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "󰸗"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 11
                                    color: root.currentTab === 0 ? Island.Theme.primary : (tab0Mouse.containsMouse ? Island.Theme.foreground : Island.Theme.mutedDark)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "01 // CHRONO"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1.2
                                    color: root.currentTab === 0 ? Island.Theme.foreground : (tab0Mouse.containsMouse ? Island.Theme.foreground : Island.Theme.mutedDark)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: tab0Mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentTab = 0
                            }
                        }

                        // Tab 1: Surfaces
                        Item {
                            width: parent.width / 3
                            height: parent.height

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 4
                                color: tab1Mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "󰕰"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 11
                                    color: root.currentTab === 1 ? Island.Theme.primary : (tab1Mouse.containsMouse ? Island.Theme.foreground : Island.Theme.mutedDark)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "02 // SURFACES"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1.2
                                    color: root.currentTab === 1 ? Island.Theme.foreground : (tab1Mouse.containsMouse ? Island.Theme.foreground : Island.Theme.mutedDark)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: tab1Mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentTab = 1
                            }
                        }

                        // Tab 2: Telemetry
                        Item {
                            width: parent.width / 3
                            height: parent.height

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 4
                                color: tab2Mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "󰓅"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 11
                                    color: root.currentTab === 2 ? Island.Theme.primary : (tab2Mouse.containsMouse ? Island.Theme.foreground : Island.Theme.mutedDark)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "03 // TELEMETRY"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1.2
                                    color: root.currentTab === 2 ? Island.Theme.foreground : (tab2Mouse.containsMouse ? Island.Theme.foreground : Island.Theme.mutedDark)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: tab2Mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentTab = 2;
                                    if (!sysStatsProc.running) sysStatsProc.running = true;
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // 3. MAIN DECK DISPLAY CONTAINER
                // =============================================================
                Item {
                    width: parent.width
                    height: parent.height - 100
                    clip: true

                    // ---------------------------------------------------------
                    // DECK 0: GLANCE (TodayCenter: Calendar, Tasks, Scratchpad)
                    // ---------------------------------------------------------
                    Item {
                        id: glanceDeck
                        anchors.fill: parent
                        visible: root.currentTab === 0

                        TodayCenter {
                            id: todayCenter
                            anchors.fill: parent
                            desktopModel: root.desktopModel
                            surfaceModel: root.surfaceModel
                            interactionModel: root.interactionModel
                            screen: root.screen
                        }
                    }

                    // ---------------------------------------------------------
                    // DECK 1: SPACES & WINDOW HUB (Lazy Loaded)
                    // ---------------------------------------------------------
                    Loader {
                        id: spacesDeckLoader
                        anchors.fill: parent
                        active: root.currentTab === 1
                        sourceComponent: spacesDeckComp
                    }

                    Component {
                        id: spacesDeckComp

                        Flickable {
                            id: spacesDeck
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: spacesCol.implicitHeight + 20
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                        Column {
                            id: spacesCol
                            width: parent.width
                            spacing: 14

                            // Overview Launch Banner
                            Rectangle {
                                width: parent.width
                                height: 46
                                radius: 8
                                color: Qt.rgba(0, 0, 0, 0.40)
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                // Top Specular Hairline
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    height: 1
                                    color: Qt.rgba(1, 1, 1, 0.12)
                                }

                                Item {
                                    anchors.fill: parent
                                    anchors.margins: 10

                                    Row {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8

                                        Rectangle {
                                            width: 26
                                            height: 26
                                            radius: 4
                                            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.14)
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰕰"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 12
                                                color: Island.Theme.primary
                                            }
                                        }

                                        Column {
                                            spacing: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                text: root.activeSurfaces.length + " ACTIVE WINDOWS"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                font.letterSpacing: 0.8
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: "WORKSPACE " + (root.desktopModel && root.desktopModel.focusedWorkspaceName ? root.desktopModel.focusedWorkspaceName : "1")
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 8
                                                color: Island.Theme.muted
                                            }
                                        }
                                    }

                                    // Launch Overview Button (Precision Technical Trigger, No Pill)
                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24
                                        width: 90
                                        radius: 4
                                        color: overviewBtnMouse.containsMouse ? Island.Theme.primary : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.18)
                                        border.color: overviewBtnMouse.containsMouse ? Island.Theme.primary : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.5)
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "[ OVERVIEW 󰍹 ]"
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 8
                                            font.bold: true
                                            font.letterSpacing: 1.0
                                            color: overviewBtnMouse.containsMouse ? "#ffffff" : Island.Theme.primary
                                        }

                                        MouseArea {
                                            id: overviewBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleOverview()
                                        }
                                    }
                                }
                            }

                            // Active Windows List Header
                            Row {
                                width: parent.width
                                spacing: 6
                                Text {
                                    text: "◈"
                                    font.pixelSize: 9
                                    color: Island.Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "ACTIVE SURFACES (" + root.activeSurfaces.length + ")"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1.2
                                    color: Island.Theme.muted
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Active Windows Repeater
                            Repeater {
                                model: root.activeSurfaces

                                delegate: Rectangle {
                                    id: winCard
                                    width: spacesCol.width
                                    height: 50
                                    radius: 8
                                    color: (modelData.activated || winCardMouse.containsMouse) ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                                    border.color: modelData.activated ? Island.Theme.primary : (winCardMouse.containsMouse ? Island.Theme.glassBorder : Qt.rgba(1, 1, 1, 0.06))
                                    border.width: 1

                                    // Left Status Indicator Strip
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 4
                                        width: 2
                                        radius: 1
                                        color: modelData.activated ? Island.Theme.primary : (winCardMouse.containsMouse ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.45) : "transparent")
                                    }

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 8

                                        // Left: App Icon
                                        Rectangle {
                                            id: appIconRect
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 30
                                            height: 30
                                            radius: 4
                                            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.14)

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.getAppIcon(modelData.appId, modelData.windowClass)
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 14
                                                color: Island.Theme.primary
                                            }
                                        }

                                        // Middle: App Name & Title
                                        Column {
                                            anchors.left: appIconRect.right
                                            anchors.leftMargin: 10
                                            anchors.right: winActionsRow.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2

                                            Row {
                                                spacing: 6
                                                Text {
                                                    text: modelData.appName || modelData.windowClass || "Application"
                                                    font.family: Island.Theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    color: Island.Theme.foreground
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                }
                                                // Workspace Micro-Chip (No oval pill)
                                                Rectangle {
                                                    height: 15
                                                    width: wsTagText.implicitWidth + 8
                                                    radius: 3
                                                    color: Qt.rgba(1, 1, 1, 0.06)
                                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                                    border.width: 1
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text {
                                                        id: wsTagText
                                                        anchors.centerIn: parent
                                                        text: "[ WS " + (modelData.workspaceId || "?") + " ]"
                                                        font.family: Island.Theme.fontFamily
                                                        font.pixelSize: 8
                                                        font.bold: true
                                                        color: Island.Theme.muted
                                                    }
                                                }
                                            }

                                            Text {
                                                text: modelData.title || ""
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 9
                                                color: Island.Theme.muted
                                                elide: Text.ElideRight
                                                width: parent.width
                                                maximumLineCount: 1
                                            }
                                        }

                                        // Right: Actions Row (Focus, Stash, Close)
                                        Row {
                                            id: winActionsRow
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 5

                                            // Focus Button
                                            Rectangle {
                                                width: 22
                                                height: 22
                                                radius: 4
                                                color: actFocusMouse.containsMouse ? Island.Theme.primary : Qt.rgba(1, 1, 1, 0.06)
                                                border.color: actFocusMouse.containsMouse ? Island.Theme.primary : Qt.rgba(1, 1, 1, 0.1)
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰍹"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 10
                                                    color: actFocusMouse.containsMouse ? "#ffffff" : Island.Theme.foreground
                                                }
                                                MouseArea {
                                                    id: actFocusMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root.interactionModel && modelData.address) {
                                                             root.interactionModel.requestActivate(modelData.address);
                                                        }
                                                    }
                                                }
                                            }

                                            // Stash Button
                                            Rectangle {
                                                width: 22
                                                height: 22
                                                radius: 4
                                                color: actStashMouse.containsMouse ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.3) : Qt.rgba(1, 1, 1, 0.06)
                                                border.color: actStashMouse.containsMouse ? Island.Theme.primary : Qt.rgba(1, 1, 1, 0.1)
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅍"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 10
                                                    color: actStashMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                                                }
                                                MouseArea {
                                                    id: actStashMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (modelData.address) {
                                                            if (root.compositorActionLayer) {
                                                                root.compositorActionLayer.executeAction("moveToSpecialWorkspace", modelData.address, { specialWorkspace: "stash", silent: true });
                                                            } else if (typeof Hyprland !== "undefined" && typeof Hyprland.dispatch === "function") {
                                                                Hyprland.dispatch("hl.dsp.window.move({ workspace = 'special:stash', window = 'address:" + modelData.address + "', silent = true })");
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            // Close Button
                                            Rectangle {
                                                width: 22
                                                height: 22
                                                radius: 4
                                                color: actCloseMouse.containsMouse ? Island.Theme.red : Qt.rgba(1, 1, 1, 0.06)
                                                border.color: actCloseMouse.containsMouse ? Island.Theme.red : Qt.rgba(1, 1, 1, 0.1)
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅖"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 10
                                                    color: actCloseMouse.containsMouse ? "#ffffff" : Island.Theme.muted
                                                }
                                                MouseArea {
                                                    id: actCloseMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root.interactionModel && modelData.address) {
                                                            root.interactionModel.requestClose(modelData.address);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: winCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton
                                        onClicked: {
                                            if (root.interactionModel && modelData.address) {
                                                root.interactionModel.requestActivate(modelData.address);
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty surfaces indicator
                            Item {
                                width: parent.width
                                height: 40
                                visible: root.activeSurfaces.length === 0
                                Text {
                                    anchors.centerIn: parent
                                    text: "No active application windows"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                }
                            }

                            // Stashed Windows Section
                            Row {
                                width: parent.width
                                spacing: 6
                                Text {
                                    text: "◈"
                                    font.pixelSize: 9
                                    color: Island.Theme.yellow
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "STASH VAULT (" + root.stashedSurfaces.length + " DOCKED)"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1.2
                                    color: Island.Theme.yellow
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Repeater {
                                model: root.stashedSurfaces

                                delegate: Rectangle {
                                    width: spacesCol.width
                                    height: 42
                                    radius: 8
                                    color: Qt.rgba(Island.Theme.yellow.r, Island.Theme.yellow.g, Island.Theme.yellow.b, 0.08)
                                    border.color: Qt.rgba(Island.Theme.yellow.r, Island.Theme.yellow.g, Island.Theme.yellow.b, 0.25)
                                    border.width: 1

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 8

                                        Row {
                                            anchors.left: parent.left
                                            anchors.right: restoreBtn.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 8

                                            Text {
                                                text: "󰅍"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 12
                                                color: Island.Theme.yellow
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: (modelData.appName || modelData.windowClass || "Stashed Window") + ": " + (modelData.title || "")
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Island.Theme.foreground
                                                elide: Text.ElideRight
                                                width: parent.width - 25
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        Rectangle {
                                            id: restoreBtn
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 22
                                            width: 72
                                            radius: 4
                                            color: restoreMouse.containsMouse ? Island.Theme.yellow : Qt.rgba(Island.Theme.yellow.r, Island.Theme.yellow.g, Island.Theme.yellow.b, 0.18)
                                            border.color: restoreMouse.containsMouse ? Island.Theme.yellow : Qt.rgba(Island.Theme.yellow.r, Island.Theme.yellow.g, Island.Theme.yellow.b, 0.4)
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "[ RESTORE ]"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 8
                                                font.bold: true
                                                font.letterSpacing: 0.8
                                                color: restoreMouse.containsMouse ? "#000000" : Island.Theme.yellow
                                            }

                                            MouseArea {
                                                id: restoreMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const targetWs = (root.desktopModel && root.desktopModel.focusedWorkspaceId > 0) ? String(root.desktopModel.focusedWorkspaceId) : "1";
                                                    if (modelData.address) {
                                                        if (root.compositorActionLayer) {
                                                            root.compositorActionLayer.executeAction("moveSurfaceToWorkspace", modelData.address, { workspaceId: targetWs });
                                                        } else if (typeof Hyprland !== "undefined" && typeof Hyprland.dispatch === "function") {
                                                            Hyprland.dispatch("hl.dsp.window.move({ workspace = " + targetWs + ", window = 'address:" + modelData.address + "' })");
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty stash indicator
                            Item {
                                width: parent.width
                                height: 32
                                visible: root.stashedSurfaces.length === 0
                                Text {
                                    anchors.centerIn: parent
                                    text: "No windows in stash pocket"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Island.Theme.muted
                                }
                            }
                        }
                    }
                    }

                    // ---------------------------------------------------------
                    // DECK 2: SYSTEM TELEMETRY & HARDWARE HUB (Lazy Loaded)
                    // ---------------------------------------------------------
                    Loader {
                        id: systemDeckLoader
                        anchors.fill: parent
                        active: root.currentTab === 2
                        sourceComponent: systemDeckComp
                    }

                    Component {
                        id: systemDeckComp

                        Flickable {
                            id: systemDeck
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: systemCol.implicitHeight + 20
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                        Column {
                            id: systemCol
                            width: parent.width
                            spacing: 14

                            // 1. HARDWARE TELEMETRY GAUGES CARD (16-Segment LED VU Arrays)
                            Rectangle {
                                width: parent.width
                                implicitHeight: hwCol.implicitHeight + 28
                                radius: 8
                                color: Qt.rgba(0, 0, 0, 0.40)
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                // Top Specular Hairline
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    height: 1
                                    color: Qt.rgba(1, 1, 1, 0.12)
                                }

                                Column {
                                    id: hwCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 14
                                    spacing: 14

                                    Row {
                                        width: parent.width
                                        spacing: 6
                                        Text {
                                            text: "◈"
                                            font.pixelSize: 9
                                            color: Island.Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "HARDWARE // TELEMETRY ARRAY"
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 9
                                            font.bold: true
                                            font.letterSpacing: 1.2
                                            color: Island.Theme.muted
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    // CPU Gauge (16-Segment LED VU-Meter)
                                    Column {
                                        width: parent.width
                                        spacing: 6

                                        Item {
                                            width: parent.width
                                            height: 16
                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6
                                                Text {
                                                    text: "󰍛"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 12
                                                    color: Island.Theme.primary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                Text {
                                                    text: "CPU COMPUTE"
                                                    font.family: Island.Theme.fontFamily
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    font.letterSpacing: 1.0
                                                    color: Island.Theme.foreground
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                            Text {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.cpuPct + "%" + (root.cpuTemp > 0 ? (" · " + root.cpuTemp + "°C") : "")
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: root.cpuPct > 80 ? Island.Theme.red : Island.Theme.primary
                                            }
                                        }

                                        Row {
                                            width: parent.width
                                            height: 8
                                            spacing: 3

                                            Repeater {
                                                model: 16
                                                Rectangle {
                                                    readonly property bool lit: root.cpuPct >= ((index + 1) / 16.0 * 100.0)
                                                    width: (parent.width - 15 * 3) / 16.0
                                                    height: parent.height
                                                    radius: 2
                                                    color: lit ? (index >= 13 ? Island.Theme.red : (index >= 10 ? Island.Theme.yellow : Island.Theme.primary)) : Qt.rgba(1, 1, 1, 0.06)
                                                    border.color: lit ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
                                                    border.width: lit ? 1 : 0
                                                    Behavior on color { ColorAnimation { duration: 160 } }
                                                }
                                            }
                                        }
                                    }

                                    // GPU Gauge (16-Segment LED VU-Meter)
                                    Column {
                                        width: parent.width
                                        spacing: 6

                                        Item {
                                            width: parent.width
                                            height: 16
                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6
                                                Text {
                                                    text: "󰢮"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 12
                                                    color: Island.Theme.primary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                Text {
                                                    text: "GPU COMPUTE"
                                                    font.family: Island.Theme.fontFamily
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    font.letterSpacing: 1.0
                                                    color: Island.Theme.foreground
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                            Text {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.gpuPct + "%" + (root.gpuTemp > 0 ? (" · " + root.gpuTemp + "°C") : "")
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: root.gpuPct > 80 ? Island.Theme.red : Island.Theme.primary
                                            }
                                        }

                                        Row {
                                            width: parent.width
                                            height: 8
                                            spacing: 3

                                            Repeater {
                                                model: 16
                                                Rectangle {
                                                    readonly property bool lit: root.gpuPct >= ((index + 1) / 16.0 * 100.0)
                                                    width: (parent.width - 15 * 3) / 16.0
                                                    height: parent.height
                                                    radius: 2
                                                    color: lit ? (index >= 13 ? Island.Theme.red : (index >= 10 ? Island.Theme.yellow : Island.Theme.primary)) : Qt.rgba(1, 1, 1, 0.06)
                                                    border.color: lit ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
                                                    border.width: lit ? 1 : 0
                                                    Behavior on color { ColorAnimation { duration: 160 } }
                                                }
                                            }
                                        }
                                    }

                                    // RAM Gauge (16-Segment LED VU-Meter)
                                    Column {
                                        width: parent.width
                                        spacing: 6

                                        Item {
                                            width: parent.width
                                            height: 16
                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6
                                                Text {
                                                    text: "󰘚"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 12
                                                    color: Island.Theme.primary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                Text {
                                                    text: "RAM POOL"
                                                    font.family: Island.Theme.fontFamily
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    font.letterSpacing: 1.0
                                                    color: Island.Theme.foreground
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                            Text {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: (root.memUsedGb > 0 ? (root.memUsedGb.toFixed(1) + " / " + root.memTotalGb.toFixed(1) + " GB (" + root.memPct + "%)") : "Analyzing...")
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: root.memPct > 85 ? Island.Theme.red : Island.Theme.muted
                                            }
                                        }

                                        Row {
                                            width: parent.width
                                            height: 8
                                            spacing: 3

                                            Repeater {
                                                model: 16
                                                Rectangle {
                                                    readonly property bool lit: root.memPct >= ((index + 1) / 16.0 * 100.0)
                                                    width: (parent.width - 15 * 3) / 16.0
                                                    height: parent.height
                                                    radius: 2
                                                    color: lit ? (index >= 13 ? Island.Theme.red : (index >= 10 ? Island.Theme.yellow : Island.Theme.primary)) : Qt.rgba(1, 1, 1, 0.06)
                                                    border.color: lit ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
                                                    border.width: lit ? 1 : 0
                                                    Behavior on color { ColorAnimation { duration: 160 } }
                                                }
                                            }
                                        }
                                    }

                                    // Battery Gauge (16-Segment LED VU-Meter)
                                    Column {
                                        width: parent.width
                                        spacing: 6

                                        Item {
                                            width: parent.width
                                            height: 16
                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6
                                                Text {
                                                    text: root.batCharging ? "󰂄" : "󰁹"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 12
                                                    color: root.batCharging ? Island.Theme.green : Island.Theme.primary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                Text {
                                                    text: "POWER SOURCE"
                                                    font.family: Island.Theme.fontFamily
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    font.letterSpacing: 1.0
                                                    color: Island.Theme.foreground
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                            Text {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: (root.batPct >= 0 ? (Math.round(root.batPct) + "%") : "AC MAINS") + (root.batCharging ? " // CHARGING" : "")
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: root.batCharging ? Island.Theme.green : Island.Theme.primary
                                            }
                                        }

                                        Row {
                                            width: parent.width
                                            height: 8
                                            spacing: 3

                                            Repeater {
                                                model: 16
                                                Rectangle {
                                                    readonly property real pct: root.batPct >= 0 ? root.batPct : 100
                                                    readonly property bool lit: pct >= ((index + 1) / 16.0 * 100.0)
                                                    width: (parent.width - 15 * 3) / 16.0
                                                    height: parent.height
                                                    radius: 2
                                                    color: lit ? (root.batCharging ? Island.Theme.green : (pct < 20 ? Island.Theme.red : Island.Theme.primary)) : Qt.rgba(1, 1, 1, 0.06)
                                                    border.color: lit ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
                                                    border.width: lit ? 1 : 0
                                                    Behavior on color { ColorAnimation { duration: 160 } }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 2. PIPEWIRE AUDIO MASTER CHANNEL STRIP
                            Rectangle {
                                width: parent.width
                                implicitHeight: audioCol.implicitHeight + 28
                                radius: 8
                                color: Qt.rgba(0, 0, 0, 0.40)
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                // Top Specular Hairline
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    height: 1
                                    color: Qt.rgba(1, 1, 1, 0.12)
                                }

                                Column {
                                    id: audioCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 14
                                    spacing: 12

                                    Item {
                                        width: parent.width
                                        height: 34

                                        Row {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 8

                                            Rectangle {
                                                width: 30
                                                height: 30
                                                radius: 4
                                                color: root.audioMuted ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.15) : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.14)
                                                border.color: root.audioMuted ? Island.Theme.red : Island.Theme.primary
                                                border.width: 1
                                                anchors.verticalCenter: parent.verticalCenter

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.audioMuted ? "󰖁" : "󰕾"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 13
                                                    color: root.audioMuted ? Island.Theme.red : Island.Theme.primary
                                                }
                                            }

                                            Column {
                                                spacing: 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text {
                                                    text: "AUDIO // MASTER SINK"
                                                    font.family: Island.Theme.fontFamily
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    font.letterSpacing: 1.0
                                                    color: Island.Theme.foreground
                                                }
                                                Text {
                                                    text: root.sinkName
                                                    font.family: Island.Theme.fontFamily
                                                    font.pixelSize: 9
                                                    color: Island.Theme.muted
                                                    elide: Text.ElideRight
                                                    width: audioCol.width - 120
                                                }
                                            }
                                        }

                                        // Mute Toggle Button (Precision Studio Tally Trigger, No Oval Pill)
                                        Rectangle {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 24
                                            width: 66
                                            radius: 4
                                            color: root.audioMuted ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.22) : (muteMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04))
                                            border.color: root.audioMuted ? Island.Theme.red : Qt.rgba(1, 1, 1, 0.14)
                                            border.width: 1

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 5
                                                Rectangle {
                                                    width: 5
                                                    height: 5
                                                    radius: 1
                                                    color: root.audioMuted ? Island.Theme.red : Island.Theme.green
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                Text {
                                                    text: root.audioMuted ? "MUTED" : "LIVE"
                                                    font.family: Island.Theme.fontFamily
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    font.letterSpacing: 1.0
                                                    color: root.audioMuted ? Island.Theme.red : Island.Theme.foreground
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                id: muteMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.sinkAudio) root.sinkAudio.muted = !root.sinkAudio.muted;
                                                }
                                            }
                                        }
                                    }

                                    // Interactive Level Fader Track with Studio Slider Cap
                                    Item {
                                        width: parent.width
                                        height: 22

                                        Rectangle {
                                            id: volTrack
                                            anchors.left: parent.left
                                            anchors.right: volPctText.left
                                            anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 6
                                            radius: 3
                                            color: Qt.rgba(1, 1, 1, 0.08)

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: parent.width * root.audioVolume
                                                radius: 3
                                                color: root.audioMuted ? Island.Theme.muted : Island.Theme.primary

                                                // Studio Console Slider Cap (No round circle knob)
                                                Rectangle {
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 6
                                                    height: 16
                                                    radius: 2
                                                    color: "#ffffff"
                                                    border.color: Island.Theme.primary
                                                    border.width: 1
                                                    visible: !root.audioMuted
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: (mouse) => {
                                                    if (root.sinkAudio) {
                                                        const vol = Math.max(0.0, Math.min(1.0, mouse.x / width));
                                                        root.sinkAudio.volume = vol;
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            id: volPctText
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Math.round(root.audioVolume * 100) + "%"
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: root.audioMuted ? Island.Theme.muted : Island.Theme.foreground
                                            width: 36
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }

                            // 3. EXECUTIVE SESSION MATRIX
                            Row {
                                width: parent.width
                                spacing: 6
                                Text {
                                    text: "◈"
                                    font.pixelSize: 9
                                    color: Island.Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "SESSION // POWER MATRIX"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1.2
                                    color: Island.Theme.muted
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Grid {
                                width: parent.width
                                columns: 2
                                spacing: 8

                                // Action 1: Lock
                                Rectangle {
                                    width: (systemCol.width - 8) / 2
                                    height: 50
                                    radius: 8
                                    color: actLockMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                                    border.color: actLockMouse.containsMouse ? Island.Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        height: 1
                                        color: Qt.rgba(1, 1, 1, 0.1)
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        Rectangle {
                                            width: 26
                                            height: 26
                                            radius: 4
                                            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.15)
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰌾"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 12
                                                color: Island.Theme.primary
                                            }
                                        }

                                        Column {
                                            spacing: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                text: "LOCK"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                font.letterSpacing: 0.8
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: "Secure Session"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 8
                                                color: Island.Theme.muted
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: actLockMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["hyprlock"])
                                    }
                                }

                                // Action 2: Suspend
                                Rectangle {
                                    width: (systemCol.width - 8) / 2
                                    height: 50
                                    radius: 8
                                    color: actSuspMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                                    border.color: actSuspMouse.containsMouse ? Island.Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        height: 1
                                        color: Qt.rgba(1, 1, 1, 0.1)
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        Rectangle {
                                            width: 26
                                            height: 26
                                            radius: 4
                                            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.15)
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰤄"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 12
                                                color: Island.Theme.primary
                                            }
                                        }

                                        Column {
                                            spacing: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                text: "SLEEP"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                font.letterSpacing: 0.8
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: "Suspend Power"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 8
                                                color: Island.Theme.muted
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: actSuspMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                                    }
                                }

                                // Action 3: Reboot
                                Rectangle {
                                    width: (systemCol.width - 8) / 2
                                    height: 50
                                    radius: 8
                                    color: actRebootMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                                    border.color: actRebootMouse.containsMouse ? Island.Theme.yellow : Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        height: 1
                                        color: Qt.rgba(1, 1, 1, 0.1)
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        Rectangle {
                                            width: 26
                                            height: 26
                                            radius: 4
                                            color: Qt.rgba(Island.Theme.yellow.r, Island.Theme.yellow.g, Island.Theme.yellow.b, 0.15)
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰜉"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 12
                                                color: Island.Theme.yellow
                                            }
                                        }

                                        Column {
                                            spacing: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                text: "RESTART"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                font.letterSpacing: 0.8
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: "Warm Reboot"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 8
                                                color: Island.Theme.muted
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: actRebootMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                                    }
                                }

                                // Action 4: Power Off
                                Rectangle {
                                    width: (systemCol.width - 8) / 2
                                    height: 50
                                    radius: 8
                                    color: actPowerMouse.containsMouse ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.22) : Qt.rgba(1, 1, 1, 0.04)
                                    border.color: actPowerMouse.containsMouse ? Island.Theme.red : Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        height: 1
                                        color: Qt.rgba(1, 1, 1, 0.1)
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        Rectangle {
                                            width: 26
                                            height: 26
                                            radius: 4
                                            color: Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.15)
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰐥"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 12
                                                color: Island.Theme.red
                                            }
                                        }

                                        Column {
                                            spacing: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                text: "SHUT DOWN"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                font.letterSpacing: 0.8
                                                color: actPowerMouse.containsMouse ? Island.Theme.red : Island.Theme.foreground
                                            }
                                            Text {
                                                text: "Halt System"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 8
                                                color: Island.Theme.muted
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: actPowerMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                                    }
                                }
                            }
                        }
                    }
                }
            }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: pingHover()
        onExited: releaseHover()
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: contentTranslate
            property: "x"
            to: 0
            duration: 380
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 1.0
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: contentTranslate
            property: "x"
            to: 450
            duration: 280
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 0.0
            duration: 240
            easing.type: Easing.InCubic
        }
    }

    onOpenChanged: {
        if (open) {
            hoverLatching = true;
            openGraceTimer.restart();
            if (currentTab === 2 && !sysStatsProc.running) sysStatsProc.running = true;
            closeAnim.stop();
            openAnim.start();
        } else {
            hoverLatching = false;
            openGraceTimer.stop();
            sidebarGraceTimer.stop();
            openAnim.stop();
            closeAnim.start();
        }
    }
}