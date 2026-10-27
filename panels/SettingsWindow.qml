import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "../island" as Island
import "../island/components"
import "../core"

PanelWindow {
    id: root

    property bool open: false
    visible: open
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "cool-shell-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    focusable: open

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // =========================================================================
    // HARDWARE & SUBSYSTEM DATA MODELS
    // =========================================================================

    // Networking
    readonly property var wifiDevice: {
        if (!Networking.devices || !Networking.devices.values) return null;
        return Networking.devices.values.find((d) => d.type === DeviceType.Wifi || d.type === 2) || null;
    }
    readonly property var wifiNetworks: {
        let list = [];
        if (wifiDevice && wifiDevice.networks && wifiDevice.networks.values) {
            list = wifiDevice.networks.values.slice().sort((a, b) => {
                if (a.connected !== b.connected) return a.connected ? -1 : 1;
                let sa = (a.signalStrength !== undefined ? a.signalStrength : (a.strength || 0));
                let sb = (b.signalStrength !== undefined ? b.signalStrength : (b.strength || 0));
                return sb - sa;
            });
        }
        if (list.length === 0 && fallbackNetworks.length > 0) {
            return fallbackNetworks;
        }
        return list;
    }
    readonly property var connectedWifi: {
        if (wifiNetworks && wifiNetworks.length > 0) {
            let found = wifiNetworks.find((n) => n.connected);
            if (found) return found;
        }
        if (wifiDevice && wifiDevice.connected) return wifiDevice;
        return fallbackConnected;
    }
    property var fallbackNetworks: []
    property var fallbackConnected: null
    property var pendingWifiNetwork: null

    function getConnectedSsid() {
        if (connectedWifi) {
            if (connectedWifi.ssid) return connectedWifi.ssid;
            if (connectedWifi.name) return connectedWifi.name;
        }
        if (wifiDevice && wifiDevice.activeAccessPoint && wifiDevice.activeAccessPoint.ssid) {
            return wifiDevice.activeAccessPoint.ssid;
        }
        if (fallbackConnected && fallbackConnected.ssid) {
            return fallbackConnected.ssid;
        }
        return "";
    }

    function getConnectedSignalPct() {
        let target = connectedWifi || fallbackConnected;
        if (!target) return 0;
        let s = target.signalStrength !== undefined ? target.signalStrength : (target.strength !== undefined ? target.strength : null);
        if (s === null && wifiDevice && wifiDevice.activeAccessPoint && wifiDevice.activeAccessPoint.strength !== undefined) {
            s = wifiDevice.activeAccessPoint.strength;
        }
        if (s === null && fallbackConnected) {
            s = fallbackConnected.signalStrength;
        }
        if (s === null || s === undefined) return 75;
        if (s > 1) return Math.round(s);
        return Math.round(s * 100);
    }

    // Bluetooth
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var bluetoothDevices: adapter ? adapter.devices.values : []
    readonly property var pairedBluetoothDevices: bluetoothDevices.filter((d) => d.paired || d.bonded)
    readonly property var availableBluetoothDevices: bluetoothDevices.filter((d) => !d.paired && !d.bonded)

    // Audio
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // Hardware Telemetry & Preferences
    property int currentBrightness: 50
    property real mouseSensitivity: 0.0
    property string mouseAccelProfile: "adaptive"
    property bool touchpadNaturalScroll: false
    property bool touchpadTapToClick: true
    property bool mouseLeftHanded: false
    property int keyRepeatDelay: 300
    property int keyRepeatRate: 40
    property bool keyNumlockDefault: false
    property int idleTimeoutMinutes: Island.ShellState ? Math.max(1, Math.round(Island.ShellState.idleTimeoutSeconds / 60)) : 2
    property var gameModeExceptions: ["steam", "discord", "spotify", "obs", "heroic"]
    property string activeCategory: "modes"
    property bool batteryLimitEnabled: false
    property int batteryLimitPercent: 80

    // =========================================================================
    // PUBLIC API METHODS
    // =========================================================================

    function toggle() {
        open = !open;
        if (open) refreshTelemetry();
    }

    function show() {
        open = true;
        refreshTelemetry();
    }

    function hide() {
        open = false;
        pendingWifiNetwork = null;
    }

    function openCategory(cat) {
        if (cat) {
            root.activeCategory = (cat === "gamemode" ? "modes" : cat);
        }
        show();
    }

    onOpenChanged: {
        if (open) refreshTelemetry();
    }

    onActiveCategoryChanged: {
        if (open && activeCategory === "network") {
            refreshTelemetry();
        }
    }

    Component.onCompleted: {
        refreshTelemetry();
    }

    function refreshTelemetry() {
        if (!getBrightnessProc.running) getBrightnessProc.running = true;
        if (wifiDevice && Networking.wifiEnabled) wifiDevice.scannerEnabled = true;
        if (!nmcliWifiProc.running) nmcliWifiProc.running = true;
        if (!nmcliActiveProc.running) nmcliActiveProc.running = true;
        if (!getExceptionsProc.running) getExceptionsProc.running = true;
        if (!getBatteryLimitProc.running) getBatteryLimitProc.running = true;
    }

    function setBatteryLimit(pct) {
        let val = (pct <= 85) ? 80 : 100;
        root.batteryLimitPercent = val;
        root.batteryLimitEnabled = (val === 80);
        if (!setBatteryLimitProc.running) {
            setBatteryLimitProc.command = [Quickshell.shellPath("scripts/battery-limit.sh"), "set-limit", val.toString()];
            setBatteryLimitProc.running = true;
        }
    }

    function toggleBatteryLimit() {
        if (!setBatteryLimitProc.running) {
            setBatteryLimitProc.command = [Quickshell.shellPath("scripts/battery-limit.sh"), "toggle"];
            setBatteryLimitProc.running = true;
        }
    }

    // Subsystem Actuators
    function selectDefaultSink(node) {
        if (!node) return;
        Pipewire.preferredDefaultAudioSink = node;
        if (node.id) {
            actuatorProc.exec(["wpctl", "set-default", node.id.toString()]);
        }
    }

    function selectDefaultSource(node) {
        if (!node) return;
        Pipewire.preferredDefaultAudioSource = node;
        if (node.id) {
            actuatorProc.exec(["wpctl", "set-default", node.id.toString()]);
        }
    }

    function setBrightness(pct) {
        currentBrightness = Math.max(1, Math.min(100, pct));
        actuatorProc.exec(["brightnessctl", "set", currentBrightness + "%"]);
    }

    function setMouseSensitivity(val) {
        mouseSensitivity = Math.max(-1.0, Math.min(1.0, val));
        actuatorProc.exec(["hyprctl", "keyword", "input:sensitivity", mouseSensitivity.toFixed(2)]);
    }

    function setMouseAccelProfile(profile) {
        mouseAccelProfile = profile;
        actuatorProc.exec(["hyprctl", "keyword", "input:accel_profile", profile]);
    }

    function setTouchpadNaturalScroll(val) {
        touchpadNaturalScroll = val;
        actuatorProc.exec(["hyprctl", "keyword", "input:touchpad:natural_scroll", val ? "true" : "false"]);
    }

    function setTouchpadTapToClick(val) {
        touchpadTapToClick = val;
        actuatorProc.exec(["hyprctl", "keyword", "input:touchpad:tap-to-click", val ? "true" : "false"]);
    }

    function setMouseLeftHanded(val) {
        mouseLeftHanded = val;
        actuatorProc.exec(["hyprctl", "keyword", "input:left_handed", val ? "true" : "false"]);
    }

    function setKeyRepeatDelay(val) {
        keyRepeatDelay = val;
        actuatorProc.exec(["hyprctl", "keyword", "input:repeat_delay", val.toString()]);
    }

    function setKeyRepeatRate(val) {
        keyRepeatRate = val;
        actuatorProc.exec(["hyprctl", "keyword", "input:repeat_rate", val.toString()]);
    }

    function setKeyNumlockDefault(val) {
        keyNumlockDefault = val;
        actuatorProc.exec(["hyprctl", "keyword", "input:numlock_by_default", val ? "true" : "false"]);
    }

    function setIdleMinutes(mins) {
        idleTimeoutMinutes = mins;
        let secs = mins * 60;
        if (Island.ShellState) {
            Island.ShellState.idleTimeoutSeconds = secs;
        }
        actuatorProc.exec(["quickshell", "ipc", "-c", "cool-shell", "call", "idle", "setIdleTimeout", secs.toString()]);
    }

    function wipeClipboard() {
        actuatorProc.exec(["cliphist", "wipe"]);
        Island.IslandHub.showTransient("Clipboard history wiped clean.", 2500);
    }

    function wipeThumbnailCache() {
        actuatorProc.exec(["sh", "-c", "rm -rf '" + Quickshell.env("HOME") + "/.cache/cool-shell/thumbnails' /tmp/cool-shell-thumbs/*"]);
        Island.IslandHub.showTransient("Thumbnail cache cleared.", 2500);
    }

    function addException(name) {
        if (name && !modExceptionProc.running) {
            modExceptionProc.command = ["python3", Quickshell.shellPath("island/scripts/game-mode.py"), "add-exception", name.trim().toLowerCase()];
            modExceptionProc.running = true;
        }
    }

    function removeException(name) {
        if (name && !modExceptionProc.running) {
            modExceptionProc.command = ["python3", Quickshell.shellPath("island/scripts/game-mode.py"), "remove-exception", name.trim().toLowerCase()];
            modExceptionProc.running = true;
        }
    }

    // =========================================================================
    // BACKGROUND PROCESSES
    // =========================================================================

    Process {
        id: actuatorProc
    }

    Process {
        id: getBrightnessProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parts = text.trim().split(",");
                    if (parts.length >= 4) {
                        let pct = parseInt(parts[3].replace("%", ""), 10);
                        if (!isNaN(pct)) root.currentBrightness = pct;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: getExceptionsProc
        command: ["python3", Quickshell.shellPath("island/scripts/game-mode.py"), "list-exceptions"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.gameModeExceptions = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: modExceptionProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.gameModeExceptions = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: getBatteryLimitProc
        command: [Quickshell.shellPath("scripts/battery-limit.sh"), "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text.trim());
                    if (data.enabled !== undefined) root.batteryLimitEnabled = (data.enabled === true);
                    if (data.limit !== undefined) root.batteryLimitPercent = data.limit;
                } catch (e) {}
            }
        }
    }

    Process {
        id: nmcliWifiProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,BARS", "device", "wifi", "list", "--rescan", "no"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let lines = text.trim().split("\n");
                    let seen = new Map();
                    let activeNet = null;
                    for (let i = 0; i < lines.length; i++) {
                        let line = lines[i].trim();
                        if (!line) continue;
                        let parts = line.split(":");
                        if (parts.length >= 4) {
                            let inUse = parts[0].trim() === "*";
                            let ssid = parts[1].trim();
                            if (!ssid || ssid === "--") continue;
                            let sig = parseInt(parts[2], 10) || 0;
                            let sec = parts[3] || "Secured";
                            if (seen.has(ssid)) {
                                let existing = seen.get(ssid);
                                if (inUse) {
                                    existing.connected = true;
                                    activeNet = existing;
                                }
                                if (sig > existing.rawSig) {
                                    existing.rawSig = sig;
                                    existing.signalStrength = sig / 100.0;
                                    existing.strength = sig / 100.0;
                                }
                            } else {
                                let netObj = {
                                    ssid: ssid,
                                    name: ssid,
                                    rawSig: sig,
                                    signalStrength: sig / 100.0,
                                    strength: sig / 100.0,
                                    connected: inUse,
                                    security: sec,
                                    known: inUse,
                                    isFallback: true,
                                    connect: function() {
                                        Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", ssid]);
                                    },
                                    disconnect: function() {
                                        Quickshell.execDetached(["nmcli", "c", "down", "id", ssid]);
                                    }
                                };
                                seen.set(ssid, netObj);
                                if (inUse) activeNet = netObj;
                            }
                        }
                    }
                    root.fallbackNetworks = Array.from(seen.values()).sort((a, b) => {
                        if (a.connected !== b.connected) return a.connected ? -1 : 1;
                        return b.rawSig - a.rawSig;
                    });
                    if (activeNet) root.fallbackConnected = activeNet;
                } catch (e) {}
            }
        }
    }

    Process {
        id: nmcliActiveProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE,STATE", "connection", "show", "--active"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let lines = text.trim().split("\n");
                    for (let i = 0; i < lines.length; i++) {
                        let parts = lines[i].trim().split(":");
                        if (parts.length >= 4 && (parts[1] === "802-11-wireless" || parts[1] === "wifi") && parts[3] === "activated") {
                            let ssid = parts[0];
                            if (!root.fallbackConnected || !root.fallbackConnected.connected || root.fallbackConnected.ssid !== ssid) {
                                root.fallbackConnected = {
                                    ssid: ssid,
                                    name: ssid,
                                    signalStrength: 0.8,
                                    strength: 0.8,
                                    connected: true,
                                    security: "Secured",
                                    known: true,
                                    isFallback: true,
                                    disconnect: function() {
                                        Quickshell.execDetached(["nmcli", "c", "down", "id", ssid]);
                                    }
                                };
                            }
                            break;
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: setBatteryLimitProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text.trim());
                    if (data.enabled !== undefined) root.batteryLimitEnabled = (data.enabled === true);
                    if (data.limit !== undefined) root.batteryLimitPercent = data.limit;
                } catch (e) {}
            }
        }
    }

    // =========================================================================
    // DISMISSAL & MODAL BACKDROP (Zero-Render when closed via on-demand Loader)
    // =========================================================================

    Loader {
        id: windowLoader
        anchors.fill: parent
        active: root.open
        sourceComponent: focusScopeComp
    }

    Component {
        id: focusScopeComp

        FocusScope {
            id: focusScope
            anchors.fill: parent
            focus: true

        Keys.onEscapePressed: {
            root.hide();
        }

        // Dimmed frosted backdrop
        Rectangle {
            id: backdrop
            anchors.fill: parent
            color: Qt.rgba(0.02, 0.02, 0.04, 0.58)
            opacity: root.open ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }
        }

        // =====================================================================
        // CENTERED SMOKED GLASS SETTINGS WINDOW (880 x 580)
        // =====================================================================
        Rectangle {
            id: windowCard
            anchors.centerIn: parent
            width: Math.min(880, parent.width - 40)
            height: Math.min(580, parent.height - 40)
            radius: Island.Theme.radiusWindow
            color: Island.Theme.glassBackground
            border.color: Island.Theme.glassBorder
            border.width: Island.Theme.glassBorderWidth
            clip: true

            scale: root.open ? 1.0 : 0.96
            opacity: root.open ? 1.0 : 0.0

            Behavior on scale {
                NumberAnimation { duration: 220; easing.type: Easing.OutBack }
            }
            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            // Absorb clicks inside window so backdrop click doesn't trigger
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            property string activeCategory: root.activeCategory
            onActiveCategoryChanged: {
                if (root.activeCategory !== activeCategory) {
                    root.activeCategory = activeCategory;
                }
            }
            Binding {
                target: windowCard
                property: "activeCategory"
                value: root.activeCategory
            }

            Column {
                anchors.fill: parent

                // -------------------------------------------------------------
                // WINDOW HEADER BAR
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: 54

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.16)
                            border.color: Island.Theme.glassBorderActive
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "󰒓"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 16
                                color: Island.Theme.primary
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: "Settings"
                                font.pixelSize: 14
                                font.bold: true
                                font.family: Island.Theme.fontFamily
                                color: Island.Theme.foreground
                            }

                            Text {
                                text: "Privacy-First Desktop & Device Management"
                                font.pixelSize: 10
                                font.family: Island.Theme.fontFamily
                                color: Island.Theme.muted
                            }
                        }
                    }

                    // Top-right close button
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        radius: 15
                        color: closeMouse.containsMouse ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.22) : Island.Theme.glassCard
                        border.color: closeMouse.containsMouse ? Island.Theme.red : Island.Theme.glassBorderSubtle
                        border.width: 1
                        scale: closeMouse.pressed ? 0.92 : 1.0

                        Behavior on scale { NumberAnimation { duration: 90 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            font.pixelSize: 18
                            font.bold: true
                            color: closeMouse.containsMouse ? Island.Theme.red : Island.Theme.muted
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.hide()
                        }
                    }

                    // Hairline separator
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Island.Theme.glassBorderSubtle
                    }
                }

                // -------------------------------------------------------------
                // WINDOW MAIN BODY (SIDEBAR + CONTENT)
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: parent.height - 54

                    // Left Category Navigation Sidebar (230px)
                    Rectangle {
                        id: navSidebar
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 230
                        color: Qt.rgba(Island.Theme.bgDim.r, Island.Theme.bgDim.g, Island.Theme.bgDim.b, 0.45)

                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 1
                            color: Island.Theme.glassBorderSubtle
                        }

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 10
                            contentHeight: navCol.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: navCol
                                width: parent.width
                                spacing: 4

                                readonly property var categories: [
                                    { id: "modes", name: "System Modes", icon: "󰓅" },
                                    { id: "network", name: "Network & Wi-Fi", icon: "󰤨" },
                                    { id: "bluetooth", name: "Bluetooth & Devices", icon: "󰂯" },
                                    { id: "display", name: "Display & Brightness", icon: "󰍹" },
                                    { id: "audio", name: "Sound & Volume", icon: "󰕾" },
                                    { id: "mouse", name: "Mouse & Touchpad", icon: "󰍽" },
                                    { id: "keyboard", name: "Keyboard & Shortcuts", icon: "󰌌" },
                                    { id: "appearance", name: "Appearance & Themes", icon: "󰏘" },
                                    { id: "power", name: "Power & Battery", icon: "󰁹" },
                                    { id: "privacy", name: "Privacy & Security", icon: "󰌾" },
                                    { id: "a11y", name: "Accessibility & Voice", icon: "󰐝" },
                                    { id: "about", name: "System & About", icon: "󰋽" }
                                ]

                                Repeater {
                                    model: navCol.categories

                                    delegate: Rectangle {
                                        id: catPill
                                        required property var modelData
                                        readonly property bool isSelected: windowCard.activeCategory === modelData.id || (modelData.id === "modes" && windowCard.activeCategory === "gamemode")

                                        width: navCol.width
                                        height: 36
                                        radius: 10
                                        color: isSelected
                                            ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.18)
                                            : (catMouse.containsMouse ? Island.Theme.glassCardHover : "transparent")
                                        border.color: isSelected ? Island.Theme.glassBorderActive : (catMouse.containsMouse ? Island.Theme.glassBorderSubtle : "transparent")
                                        border.width: 1
                                        scale: catMouse.pressed ? 0.97 : 1.0

                                        Behavior on scale { NumberAnimation { duration: 90 } }
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 10

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: catPill.modelData.icon
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 15
                                                color: catPill.isSelected ? Island.Theme.primary : Island.Theme.muted
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: catPill.modelData.name
                                                font.pixelSize: 11
                                                font.bold: catPill.isSelected
                                                font.family: Island.Theme.fontFamily
                                                color: catPill.isSelected ? Island.Theme.foreground : Island.Theme.muted
                                            }
                                        }

                                        MouseArea {
                                            id: catMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: windowCard.activeCategory = catPill.modelData.id
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Right Scrollable Content Canvas
                    Flickable {
                        id: contentFlickable
                        anchors.left: navSidebar.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 20
                        clip: true
                        contentHeight: contentStack.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: contentStack
                            width: parent.width - 12
                            spacing: 16

                            // =================================================
                            // 1. NETWORK & WI-FI PAGE
                            // =================================================
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "network"

                                Text {
                                    text: "Network & Wi-Fi"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }
                                Text {
                                    text: "Manage Wi-Fi wireless connections, Ethernet interfaces, and privacy DNS settings."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                }

                                // Wi-Fi Master Toggle Card
                                Rectangle {
                                    width: parent.width
                                    height: 60
                                    radius: 12
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Networking.wifiEnabled ? "󰤨" : "󰤮"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 20
                                            color: Networking.wifiEnabled ? Island.Theme.primary : Island.Theme.muted
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 110
                                            spacing: 2
                                            Text {
                                                text: "Wi-Fi Wireless Networking"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: (Networking.wifiEnabled || root.connectedWifi !== null) ? (root.getConnectedSsid() !== "" ? ("Connected to " + root.getConnectedSsid()) : "Enabled (Scanning)") : "Disabled"
                                                font.pixelSize: 10
                                                color: Island.Theme.muted
                                            }
                                        }

                                        // Toggle Switch
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 44
                                            height: 24
                                            radius: 12
                                            color: Networking.wifiEnabled ? Island.Theme.primary : Island.Theme.glassCardHover
                                            border.color: Networking.wifiEnabled ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                            border.width: 1

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: Networking.wifiEnabled ? parent.width - width - 3 : 3
                                                width: 18
                                                height: 18
                                                radius: 9
                                                color: Networking.wifiEnabled ? "#ffffff" : Island.Theme.muted
                                                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Networking.wifiEnabled = !Networking.wifiEnabled;
                                                    if (Networking.wifiEnabled) {
                                                        if (root.wifiDevice) root.wifiDevice.scannerEnabled = true;
                                                        if (!nmcliWifiProc.running) nmcliWifiProc.running = true;
                                                        if (!nmcliActiveProc.running) nmcliActiveProc.running = true;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Active Connected Network Card
                                Rectangle {
                                    visible: (Networking.wifiEnabled || root.connectedWifi !== null) && root.getConnectedSsid() !== ""
                                    width: parent.width
                                    height: 80
                                    radius: 12
                                    color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.12)
                                    border.color: Island.Theme.glassBorderActive
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰤨"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 22
                                            color: Island.Theme.primary
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 150
                                            spacing: 3
                                            Text {
                                                text: root.getConnectedSsid()
                                                font.pixelSize: 13
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: "Signal: " + root.getConnectedSignalPct() + "% • Active Default Route"
                                                font.pixelSize: 10
                                                color: Island.Theme.primary
                                            }
                                        }

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 86
                                            height: 30
                                            radius: 8
                                            color: discMouse.containsMouse ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.22) : Island.Theme.glassCardHover
                                            border.color: discMouse.containsMouse ? Island.Theme.red : Island.Theme.glassBorderSubtle
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Disconnect"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: discMouse.containsMouse ? Island.Theme.red : Island.Theme.foreground
                                            }
                                            MouseArea {
                                                id: discMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.connectedWifi && typeof root.connectedWifi.disconnect === "function") {
                                                        root.connectedWifi.disconnect();
                                                    } else {
                                                        let cur = root.getConnectedSsid();
                                                        if (cur) Quickshell.execDetached(["nmcli", "c", "down", "id", cur]);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Available Networks List Header
                                Row {
                                    width: parent.width
                                    visible: Networking.wifiEnabled || root.wifiNetworks.length > 0
                                    Text {
                                        text: "AVAILABLE NETWORKS (" + root.wifiNetworks.length + ")"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.letterSpacing: 1
                                        color: Island.Theme.primary
                                    }
                                    Item { Layout.fillWidth: true; width: 10 }
                                    Text {
                                        text: "󰑐 Scan"
                                        font.family: Island.Theme.iconFontFamily
                                        font.pixelSize: 11
                                        color: Island.Theme.muted
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.wifiDevice) root.wifiDevice.scannerEnabled = true;
                                                if (!nmcliWifiProc.running) nmcliWifiProc.running = true;
                                                if (!nmcliActiveProc.running) nmcliActiveProc.running = true;
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 6
                                    visible: Networking.wifiEnabled || root.wifiNetworks.length > 0

                                    Repeater {
                                        model: root.wifiNetworks

                                        delegate: Rectangle {
                                            id: netCard
                                            required property var modelData
                                            width: parent.width
                                            height: 44
                                            radius: 10
                                            color: modelData.connected ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.08) : (netMouse.containsMouse ? Island.Theme.glassCardHover : Island.Theme.glassCard)
                                            border.color: modelData.connected ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                            border.width: 1

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 10

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    property real strVal: {
                                                        let s = modelData.signalStrength !== undefined ? modelData.signalStrength : (modelData.strength !== undefined ? modelData.strength : 0.5);
                                                        return s > 1 ? s / 100.0 : s;
                                                    }
                                                    text: strVal > 0.7 ? "󰤨" : (strVal > 0.4 ? "󰤥" : "󰤟")
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 15
                                                    color: modelData.connected ? Island.Theme.primary : Island.Theme.muted
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 150
                                                    text: modelData.ssid || modelData.name || "Hidden Network"
                                                    font.pixelSize: 11
                                                    font.bold: modelData.connected
                                                    color: Island.Theme.foreground
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.connected ? "Active" : (modelData.known ? "Saved" : (modelData.security ? modelData.security : ""))
                                                    font.pixelSize: 9
                                                    color: modelData.connected ? Island.Theme.primary : Island.Theme.mutedDark
                                                }

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 68
                                                    height: 24
                                                    radius: 6
                                                    color: modelData.connected ? Island.Theme.primary : (connMouse.containsMouse ? Island.Theme.primaryContainer : Island.Theme.glassCard)
                                                    border.color: modelData.connected ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.connected ? "Active" : "Connect"
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                        color: modelData.connected ? "#0a0a0f" : Island.Theme.foreground
                                                    }
                                                    MouseArea {
                                                        id: connMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (!modelData.connected) {
                                                                if (typeof modelData.connect === "function") {
                                                                    modelData.connect();
                                                                } else {
                                                                    let sName = modelData.ssid || modelData.name;
                                                                    if (sName) {
                                                                        Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", sName]);
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            MouseArea {
                                                id: netMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: root.wifiNetworks.length === 0
                                        width: parent.width
                                        height: 52
                                        radius: 10
                                        color: Island.Theme.glassCard
                                        border.color: Island.Theme.glassBorderSubtle
                                        border.width: 1

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 8
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰑐"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 13
                                                color: Island.Theme.muted
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Scanning for nearby Wi-Fi networks..."
                                                font.pixelSize: 11
                                                color: Island.Theme.muted
                                            }
                                        }
                                    }
                                }

                                // Private DNS & Offline Privacy Banner
                                Rectangle {
                                    width: parent.width
                                    height: 52
                                    radius: 10
                                    color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.08)
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 10
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰌾"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 16
                                            color: Island.Theme.primary
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Zero-Logging Security: Cool-Shell never forwards network activity to any remote service."
                                            font.pixelSize: 10
                                            color: Island.Theme.muted
                                        }
                                    }
                                }
                            }

                            // =================================================
                            // 2. BLUETOOTH & DEVICES PAGE
                            // =================================================
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "bluetooth"

                                Text {
                                    text: "Bluetooth & Devices"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }
                                Text {
                                    text: "Manage wireless audio accessories, mice, keyboards, and input devices."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                }

                                // Master Bluetooth Toggle
                                Rectangle {
                                    width: parent.width
                                    height: 60
                                    radius: 12
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (root.adapter && root.adapter.enabled) ? "󰂯" : "󰂲"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 20
                                            color: (root.adapter && root.adapter.enabled) ? Island.Theme.blue : Island.Theme.muted
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 110
                                            spacing: 2
                                            Text {
                                                text: "Bluetooth Adapter"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: root.adapter ? (root.adapter.enabled ? ("Online (" + root.pairedBluetoothDevices.length + " paired)") : "Turned off") : "No adapter found"
                                                font.pixelSize: 10
                                                color: Island.Theme.muted
                                            }
                                        }

                                        // Toggle Switch
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 44
                                            height: 24
                                            radius: 12
                                            color: (root.adapter && root.adapter.enabled) ? Island.Theme.primary : Island.Theme.glassCardHover
                                            border.color: (root.adapter && root.adapter.enabled) ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                            border.width: 1

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: (root.adapter && root.adapter.enabled) ? parent.width - width - 3 : 3
                                                width: 18
                                                height: 18
                                                radius: 9
                                                color: (root.adapter && root.adapter.enabled) ? "#ffffff" : Island.Theme.muted
                                                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.adapter) root.adapter.enabled = !root.adapter.enabled;
                                                }
                                            }
                                        }
                                    }
                                }

                                // Paired Devices List Header
                                Row {
                                    width: parent.width
                                    visible: root.adapter && root.adapter.enabled
                                    Text {
                                        text: "PAIRED ACCESSORIES"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.letterSpacing: 1
                                        color: Island.Theme.primary
                                    }
                                    Item { Layout.fillWidth: true; width: 10 }
                                    Text {
                                        text: (root.adapter && root.adapter.discovering) ? "󰐊 Scanning..." : "󰑐 Scan"
                                        font.family: Island.Theme.iconFontFamily
                                        font.pixelSize: 11
                                        color: (root.adapter && root.adapter.discovering) ? Island.Theme.primary : Island.Theme.muted
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.adapter) root.adapter.discovering = !root.adapter.discovering;
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 6
                                    visible: root.adapter && root.adapter.enabled

                                    Text {
                                        text: "No paired Bluetooth devices."
                                        font.pixelSize: 11
                                        color: Island.Theme.muted
                                        visible: root.pairedBluetoothDevices.length === 0
                                    }

                                    Repeater {
                                        model: root.pairedBluetoothDevices

                                        delegate: Rectangle {
                                            required property var modelData
                                            width: parent.width
                                            height: 48
                                            radius: 10
                                            color: modelData.connected ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.08) : Island.Theme.glassCard
                                            border.color: modelData.connected ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                            border.width: 1

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 10

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: (modelData.name && modelData.name.toLowerCase().includes("head")) ? "󰋋" : ((modelData.name && modelData.name.toLowerCase().includes("key")) ? "󰌌" : "󰂯")
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 16
                                                    color: modelData.connected ? Island.Theme.primary : Island.Theme.muted
                                                }

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 170
                                                    spacing: 1
                                                    Text {
                                                        text: modelData.name || "Bluetooth Accessory"
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                        color: Island.Theme.foreground
                                                        elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        text: modelData.connected ? ("Connected" + (modelData.batteryPercentage !== undefined ? (" • " + modelData.batteryPercentage + "%") : "")) : "Paired"
                                                        font.pixelSize: 9
                                                        color: modelData.connected ? Island.Theme.primary : Island.Theme.mutedDark
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 76
                                                    height: 26
                                                    radius: 6
                                                    color: modelData.connected ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.18) : (btBtnMouse.containsMouse ? Island.Theme.primaryContainer : Island.Theme.glassCardHover)
                                                    border.color: modelData.connected ? Island.Theme.red : Island.Theme.glassBorderSubtle
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.connected ? "Disconnect" : "Connect"
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                        color: modelData.connected ? Island.Theme.red : Island.Theme.foreground
                                                    }
                                                    MouseArea {
                                                        id: btBtnMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (modelData.connected) modelData.disconnect();
                                                            else modelData.connect();
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // =================================================
                            // 3. DISPLAY & BRIGHTNESS PAGE
                            // =================================================
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "display"

                                Text {
                                    text: "Display & Brightness"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }
                                Text {
                                    text: "Connected monitor topology, screen brightness controls, and Night Light color temperature."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                }

                                // Connected Displays Card
                                Rectangle {
                                    width: parent.width
                                    height: Math.max(80, 42 + Quickshell.screens.length * 28)
                                    radius: 12
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 8

                                        Text {
                                            text: "CONNECTED MONITORS"
                                            font.pixelSize: 10
                                            font.bold: true
                                            font.letterSpacing: 1
                                            color: Island.Theme.primary
                                        }

                                        Repeater {
                                            model: Quickshell.screens
                                            delegate: Row {
                                                required property var modelData
                                                spacing: 12
                                                Text {
                                                    text: "🖥️ " + (modelData.name || "Output")
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    color: Island.Theme.foreground
                                                }
                                                Text {
                                                    text: modelData.width + " × " + modelData.height + " @ 60Hz"
                                                    font.pixelSize: 11
                                                    color: Island.Theme.muted
                                                }
                                                Text {
                                                    text: "Scale: 1.0x"
                                                    font.pixelSize: 10
                                                    color: Island.Theme.mutedDark
                                                }
                                            }
                                        }
                                    }
                                }

                                // Screen Brightness Card
                                Rectangle {
                                    width: parent.width
                                    height: 72
                                    radius: 12
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 14

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰃟"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 22
                                            color: Island.Theme.yellow
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 150
                                            spacing: 2
                                            Text {
                                                text: "Hardware Brightness"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: root.currentBrightness + "% Output Level"
                                                font.pixelSize: 10
                                                color: Island.Theme.muted
                                            }
                                        }

                                        StyledSlider {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: contentStack.width - 250
                                            height: 18
                                            value: root.currentBrightness / 100.0
                                            onMoved: (val) => {
                                                root.setBrightness(Math.round(val * 100));
                                            }
                                        }
                                    }
                                }

                                // Night Light Card
                                Rectangle {
                                    width: parent.width
                                    height: 80
                                    radius: 12
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 14

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰖔"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 22
                                            color: Island.Theme.orange
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 150
                                            spacing: 2
                                            Text {
                                                text: "Night Light"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: Island.ShellState.nightLightTemperature + "K Warm Tone"
                                                font.pixelSize: 10
                                                color: Island.Theme.muted
                                            }
                                        }

                                        StyledSlider {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: contentStack.width - 250
                                            height: 18
                                            value: Math.max(0, Math.min(1, (6500 - Island.ShellState.nightLightTemperature) / 3500.0))
                                            onMoved: (val) => {
                                                let temp = Math.round(6500 - val * 3500);
                                                Island.ShellState.nightLightTemperature = temp;
                                                actuatorProc.exec([Quickshell.shellPath("island/scripts/shell-actions.sh"), "night-light-set", temp.toString()]);
                                            }
                                        }
                                    }
                                }
                            }

                            // =================================================
                            // 4. SOUND & VOLUME PAGE
                            // =================================================
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "audio"

                                Text {
                                    text: "Sound & Volume"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }
                                Text {
                                    text: "Output audio sinks, microphone input streams, and individual application volume mixer."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                }

                                // Master Output Sink
                                Text {
                                    text: "OUTPUT AUDIO SINKS"
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: Island.Theme.primary
                                }

                                Column {
                                    width: parent.width
                                    spacing: 6

                                    Repeater {
                                        model: Pipewire.nodes ? Pipewire.nodes.values.filter((n) => n.audio && n.isSink && !n.isStream) : []

                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property bool isDefault: Pipewire.defaultAudioSink && modelData.id === Pipewire.defaultAudioSink.id
                                            width: contentStack.width
                                            height: 50
                                            radius: 10
                                            color: isDefault ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.12) : Island.Theme.glassCard
                                            border.color: isDefault ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                            border.width: isDefault ? 1.5 : 1

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 10

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: (modelData.name && modelData.name.includes("bluez")) ? "󰋋" : "󰕾"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 18
                                                    color: isDefault ? Island.Theme.primary : Island.Theme.muted
                                                }

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 170
                                                    spacing: 1
                                                    Text {
                                                        text: modelData.description || modelData.name || "Output Device"
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                        color: Island.Theme.foreground
                                                        elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        text: isDefault ? "Default Output" : "Available"
                                                        font.pixelSize: 9
                                                        color: isDefault ? Island.Theme.primary : Island.Theme.muted
                                                    }
                                                }

                                                StyledSlider {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 140
                                                    height: 18
                                                    value: modelData.audio ? modelData.audio.volume : 0.5
                                                    onMoved: (val) => {
                                                        if (modelData.audio) modelData.audio.volume = val;
                                                    }
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: Math.round((modelData.audio ? modelData.audio.volume : 0) * 100) + "%"
                                                    font.pixelSize: 10
                                                    color: Island.Theme.muted
                                                    width: 32
                                                }

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 60
                                                    height: 24
                                                    radius: 6
                                                    color: isDefault ? Island.Theme.primary : Island.Theme.glassCardHover
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: isDefault ? "Active" : "Select"
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                        color: isDefault ? "#0a0a0f" : Island.Theme.foreground
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: isDefault ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                        onClicked: root.selectDefaultSink(modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Per-Application Volume Mixer
                                Text {
                                    text: "APPLICATION STREAMS"
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: Island.Theme.primary
                                }

                                Text {
                                    text: "No active application audio playback streams found."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                    visible: (Pipewire.nodes ? Pipewire.nodes.values.filter((n) => n.audio && n.isStream && !n.isSink).length : 0) === 0
                                }

                                Column {
                                    width: parent.width
                                    spacing: 6
                                    visible: (Pipewire.nodes ? Pipewire.nodes.values.filter((n) => n.audio && n.isStream && !n.isSink).length : 0) > 0

                                    Repeater {
                                        model: Pipewire.nodes ? Pipewire.nodes.values.filter((n) => n.audio && n.isStream && !n.isSink) : []

                                        delegate: Rectangle {
                                            required property var modelData
                                            width: contentStack.width
                                            height: 44
                                            radius: 10
                                            color: Island.Theme.glassCard
                                            border.color: Island.Theme.glassBorderSubtle
                                            border.width: 1

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 10

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "󰓃"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 14
                                                    color: Island.Theme.primary
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 160
                                                    text: modelData.name || "Application"
                                                    font.pixelSize: 11
                                                    color: Island.Theme.foreground
                                                    elide: Text.ElideRight
                                                }

                                                StyledSlider {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 180
                                                    height: 18
                                                    value: modelData.audio ? modelData.audio.volume : 0.5
                                                    onMoved: (val) => {
                                                        if (modelData.audio) modelData.audio.volume = val;
                                                    }
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: Math.round((modelData.audio ? modelData.audio.volume : 0) * 100) + "%"
                                                    font.pixelSize: 10
                                                    color: Island.Theme.muted
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // =================================================
                            // 5. MOUSE & TOUCHPAD PAGE
                            // =================================================
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "mouse"

                                Text {
                                    text: "Mouse & Touchpad"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }
                                Text {
                                    text: "Pointer sensitivity, hardware acceleration profiles, natural scrolling, and touchpad gestures."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                }

                                // Pointer Sensitivity Card
                                Rectangle {
                                    width: parent.width
                                    height: 72
                                    radius: 12
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 14

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰍽"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 22
                                            color: Island.Theme.primary
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 160
                                            spacing: 2
                                            Text {
                                                text: "Pointer Sensitivity"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: root.mouseSensitivity.toFixed(2) + " (Range: -1.0 to 1.0)"
                                                font.pixelSize: 10
                                                color: Island.Theme.muted
                                            }
                                        }

                                        StyledSlider {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: contentStack.width - 250
                                            height: 18
                                            value: (root.mouseSensitivity + 1.0) / 2.0
                                            onMoved: (val) => {
                                                let sens = (val * 2.0) - 1.0;
                                                root.setMouseSensitivity(sens);
                                            }
                                        }
                                    }
                                }

                                // Natural Scrolling & Gestures
                                Column {
                                    width: parent.width
                                    spacing: 8

                                    // Natural Scroll Toggle
                                    Rectangle {
                                        width: parent.width
                                        height: 52
                                        radius: 10
                                        color: Island.Theme.glassCard
                                        border.color: Island.Theme.glassBorderSubtle
                                        border.width: 1

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 60
                                                text: "Natural Scrolling (Inverted wheel direction)"
                                                font.pixelSize: 11
                                                color: Island.Theme.foreground
                                            }

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 44
                                                height: 24
                                                radius: 12
                                                color: root.touchpadNaturalScroll ? Island.Theme.primary : Island.Theme.glassCardHover

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: root.touchpadNaturalScroll ? parent.width - width - 3 : 3
                                                    width: 18
                                                    height: 18
                                                    radius: 9
                                                    color: root.touchpadNaturalScroll ? "#ffffff" : Island.Theme.muted
                                                    Behavior on x { NumberAnimation { duration: 120 } }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.setTouchpadNaturalScroll(!root.touchpadNaturalScroll)
                                                }
                                            }
                                        }
                                    }

                                    // Tap to Click Toggle
                                    Rectangle {
                                        width: parent.width
                                        height: 52
                                        radius: 10
                                        color: Island.Theme.glassCard
                                        border.color: Island.Theme.glassBorderSubtle
                                        border.width: 1

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 60
                                                text: "Touchpad Tap-to-Click"
                                                font.pixelSize: 11
                                                color: Island.Theme.foreground
                                            }

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 44
                                                height: 24
                                                radius: 12
                                                color: root.touchpadTapToClick ? Island.Theme.primary : Island.Theme.glassCardHover

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: root.touchpadTapToClick ? parent.width - width - 3 : 3
                                                    width: 18
                                                    height: 18
                                                    radius: 9
                                                    color: root.touchpadTapToClick ? "#ffffff" : Island.Theme.muted
                                                    Behavior on x { NumberAnimation { duration: 120 } }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.setTouchpadTapToClick(!root.touchpadTapToClick)
                                                }
                                            }
                                        }
                                    }

                                    // Left Handed Mouse Toggle
                                    Rectangle {
                                        width: parent.width
                                        height: 52
                                        radius: 10
                                        color: Island.Theme.glassCard
                                        border.color: Island.Theme.glassBorderSubtle
                                        border.width: 1

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 60
                                                text: "Left-Handed Button Mapping (Swap Primary Buttons)"
                                                font.pixelSize: 11
                                                color: Island.Theme.foreground
                                            }

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 44
                                                height: 24
                                                radius: 12
                                                color: root.mouseLeftHanded ? Island.Theme.primary : Island.Theme.glassCardHover

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: root.mouseLeftHanded ? parent.width - width - 3 : 3
                                                    width: 18
                                                    height: 18
                                                    radius: 9
                                                    color: root.mouseLeftHanded ? "#ffffff" : Island.Theme.muted
                                                    Behavior on x { NumberAnimation { duration: 120 } }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.setMouseLeftHanded(!root.mouseLeftHanded)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // =================================================
                            // 6. KEYBOARD & SHORTCUTS PAGE
                            // =================================================
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "keyboard"

                                Text {
                                    text: "Keyboard & Shortcuts"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }
                                Text {
                                    text: "Hardware repeat latency, repeat rates, numlock defaults, and tactical desktop shortcuts."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                }

                                // Key Repeat Delay Card
                                Rectangle {
                                    width: parent.width
                                    height: 72
                                    radius: 12
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 14

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰌌"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 22
                                            color: Island.Theme.primary
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 160
                                            spacing: 2
                                            Text {
                                                text: "Key Repeat Delay"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: root.keyRepeatDelay + " ms Latency"
                                                font.pixelSize: 10
                                                color: Island.Theme.muted
                                            }
                                        }

                                        StyledSlider {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: contentStack.width - 250
                                            height: 18
                                            value: (root.keyRepeatDelay - 150) / 450.0
                                            onMoved: (val) => {
                                                let delay = Math.round(150 + val * 450);
                                                root.setKeyRepeatDelay(delay);
                                            }
                                        }
                                    }
                                }

                                // Key Repeat Rate Card
                                Rectangle {
                                    width: parent.width
                                    height: 72
                                    radius: 12
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 14

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰅂"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 22
                                            color: Island.Theme.primary
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 160
                                            spacing: 2
                                            Text {
                                                text: "Key Repeat Rate"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: root.keyRepeatRate + " chars / sec"
                                                font.pixelSize: 10
                                                color: Island.Theme.muted
                                            }
                                        }

                                        StyledSlider {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: contentStack.width - 250
                                            height: 18
                                            value: (root.keyRepeatRate - 10) / 50.0
                                            onMoved: (val) => {
                                                let rate = Math.round(10 + val * 50);
                                                root.setKeyRepeatRate(rate);
                                            }
                                        }
                                    }
                                }

                                // Shortcuts Cheat Sheet Card
                                Rectangle {
                                    width: parent.width
                                    implicitHeight: cheatCol.implicitHeight + 28
                                    radius: 12
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Column {
                                        id: cheatCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 14
                                        spacing: 8

                                        Text {
                                            text: "TACTICAL SHORTCUT CHEAT SHEET"
                                            font.pixelSize: 10
                                            font.bold: true
                                            font.letterSpacing: 1
                                            color: Island.Theme.primary
                                        }

                                        Row {
                                            width: parent.width
                                            Text { width: 150; text: "Super (Tap)"; font.pixelSize: 11; font.bold: true; color: Island.Theme.foreground }
                                            Text { text: "Open Dynamic Island Application Launcher"; font.pixelSize: 11; color: Island.Theme.muted }
                                        }
                                        Row {
                                            width: parent.width
                                            Text { width: 150; text: "Super + Tab / Super + R"; font.pixelSize: 11; font.bold: true; color: Island.Theme.foreground }
                                            Text { text: "Toggle Spatial 3D Map (Tab) or Bird's-Eye Canvas (R)"; font.pixelSize: 11; color: Island.Theme.muted }
                                        }
                                        Row {
                                            width: parent.width
                                            Text { width: 150; text: "Super + Shift + S"; font.pixelSize: 11; font.bold: true; color: Island.Theme.foreground }
                                            Text { text: "Universal Screen Lens (OCR, QR, Color Picker & TTS)"; font.pixelSize: 11; color: Island.Theme.muted }
                                        }
                                        Row {
                                            width: parent.width
                                            Text { width: 150; text: "Super + G / Super + A / C"; font.pixelSize: 11; font.bold: true; color: Island.Theme.foreground }
                                            Text { text: "Open AI Studio (G), Wallpapers (A), or Theme Picker (C)"; font.pixelSize: 11; color: Island.Theme.muted }
                                        }
                                        Row {
                                            width: parent.width
                                            Text { width: 150; text: "Super + S / Super + Alt + S"; font.pixelSize: 11; font.bold: true; color: Island.Theme.foreground }
                                            Text { text: "Toggle Stash Pocket (S) or Stash Active Window (Alt+S)"; font.pixelSize: 11; color: Island.Theme.muted }
                                        }
                                        Row {
                                            width: parent.width
                                            Text { width: 150; text: "Super + P / Super + Alt + P"; font.pixelSize: 11; font.bold: true; color: Island.Theme.foreground }
                                            Text { text: "Cycle Display Mode (P) or Toggle CoolPhone Mirror (Alt+P)"; font.pixelSize: 11; color: Island.Theme.muted }
                                        }
                                        Row {
                                            width: parent.width
                                            Text { width: 150; text: "Bottom & Right Edges"; font.pixelSize: 11; font.bold: true; color: Island.Theme.foreground }
                                            Text { text: "Control Center (BL), Dock (BC), Today (BR), Media & Stash (Right)"; font.pixelSize: 11; color: Island.Theme.muted }
                                        }
                                    }
                                }
                            }

                            // =================================================
                            // 7. APPEARANCE & THEMES PAGE
                            // =================================================
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "appearance"

                                Text {
                                    text: "Appearance & Themes"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }
                                Text {
                                    text: "Choose a handcrafted color palette. Switching themes immediately restyles the entire desktop, Dynamic Island, and HUD drawers."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Flow {
                                    width: parent.width
                                    spacing: 10

                                    Repeater {
                                        model: Island.AppearanceState ? Island.AppearanceState.themes : []

                                        delegate: Rectangle {
                                            id: themeCard
                                            required property var modelData
                                            readonly property bool isCurrent: Island.AppearanceState && Island.AppearanceState.currentTheme === modelData.slug

                                            width: 162
                                            height: 82
                                            radius: 14
                                            color: isCurrent ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.16) : Island.Theme.glassCard
                                            border.color: isCurrent ? Island.Theme.primary : (themeHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                                            border.width: isCurrent ? 2 : 1
                                            scale: themeTap.pressed ? 0.96 : 1.0

                                            Behavior on scale { NumberAnimation { duration: 90 } }
                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            HoverHandler { id: themeHover }
                                            TapHandler {
                                                id: themeTap
                                                onTapped: {
                                                    if (Island.AppearanceState) {
                                                        Island.AppearanceState.setTheme(themeCard.modelData.slug);
                                                    }
                                                }
                                            }

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 8

                                                Row {
                                                    width: parent.width
                                                    spacing: 6

                                                    Text {
                                                        text: themeCard.modelData.name || "Theme"
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                        color: themeCard.isCurrent ? Island.Theme.primary : Island.Theme.foreground
                                                        elide: Text.ElideRight
                                                        width: parent.width - 24
                                                    }

                                                    Text {
                                                        visible: themeCard.isCurrent
                                                        text: "✓"
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        color: Island.Theme.primary
                                                    }
                                                }

                                                // Color swatch previews
                                                Row {
                                                    spacing: 5
                                                    Rectangle { width: 14; height: 14; radius: 7; color: themeCard.modelData.colors ? themeCard.modelData.colors.primary : "#a7c080" }
                                                    Rectangle { width: 14; height: 14; radius: 7; color: themeCard.modelData.colors ? themeCard.modelData.colors.bg0 : "#2d353b" }
                                                    Rectangle { width: 14; height: 14; radius: 7; color: themeCard.modelData.colors ? themeCard.modelData.colors.blue : "#7fbbb3" }
                                                    Rectangle { width: 14; height: 14; radius: 7; color: themeCard.modelData.colors ? themeCard.modelData.colors.purple : "#d699b6" }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // =================================================
                            // 8. SYSTEM MODES & TACTICAL PRESETS PAGE
                            // =================================================
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "modes" || windowCard.activeCategory === "gamemode"

                                Text {
                                    text: "System Modes"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }
                                Text {
                                    text: "Unified control center for Game Mode, The Feather battery saver, Study focus lockdown, and God's Eye panoramic overview."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                // -------------------------------------------------
                                // 1. EXTREME GAME MODE CARD
                                // -------------------------------------------------
                                Rectangle {
                                    width: parent.width
                                    radius: 12
                                    color: Island.ShellState.gameMode ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.12) : Island.Theme.glassCard
                                    border.color: Island.ShellState.gameMode ? Island.Theme.red : Island.Theme.glassBorderSubtle
                                    border.width: Island.ShellState.gameMode ? 1.5 : 1
                                    clip: true
                                    implicitHeight: gameCol.implicitHeight + 24

                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    Behavior on border.color { ColorAnimation { duration: 140 } }

                                    Column {
                                        id: gameCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 12
                                        spacing: 10

                                        Row {
                                            width: parent.width
                                            spacing: 12

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰓅"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 22
                                                color: Island.ShellState.gameMode ? Island.Theme.red : Island.Theme.muted
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 90
                                                spacing: 2

                                                Row {
                                                    spacing: 8
                                                    Text {
                                                        text: "Game Mode (Extreme Performance)"
                                                        font.pixelSize: 13
                                                        font.bold: true
                                                        color: Island.Theme.foreground
                                                    }
                                                    Rectangle {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        height: 16
                                                        implicitWidth: gameBadgeText.implicitWidth + 10
                                                        radius: 8
                                                        color: Island.ShellState.gameMode ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                                                        border.color: Island.ShellState.gameMode ? Island.Theme.red : Island.Theme.glassBorderSubtle
                                                        border.width: 1

                                                        Text {
                                                            id: gameBadgeText
                                                            anchors.centerIn: parent
                                                            text: Island.ShellState.gameMode ? ("ACTIVE • " + Island.ShellState.gameModeKilledCount + " PRUNED") : "STANDBY"
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                            color: Island.ShellState.gameMode ? Island.Theme.red : Island.Theme.muted
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: "Suspends background bloat and unmaps heavy shell layers to free maximum GPU/CPU & RAM."
                                                    font.pixelSize: 10
                                                    color: Island.Theme.muted
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                            }

                                            // Toggle Pill Switch
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 44
                                                height: 24
                                                radius: 12
                                                color: Island.ShellState.gameMode ? Island.Theme.red : Island.Theme.glassCardHover
                                                border.color: Island.ShellState.gameMode ? Island.Theme.red : Island.Theme.glassBorderSubtle
                                                border.width: 1

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: Island.ShellState.gameMode ? parent.width - width - 3 : 3
                                                    width: 18
                                                    height: 18
                                                    radius: 9
                                                    color: Island.ShellState.gameMode ? "#0a0a0f" : Island.Theme.muted
                                                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                                }

                                                TapHandler {
                                                    onTapped: Island.ShellState.toggleGameMode()
                                                }
                                            }
                                        }

                                        // Protected Whitelist Header
                                        Row {
                                            spacing: 6
                                            Text {
                                                text: "PROTECTED WHITELIST"
                                                font.pixelSize: 9
                                                font.bold: true
                                                font.letterSpacing: 1
                                                color: Island.Theme.primary
                                            }
                                            Text {
                                                text: "• These apps are shielded and never terminated"
                                                font.pixelSize: 9
                                                color: Island.Theme.muted
                                            }
                                        }

                                        // Exceptions Flow
                                        Flow {
                                            width: parent.width
                                            spacing: 6

                                            Repeater {
                                                model: root.gameModeExceptions

                                                delegate: Rectangle {
                                                    required property var modelData
                                                    width: excText.implicitWidth + 34
                                                    height: 24
                                                    radius: 12
                                                    color: Island.Theme.glassCardHover
                                                    border.color: Island.Theme.glassBorderSubtle
                                                    border.width: 1

                                                    Row {
                                                        anchors.centerIn: parent
                                                        spacing: 6

                                                        Text {
                                                            id: excText
                                                            text: modelData
                                                            font.pixelSize: 10
                                                            color: Island.Theme.foreground
                                                        }

                                                        Text {
                                                            text: "×"
                                                            font.pixelSize: 13
                                                            font.bold: true
                                                            color: Island.Theme.red
                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: root.removeException(modelData)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Add Whitelist App Input Row
                                        Row {
                                            width: parent.width
                                            spacing: 8

                                            Rectangle {
                                                height: 30
                                                width: Math.min(260, parent.width - 100)
                                                radius: 8
                                                color: Island.Theme.glassCard
                                                border.color: addInput.activeFocus ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                                border.width: 1

                                                TextInput {
                                                    id: addInput
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 8
                                                    anchors.rightMargin: 8
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    font.pixelSize: 11
                                                    font.family: Island.Theme.fontFamily
                                                    color: Island.Theme.foreground
                                                    selectByMouse: true
                                                    clip: true

                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "Add app process (e.g. steam, heroic)..."
                                                        font.pixelSize: 10
                                                        font.family: Island.Theme.fontFamily
                                                        color: Island.Theme.muted
                                                        visible: !addInput.text && !addInput.activeFocus
                                                    }

                                                    onAccepted: {
                                                        if (text.trim() !== "") {
                                                            root.addException(text.trim());
                                                            text = "";
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                height: 30
                                                width: 84
                                                radius: 8
                                                color: addBtnHover.hovered ? Island.Theme.primary : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.2)
                                                border.color: Island.Theme.primary
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "+ Add App"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    font.family: Island.Theme.fontFamily
                                                    color: addBtnHover.hovered ? "#0a0a0f" : Island.Theme.foreground
                                                }

                                                HoverHandler { id: addBtnHover }
                                                TapHandler {
                                                    onTapped: {
                                                        if (addInput.text.trim() !== "") {
                                                            root.addException(addInput.text.trim());
                                                            addInput.text = "";
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // -------------------------------------------------
                                // 2. THE FEATHER: BATTERY SAVER MODE CARD
                                // -------------------------------------------------
                                Rectangle {
                                    width: parent.width
                                    radius: 12
                                    color: (Island.ShellState && Island.ShellState.featherMode) ? Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.12) : Island.Theme.glassCard
                                    border.color: (Island.ShellState && Island.ShellState.featherMode) ? Island.Theme.green : Island.Theme.glassBorderSubtle
                                    border.width: (Island.ShellState && Island.ShellState.featherMode) ? 1.5 : 1
                                    clip: true
                                    implicitHeight: featherCol.implicitHeight + 24

                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    Behavior on border.color { ColorAnimation { duration: 140 } }

                                    Column {
                                        id: featherCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 12
                                        spacing: 10

                                        Row {
                                            width: parent.width
                                            spacing: 12

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰌪"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 22
                                                color: (Island.ShellState && Island.ShellState.featherMode) ? Island.Theme.green : Island.Theme.muted
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 90
                                                spacing: 2

                                                Row {
                                                    spacing: 8
                                                    Text {
                                                        text: "The Feather (Absolute Battery)"
                                                        font.pixelSize: 13
                                                        font.bold: true
                                                        color: Island.Theme.foreground
                                                    }
                                                    Rectangle {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        height: 16
                                                        implicitWidth: featherBadgeText.implicitWidth + 10
                                                        radius: 8
                                                        color: (Island.ShellState && Island.ShellState.featherMode) ? Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                                                        border.color: (Island.ShellState && Island.ShellState.featherMode) ? Island.Theme.green : Island.Theme.glassBorderSubtle
                                                        border.width: 1

                                                        Text {
                                                            id: featherBadgeText
                                                            anchors.centerIn: parent
                                                            text: (Island.ShellState && Island.ShellState.featherMode) ? ("ACTIVE • " + (Island.ShellState.featherLimit || 20) + "% CPU CAP") : "STANDBY"
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                            color: (Island.ShellState && Island.ShellState.featherMode) ? Island.Theme.green : Island.Theme.muted
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: (Island.ShellState && Island.ShellState.featherMode)
                                                        ? ("Active • " + (Island.ShellState.featherLimit || 20) + "% CPU/GPU (" + ((Island.ShellState.featherLimit || 20) <= 25 ? "30Hz" : "60Hz") + ") • " + Island.ShellState.featherKilledCount + " apps pruned")
                                                        : "Prunes user bloat & caps CPU/GPU governor with bare-minimum Hyprland overhead."
                                                    font.pixelSize: 10
                                                    color: Island.Theme.muted
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                            }

                                            // Toggle Pill Switch
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 44
                                                height: 24
                                                radius: 12
                                                color: (Island.ShellState && Island.ShellState.featherMode) ? Island.Theme.green : Island.Theme.glassCardHover
                                                border.color: (Island.ShellState && Island.ShellState.featherMode) ? Island.Theme.green : Island.Theme.glassBorderSubtle
                                                border.width: 1

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: (Island.ShellState && Island.ShellState.featherMode) ? parent.width - width - 3 : 3
                                                    width: 18
                                                    height: 18
                                                    radius: 9
                                                    color: (Island.ShellState && Island.ShellState.featherMode) ? "#0a0a0f" : Island.Theme.muted
                                                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                                }

                                                TapHandler {
                                                    onTapped: {
                                                        if (Island.ShellState) Island.ShellState.toggleFeatherMode();
                                                    }
                                                }
                                            }
                                        }

                                        // Presets Row
                                        Row {
                                            width: parent.width
                                            height: 26
                                            spacing: 8

                                            Rectangle {
                                                width: (parent.width - 16) / 3
                                                height: 26
                                                radius: 8
                                                color: (Island.ShellState && Island.ShellState.featherLimit <= 25)
                                                    ? Island.Theme.green
                                                    : Qt.rgba(Island.Theme.glassCardHover.r, Island.Theme.glassCardHover.g, Island.Theme.glassCardHover.b, 0.5)
                                                border.color: (Island.ShellState && Island.ShellState.featherLimit <= 25) ? Island.Theme.green : Island.Theme.glassBorderSubtle
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "20% Extreme (30Hz)"
                                                    font.pixelSize: 10
                                                    font.bold: Island.ShellState && Island.ShellState.featherLimit <= 25
                                                    color: (Island.ShellState && Island.ShellState.featherLimit <= 25) ? "#0a0a0f" : Island.Theme.muted
                                                }

                                                TapHandler {
                                                    onTapped: {
                                                        if (Island.ShellState) Island.ShellState.setFeatherLimit(20);
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: (parent.width - 16) / 3
                                                height: 26
                                                radius: 8
                                                color: (Island.ShellState && Island.ShellState.featherLimit > 25 && Island.ShellState.featherLimit <= 40)
                                                    ? Island.Theme.green
                                                    : Qt.rgba(Island.Theme.glassCardHover.r, Island.Theme.glassCardHover.g, Island.Theme.glassCardHover.b, 0.5)
                                                border.color: (Island.ShellState && Island.ShellState.featherLimit > 25 && Island.ShellState.featherLimit <= 40) ? Island.Theme.green : Island.Theme.glassBorderSubtle
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "35% Balanced (60Hz)"
                                                    font.pixelSize: 10
                                                    font.bold: Island.ShellState && Island.ShellState.featherLimit > 25 && Island.ShellState.featherLimit <= 40
                                                    color: (Island.ShellState && Island.ShellState.featherLimit > 25 && Island.ShellState.featherLimit <= 40) ? "#0a0a0f" : Island.Theme.muted
                                                }

                                                TapHandler {
                                                    onTapped: {
                                                        if (Island.ShellState) Island.ShellState.setFeatherLimit(35);
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: (parent.width - 16) / 3
                                                height: 26
                                                radius: 8
                                                color: (Island.ShellState && Island.ShellState.featherLimit > 40)
                                                    ? Island.Theme.green
                                                    : Qt.rgba(Island.Theme.glassCardHover.r, Island.Theme.glassCardHover.g, Island.Theme.glassCardHover.b, 0.5)
                                                border.color: (Island.ShellState && Island.ShellState.featherLimit > 40) ? Island.Theme.green : Island.Theme.glassBorderSubtle
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "50% Minimal"
                                                    font.pixelSize: 10
                                                    font.bold: Island.ShellState && Island.ShellState.featherLimit > 40
                                                    color: (Island.ShellState && Island.ShellState.featherLimit > 40) ? "#0a0a0f" : Island.Theme.muted
                                                }

                                                TapHandler {
                                                    onTapped: {
                                                        if (Island.ShellState) Island.ShellState.setFeatherLimit(50);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // -------------------------------------------------
                                // 3. STUDY MODE: FOCUS & DISTRACTION LOCKDOWN CARD
                                // -------------------------------------------------
                                Rectangle {
                                    id: studyCardRoot
                                    width: parent.width
                                    radius: 12
                                    color: (Island.ShellState && Island.ShellState.studyActive) ? Qt.rgba(Island.Theme.orange.r, Island.Theme.orange.g, Island.Theme.orange.b, 0.12) : Island.Theme.glassCard
                                    border.color: (Island.ShellState && Island.ShellState.studyActive) ? Island.Theme.orange : Island.Theme.glassBorderSubtle
                                    border.width: (Island.ShellState && Island.ShellState.studyActive) ? 1.5 : 1
                                    clip: true
                                    implicitHeight: studyCol.implicitHeight + 24

                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    Behavior on border.color { ColorAnimation { duration: 140 } }

                                    property bool isCustomSelected: false
                                    property int customDays: 30
                                    property int customHours: 0

                                    function applyCustomDuration() {
                                        let total = (customDays * 86400) + (customHours * 3600);
                                        if (total < 1800) total = 1800;
                                        if (Island.ShellState) Island.ShellState.studyTargetDuration = total;
                                    }

                                    function formatStudyTimeFriendly(sec) {
                                        if (sec >= 86400) {
                                            const d = Math.floor(sec / 86400);
                                            const h = Math.floor((sec % 86400) / 3600);
                                            return d + "d" + (h > 0 ? " " + h + "h" : "");
                                        }
                                        if (sec >= 3600) {
                                            const h = Math.floor(sec / 3600);
                                            const m = Math.floor((sec % 3600) / 60);
                                            return h + "h" + (m > 0 ? " " + m + "m" : "");
                                        }
                                        const m = Math.floor(sec / 60);
                                        return m + "m";
                                    }

                                    function formatRemainingFriendly(sec) {
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

                                    Column {
                                        id: studyCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 12
                                        spacing: 10

                                        Row {
                                            width: parent.width
                                            spacing: 12

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰈈"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 22
                                                color: (Island.ShellState && Island.ShellState.studyActive) ? Island.Theme.orange : Island.Theme.muted
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 130
                                                spacing: 2

                                                Row {
                                                    spacing: 8
                                                    Text {
                                                        text: "Study Mode (Deep Focus Lockdown)"
                                                        font.pixelSize: 13
                                                        font.bold: true
                                                        color: Island.Theme.foreground
                                                    }
                                                    Rectangle {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        height: 16
                                                        implicitWidth: studyBadgeText.implicitWidth + 10
                                                        radius: 8
                                                        color: (Island.ShellState && Island.ShellState.studyActive)
                                                            ? Qt.rgba(Island.Theme.orange.r, Island.Theme.orange.g, Island.Theme.orange.b, 0.25)
                                                            : Qt.rgba(1, 1, 1, 0.08)
                                                        border.color: (Island.ShellState && Island.ShellState.studyActive) ? Island.Theme.orange : Island.Theme.glassBorderSubtle
                                                        border.width: 1

                                                        Text {
                                                            id: studyBadgeText
                                                            anchors.centerIn: parent
                                                            text: (Island.ShellState && Island.ShellState.studyActive)
                                                                ? ("LOCKED IN • " + studyCardRoot.formatRemainingFriendly(Island.ShellState.studyRemaining) + " LEFT")
                                                                : ((studyCardRoot.isCustomSelected || (Island.ShellState && Island.ShellState.studyTargetDuration >= 14400)) ? "EXAM PROFILE" : "STANDBY")
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                            color: (Island.ShellState && Island.ShellState.studyActive) ? Island.Theme.orange : Island.Theme.muted
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: "Anti-jailbreak focus shielding: Blocks games/social media, allows ICAI / PDFs / study tools. Exam Profile (≥4h) unlocks Gemini, Spotify, Hotstar (1h/day) & Chess (1h/day)."
                                                    font.pixelSize: 10
                                                    color: Island.Theme.muted
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                            }

                                            // Start Focus Session Button (Standby)
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 110
                                                height: 28
                                                radius: 8
                                                visible: !(Island.ShellState && Island.ShellState.studyActive)
                                                color: studyStartHover.hovered ? Island.Theme.orange : Qt.rgba(Island.Theme.orange.r, Island.Theme.orange.g, Island.Theme.orange.b, 0.2)
                                                border.color: Island.Theme.orange
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Lock In 󰌾"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    font.family: Island.Theme.fontFamily
                                                    color: studyStartHover.hovered ? "#0a0a0f" : Island.Theme.foreground
                                                }

                                                HoverHandler { id: studyStartHover }
                                                TapHandler {
                                                    onTapped: {
                                                        let dur = (Island.ShellState ? Island.ShellState.studyTargetDuration : 1800);
                                                        let isCustom = studyCardRoot.isCustomSelected || dur >= 14400;
                                                        let args = ["python3", Quickshell.shellPath("scripts/study-mode.py"), "prompt-and-start", "--duration", dur.toString()];
                                                        if (isCustom) args.push("--custom");
                                                        Quickshell.execDetached(args);
                                                    }
                                                }
                                            }
                                        }

                                        // Active Session Dashboard / Controls
                                        Column {
                                            width: parent.width
                                            spacing: 8
                                            visible: Boolean(Island.ShellState && Island.ShellState.studyActive)

                                            Rectangle {
                                                width: parent.width
                                                implicitHeight: activeRow.implicitHeight + 16
                                                radius: 8
                                                color: Qt.rgba(Island.Theme.orange.r, Island.Theme.orange.g, Island.Theme.orange.b, 0.1)
                                                border.color: Island.Theme.orange
                                                border.width: 1

                                                Row {
                                                    id: activeRow
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    anchors.margins: 8
                                                    spacing: 12

                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: (Island.ShellState && Island.ShellState.studyOvertime) ? "󰐊" : "󰌾"
                                                        font.family: Island.Theme.iconFontFamily
                                                        font.pixelSize: 22
                                                        color: (Island.ShellState && Island.ShellState.studyOvertime) ? Island.Theme.primary : Island.Theme.orange
                                                    }

                                                    Column {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: parent.width - 150
                                                        spacing: 3

                                                        Text {
                                                            text: (Island.ShellState && Island.ShellState.studyOvertime)
                                                                ? "Target Met! Overtime Flow Active (+" + studyCardRoot.formatStudyTimeFriendly(Island.ShellState.studyOvertimeSeconds) + ")"
                                                                : "Lockdown Active: " + studyCardRoot.formatRemainingFriendly(Island.ShellState.studyRemaining) + " remaining"
                                                            font.pixelSize: 12
                                                            font.bold: true
                                                            color: Island.Theme.foreground
                                                        }

                                                        Text {
                                                            text: {
                                                                let isExam = (Island.ShellState && Island.ShellState.studyIsLongSession);
                                                                let chessRem = (Island.ShellState ? Island.ShellState.studyChessQuotaRemaining : 3600);
                                                                let chessMin = Math.floor(chessRem / 60);
                                                                let hotstarRem = (Island.ShellState ? Island.ShellState.studyHotstarQuotaRemaining : 3600);
                                                                let hotstarMin = Math.floor(hotstarRem / 60);
                                                                return isExam
                                                                    ? ("Exam Profile: Gemini/Spotify • Hotstar: " + hotstarMin + "m left • Chess: " + chessMin + "m left • Kitty terminal safe")
                                                                    : "Sprint Mode: Pure offline study whitelist • Distractions blocked";
                                                            }
                                                            font.pixelSize: 10
                                                            color: Island.Theme.muted
                                                            elide: Text.ElideRight
                                                            width: parent.width
                                                        }
                                                    }

                                                    // Stop / Finish Session or Locked Button
                                                    Rectangle {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: 120
                                                        height: 28
                                                        radius: 8
                                                        readonly property bool canStop: Boolean(Island.ShellState && (Island.ShellState.studyOvertime || Island.ShellState.studyRemaining <= 0))
                                                        color: canStop ? Island.Theme.green : Qt.rgba(1, 1, 1, 0.08)
                                                        border.color: canStop ? Island.Theme.green : Island.Theme.glassBorderSubtle
                                                        border.width: 1

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: parent.canStop ? "Finish Session ✨" : "Locked (No Exit) 🔒"
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            color: parent.canStop ? "#0a0a0f" : Island.Theme.muted
                                                        }

                                                        TapHandler {
                                                            onTapped: {
                                                                if (parent.canStop) {
                                                                    if (Island.ShellState) Island.ShellState.stopStudyMode();
                                                                } else {
                                                                    Island.IslandHub.showTransient("🔒 Hard Lock Active: Cannot exit early! (" + studyCardRoot.formatStudyTimeFriendly(Island.ShellState.studyRemaining) + " left)", 4000);
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Duration Selection Pills (when standby)
                                        Flow {
                                            width: parent.width
                                            spacing: 6
                                            visible: !(Island.ShellState && Island.ShellState.studyActive)

                                            Repeater {
                                                model: [
                                                    { name: "30 min", seconds: 1800, isCustom: false },
                                                    { name: "1 hr", seconds: 3600, isCustom: false },
                                                    { name: "2 hr", seconds: 7200, isCustom: false },
                                                    { name: "4 hr", seconds: 14400, isCustom: false },
                                                    { name: "1 Day", seconds: 86400, isCustom: false },
                                                    { name: "1 Week", seconds: 604800, isCustom: false },
                                                    { name: "1 Month", seconds: 2592000, isCustom: false },
                                                    { name: "Custom ⚙", seconds: 0, isCustom: true }
                                                ]

                                                delegate: Rectangle {
                                                    required property var modelData
                                                    width: Math.max(54, pillText.implicitWidth + 16)
                                                    height: 26
                                                    radius: 8
                                                    readonly property bool isSelected: modelData.isCustom
                                                        ? studyCardRoot.isCustomSelected
                                                        : (!studyCardRoot.isCustomSelected && (Island.ShellState ? Island.ShellState.studyTargetDuration : 1800) === modelData.seconds)
                                                    color: isSelected
                                                        ? Island.Theme.orange
                                                        : Qt.rgba(Island.Theme.glassCardHover.r, Island.Theme.glassCardHover.g, Island.Theme.glassCardHover.b, 0.5)
                                                    border.color: isSelected ? Island.Theme.orange : Island.Theme.glassBorderSubtle
                                                    border.width: 1

                                                    Text {
                                                        id: pillText
                                                        anchors.centerIn: parent
                                                        text: modelData.name
                                                        font.pixelSize: 10
                                                        font.bold: isSelected
                                                        color: isSelected ? "#0a0a0f" : Island.Theme.muted
                                                    }

                                                    TapHandler {
                                                        onTapped: {
                                                            if (modelData.isCustom) {
                                                                studyCardRoot.isCustomSelected = true;
                                                                studyCardRoot.applyCustomDuration();
                                                            } else {
                                                                studyCardRoot.isCustomSelected = false;
                                                                if (Island.ShellState) Island.ShellState.studyTargetDuration = modelData.seconds;
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Custom Duration Stepper Box (Shown when Custom is selected)
                                        Rectangle {
                                            width: parent.width
                                            height: 38
                                            radius: 8
                                            visible: !(Island.ShellState && Island.ShellState.studyActive) && studyCardRoot.isCustomSelected
                                            color: Qt.rgba(Island.Theme.glassCardHover.r, Island.Theme.glassCardHover.g, Island.Theme.glassCardHover.b, 0.4)
                                            border.color: Island.Theme.orange
                                            border.width: 1

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 20

                                                // Days stepper
                                                Row {
                                                    spacing: 6
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text {
                                                        text: "Days:"
                                                        font.pixelSize: 11
                                                        font.family: Island.Theme.fontFamily
                                                        color: Island.Theme.muted
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    Rectangle {
                                                        width: 22
                                                        height: 22
                                                        radius: 5
                                                        color: Qt.rgba(1, 1, 1, 0.1)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        Text { anchors.centerIn: parent; text: "−"; font.bold: true; color: Island.Theme.foreground }
                                                        TapHandler {
                                                            onTapped: {
                                                                if (studyCardRoot.customDays > 0) studyCardRoot.customDays -= 1;
                                                                studyCardRoot.applyCustomDuration();
                                                            }
                                                        }
                                                    }
                                                    Text {
                                                        text: studyCardRoot.customDays.toString()
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        font.family: Island.Theme.fontFamily
                                                        color: Island.Theme.orange
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        horizontalAlignment: Text.AlignHCenter
                                                        width: 28
                                                    }
                                                    Rectangle {
                                                        width: 22
                                                        height: 22
                                                        radius: 5
                                                        color: Qt.rgba(1, 1, 1, 0.1)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        Text { anchors.centerIn: parent; text: "+"; font.bold: true; color: Island.Theme.foreground }
                                                        TapHandler {
                                                            onTapped: {
                                                                if (studyCardRoot.customDays < 365) studyCardRoot.customDays += 1;
                                                                studyCardRoot.applyCustomDuration();
                                                            }
                                                        }
                                                    }
                                                }

                                                // Hours stepper
                                                Row {
                                                    spacing: 6
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text {
                                                        text: "Hours:"
                                                        font.pixelSize: 11
                                                        font.family: Island.Theme.fontFamily
                                                        color: Island.Theme.muted
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    Rectangle {
                                                        width: 22
                                                        height: 22
                                                        radius: 5
                                                        color: Qt.rgba(1, 1, 1, 0.1)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        Text { anchors.centerIn: parent; text: "−"; font.bold: true; color: Island.Theme.foreground }
                                                        TapHandler {
                                                            onTapped: {
                                                                if (studyCardRoot.customHours > 0) studyCardRoot.customHours -= 1;
                                                                studyCardRoot.applyCustomDuration();
                                                            }
                                                        }
                                                    }
                                                    Text {
                                                        text: studyCardRoot.customHours.toString()
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        font.family: Island.Theme.fontFamily
                                                        color: Island.Theme.orange
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        horizontalAlignment: Text.AlignHCenter
                                                        width: 24
                                                    }
                                                    Rectangle {
                                                        width: 22
                                                        height: 22
                                                        radius: 5
                                                        color: Qt.rgba(1, 1, 1, 0.1)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        Text { anchors.centerIn: parent; text: "+"; font.bold: true; color: Island.Theme.foreground }
                                                        TapHandler {
                                                            onTapped: {
                                                                if (studyCardRoot.customHours < 23) studyCardRoot.customHours += 1;
                                                                studyCardRoot.applyCustomDuration();
                                                            }
                                                        }
                                                    }
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "= " + studyCardRoot.formatStudyTimeFriendly(studyCardRoot.customDays * 86400 + studyCardRoot.customHours * 3600) + " lockdown"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: Island.Theme.foreground
                                                }
                                            }
                                        }

                                        // Profile Info Banner (Standby only)
                                        Rectangle {
                                            width: parent.width
                                            height: 44
                                            radius: 8
                                            visible: !(Island.ShellState && Island.ShellState.studyActive)
                                            readonly property bool isExam: studyCardRoot.isCustomSelected || (Island.ShellState && Island.ShellState.studyTargetDuration >= 14400)
                                            color: isExam ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.12) : Qt.rgba(1, 1, 1, 0.04)
                                            border.color: isExam ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                            border.width: 1

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 10

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: parent.parent.isExam ? "🎓" : "⚡"
                                                    font.pixelSize: 18
                                                }

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 2

                                                    Text {
                                                        text: parent.parent.parent.isExam
                                                            ? "Exam Profile (≥ 4h / Custom Timer Locked In)"
                                                            : "Sprint Profile (< 4h Deep Work)"
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                        color: parent.parent.parent.isExam ? Island.Theme.primary : Island.Theme.foreground
                                                    }

                                                    Text {
                                                        text: parent.parent.parent.isExam
                                                            ? "Gemini AI allowed • Spotify permitted • Hotstar 1h/day quota • Chess.com 1h/day quota • Kitty whitelisted • Anti-jailbreak lock"
                                                            : "Strict distraction blocking • Spotify paused • Offline PDFs & ICAI focus"
                                                        font.pixelSize: 9
                                                        color: Island.Theme.muted
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // -------------------------------------------------
                                // 4. GOD'S EYE VIEW MODE CARD
                                // -------------------------------------------------
                                Rectangle {
                                    width: parent.width
                                    radius: 12
                                    color: (Island.ShellState && Island.ShellState.godsEyeActive) ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.12) : Island.Theme.glassCard
                                    border.color: (Island.ShellState && Island.ShellState.godsEyeActive) ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                    border.width: (Island.ShellState && Island.ShellState.godsEyeActive) ? 1.5 : 1
                                    clip: true
                                    implicitHeight: godsEyeCol.implicitHeight + 24

                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    Behavior on border.color { ColorAnimation { duration: 140 } }

                                    Column {
                                        id: godsEyeCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 12
                                        spacing: 10

                                        Row {
                                            width: parent.width
                                            spacing: 12

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰍹"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 22
                                                color: (Island.ShellState && Island.ShellState.godsEyeActive) ? Island.Theme.primary : Island.Theme.muted
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 90
                                                spacing: 2

                                                Row {
                                                    spacing: 8
                                                    Text {
                                                        text: "God's Eye View Mode"
                                                        font.pixelSize: 13
                                                        font.bold: true
                                                        color: Island.Theme.foreground
                                                    }
                                                    Rectangle {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        height: 16
                                                        implicitWidth: godsEyeBadgeText.implicitWidth + 10
                                                        radius: 8
                                                        color: (Island.ShellState && Island.ShellState.godsEyeActive) ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                                                        border.color: (Island.ShellState && Island.ShellState.godsEyeActive) ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                                        border.width: 1

                                                        Text {
                                                            id: godsEyeBadgeText
                                                            anchors.centerIn: parent
                                                            text: (Island.ShellState && Island.ShellState.godsEyeActive) ? "ACTIVE" : "STANDBY"
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                            color: (Island.ShellState && Island.ShellState.godsEyeActive) ? Island.Theme.primary : Island.Theme.muted
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: "Panoramic system matrix, visual window topology, and real-time spatial desktop monitoring."
                                                    font.pixelSize: 10
                                                    color: Island.Theme.muted
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                            }

                                            // Toggle Pill Switch
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 44
                                                height: 24
                                                radius: 12
                                                color: (Island.ShellState && Island.ShellState.godsEyeActive) ? Island.Theme.primary : Island.Theme.glassCardHover
                                                border.color: (Island.ShellState && Island.ShellState.godsEyeActive) ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                                border.width: 1

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: (Island.ShellState && Island.ShellState.godsEyeActive) ? parent.width - width - 3 : 3
                                                    width: 18
                                                    height: 18
                                                    radius: 9
                                                    color: (Island.ShellState && Island.ShellState.godsEyeActive) ? "#0a0a0f" : Island.Theme.muted
                                                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                                }

                                                TapHandler {
                                                    onTapped: {
                                                        if (Island.ShellState) Island.ShellState.toggleGodsEye();
                                                    }
                                                }
                                            }
                                        }

                                        // Action Button: Open in Browser
                                        Rectangle {
                                            width: 140
                                            height: 26
                                            radius: 8
                                            visible: Island.ShellState && Island.ShellState.godsEyeActive
                                            color: godsEyeOpenHover.hovered ? Island.Theme.primary : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.2)
                                            border.color: Island.Theme.primary
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Open in Browser 󰖟"
                                                font.pixelSize: 10
                                                font.bold: true
                                                font.family: Island.Theme.fontFamily
                                                color: godsEyeOpenHover.hovered ? "#0a0a0f" : Island.Theme.foreground
                                            }

                                            HoverHandler { id: godsEyeOpenHover }
                                            TapHandler {
                                                onTapped: {
                                                    if (Island.ShellState) Island.ShellState.openGodsEyeBrowser();
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // =================================================
                            // 9. POWER & BATTERY PAGE
                            // =================================================
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "power"

                                Text {
                                    text: "Power & Battery"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }
                                Text {
                                    text: "Battery health telemetry, inactivity sleep timeouts, and tactical power actions."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                }

                                // Battery Status Card
                                Rectangle {
                                    width: parent.width
                                    height: 80
                                    radius: 12
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 14

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Island.PowerState && Island.PowerState.charging ? "󰂄" : "󰁹"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 26
                                            color: Island.PowerState && Island.PowerState.charging ? Island.Theme.green : Island.Theme.primary
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3
                                            Text {
                                                text: (Island.PowerState ? Math.round(Island.PowerState.percent * 100) : 100) + "% Remaining"
                                                font.pixelSize: 15
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: Island.PowerState && Island.PowerState.charging ? "Connected to AC Power (Charging)" : "Running on Battery Power"
                                                font.pixelSize: 10
                                                color: Island.Theme.muted
                                            }
                                        }
                                    }
                                }

                                // =============================================
                                // Battery Charge Limit Card (80% Health Mode)
                                // =============================================
                                Rectangle {
                                    width: parent.width
                                    radius: 12
                                    color: root.batteryLimitEnabled ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.12) : Island.Theme.glassCard
                                    border.color: root.batteryLimitEnabled ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                    border.width: root.batteryLimitEnabled ? 1.5 : 1
                                    clip: true
                                    implicitHeight: battLimitCol.implicitHeight + 24

                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    Behavior on border.color { ColorAnimation { duration: 140 } }

                                    Column {
                                        id: battLimitCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 12
                                        spacing: 12

                                        // Header Row: Icon, Title, Subtitle, Toggle Switch
                                        Row {
                                            width: parent.width
                                            spacing: 12

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󱈑"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 24
                                                color: root.batteryLimitEnabled ? Island.Theme.primary : Island.Theme.muted
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 90
                                                spacing: 2

                                                Row {
                                                    spacing: 8
                                                    Text {
                                                        text: "Battery Charge Limit (Health Mode)"
                                                        font.pixelSize: 13
                                                        font.bold: true
                                                        color: Island.Theme.foreground
                                                    }
                                                    Rectangle {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        height: 16
                                                        implicitWidth: battLimitBadgeText.implicitWidth + 10
                                                        radius: 8
                                                        color: root.batteryLimitEnabled ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                                                        border.color: root.batteryLimitEnabled ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                                        border.width: 1

                                                        Text {
                                                            id: battLimitBadgeText
                                                            anchors.centerIn: parent
                                                            text: root.batteryLimitEnabled ? (root.batteryLimitPercent + "% CAP ACTIVE") : "OFF (100% FULL)"
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                            color: root.batteryLimitEnabled ? Island.Theme.primary : Island.Theme.muted
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: "Halts charging at target limit to preserve lithium chemistry when operating on AC power."
                                                    font.pixelSize: 10
                                                    color: Island.Theme.muted
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                            }

                                            // Toggle Pill Switch
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 44
                                                height: 24
                                                radius: 12
                                                color: root.batteryLimitEnabled ? Island.Theme.primary : Island.Theme.glassCardHover
                                                border.color: root.batteryLimitEnabled ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                                border.width: 1

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: root.batteryLimitEnabled ? parent.width - width - 3 : 3
                                                    width: 18
                                                    height: 18
                                                    radius: 9
                                                    color: root.batteryLimitEnabled ? "#0a0a0f" : Island.Theme.muted
                                                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                                }

                                                TapHandler {
                                                    onTapped: root.toggleBatteryLimit()
                                                }
                                            }
                                        }

                                        // Mode Options (80% Health Mode vs 100% Full Capacity)
                                        Row {
                                            width: parent.width
                                            height: 48
                                            spacing: 8

                                            // 80% Health Mode Tile
                                            Rectangle {
                                                id: tile80
                                                width: (parent.width - 8) / 2
                                                height: parent.height
                                                radius: 10
                                                readonly property bool isSelected: root.batteryLimitEnabled
                                                color: tile80.isSelected
                                                    ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.2)
                                                    : Qt.rgba(Island.Theme.glassCardHover.r, Island.Theme.glassCardHover.g, Island.Theme.glassCardHover.b, 0.4)
                                                border.color: tile80.isSelected ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                                border.width: tile80.isSelected ? 1.5 : 1

                                                Row {
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    spacing: 8

                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "󱈑"
                                                        font.family: Island.Theme.iconFontFamily
                                                        font.pixelSize: 20
                                                        color: tile80.isSelected ? Island.Theme.primary : Island.Theme.muted
                                                    }

                                                    Column {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 2

                                                        Text {
                                                            text: "80% Health Mode"
                                                            font.pixelSize: 11
                                                            font.bold: true
                                                            color: tile80.isSelected ? Island.Theme.foreground : Island.Theme.muted
                                                        }

                                                        Text {
                                                            text: "AC / Desk protection"
                                                            font.pixelSize: 9
                                                            color: Island.Theme.muted
                                                        }
                                                    }
                                                }

                                                TapHandler {
                                                    onTapped: root.setBatteryLimit(80)
                                                }
                                            }

                                            // 100% Full Capacity Tile
                                            Rectangle {
                                                id: tile100
                                                width: (parent.width - 8) / 2
                                                height: parent.height
                                                radius: 10
                                                readonly property bool isSelected: !root.batteryLimitEnabled
                                                color: tile100.isSelected
                                                    ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.2)
                                                    : Qt.rgba(Island.Theme.glassCardHover.r, Island.Theme.glassCardHover.g, Island.Theme.glassCardHover.b, 0.4)
                                                border.color: tile100.isSelected ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                                border.width: tile100.isSelected ? 1.5 : 1

                                                Row {
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    spacing: 8

                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "󱈏"
                                                        font.family: Island.Theme.iconFontFamily
                                                        font.pixelSize: 20
                                                        color: tile100.isSelected ? Island.Theme.primary : Island.Theme.muted
                                                    }

                                                    Column {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 2

                                                        Text {
                                                            text: "100% Full Charge"
                                                            font.pixelSize: 11
                                                            font.bold: true
                                                            color: tile100.isSelected ? Island.Theme.foreground : Island.Theme.muted
                                                        }

                                                        Text {
                                                            text: "Maximum battery life"
                                                            font.pixelSize: 9
                                                            color: Island.Theme.muted
                                                        }
                                                    }
                                                }

                                                TapHandler {
                                                    onTapped: root.setBatteryLimit(100)
                                                }
                                            }
                                        }

                                        // Acer Hardware Architecture Note
                                        Rectangle {
                                            width: parent.width
                                            implicitHeight: battHwNote.implicitHeight + 12
                                            radius: 8
                                            color: Qt.rgba(1, 1, 1, 0.04)
                                            border.color: Island.Theme.glassBorderSubtle
                                            border.width: 1

                                            Row {
                                                id: battHwNote
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                anchors.margins: 6
                                                spacing: 8

                                                Text {
                                                    text: "󰌢"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 13
                                                    color: Island.Theme.primary
                                                }

                                                Text {
                                                    width: parent.width - 24
                                                    wrapMode: Text.WordWrap
                                                    font.pixelSize: 10
                                                    color: Island.Theme.muted
                                                    text: "Acer Aspire / Nitro hardware Embedded Controller (EC) enforces a fixed 80% physical cutoff. When above 80%, the laptop switches to AC power and the battery gradually settles to 80%."
                                                }
                                            }
                                        }
                                    }
                                }

                                // Inactivity Sleep Timeout Card
                                Rectangle {
                                    width: parent.width
                                    height: 72
                                    radius: 12
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 14

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰤄"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 22
                                            color: Island.Theme.primary
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 160
                                            spacing: 2
                                            Text {
                                                text: "Inactivity Ambient Sleep"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: root.idleTimeoutMinutes + " minutes timeout"
                                                font.pixelSize: 10
                                                color: Island.Theme.muted
                                            }
                                        }

                                        StyledSlider {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: contentStack.width - 250
                                            height: 18
                                            value: (root.idleTimeoutMinutes - 1) / 9.0
                                            onMoved: (val) => {
                                                let mins = Math.max(1, Math.round(1 + val * 9));
                                                root.setIdleMinutes(mins);
                                            }
                                        }
                                    }
                                }

                                // The Feather: Absolute Battery Mode Card
                                Rectangle {
                                    width: parent.width
                                    height: (Island.ShellState && Island.ShellState.featherMode) ? 104 : 74
                                    radius: 12
                                    clip: true
                                    color: Island.ShellState && Island.ShellState.featherMode
                                        ? Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.16)
                                        : Island.Theme.glassCard
                                    border.color: Island.ShellState && Island.ShellState.featherMode
                                        ? Island.Theme.green
                                        : Island.Theme.glassBorderSubtle
                                    border.width: Island.ShellState && Island.ShellState.featherMode ? 1.5 : 1

                                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        Row {
                                            width: parent.width
                                            height: 44
                                            spacing: 14

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰌪"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 22
                                                color: Island.ShellState && Island.ShellState.featherMode ? Island.Theme.green : Island.Theme.muted
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 120
                                                spacing: 2
                                                Row {
                                                    spacing: 6
                                                    Text {
                                                        text: "The Feather (Absolute Battery)"
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        color: Island.Theme.foreground
                                                    }
                                                    Rectangle {
                                                        visible: Island.ShellState && Island.ShellState.featherMode
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: 50
                                                        height: 16
                                                        radius: 8
                                                        color: Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.25)
                                                        border.color: Island.Theme.green
                                                        border.width: 1

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: (Island.ShellState ? Island.ShellState.featherLimit : 20) + "% CAP"
                                                            font.pixelSize: 8
                                                            font.bold: true
                                                            font.family: Island.Theme.fontFamily
                                                            color: Island.Theme.green
                                                        }
                                                    }
                                                }
                                                Text {
                                                    text: Island.ShellState && Island.ShellState.featherMode
                                                        ? ("Active • " + (Island.ShellState ? Island.ShellState.featherLimit : 20) + "% CPU/GPU (" + ((Island.ShellState ? Island.ShellState.featherLimit : 20) <= 25 ? "30Hz" : "60Hz") + ") • " + Island.ShellState.featherKilledCount + " apps pruned")
                                                        : "Prunes user bloat & caps CPU/GPU (20% extreme or 35% balanced) with bare-minimum Hyprland."
                                                    font.pixelSize: 10
                                                    color: Island.ShellState && Island.ShellState.featherMode ? Island.Theme.green : Island.Theme.muted
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            // Toggle Pill Switch
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 44
                                                height: 24
                                                radius: 12
                                                color: (Island.ShellState && Island.ShellState.featherMode) ? Island.Theme.green : Island.Theme.glassCardHover
                                                border.color: (Island.ShellState && Island.ShellState.featherMode) ? Island.Theme.green : Island.Theme.glassBorderSubtle
                                                border.width: 1

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: (Island.ShellState && Island.ShellState.featherMode) ? parent.width - width - 3 : 3
                                                    width: 18
                                                    height: 18
                                                    radius: 9
                                                    color: (Island.ShellState && Island.ShellState.featherMode) ? "#0a0a0f" : Island.Theme.muted

                                                    Behavior on x {
                                                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                                    }
                                                }

                                                TapHandler {
                                                    onTapped: {
                                                        if (Island.ShellState) Island.ShellState.toggleFeatherMode();
                                                    }
                                                }
                                            }
                                        }

                                        // Presets Row (20% vs 35% vs 50%)
                                        Row {
                                            width: parent.width
                                            height: 26
                                            spacing: 8
                                            visible: Island.ShellState && Island.ShellState.featherMode

                                            Rectangle {
                                                width: (parent.width - 16) / 3
                                                height: 26
                                                radius: 8
                                                color: (Island.ShellState && Island.ShellState.featherLimit <= 25)
                                                    ? Island.Theme.green
                                                    : Qt.rgba(Island.Theme.glassCardHover.r, Island.Theme.glassCardHover.g, Island.Theme.glassCardHover.b, 0.5)
                                                border.color: (Island.ShellState && Island.ShellState.featherLimit <= 25)
                                                    ? Island.Theme.green
                                                    : Island.Theme.glassBorderSubtle
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "20% Extreme (30Hz)"
                                                    font.pixelSize: 10
                                                    font.bold: Island.ShellState && Island.ShellState.featherLimit <= 25
                                                    font.family: Island.Theme.fontFamily
                                                    color: (Island.ShellState && Island.ShellState.featherLimit <= 25) ? "#0a0a0f" : Island.Theme.muted
                                                }

                                                TapHandler {
                                                    onTapped: {
                                                        if (Island.ShellState) Island.ShellState.setFeatherLimit(20);
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: (parent.width - 16) / 3
                                                height: 26
                                                radius: 8
                                                color: (Island.ShellState && Island.ShellState.featherLimit > 25 && Island.ShellState.featherLimit <= 40)
                                                    ? Island.Theme.green
                                                    : Qt.rgba(Island.Theme.glassCardHover.r, Island.Theme.glassCardHover.g, Island.Theme.glassCardHover.b, 0.5)
                                                border.color: (Island.ShellState && Island.ShellState.featherLimit > 25 && Island.ShellState.featherLimit <= 40)
                                                    ? Island.Theme.green
                                                    : Island.Theme.glassBorderSubtle
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "35% Balanced (60Hz)"
                                                    font.pixelSize: 10
                                                    font.bold: Island.ShellState && Island.ShellState.featherLimit > 25 && Island.ShellState.featherLimit <= 40
                                                    font.family: Island.Theme.fontFamily
                                                    color: (Island.ShellState && Island.ShellState.featherLimit > 25 && Island.ShellState.featherLimit <= 40) ? "#0a0a0f" : Island.Theme.muted
                                                }

                                                TapHandler {
                                                    onTapped: {
                                                        if (Island.ShellState) Island.ShellState.setFeatherLimit(35);
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: (parent.width - 16) / 3
                                                height: 26
                                                radius: 8
                                                color: (Island.ShellState && Island.ShellState.featherLimit > 40)
                                                    ? Island.Theme.green
                                                    : Qt.rgba(Island.Theme.glassCardHover.r, Island.Theme.glassCardHover.g, Island.Theme.glassCardHover.b, 0.5)
                                                border.color: (Island.ShellState && Island.ShellState.featherLimit > 40)
                                                    ? Island.Theme.green
                                                    : Island.Theme.glassBorderSubtle
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "50% Minimal"
                                                    font.pixelSize: 10
                                                    font.bold: Island.ShellState && Island.ShellState.featherLimit > 40
                                                    font.family: Island.Theme.fontFamily
                                                    color: (Island.ShellState && Island.ShellState.featherLimit > 40) ? "#0a0a0f" : Island.Theme.muted
                                                }

                                                TapHandler {
                                                    onTapped: {
                                                        if (Island.ShellState) Island.ShellState.setFeatherLimit(50);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // =================================================
                            // 10. PRIVACY & SECURITY PAGE
                            // =================================================
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "privacy"

                                Text {
                                    text: "Privacy & Security"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }
                                Text {
                                    text: "Real-time hardware sensors, clipboard hygiene, and local offline guarantees."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                }

                                // Hardware Sensor Status Dashboard
                                Rectangle {
                                    width: parent.width
                                    height: 90
                                    radius: 12
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 10

                                        Text {
                                            text: "HARDWARE SENSORS"
                                            font.pixelSize: 10
                                            font.bold: true
                                            font.letterSpacing: 1
                                            color: Island.Theme.primary
                                        }

                                        Row {
                                            spacing: 24
                                            Row {
                                                spacing: 8
                                                Text { text: "󰍬"; font.family: Island.Theme.iconFontFamily; font.pixelSize: 14; color: Island.PrivacyState && Island.PrivacyState.micActive ? Island.Theme.yellow : Island.Theme.green }
                                                Text { text: Island.PrivacyState && Island.PrivacyState.micActive ? "Microphone in use" : "Microphone idle"; font.pixelSize: 11; color: Island.Theme.foreground }
                                            }
                                            Row {
                                                spacing: 8
                                                Text { text: "󰄀"; font.family: Island.Theme.iconFontFamily; font.pixelSize: 14; color: Island.PrivacyState && Island.PrivacyState.camActive ? Island.Theme.purple : Island.Theme.green }
                                                Text { text: Island.PrivacyState && Island.PrivacyState.camActive ? "Camera active" : "Camera idle"; font.pixelSize: 11; color: Island.Theme.foreground }
                                            }
                                        }
                                    }
                                }

                                // Data Hygiene Actions
                                Text {
                                    text: "DATA HYGIENE"
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: Island.Theme.primary
                                }

                                Row {
                                    spacing: 12

                                    Rectangle {
                                        width: 190
                                        height: 38
                                        radius: 10
                                        color: clipMouse.containsMouse ? Island.Theme.primaryContainer : Island.Theme.glassCard
                                        border.color: Island.Theme.glassBorderSubtle
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅖 Wipe Clipboard History"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: Island.Theme.foreground
                                        }
                                        MouseArea {
                                            id: clipMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.wipeClipboard()
                                        }
                                    }

                                    Rectangle {
                                        width: 190
                                        height: 38
                                        radius: 10
                                        color: thumbMouse.containsMouse ? Island.Theme.primaryContainer : Island.Theme.glassCard
                                        border.color: Island.Theme.glassBorderSubtle
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰸉 Clear Thumbnail Cache"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: Island.Theme.foreground
                                        }
                                        MouseArea {
                                            id: thumbMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.wipeThumbnailCache()
                                        }
                                    }
                                }
                            }

                            // =================================================
                            // 11. ACCESSIBILITY & VOICE PAGE
                            // =================================================
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "a11y"

                                Text {
                                    text: "Accessibility & Voice"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }
                                Text {
                                    text: "Inclusive system controls: Text-to-speech audio feedback, contrast, and motion adjustments."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                }

                                // Screen Reader TTS
                                Rectangle {
                                    width: parent.width
                                    height: 52
                                    radius: 10
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 110
                                            text: "Screen Reader Voice Readout (speech-dispatcher)"
                                            font.pixelSize: 11
                                            color: Island.Theme.foreground
                                        }

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 90
                                            height: 26
                                            radius: 8
                                            color: Island.AccessibilityState && Island.AccessibilityState.screenReader ? Island.Theme.primary : Island.Theme.glassCardHover
                                            Text {
                                                anchors.centerIn: parent
                                                text: Island.AccessibilityState && Island.AccessibilityState.screenReader ? "Enabled" : "Disabled"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Island.AccessibilityState && Island.AccessibilityState.screenReader ? "#0a0a0f" : Island.Theme.foreground
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (Island.AccessibilityState) Island.AccessibilityState.toggleScreenReader();
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // =================================================
                            // 12. SYSTEM & ABOUT PAGE
                            // =================================================
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "about"

                                Text {
                                    text: "About Cool-Shell"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 150
                                    radius: 14
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 8

                                        Text {
                                            text: "Cool-Shell Desktop Environment"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Island.Theme.foreground
                                        }
                                        Text {
                                            text: "Architecture: Wayland / Hyprland / Quickshell 0.3.1 (Qt 6)"
                                            font.pixelSize: 11
                                            color: Island.Theme.muted
                                        }
                                        Text {
                                            text: "Performance Guarantee: 0.00% Idle CPU Overhead, Zero Infinite Loops"
                                            font.pixelSize: 11
                                            color: Island.Theme.green
                                        }

                                        Rectangle {
                                            width: 180
                                            height: 32
                                            radius: 10
                                            color: tourMouse.containsMouse ? Island.Theme.primaryContainer : Island.Theme.glassCardHover
                                            border.color: Island.Theme.glassBorder
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Replay Onboarding Guide"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            MouseArea {
                                                id: tourMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.hide();
                                                    Quickshell.execDetached(["rm", "-f", Quickshell.env("HOME") + "/.local/state/cool-shell/onboarding.json"]);
                                                    if (Island.ShellState) {
                                                        Island.ShellState.openOnboarding();
                                                    }
                                                    Island.IslandHub.showTransient("Restarting Onboarding Guide...", 2000);
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
        }
    }
}
}
