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
    readonly property var wifiDevice: Networking.devices ? Networking.devices.values.find((d) => d.type === NetworkDeviceType.Wifi || d.networks !== undefined) : null
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values.slice().sort((a, b) => (b.strength || 0) - (a.strength || 0)) : []
    readonly property var connectedWifi: wifiNetworks.find((n) => n.connected)
    property var pendingWifiNetwork: null

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
    property int idleTimeoutMinutes: 2
    property var gameModeExceptions: ["steam", "discord", "spotify", "obs", "heroic"]

    // =========================================================================
    // PUBLIC API METHODS
    // =========================================================================

    function toggle() {
        open = !open;
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
            windowCard.activeCategory = cat;
        }
        show();
    }

    function refreshTelemetry() {
        if (!getBrightnessProc.running) getBrightnessProc.running = true;
        if (wifiDevice && Networking.wifiEnabled) wifiDevice.scannerEnabled = true;
        if (!getExceptionsProc.running) getExceptionsProc.running = true;
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
        running: true
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

    // =========================================================================
    // DISMISSAL & MODAL BACKDROP
    // =========================================================================

    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: root.open

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

            property string activeCategory: "network"

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
                                    { id: "network", name: "Network & Wi-Fi", icon: "󰤨" },
                                    { id: "bluetooth", name: "Bluetooth & Devices", icon: "󰂯" },
                                    { id: "display", name: "Display & Brightness", icon: "󰍹" },
                                    { id: "audio", name: "Sound & Volume", icon: "󰕾" },
                                    { id: "mouse", name: "Mouse & Touchpad", icon: "󰍽" },
                                    { id: "keyboard", name: "Keyboard & Shortcuts", icon: "󰌌" },
                                    { id: "appearance", name: "Appearance & Themes", icon: "󰏘" },
                                    { id: "gamemode", name: "Performance", icon: "󰓅" },
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
                                        readonly property bool isSelected: windowCard.activeCategory === modelData.id

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
                                                text: Networking.wifiEnabled ? (root.connectedWifi ? ("Connected to " + root.connectedWifi.ssid) : "Enabled (Scanning)") : "Disabled"
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
                                                    if (Networking.wifiEnabled && root.wifiDevice) root.wifiDevice.scannerEnabled = true;
                                                }
                                            }
                                        }
                                    }
                                }

                                // Active Connected Network Card
                                Rectangle {
                                    visible: Networking.wifiEnabled && root.connectedWifi !== undefined && root.connectedWifi !== null
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
                                                text: root.connectedWifi ? root.connectedWifi.ssid : ""
                                                font.pixelSize: 13
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: "Signal: " + (root.connectedWifi ? Math.round(root.connectedWifi.strength * 100) : 0) + "% • Active Default Route"
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
                                                    if (root.connectedWifi) root.connectedWifi.disconnect();
                                                }
                                            }
                                        }
                                    }
                                }

                                // Available Networks List Header
                                Row {
                                    width: parent.width
                                    visible: Networking.wifiEnabled
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
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 6
                                    visible: Networking.wifiEnabled

                                    Repeater {
                                        model: root.wifiNetworks.slice(0, 10)

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
                                                    text: modelData.strength > 0.7 ? "󰤨" : (modelData.strength > 0.4 ? "󰤥" : "󰤟")
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 15
                                                    color: modelData.connected ? Island.Theme.primary : Island.Theme.muted
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 150
                                                    text: modelData.ssid || "Hidden Network"
                                                    font.pixelSize: 11
                                                    font.bold: modelData.connected
                                                    color: Island.Theme.foreground
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.known ? "Saved" : ""
                                                    font.pixelSize: 9
                                                    color: Island.Theme.mutedDark
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
                                                            if (!modelData.connected) modelData.connect();
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
                                    height: 190
                                    radius: 12
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Column {
                                        anchors.fill: parent
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
                                            Text { width: 140; text: "Super (Tap)"; font.pixelSize: 11; font.bold: true; color: Island.Theme.foreground }
                                            Text { text: "Open Dynamic Island Application Launcher"; font.pixelSize: 11; color: Island.Theme.muted }
                                        }
                                        Row {
                                            width: parent.width
                                            Text { width: 140; text: "Super + Tab"; font.pixelSize: 11; font.bold: true; color: Island.Theme.foreground }
                                            Text { text: "Toggle Spatial Mission Control 3D Overview"; font.pixelSize: 11; color: Island.Theme.muted }
                                        }
                                        Row {
                                            width: parent.width
                                            Text { width: 140; text: "Super + A"; font.pixelSize: 11; font.bold: true; color: Island.Theme.foreground }
                                            Text { text: "Open Desktop Live Wallpaper Selector"; font.pixelSize: 11; color: Island.Theme.muted }
                                        }
                                        Row {
                                            width: parent.width
                                            Text { width: 140; text: "Escape"; font.pixelSize: 11; font.bold: true; color: Island.Theme.foreground }
                                            Text { text: "Dismiss Active Modal, Settings Window, or Island"; font.pixelSize: 11; color: Island.Theme.muted }
                                        }
                                        Row {
                                            width: parent.width
                                            Text { width: 140; text: "Bottom Edge Hover"; font.pixelSize: 11; font.bold: true; color: Island.Theme.foreground }
                                            Text { text: "Slide out Control Center (Left) & Workspace Dock (Center)"; font.pixelSize: 11; color: Island.Theme.muted }
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
                            // 8. GAME MODE & RULES PAGE
                            // =================================================
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "gamemode"

                                Text {
                                    text: "Performance Mode"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }
                                Text {
                                    text: "Aggressively minimizes system RAM footprint by suspending background apps and unmapping heavy shell layers during intensive workloads."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                // Status Banner
                                Rectangle {
                                    width: parent.width
                                    height: 58
                                    radius: 12
                                    color: Island.ShellState.gameMode ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.16) : Island.Theme.glassCard
                                    border.color: Island.ShellState.gameMode ? Island.Theme.red : Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
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
                                            width: parent.width - 130
                                            spacing: 2
                                            Text {
                                                text: Island.ShellState.gameMode ? "Performance Mode Currently Active" : "Performance Mode Standby"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: Island.ShellState.gameMode ? (Island.ShellState.gameModeKilledCount + " background processes pruned.") : "Shielding Hyprland, Audio, and Protected Whitelist."
                                                font.pixelSize: 10
                                                color: Island.Theme.muted
                                            }
                                        }
                                    }
                                }

                                // Exceptions Whitelist Header
                                Text {
                                    text: "WHITELISTED APPLICATIONS"
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: Island.Theme.primary
                                }

                                Flow {
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: root.gameModeExceptions

                                        delegate: Rectangle {
                                            required property var modelData
                                            width: excText.implicitWidth + 36
                                            height: 28
                                            radius: 14
                                            color: Island.Theme.glassCardHover
                                            border.color: Island.Theme.glassBorderSubtle
                                            border.width: 1

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Text {
                                                    id: excText
                                                    text: modelData
                                                    font.pixelSize: 11
                                                    color: Island.Theme.foreground
                                                }

                                                Text {
                                                    text: "×"
                                                    font.pixelSize: 14
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
                                    height: 74
                                    radius: 12
                                    color: Island.ShellState && Island.ShellState.featherMode
                                        ? Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.16)
                                        : Island.Theme.glassCard
                                    border.color: Island.ShellState && Island.ShellState.featherMode
                                        ? Island.Theme.green
                                        : Island.Theme.glassBorderSubtle
                                    border.width: Island.ShellState && Island.ShellState.featherMode ? 1.5 : 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
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
                                                    width: 44
                                                    height: 16
                                                    radius: 8
                                                    color: Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.25)
                                                    border.color: Island.Theme.green
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "ECO"
                                                        font.pixelSize: 8
                                                        font.bold: true
                                                        font.family: Island.Theme.fontFamily
                                                        color: Island.Theme.green
                                                    }
                                                }
                                            }
                                            Text {
                                                text: Island.ShellState && Island.ShellState.featherMode
                                                    ? ("Active • " + Island.ShellState.featherKilledCount + " apps pruned • Bare-minimum Hyprland (0 animations, VFR)")
                                                    : "Prunes user bloat & drops Hyprland to bare minimum (0 animations, VFR, 15% brightness) so apps can start on demand."
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
