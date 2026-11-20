import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import Quickshell.Networking
import "../island" as Island
import "../island/components"

Item {
    id: root

    // =========================================================================
    // Upstream Authoritative Models & State Injections
    // =========================================================================
    property var desktopModel: null
    property var desktopState: null
    property var screen: null
    property bool wallpaperEnabled: true
    property bool ambientEnabled: true
    property bool ambientAlwaysOn: false

    // Action Signals (Unidirectional Event Flow to shellRoot)
    signal toggleWallpaper()
    signal toggleAmbient()
    signal cycleAmbient()

    // Dual-Layer Hover Boundary (Passive root HoverHandler)
    HoverHandler {
        id: rootHoverHandler
    }
    readonly property bool hovered: rootHoverHandler.hovered

    // PipeWire native audio binding
    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property bool audioMuted: sinkAudio ? sinkAudio.muted : false
    readonly property real currentVolume: sinkAudio ? sinkAudio.volume : 0.0

    // Networking & Bluetooth Native Bindings
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

    // VPN Native & System Tunnel State
    property bool vpnConnected: false
    property string vpnName: ""

    Process {
        id: vpnCheckProc
        command: ["bash", "-c", "ip -o link show | grep -E '(tun[0-9]|wg[0-9]|tailscale|proton|nord)' | awk -F': ' '{print $2}' | head -n 1"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                root.vpnConnected = line.length > 0;
                root.vpnName = line;
            }
        }
    }

    Timer {
        id: vpnPollTimer
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!vpnCheckProc.running) vpnCheckProc.running = true;
        }
    }

    Process {
        id: vpnToggleProc
        running: false
    }

    function toggleVpn() {
        if (vpnConnected) {
            vpnToggleProc.command = ["bash", "-c", "if [ -n '" + root.vpnName + "' ]; then ip link set '" + root.vpnName + "' down 2>/dev/null; nmcli con down id '" + root.vpnName + "' 2>/dev/null; wg-quick down '" + root.vpnName + "' 2>/dev/null; fi"];
            vpnToggleProc.running = true;
            vpnConnected = false;
            vpnName = "";
            if (Island.IslandHub) Island.IslandHub.showTransient("󰒘 VPN Disconnected", 2000);
        } else {
            vpnToggleProc.command = ["bash", "-c", "con=$(nmcli -t -f TYPE,NAME connection show | grep -E '^(vpn|wireguard):' | head -n 1 | cut -d: -f2); if [ -n \"$con\" ]; then nmcli connection up id \"$con\"; elif [ -f /etc/wireguard/wg0.conf ]; then wg-quick up wg0; else echo 'NO_VPN'; fi"];
            vpnToggleProc.running = true;
            if (Island.IslandHub) Island.IslandHub.showTransient("󰒘 Connecting VPN...", 2000);
        }
        vpnCheckProc.running = true;
    }

    // Airplane Mode State & Toggle
    property bool airplaneMode: (!wifiOn && (!btAdapter || !btAdapter.enabled))

    Process {
        id: rfkillToggleProc
        running: false
    }

    function toggleAirplaneMode() {
        if (airplaneMode) {
            Networking.wifiEnabled = true;
            if (root.btAdapter) root.btAdapter.enabled = true;
            rfkillToggleProc.command = ["rfkill", "unblock", "all"];
            rfkillToggleProc.running = true;
            airplaneMode = false;
            if (Island.IslandHub) Island.IslandHub.showTransient("󰀝 Airplane Mode: Off", 2000);
        } else {
            Networking.wifiEnabled = false;
            if (root.btAdapter) root.btAdapter.enabled = false;
            rfkillToggleProc.command = ["rfkill", "block", "all"];
            rfkillToggleProc.running = true;
            airplaneMode = true;
            if (Island.IslandHub) Island.IslandHub.showTransient("󰀝 Airplane Mode: On", 2000);
        }
    }

    // MPRIS Active Player Detection
    readonly property var activePlayer: {
        const players = Mpris.players.values;
        for (let i = 0; i < players.length; ++i) {
            const p = players[i];
            if (p && ((p.identity && p.identity.toLowerCase().indexOf("spotify") !== -1) ||
                      (p.desktopEntry && p.desktopEntry.toLowerCase().indexOf("spotify") !== -1))) {
                return p;
            }
        }
        for (let i = 0; i < players.length; ++i) {
            if (players[i] && players[i].isPlaying) return players[i];
        }
        return players.length > 0 ? players[0] : null;
    }
    readonly property bool isMediaPlaying: activePlayer ? activePlayer.isPlaying : false
    readonly property string trackTitle: (activePlayer && activePlayer.trackTitle) ? activePlayer.trackTitle : "Not Playing"
    readonly property string trackArtist: (activePlayer && activePlayer.trackArtist) ? activePlayer.trackArtist : "No Media Active"
    readonly property string trackArtUrl: (activePlayer && activePlayer.trackArtUrl) ? activePlayer.trackArtUrl : ""

    // Game Mode State directly synchronized with Island.ShellState single source of truth
    readonly property bool gameModeActive: Island.ShellState ? Island.ShellState.gameMode : false
    readonly property int gameModeKilledCount: Island.ShellState ? Island.ShellState.gameModeKilledCount : 0

    function toggleGameMode() {
        if (Island.ShellState) Island.ShellState.toggleGameMode();
    }

    // The Feather Mode State (Absolute Battery Optimization)
    readonly property bool featherModeActive: Island.ShellState ? Island.ShellState.featherMode : false
    readonly property int featherModeKilledCount: Island.ShellState ? Island.ShellState.featherKilledCount : 0
    readonly property int featherModeLimit: Island.ShellState ? Island.ShellState.featherLimit : 20

    function toggleFeatherMode(limit) {
        if (Island.ShellState) Island.ShellState.toggleFeatherMode(limit);
    }
    function setFeatherLimit(val) {
        if (Island.ShellState) Island.ShellState.setFeatherLimit(val);
    }

    // God's Eye View Mode State
    readonly property bool godsEyeActive: Island.ShellState ? Island.ShellState.godsEyeActive : false

    function toggleGodsEye() {
        if (Island.ShellState) Island.ShellState.toggleGodsEye();
    }
    function openGodsEyeBrowser() {
        if (Island.ShellState) Island.ShellState.openGodsEyeBrowser();
    }

    // Study Mode State & Ceremony Bindings
    readonly property bool studyActive: Island.ShellState ? Island.ShellState.studyActive : false
    readonly property int studyRemaining: Island.ShellState ? Island.ShellState.studyRemaining : 0
    readonly property bool studyOvertime: Island.ShellState ? Island.ShellState.studyOvertime : false
    readonly property int studyOvertimeSeconds: Island.ShellState ? Island.ShellState.studyOvertimeSeconds : 0
    readonly property string studySubject: Island.ShellState ? Island.ShellState.studySubject : "CA / ICAI Study"

    property int studyModalStep: 0 // 0: Hidden, 1: Warning 1, 2: Warning 2
    property string studyPasswordInput: ""
    property string studyPasswordError: ""

    function formatStudyDuration(sec) {
        if (sec >= 86400) {
            const d = Math.floor(sec / 86400);
            const h = Math.floor((sec % 86400) / 3600);
            return d + "d " + (h < 10 ? "0" : "") + h + "h";
        }
        if (sec >= 3600) {
            const h = Math.floor(sec / 3600);
            const m = Math.floor((sec % 3600) / 60);
            return (h < 10 ? "0" : "") + h + "h " + (m < 10 ? "0" : "") + m + "m";
        }
        const m = Math.floor(sec / 60);
        const s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function triggerStudyModeClick() {
        if (studyActive) {
            if (studyOvertime || studyRemaining <= 0) {
                if (Island.ShellState) Island.ShellState.stopStudyMode();
            } else {
                Island.IslandHub.showTransient("🔒 Hard Lock Active: Cannot exit early (" + formatStudyDuration(studyRemaining) + " left)", 3500);
            }
        } else {
            studyPasswordInput = "";
            studyPasswordError = "";
            studyModalStep = 1;
        }
    }

    // CoolPhone State & Control
    readonly property bool phoneSystemEnabled: Island.ShellState ? Island.ShellState.phoneSystemEnabled : false
    readonly property bool phoneConnected: Island.ShellState ? Island.ShellState.phoneConnected : false
    readonly property bool phoneMirrorActive: Island.ShellState ? Island.ShellState.phoneMirrorActive : false
    readonly property int phoneBattery: Island.ShellState ? Island.ShellState.phoneBattery : -1
    readonly property bool phoneCharging: Island.ShellState ? Island.ShellState.phoneCharging : false

    function togglePhoneMirror() {
        if (Island.ShellState) Island.ShellState.togglePhoneMirror();
    }

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    // =========================================================================
    // SCROLLABLE MODULAR GRID BODY (visionOS Style)
    // =========================================================================
    Flickable {
        id: mainFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + 16
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3500
        maximumFlickVelocity: 1800
        clip: true

        // Subtle vertical scroll indicator
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: -4
            y: mainFlickable.visibleArea.yPosition * mainFlickable.height
            width: 3
            height: Math.max(24, mainFlickable.visibleArea.heightRatio * mainFlickable.height)
            radius: 1.5
            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.45)
            visible: mainFlickable.contentHeight > mainFlickable.height + 2
            opacity: mainFlickable.moving ? 0.9 : 0.35
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Column {
            id: mainColumn
            width: parent.width
            spacing: 12

            // =================================================================
            // ROW 1: HEADER (Clock, Date & Settings Gear)
            // =================================================================
            Item {
                width: parent.width
                height: 48

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: Qt.formatDateTime(sysClock.date, "hh:mm")
                        font.pixelSize: 22
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                    }

                    Text {
                        text: Qt.formatDateTime(sysClock.date, "dddd, dd MMMM")
                        font.pixelSize: 11
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.muted
                    }
                }

                // Header Action Buttons (Appearance Theme, Ambient HUD, Settings Gear)
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Appearance Dark/Light Button
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        readonly property bool isLight: Island.Theme && Island.Theme.isLightMode
                        color: themeHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard
                        border.color: themeHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle
                        border.width: 1
                        scale: themeTap.pressed ? 0.94 : 1.0

                        Behavior on scale { NumberAnimation { duration: 90 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: parent.isLight ? "󰖨" : "󰖔"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 15
                            color: themeHover.hovered ? Island.Theme.primary : Island.Theme.muted
                        }

                        HoverHandler { id: themeHover }
                        TapHandler {
                            id: themeTap
                            onTapped: {
                                if (Island.AppearanceState)
                                    Island.AppearanceState.toggleMode();
                            }
                        }
                    }

                    // Ambient HUD Mode Button
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        readonly property color ambColor: root.ambientAlwaysOn ? Island.Theme.cyan : Island.Theme.blue
                        color: root.ambientEnabled 
                            ? Qt.rgba(ambColor.r, ambColor.g, ambColor.b, 0.22) 
                            : (ambHeaderHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard)
                        border.color: root.ambientEnabled ? ambColor : (ambHeaderHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                        border.width: 1
                        scale: ambHeaderTap.pressed ? 0.94 : 1.0

                        Behavior on scale { NumberAnimation { duration: 90 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.ambientAlwaysOn ? "󰈈" : "󰍹"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 15
                            color: root.ambientEnabled ? parent.ambColor : Island.Theme.muted
                        }

                        HoverHandler { id: ambHeaderHover }
                        TapHandler {
                            id: ambHeaderTap
                            onTapped: {
                                if (root.ambientEnabled && !root.ambientAlwaysOn) {
                                    if (Island.IslandHub) Island.IslandHub.showTransient("󰈈 Ambient: Always On", 2200);
                                } else if (root.ambientEnabled && root.ambientAlwaysOn) {
                                    if (Island.IslandHub) Island.IslandHub.showTransient("󰍹 Ambient: Disabled", 2200);
                                } else {
                                    if (Island.IslandHub) Island.IslandHub.showTransient("󰍹 Ambient: Dynamic (Idle Only)", 2200);
                                }
                                root.cycleAmbient();
                            }
                        }
                    }

                    // Settings Gear Icon Button
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: gearHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard
                        border.color: gearHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle
                        border.width: 1
                        scale: gearTap.pressed ? 0.94 : 1.0

                        Behavior on scale { NumberAnimation { duration: 90 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒓"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 15
                            color: gearHover.hovered ? Island.Theme.primary : Island.Theme.muted
                        }

                        HoverHandler { id: gearHover }
                        TapHandler {
                            id: gearTap
                            onTapped: {
                                if (root.desktopState) root.desktopState.setLeftSidebarOpen(false);
                                Island.ShellState.openSettings("");
                            }
                        }
                    }
                }
            }

            // =================================================================
            // ROW 2: TOP TILES (Connectivity 2x2 Pod + Now Playing Media Card)
            // =================================================================
            Row {
                width: parent.width
                spacing: 12

                // -------------------------------------------------------------
                // TILE 1: CONNECTIVITY POD (158x158px squircle)
                // -------------------------------------------------------------
                Rectangle {
                    width: (parent.width - 12) / 2
                    height: 158
                    radius: 22
                    color: Island.Theme.glassCard
                    border.color: Island.Theme.glassBorderSubtle
                    border.width: 1

                    // Refractive glass inner rim
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 21
                        color: "transparent"
                        border.color: Qt.rgba(1, 1, 1, 0.07)
                        border.width: 1
                    }

                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        spacing: 12

                        // 1. Wi-Fi Round Button
                        Rectangle {
                            width: 58
                            height: 58
                            radius: 29
                            color: root.wifiConnected 
                                ? "#0a84ff" 
                                : (root.wifiOn ? Qt.rgba(0.04, 0.52, 1.0, 0.22) : (wifiBtnHover.hovered ? Island.Theme.glassCardHover : "transparent"))
                            border.color: root.wifiConnected ? "#0a84ff" : (wifiBtnHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                            border.width: 1
                            scale: wifiBtnTap.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: wifiBtnHover }
                            TapHandler {
                                id: wifiBtnTap
                                onTapped: {
                                    Networking.wifiEnabled = !Networking.wifiEnabled;
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰤨"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 18
                                    color: root.wifiConnected ? "#ffffff" : (root.wifiOn ? "#0a84ff" : Island.Theme.muted)
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.wifiConnected ? "On" : (root.wifiOn ? "Search" : "Off")
                                    font.pixelSize: 8
                                    font.bold: true
                                    font.family: Island.Theme.fontFamily
                                    color: root.wifiConnected ? "#ffffff" : Island.Theme.muted
                                }
                            }
                        }

                        // 2. Bluetooth Round Button
                        Rectangle {
                            width: 58
                            height: 58
                            radius: 29
                            color: root.btConnected 
                                ? "#0a84ff" 
                                : (root.btOn ? Qt.rgba(0.04, 0.52, 1.0, 0.22) : (btBtnHover.hovered ? Island.Theme.glassCardHover : "transparent"))
                            border.color: root.btConnected ? "#0a84ff" : (btBtnHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                            border.width: 1
                            scale: btBtnTap.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: btBtnHover }
                            TapHandler {
                                id: btBtnTap
                                onTapped: {
                                    if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled;
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰂯"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 18
                                    color: root.btConnected ? "#ffffff" : (root.btOn ? "#0a84ff" : Island.Theme.muted)
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.btConnected ? "Paired" : (root.btOn ? "On" : "Off")
                                    font.pixelSize: 8
                                    font.bold: true
                                    font.family: Island.Theme.fontFamily
                                    color: root.btConnected ? "#ffffff" : Island.Theme.muted
                                }
                            }
                        }

                        // 3. VPN Secure Tunnel Round Button
                        Rectangle {
                            width: 58
                            height: 58
                            radius: 29
                            color: root.vpnConnected 
                                ? "#0a84ff" 
                                : (vpnBtnHover.hovered ? Island.Theme.glassCardHover : "transparent")
                            border.color: root.vpnConnected ? "#0a84ff" : (vpnBtnHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                            border.width: 1
                            scale: vpnBtnTap.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: vpnBtnHover }
                            TapHandler {
                                id: vpnBtnTap
                                onTapped: root.toggleVpn()
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰒘"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 18
                                    color: root.vpnConnected ? "#ffffff" : Island.Theme.muted
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.vpnConnected ? "On" : "VPN"
                                    font.pixelSize: 8
                                    font.bold: true
                                    font.family: Island.Theme.fontFamily
                                    color: root.vpnConnected ? "#ffffff" : Island.Theme.muted
                                }
                            }
                        }

                        // 4. Airplane Mode Round Button
                        Rectangle {
                            width: 58
                            height: 58
                            radius: 29
                            color: root.airplaneMode 
                                ? "#ff9f0a" 
                                : (airBtnHover.hovered ? Island.Theme.glassCardHover : "transparent")
                            border.color: root.airplaneMode ? "#ff9f0a" : (airBtnHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                            border.width: 1
                            scale: airBtnTap.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: airBtnHover }
                            TapHandler {
                                id: airBtnTap
                                onTapped: root.toggleAirplaneMode()
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰀝"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 18
                                    color: root.airplaneMode ? "#ffffff" : Island.Theme.muted
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.airplaneMode ? "On" : "Airplane"
                                    font.pixelSize: 8
                                    font.bold: true
                                    font.family: Island.Theme.fontFamily
                                    color: root.airplaneMode ? "#ffffff" : Island.Theme.muted
                                }
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // TILE 2: NOW PLAYING MEDIA POD (158x158px squircle)
                // -------------------------------------------------------------
                Rectangle {
                    width: (parent.width - 12) / 2
                    height: 158
                    radius: 22
                    color: Island.Theme.glassCard
                    border.color: Island.Theme.glassBorderSubtle
                    border.width: 1
                    clip: true

                    // Refractive glass inner rim
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 21
                        color: "transparent"
                        border.color: Qt.rgba(1, 1, 1, 0.07)
                        border.width: 1
                        z: 10
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // Top Row: Album Artwork & AirPlay Badge
                        Item {
                            width: parent.width
                            height: 42

                            Rectangle {
                                id: artThumb
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 42
                                height: 42
                                radius: 10
                                color: Island.Theme.glassCardHover
                                border.color: Island.Theme.glassBorderSubtle
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: root.trackArtUrl
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: Boolean(root.trackArtUrl)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰎆"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 18
                                    color: Island.Theme.primary
                                    visible: !root.trackArtUrl
                                }
                            }

                            // Speaker Output Pill
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                                height: 24
                                radius: 12
                                color: Qt.rgba(1, 1, 1, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰕾"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 12
                                    color: Island.Theme.muted
                                }
                            }
                        }

                        // Track Title & Artist Text
                        Column {
                            width: parent.width
                            spacing: 2

                            Text {
                                width: parent.width
                                text: root.trackTitle
                                font.pixelSize: 12
                                font.bold: true
                                font.family: Island.Theme.fontFamily
                                color: Island.Theme.foreground
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: root.trackArtist
                                font.pixelSize: 10
                                font.family: Island.Theme.fontFamily
                                color: Island.Theme.muted
                                elide: Text.ElideRight
                            }
                        }

                        // Transport Controls (Previous, Play/Pause, Next)
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 12

                            // Previous
                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: prevHover.hovered ? Island.Theme.glassCardHover : "transparent"
                                scale: prevTap.pressed ? 0.92 : 1.0
                                Behavior on scale { NumberAnimation { duration: 80 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒮"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 15
                                    color: Island.Theme.foreground
                                }

                                HoverHandler { id: prevHover }
                                TapHandler {
                                    id: prevTap
                                    onTapped: {
                                        if (root.activePlayer && root.activePlayer.canGoPrevious)
                                            root.activePlayer.previous();
                                    }
                                }
                            }

                            // Play / Pause Circle
                            Rectangle {
                                width: 34
                                height: 34
                                radius: 17
                                color: root.isMediaPlaying ? "#ffffff" : Island.Theme.glassCardHover
                                scale: playTap.pressed ? 0.92 : 1.0
                                Behavior on scale { NumberAnimation { duration: 80 } }
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.isMediaPlaying ? "󰏤" : "󰐊"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 16
                                    color: root.isMediaPlaying ? "#0a0a0f" : Island.Theme.foreground
                                }

                                TapHandler {
                                    id: playTap
                                    onTapped: {
                                        if (root.activePlayer)
                                            root.activePlayer.playPause();
                                    }
                                }
                            }

                            // Next
                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: nextHover.hovered ? Island.Theme.glassCardHover : "transparent"
                                scale: nextTap.pressed ? 0.92 : 1.0
                                Behavior on scale { NumberAnimation { duration: 80 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒭"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 15
                                    color: Island.Theme.foreground
                                }

                                HoverHandler { id: nextHover }
                                TapHandler {
                                    id: nextTap
                                    onTapped: {
                                        if (root.activePlayer && root.activePlayer.canGoNext)
                                            root.activePlayer.next();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // ROW 3: MODES POD & DUAL VERTICAL CAPSULE SLIDERS
            // =================================================================
            Row {
                width: parent.width
                spacing: 12

                // -------------------------------------------------------------
                // TILE 3: SYSTEM MODES POD (158x158px squircle)
                // -------------------------------------------------------------
                Rectangle {
                    width: (parent.width - 12) / 2
                    height: 158
                    radius: 22
                    color: Island.Theme.glassCard
                    border.color: Island.Theme.glassBorderSubtle
                    border.width: 1

                    // Refractive glass inner rim
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 21
                        color: "transparent"
                        border.color: Qt.rgba(1, 1, 1, 0.07)
                        border.width: 1
                    }

                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        spacing: 12

                        // 1. Performance / Game Mode Button
                        Rectangle {
                            width: 58
                            height: 58
                            radius: 29
                            color: root.gameModeActive 
                                ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.25)
                                : (gameBtnHover.hovered ? Island.Theme.glassCardHover : "transparent")
                            border.color: root.gameModeActive ? Island.Theme.red : (gameBtnHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                            border.width: 1
                            scale: gameBtnTap.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: gameBtnHover }
                            TapHandler {
                                id: gameBtnTap
                                onTapped: root.toggleGameMode()
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰓅"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 18
                                    color: root.gameModeActive ? Island.Theme.red : Island.Theme.muted
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.gameModeActive ? "Boost" : "Normal"
                                    font.pixelSize: 8
                                    font.bold: true
                                    font.family: Island.Theme.fontFamily
                                    color: root.gameModeActive ? Island.Theme.red : Island.Theme.muted
                                }
                            }
                        }

                        // 2. The Feather (Battery Optimization) Button
                        Rectangle {
                            width: 58
                            height: 58
                            radius: 29
                            color: root.featherModeActive 
                                ? Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.25)
                                : (fthrBtnHover.hovered ? Island.Theme.glassCardHover : "transparent")
                            border.color: root.featherModeActive ? Island.Theme.green : (fthrBtnHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                            border.width: 1
                            scale: fthrBtnTap.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: fthrBtnHover }
                            TapHandler {
                                id: fthrBtnTap
                                onTapped: root.toggleFeatherMode()
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰌪"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 18
                                    color: root.featherModeActive ? Island.Theme.green : Island.Theme.muted
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.featherModeActive ? (root.featherModeLimit + "%") : "Eco"
                                    font.pixelSize: 8
                                    font.bold: true
                                    font.family: Island.Theme.fontFamily
                                    color: root.featherModeActive ? Island.Theme.green : Island.Theme.muted
                                }
                            }
                        }

                        // 3. Do Not Disturb Button
                        Rectangle {
                            id: dndBtn
                            width: 58
                            height: 58
                            radius: 29
                            readonly property bool dndActive: Island.IslandHub ? Island.IslandHub.dnd : false
                            color: dndActive 
                                ? Qt.rgba(Island.Theme.purple.r, Island.Theme.purple.g, Island.Theme.purple.b, 0.25)
                                : (dndBtnHover.hovered ? Island.Theme.glassCardHover : "transparent")
                            border.color: dndActive ? Island.Theme.purple : (dndBtnHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                            border.width: 1
                            scale: dndBtnTap.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: dndBtnHover }
                            TapHandler {
                                id: dndBtnTap
                                onTapped: {
                                    if (Island.IslandHub)
                                        Island.IslandHub.dnd = !Island.IslandHub.dnd;
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰂛"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 18
                                    color: dndBtn.dndActive ? Island.Theme.purple : Island.Theme.muted
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: dndBtn.dndActive ? "Silent" : "Alerts"
                                    font.pixelSize: 8
                                    font.bold: true
                                    font.family: Island.Theme.fontFamily
                                    color: dndBtn.dndActive ? Island.Theme.purple : Island.Theme.muted
                                }
                            }
                        }

                        // 4. Wallpaper Dynamic Toggle Button
                        Rectangle {
                            width: 58
                            height: 58
                            radius: 29
                            color: root.wallpaperEnabled 
                                ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25)
                                : (wpBtnHover.hovered ? Island.Theme.glassCardHover : "transparent")
                            border.color: root.wallpaperEnabled ? Island.Theme.primary : (wpBtnHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                            border.width: 1
                            scale: wpBtnTap.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: wpBtnHover }
                            TapHandler {
                                id: wpBtnTap
                                onTapped: root.toggleWallpaper()
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰸉"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 18
                                    color: root.wallpaperEnabled ? Island.Theme.primary : Island.Theme.muted
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.wallpaperEnabled ? "Dynamic" : "Static"
                                    font.pixelSize: 8
                                    font.bold: true
                                    font.family: Island.Theme.fontFamily
                                    color: root.wallpaperEnabled ? Island.Theme.primary : Island.Theme.muted
                                }
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // TILE 4: DUAL VERTICAL CAPSULE SLIDERS (158x158px pod)
                // -------------------------------------------------------------
                Row {
                    width: (parent.width - 12) / 2
                    height: 158
                    spacing: 14

                    // 1. Display Brightness Capsule Slider
                    VerticalCapsuleSlider {
                        width: (parent.width - 14) / 2
                        height: 158
                        value: (Island.Backend ? Island.Backend.brightness : 80) / 100.0
                        icon: "󰃠"
                        iconActive: "󰃟"
                        label: "Brightness"
                        valueText: (Island.Backend ? Island.Backend.brightness : 80) + "%"
                        activeFillColor: "#ffffff"
                        onMoved: (val) => {
                            if (Island.Backend) {
                                Island.Backend.setBrightness(Math.round(val * 100));
                            }
                        }
                    }

                    // 2. Master Volume Capsule Slider
                    VerticalCapsuleSlider {
                        width: (parent.width - 14) / 2
                        height: 158
                        value: root.currentVolume
                        icon: root.audioMuted ? "󰖁" : "󰕾"
                        iconActive: "󰖁"
                        isMuted: root.audioMuted
                        label: "Volume"
                        valueText: root.audioMuted ? "Muted" : Math.round(root.currentVolume * 100) + "%"
                        activeFillColor: "#ffffff"
                        onMoved: (val) => {
                            if (root.sinkAudio) {
                                root.sinkAudio.volume = val;
                            }
                        }
                        onIconTapped: {
                            if (root.sinkAudio) {
                                root.sinkAudio.muted = !root.sinkAudio.muted;
                            }
                        }
                    }
                }
            }

            // =================================================================
            // ROW 4: STUDY MODE FOCUS LOCKOUT BANNER (Full Width)
            // =================================================================
            Rectangle {
                width: parent.width
                height: 60
                radius: 18
                color: root.studyActive 
                    ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.18)
                    : (studyCardHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard)
                border.color: root.studyActive ? Island.Theme.red : (studyCardHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                border.width: root.studyActive ? 1.5 : 1

                HoverHandler { id: studyCardHover }

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: root.studyActive ? Island.Theme.red : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.18)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: root.studyActive ? "󰌾" : "󰌵"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 18
                            color: root.studyActive ? "#ffffff" : Island.Theme.primary
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 36 - 80 - 24
                        spacing: 2

                        Text {
                            text: root.studyActive ? "Study Lockdown Active" : "Study Mode"
                            font.pixelSize: 12
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                        }

                        Text {
                            text: root.studyActive
                                ? (root.studyOvertime ? ("Overtime +" + root.formatStudyDuration(root.studyOvertimeSeconds)) : (root.formatStudyDuration(root.studyRemaining) + " remaining"))
                                : "Deep work lockout • Whitelist only"
                            font.pixelSize: 10
                            font.family: Island.Theme.fontFamily
                            color: root.studyActive ? Island.Theme.red : Island.Theme.muted
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 76
                        height: 30
                        radius: 15
                        color: root.studyActive ? Island.Theme.red : Island.Theme.primary
                        scale: studyBtnTap.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.studyActive ? "Unlock" : "Lock In"
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: root.studyActive ? "#ffffff" : "#0a0a0f"
                        }

                        TapHandler {
                            id: studyBtnTap
                            onTapped: root.triggerStudyModeClick()
                        }
                    }
                }
            }

            // =================================================================
            // ROW 5: SPECIALIZED PRO TOOLS (CoolPhone Device Bridge)
            // =================================================================
            Rectangle {
                width: parent.width
                height: 60
                radius: 18
                color: root.phoneMirrorActive
                    ? Qt.rgba(Island.Theme.blue.r, Island.Theme.blue.g, Island.Theme.blue.b, 0.16)
                    : (phoneHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard)
                border.color: root.phoneMirrorActive ? Island.Theme.blue : (phoneHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                border.width: root.phoneMirrorActive ? 1.5 : 1

                HoverHandler { id: phoneHover }

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: root.phoneConnected 
                            ? Island.Theme.blue 
                            : Qt.rgba(Island.Theme.blue.r, Island.Theme.blue.g, Island.Theme.blue.b, 0.18)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰏲"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 18
                            color: root.phoneConnected ? "#0a0a0f" : Island.Theme.blue
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 36 - 84 - 24
                        spacing: 2

                        Text {
                            text: "CoolPhone Bridge"
                            font.pixelSize: 12
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                        }

                        Text {
                            text: root.phoneConnected 
                                ? ("Connected" + (root.phoneBattery >= 0 ? " • " + root.phoneBattery + "%" : "") + (root.phoneCharging ? " 󱐋" : "")) 
                                : "Disconnected • Scrcpy Mirror"
                            font.pixelSize: 10
                            font.family: Island.Theme.fontFamily
                            color: root.phoneConnected ? Island.Theme.blue : Island.Theme.muted
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 80
                        height: 30
                        radius: 15
                        color: phoneBtnHover.hovered ? Island.Theme.blue : Qt.rgba(Island.Theme.blue.r, Island.Theme.blue.g, Island.Theme.blue.b, 0.22)
                        border.color: Island.Theme.blue
                        border.width: 1
                        scale: phoneBtnTap.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.phoneMirrorActive ? "STOP" : "MIRROR"
                            font.pixelSize: 9
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: phoneBtnHover.hovered ? "#0a0a0f" : Island.Theme.blue
                        }

                        HoverHandler { id: phoneBtnHover }
                        TapHandler {
                            id: phoneBtnTap
                            onTapped: root.togglePhoneMirror()
                        }
                    }
                }
            }

            // =================================================================
            // ROW 6: AI IMAGE STUDIO CARD & LIFECYCLE TOGGLE
            // =================================================================
            Rectangle {
                width: parent.width
                height: 60
                radius: 18
                color: aiCardHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard
                border.color: aiCardHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle
                border.width: 1

                HoverHandler { id: aiCardHover }

                TapHandler {
                    id: aiCardTap
                    onTapped: {
                        if (root.desktopState) root.desktopState.setLeftSidebarOpen(false);
                        if (Island.IslandHub) Island.IslandHub.triggerAiPromptRequested();
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: Qt.rgba(Island.Theme.purple.r, Island.Theme.purple.g, Island.Theme.purple.b, 0.18)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󱨊"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 18
                            color: Island.Theme.purple
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 36 - 120 - 24
                        spacing: 2

                        Text {
                            text: "AI Image Studio"
                            font.pixelSize: 12
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                        }

                        Text {
                            text: {
                                const state = Island.ShellState;
                                if (!state) return "Realistic Vision v5.1 + LCM • Super + G";
                                if (state.aiDaemonLoading) {
                                    const ram = state.aiDaemonRamMb;
                                    if (ram > 50) {
                                        const ramStr = ram >= 1024 ? (ram / 1024.0).toFixed(1) + " GB" : Math.round(ram) + " MB";
                                        return "Loading weights into RAM (" + ramStr + ")...";
                                    }
                                    return "Loading weights into RAM...";
                                }
                                if (state.aiDaemonLoaded) {
                                    const ram = state.aiDaemonRamMb;
                                    const ramStr = ram >= 1024 ? (ram / 1024.0).toFixed(1) + " GB" : (ram > 0 ? Math.round(ram) + " MB" : "Active");
                                    return "Model Warm (" + ramStr + " RAM) • Super + G";
                                }
                                return "Model Offloaded (0 MB RAM) • Super + G";
                            }
                            font.pixelSize: 10
                            font.family: Island.Theme.fontFamily
                            color: (Island.ShellState && Island.ShellState.aiDaemonLoaded)
                                ? Qt.rgba(Island.Theme.purple.r, Island.Theme.purple.g, Island.Theme.purple.b, 0.9)
                                : Island.Theme.muted
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // WebUI Studio Chat Launcher Button
                        Rectangle {
                            width: 30
                            height: 30
                            radius: 15
                            anchors.verticalCenter: parent.verticalCenter
                            color: studioChatHover.hovered 
                                ? Qt.rgba(Island.Theme.purple.r, Island.Theme.purple.g, Island.Theme.purple.b, 0.28) 
                                : Qt.rgba(255, 255, 255, 0.05)
                            border.color: studioChatHover.hovered ? Island.Theme.purple : Island.Theme.glassBorderSubtle
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰭹"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 13
                                color: studioChatHover.hovered ? Island.Theme.purple : Island.Theme.foreground
                            }

                            HoverHandler { id: studioChatHover }
                            TapHandler {
                                onTapped: {
                                    Quickshell.execDetached([Quickshell.shellPath("scripts/launch-chat.sh")]);
                                }
                            }
                        }

                        // Model Lifecycle Toggle Button (ON / OFF)
                        Rectangle {
                            id: aiToggleBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: 76
                            height: 30
                            radius: 15

                            readonly property bool isLoaded: Island.ShellState ? Island.ShellState.aiDaemonLoaded : false
                            readonly property bool isLoading: Island.ShellState ? Island.ShellState.aiDaemonLoading : false

                            color: isLoaded
                                ? Qt.rgba(Island.Theme.purple.r, Island.Theme.purple.g, Island.Theme.purple.b, 0.25)
                                : (isLoading
                                    ? Qt.rgba(Island.Theme.purple.r, Island.Theme.purple.g, Island.Theme.purple.b, 0.12)
                                    : (aiToggleHover.hovered ? Island.Theme.glassCardHover : Qt.rgba(255, 255, 255, 0.04)))
                            border.color: isLoaded
                                ? Island.Theme.purple
                                : (isLoading
                                    ? Qt.rgba(Island.Theme.purple.r, Island.Theme.purple.g, Island.Theme.purple.b, 0.45)
                                    : (aiToggleHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle))
                            border.width: 1
                            scale: aiToggleTap.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            HoverHandler { id: aiToggleHover }

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                // Indicator dot
                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: aiToggleBtn.isLoaded
                                        ? Island.Theme.purple
                                        : (aiToggleBtn.isLoading ? Island.Theme.yellow : Island.Theme.muted)
                                    opacity: aiToggleBtn.isLoaded ? 1.0 : (aiToggleBtn.isLoading ? 0.8 : 0.4)

                                    SequentialAnimation on opacity {
                                        running: aiToggleBtn.isLoading
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.2; duration: 400; easing.type: Easing.InOutQuad }
                                        NumberAnimation { to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: aiToggleBtn.isLoading
                                        ? "LOAD..."
                                        : (aiToggleBtn.isLoaded ? "ON" : "OFF")
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.family: Island.Theme.fontFamily
                                    color: aiToggleBtn.isLoaded
                                        ? Island.Theme.purple
                                        : (aiToggleBtn.isLoading ? Island.Theme.yellow : Island.Theme.muted)
                                }
                            }

                            TapHandler {
                                id: aiToggleTap
                                onTapped: {
                                    if (Island.ShellState) Island.ShellState.toggleAiDaemon();
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // ROW 7: WORKSPACE TELEMETRY & QUICK SHORTCUTS
            // =================================================================
            Rectangle {
                width: parent.width
                height: 52
                radius: 16
                color: Island.Theme.glassCard
                border.color: Island.Theme.glassBorderSubtle
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    // Workspace indicator pill
                    Rectangle {
                        height: 24
                        width: wsLabel.implicitWidth + 16
                        radius: 12
                        color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.2)
                        border.color: Island.Theme.glassBorderActive
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: wsLabel
                            anchors.centerIn: parent
                            text: "WS " + (root.desktopState ? root.desktopState.currentWorkspaceId : "1")
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.primary
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const count = root.desktopState ? root.desktopState.currentSurfaceCount : 0;
                            return (count === 1 ? "1 window" : count + " windows") + " • " + (root.screen ? root.screen.width + "×" + root.screen.height : "1080p");
                        }
                        font.pixelSize: 10
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.muted
                    }
                }
            }

            // Action Buttons Row: Snipping, Screenshot, Record
            Row {
                width: parent.width
                spacing: 8

                // Snipping Tool
                Rectangle {
                    width: (parent.width - 16) / 3
                    height: 36
                    radius: 12
                    color: snipHover.hovered ? Island.Theme.primaryContainer : Island.Theme.glassCard
                    border.color: snipHover.hovered ? Island.Theme.glassBorderActive : Island.Theme.glassBorderSubtle
                    border.width: 1
                    scale: snipTap.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    HoverHandler { id: snipHover }
                    TapHandler {
                        id: snipTap
                        onTapped: {
                            if (root.desktopState) root.desktopState.setLeftSidebarOpen(false);
                            Island.Backend.capture("region");
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰩭"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: Island.Theme.primary
                        }
                        Text {
                            text: "Snip"
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                        }
                    }
                }

                // Fullscreen Screenshot
                Rectangle {
                    width: (parent.width - 16) / 3
                    height: 36
                    radius: 12
                    color: scHover.hovered ? Island.Theme.primaryContainer : Island.Theme.glassCard
                    border.color: scHover.hovered ? Island.Theme.glassBorderActive : Island.Theme.glassBorderSubtle
                    border.width: 1
                    scale: scTap.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    HoverHandler { id: scHover }
                    TapHandler {
                        id: scTap
                        onTapped: {
                            if (root.desktopState) root.desktopState.setLeftSidebarOpen(false);
                            Island.Backend.capture("screen");
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰹑"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: Island.Theme.primary
                        }
                        Text {
                            text: "Screen"
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                        }
                    }
                }

                // Record Screen
                Rectangle {
                    width: (parent.width - 16) / 3
                    height: 36
                    radius: 12
                    color: recHover.hovered ? Island.Theme.primaryContainer : Island.Theme.glassCard
                    border.color: recHover.hovered ? Island.Theme.glassBorderActive : Island.Theme.glassBorderSubtle
                    border.width: 1
                    scale: recTap.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    HoverHandler { id: recHover }
                    TapHandler {
                        id: recTap
                        onTapped: {
                            if (root.desktopState) root.desktopState.setLeftSidebarOpen(false);
                            Island.Backend.toggleRecording("region", Island.Backend.recordAudio);
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰑋"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: Island.Theme.red
                        }
                        Text {
                            text: "Record"
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // STUDY MODE: 2-WARNING CEREMONY & POP-UP PASSWORD WINDOW
    // =========================================================================
    Process {
        id: promptStudyProc
        command: ["python3", Quickshell.shellPath("scripts/study-mode.py"), "prompt-and-start", "--duration", (Island.ShellState ? Island.ShellState.studyTargetDuration.toString() : "1800")]
        running: false
    }

    Rectangle {
        id: studyModalOverlay
        anchors.fill: parent
        z: 999
        visible: root.studyModalStep > 0
        color: Qt.rgba(0.04, 0.05, 0.08, 0.96)
        radius: 18
        border.color: Island.Theme.glassBorderActive
        border.width: 1

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - 36
            spacing: 16

            // Header Icon & Step pill
            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    width: 36
                    height: 36
                    radius: 10
                    color: root.studyModalStep === 1
                        ? Qt.rgba(Island.Theme.orange.r, Island.Theme.orange.g, Island.Theme.orange.b, 0.2)
                        : Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.2)
                    border.color: root.studyModalStep === 1 ? Island.Theme.orange : Island.Theme.red
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.studyModalStep === 1 ? "󰀦" : "󰈈"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 18
                        color: parent.border.color
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: root.studyModalStep === 1
                            ? "Warning 1: Lockdown Block"
                            : "Warning 2: Hard Commitment"
                        font.pixelSize: 13
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                    }
                    Text {
                        text: "Step " + root.studyModalStep + " of 2 • Study Lockdown"
                        font.pixelSize: 10
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.muted
                    }
                }
            }

            // Body Card with explanatory text
            Rectangle {
                width: parent.width
                height: 155
                radius: 12
                color: Island.Theme.glassCard
                border.color: Island.Theme.glassBorderSubtle
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Step 1: Warning 1 Text
                    Column {
                        visible: root.studyModalStep === 1
                        width: parent.width
                        spacing: 6

                        Text {
                            text: "• Everything except Dolphin, Brave, and PDF readers will be terminated."
                            font.pixelSize: 11
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                        Text {
                            text: "• In Brave: ONLY ICAI BOS, Google Notebook, and WhatsApp Web can load. All other sites are blocked."
                            font.pixelSize: 11
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                        Text {
                            text: "• Spotify is stopped. You can play your local lo-fi MP3s from ~/Music/study/."
                            font.pixelSize: 11
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.muted
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    // Step 2: Warning 2 Text
                    Column {
                        visible: root.studyModalStep === 2
                        width: parent.width
                        spacing: 6

                        Text {
                            text: "• NO EARLY EXIT. There is no cancel button once engaged."
                            font.pixelSize: 11
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.red
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                        Text {
                            text: "• Even a hard reboot will NOT release the lockdown until the timer runs out."
                            font.pixelSize: 11
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                        Text {
                            text: "• Duration: 30 minutes (Deep Focus). After countdown, overtime counts UP with no exit penalty."
                            font.pixelSize: 11
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.green
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }
                }
            }

            // Action Buttons Row
            Row {
                width: parent.width
                spacing: 10

                // Cancel / Back Button
                Rectangle {
                    width: (parent.width - 10) / 2
                    height: 38
                    radius: 12
                    color: cancelHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard
                    border.color: Island.Theme.glassBorderSubtle
                    border.width: 1

                    HoverHandler { id: cancelHover }
                    TapHandler {
                        onTapped: {
                            root.studyModalStep = 0;
                            root.studyPasswordInput = "";
                            root.studyPasswordError = "";
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.studyModalStep === 1 ? "Cancel" : "Back"
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: Island.Theme.muted
                    }
                }

                // Proceed Button
                Rectangle {
                    width: (parent.width - 10) / 2
                    height: 38
                    radius: 12
                    color: root.studyModalStep === 2 ? Island.Theme.red : Island.Theme.primary
                    scale: proceedTap.pressed ? 0.96 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    HoverHandler { id: proceedHover }
                    TapHandler {
                        id: proceedTap
                        onTapped: {
                            if (root.studyModalStep === 1) {
                                root.studyModalStep = 2;
                            } else if (root.studyModalStep === 2) {
                                root.studyModalStep = 0;
                                promptStudyProc.running = true;
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.studyModalStep === 1 ? "Continue" : "Lock In 󰌾"
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: root.studyModalStep === 2 ? "#ffffff" : "#0a0a0f"
                    }
                }
            }
        }
    }
}
