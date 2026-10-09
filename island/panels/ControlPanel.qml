import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import ".."
import "../components"

FocusScope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var player: (() => {
        const players = Mpris.players.values;
        for (let i = 0; i < players.length; ++i) {
            if (players[i] && players[i].isPlaying)
                return players[i];
        }
        return players.length > 0 ? players[0] : null;
    })()
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var wifiDevice: Networking.devices.values.find((device) => {
        return device.type === DeviceType.Wifi;
    }) || null
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values.slice().sort((left, right) => {
        if (left.connected !== right.connected)
            return left.connected ? -1 : 1;

        return right.signalStrength - left.signalStrength;
    }) : []
    readonly property var connectedWifi: wifiNetworks.find((network) => {
        return network.connected;
    }) || null
    readonly property var knownWifiNetworks: wifiNetworks.filter((network) => network.known)
    readonly property var availableWifiNetworks: wifiNetworks.filter((network) => !network.known)
    readonly property var audioSinks: Pipewire.nodes.values.filter((node) => {
        return node.isSink && !node.isStream && node.audio;
    }).slice().sort((left, right) => {
        if (sink && left.id === sink.id)
            return -1;

        if (sink && right.id === sink.id)
            return 1;

        return (left.description || left.nickname || left.name).localeCompare(right.description || right.nickname || right.name);
    })
    readonly property var audioSources: Pipewire.nodes.values.filter((node) => {
        return !node.isSink && !node.isStream && node.audio;
    }).slice().sort((left, right) => {
        if (source && left.id === source.id)
            return -1;

        if (source && right.id === source.id)
            return 1;

        return (left.description || left.nickname || left.name).localeCompare(right.description || right.nickname || right.name);
    })
    property var appAudioStreams: []
    property string audioOutputTab: "devices"

    Timer {
        id: streamCoalesceTimer
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            root.appAudioStreams = Pipewire.nodes.values.filter((node) => {
                return node.isStream && node.audio && !node.isSink;
            }).slice();
        }
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() {
            if (!streamCoalesceTimer.running)
                streamCoalesceTimer.start();
        }
    }
    readonly property var bluetoothDevices: adapter ? adapter.devices.values.filter((device) => {
        return device.name || device.deviceName;
    }).slice().sort((left, right) => {
        if (left.connected !== right.connected)
            return left.connected ? -1 : 1;

        if (left.paired !== right.paired)
            return left.paired ? -1 : 1;

        return (left.name || left.deviceName).localeCompare(right.name || right.deviceName);
    }) : []
    readonly property var knownBluetoothDevices: bluetoothDevices.filter((device) => device.paired || device.bonded)
    readonly property var availableBluetoothDevices: bluetoothDevices.filter((device) => !device.paired && !device.bonded)
    readonly property var connectedDevices: adapter ? adapter.devices.values.filter((device) => {
        return device.connected;
    }) : []
    readonly property real batteryLevel: UPower.displayDevice ? UPower.displayDevice.percentage : 0
    readonly property bool batteryCharging: UPower.displayDevice && (!UPower.onBattery || UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.PendingCharge)
    property string expandedSection: ""
    property string displayedSection: ""
    property var pendingWifiNetwork: null
    property string wifiError: ""
    property bool wifiRefreshPending: false
    readonly property real detailScrollFactor: 2

    function toggleSection(section) {
        const nextSection = expandedSection === section ? "" : section;
        if (expandedSection === "wifi" && nextSection !== "wifi")
            stopWifiScanner();

        if (expandedSection === "bluetooth" && nextSection !== "bluetooth")
            stopBluetoothDiscovery();

        expandedSection = nextSection;
        if (nextSection) {
            sectionCloseTimer.stop();
            displayedSection = nextSection;
        } else {
            sectionCloseTimer.restart();
        }
        pendingWifiNetwork = null;
        if (nextSection === "wifi")
            startWifiScanner();
        else if (nextSection === "bluetooth")
            startBluetoothDiscovery();
    }

    function closeDetails() {
        if (!expandedSection)
            return ;

        toggleSection(expandedSection);
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function toggleAudio() {
        if (source && source.audio)
            source.audio.muted = !source.audio.muted;
    }

    function toggleOutputAudio() {
        if (sink && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleBluetooth() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    function scrollDetailList(list, event) {
        const rawDelta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y * 0.6;
        const minimum = list.originY;
        const maximum = Math.max(minimum, minimum + list.contentHeight - list.height);
        list.contentY = Math.max(minimum, Math.min(maximum, list.contentY - rawDelta * detailScrollFactor));
        event.accepted = true;
    }

    function startWifiScanner() {
        wifiError = "";
        if (!wifiDevice || !Networking.wifiEnabled)
            return ;

        wifiDevice.scannerEnabled = true;
        wifiRefreshPending = true;
        wifiRefreshTimer.restart();
    }

    function restartWifiScanner() {
        if (!wifiDevice || !Networking.wifiEnabled || wifiRefreshPending)
            return ;

        wifiError = "";
        wifiRefreshPending = true;
        wifiDevice.scannerEnabled = false;
        Qt.callLater(() => {
            if (root.wifiDevice && root.expandedSection === "wifi" && Networking.wifiEnabled)
                root.wifiDevice.scannerEnabled = true;

            wifiRefreshTimer.restart();
        });
    }

    function stopWifiScanner() {
        wifiRefreshTimer.stop();
        wifiRefreshPending = false;
        if (wifiDevice && wifiDevice.scannerEnabled)
            wifiDevice.scannerEnabled = false;
    }

    function startBluetoothDiscovery() {
        if (!adapter || !adapter.enabled)
            return ;

        adapter.discovering = true;
        bluetoothScanTimer.restart();
    }

    function stopBluetoothDiscovery() {
        bluetoothScanTimer.stop();
        if (adapter && adapter.discovering)
            adapter.discovering = false;

    }

    function selectWifi(network) {
        if (!network || network.stateChanging)
            return ;

        if (network.connected) {
            network.disconnect();
            return ;
        }
        wifiError = "";
        if (!network.known && wifiUsesPsk(network.security)) {
            pendingWifiNetwork = network;
            Qt.callLater(() => {
                return wifiPasswordInput.forceActiveFocus(Qt.TabFocusReason);
            });
            return ;
        }
        network.connect();
    }

    function connectPendingWifi() {
        if (!pendingWifiNetwork || !wifiPasswordInput.text)
            return ;

        wifiError = "";
        pendingWifiNetwork.connectWithPsk(wifiPasswordInput.text);
        wifiPasswordInput.clear();
        pendingWifiNetwork = null;
    }

    function wifiUsesPsk(security) {
        return security === WifiSecurityType.WpaPsk || security === WifiSecurityType.Wpa2Psk || security === WifiSecurityType.Sae;
    }

    function wifiSecurityLabel(security) {
        switch (security) {
        case WifiSecurityType.Open:
            return "Open network";
        case WifiSecurityType.Sae:
            return "WPA3";
        case WifiSecurityType.Wpa2Psk:
            return "WPA2";
        case WifiSecurityType.WpaPsk:
            return "WPA";
        case WifiSecurityType.Owe:
            return "Enhanced Open";
        case WifiSecurityType.Wpa2Eap:
            return "WPA2 Enterprise";
        case WifiSecurityType.WpaEap:
            return "WPA Enterprise";
        case WifiSecurityType.Wpa3SuiteB192:
            return "WPA3 Enterprise";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "WEP";
        case WifiSecurityType.Leap:
            return "LEAP";
        default:
            return "Secured";
        }
    }

    function wifiConnectionFailed(network, reason) {
        if (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout)
            wifiError = "Authentication failed for " + network.name;
        else if (reason === ConnectionFailReason.WifiNetworkLost)
            wifiError = "Network lost while connecting";
        else
            wifiError = "Could not connect to " + network.name;
    }

    function activateBluetoothDevice(device) {
        if (device.connected) {
            device.disconnect();
        } else if (device.paired || device.bonded) {
            device.connect();
        } else {
            device.trusted = true;
            device.pair();
        }
    }

    function bluetoothIcon(device) {
        const iconName = (device.icon || "").toLowerCase();
        if (iconName.indexOf("head") >= 0 || iconName.indexOf("audio") >= 0)
            return "󰋋";

        if (iconName.indexOf("mouse") >= 0)
            return "󰍽";

        if (iconName.indexOf("keyboard") >= 0)
            return "󰌌";

        return "󰂯";
    }

    function wifiSignalPercent(signal) {
        const value = Number(signal);
        if (!Number.isFinite(value))
            return null;

        return Math.round(Math.max(0, Math.min(1, value)) * 100);
    }

    function wifiSignalIcon(signal) {
        const strength = Number(signal);
        if (!Number.isFinite(strength))
            return "󰤯";

        if (strength >= 0.7)
            return "󰤨";

        if (strength >= 0.4)
            return "󰤢";

        return "󰤟";
    }

    function formatDuration(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0)
            return "0:00";

        const minutes = Math.floor(seconds / 60);
        return minutes + ":" + String(Math.floor(seconds % 60)).padStart(2, "0");
    }

    implicitWidth: 492
    implicitHeight: content.implicitHeight
    onWifiDeviceChanged: {
        if (root.wifiDevice && root.expandedSection === "wifi")
            root.startWifiScanner();
    }
    Component.onDestruction: root.stopWifiScanner()
    Keys.onEscapePressed: (event) => {
        if (root.expandedSection) {
            root.closeDetails();
            event.accepted = true;
        }
    }

    PwObjectTracker {
        objects: root.audioSinks
    }

    PwObjectTracker {
        objects: root.audioSources
    }

    Timer {
        id: wifiRefreshTimer

        interval: 1000
        onTriggered: root.wifiRefreshPending = false
    }

    Timer {
        id: bluetoothScanTimer

        interval: 12000
        onTriggered: root.stopBluetoothDiscovery()
    }

    Timer {
        id: sectionCloseTimer

        interval: Theme.animationNormal
        onTriggered: {
            if (!root.expandedSection)
                root.displayedSection = "";
        }
    }

    Connections {
        function onWifiEnabledChanged() {
            if (Networking.wifiEnabled && root.expandedSection === "wifi")
                Qt.callLater(() => root.startWifiScanner());
            else if (!Networking.wifiEnabled)
                root.stopWifiScanner();
        }

        target: Networking
    }

    Connections {
        function onEnabledChanged() {
            if (root.adapter && root.adapter.enabled && root.expandedSection === "bluetooth")
                root.startBluetoothDiscovery();

        }

        target: root.adapter
    }

    Connections {
        function onPanelChanged() {
            if (ShellState.panel === "control")
                Backend.refreshQuickControls();

            if (ShellState.panel !== "control") {
                root.closeDetails();
                root.stopBluetoothDiscovery();
            }
        }

        target: ShellState
    }

    Timer {
        interval: 1000
        running: root.player && root.player.isPlaying
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Column {
        id: content

        width: parent.width
        spacing: 8

        Item {
            width: parent.width
            height: 32

            PanelHeader {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                title: "Control Center"
                showCloseButton: false
                onCloseRequested: ShellState.close()
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                icon: "󰒓"
                accessibleName: "Settings"
                onClicked: {
                    ShellState.openSettings("");
                }
            }
        }

        Row {
            id: systemActions

            width: parent.width
            height: 58
            spacing: 7

            ActionTile {
                id: audioTile

                width: (parent.width - 14) / 3
                icon: root.source && root.source.audio && root.source.audio.muted ? "󰍭" : "󰍬"
                title: "Input Audio"
                subtitle: root.source ? (root.source.description || root.source.nickname || "Default input") : "No input"
                active: root.source && root.source.audio && !root.source.audio.muted
                expandable: true
                expanded: root.expandedSection === "audio"
                detailAccessibleName: "Show audio inputs"
                onClicked: root.toggleAudio()
                onDetailClicked: root.toggleSection("audio")
            }

            ActionTile {
                id: bluetoothTile

                width: (parent.width - 14) / 3
                icon: "󰂯"
                title: "Bluetooth"
                subtitle: root.connectedDevices.length > 0 ? root.connectedDevices[0].name : (root.adapter && root.adapter.enabled ? "On" : "Off")
                active: root.adapter && root.adapter.enabled
                expandable: true
                expanded: root.expandedSection === "bluetooth"
                detailAccessibleName: "Show Bluetooth devices"
                onClicked: root.toggleBluetooth()
                onDetailClicked: root.toggleSection("bluetooth")
            }

            ActionTile {
                id: outputAudioTile

                width: (parent.width - 14) / 3
                icon: root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾"
                title: "Output Audio"
                subtitle: root.sink ? (root.sink.description || root.sink.nickname || "Default output") : "No output"
                active: root.sink && root.sink.audio && !root.sink.audio.muted
                expandable: true
                expanded: root.expandedSection === "output"
                detailAccessibleName: "Show audio outputs"
                onClicked: root.toggleOutputAudio()
                onDetailClicked: root.toggleSection("output")
            }

        }

        Rectangle {
            id: devicePicker

            parent: root
            readonly property bool audioMode: root.displayedSection === "audio" || root.displayedSection === "output"
            readonly property bool nightLightMode: root.displayedSection === "nightlight"
            readonly property bool compactMode: nightLightMode
            readonly property real availableHeight: root.height - y

            x: compactMode ? root.width - width : 0
            y: systemActions.y + systemActions.height + content.spacing
            z: 20
            width: compactMode ? 320 : root.width
            height: nightLightMode ? Math.min(92, availableHeight) : availableHeight
            radius: Theme.radius
            color: Theme.bg0
            clip: true
            enabled: root.expandedSection !== ""
            visible: opacity > 0
            opacity: root.expandedSection ? 1 : 0

            Rectangle {
                anchors.top: parent.top
                x: {
                    const sourceTile = root.displayedSection === "audio" ? audioTile : (root.displayedSection === "bluetooth" ? bluetoothTile : outputAudioTile);
                    const centeredX = sourceTile.x + sourceTile.width / 2 - devicePicker.x - width / 2;
                    return Math.max(Theme.radius, Math.min(parent.width - width - Theme.radius, centeredX));
                }
                width: 42
                height: 2
                radius: 1
                visible: devicePicker.compactMode
                color: Theme.primary
            }

            Item {
                id: pickerHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                height: 30

                Column {
                    anchors.left: parent.left
                    anchors.right: scanButton.visible ? scanButton.left : (powerButton.visible ? powerButton.left : parent.right)
                    anchors.rightMargin: scanButton.visible || powerButton.visible ? 8 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    ShellText {
                        width: parent.width
                        text: root.displayedSection === "wifi" ? "Wi-Fi networks" : (root.displayedSection === "audio" ? "Audio input" : (root.displayedSection === "output" ? "Audio output" : (root.displayedSection === "nightlight" ? ShellState.nightLightTemperature + " K" : "Bluetooth devices")))
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    ShellText {
                        width: parent.width
                        text: {
                            if (root.displayedSection === "wifi")
                                return root.wifiError || (root.wifiRefreshPending ? "Refreshing…" : root.wifiNetworks.length + " available");

                            if (root.displayedSection === "audio")
                                return root.audioSources.length + " available";

                            if (root.displayedSection === "output")
                                return root.audioSinks.length + " available";

                            if (root.displayedSection === "nightlight")
                                return "";

                            return root.adapter && root.adapter.discovering ? "Looking for devices…" : root.bluetoothDevices.length + " available";
                        }
                        color: root.wifiError && root.displayedSection === "wifi" ? Theme.red : Theme.muted
                        visible: text.length > 0
                        elide: Text.ElideRight
                        font.pixelSize: 10
                    }

                }

                IconButton {
                    id: powerButton

                    anchors.right: scanButton.visible ? scanButton.left : parent.right
                    anchors.rightMargin: scanButton.visible ? 5 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 25
                    visible: root.displayedSection === "audio" || root.displayedSection === "output" || root.displayedSection === "nightlight"
                    icon: root.displayedSection === "audio" ? (root.source && root.source.audio && root.source.audio.muted ? "󰍭" : "󰍬") : (root.displayedSection === "output" ? (root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾") : "󰐥")
                    accessibleName: {
                        if (root.displayedSection === "wifi")
                            return Networking.wifiEnabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on";

                        if (root.displayedSection === "audio")
                            return root.source && root.source.audio && root.source.audio.muted ? "Unmute microphone" : "Mute microphone";

                        if (root.displayedSection === "output")
                            return root.sink && root.sink.audio && root.sink.audio.muted ? "Unmute output" : "Mute output";

                        if (root.displayedSection === "nightlight")
                            return Backend.nightLightStatus === "on" ? "Turn Night Light off" : "Turn Night Light on";

                        return root.adapter && root.adapter.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on";
                    }
                    foregroundColor: {
                        if (root.displayedSection === "wifi")
                            return Networking.wifiEnabled ? Theme.primary : Theme.muted;

                        if (root.displayedSection === "audio")
                            return root.source && root.source.audio && !root.source.audio.muted ? Theme.primary : Theme.muted;

                        if (root.displayedSection === "output")
                            return root.sink && root.sink.audio && !root.sink.audio.muted ? Theme.primary : Theme.muted;

                        if (root.displayedSection === "nightlight")
                            return Backend.nightLightStatus === "on" ? Theme.primary : Theme.muted;

                        return root.adapter && root.adapter.enabled ? Theme.primary : Theme.muted;
                    }
                    onClicked: {
                        if (root.displayedSection === "wifi")
                            root.toggleWifi();
                        else if (root.displayedSection === "audio" && root.source && root.source.audio)
                            root.source.audio.muted = !root.source.audio.muted;
                        else if (root.displayedSection === "output" && root.sink && root.sink.audio)
                            root.sink.audio.muted = !root.sink.audio.muted;
                        else if (root.displayedSection === "nightlight")
                            Backend.toggleNightLight();
                        else if (root.adapter)
                            root.adapter.enabled = !root.adapter.enabled;
                    }
                }

                IconButton {
                    id: scanButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 25
                    visible: root.displayedSection === "wifi" || root.displayedSection === "bluetooth"
                    enabled: root.displayedSection === "wifi" ? Networking.wifiEnabled && root.wifiDevice && !root.wifiRefreshPending : root.adapter && root.adapter.enabled && !root.adapter.discovering
                    icon: "󰑐"
                    accessibleName: root.displayedSection === "wifi" ? "Scan for Wi-Fi networks" : "Scan for Bluetooth devices"
                    foregroundColor: enabled ? Theme.foreground : Theme.mutedDark
                    onClicked: {
                        if (root.displayedSection === "wifi")
                            root.restartWifiScanner();
                        else
                            root.startBluetoothDiscovery();
                    }
                }

            }

            StyledSlider {
                id: nightLightSlider

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 4
                visible: root.displayedSection === "nightlight"
                enabled: visible
                filled: true
                icon: "󰖔"
                accessibleName: "Night Light temperature"
                value: (ShellState.nightLightTemperature - 2500) / 3500
                onMoved: (value) => Backend.setNightLightTemperature(2500 + value * 3500)
            }

            StyledSlider {
                id: inputVolumeSlider

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 5
                visible: root.displayedSection === "audio"
                enabled: visible && root.source && root.source.audio
                filled: true
                icon: root.source && root.source.audio && root.source.audio.muted ? "󰍭" : "󰍬"
                accessibleName: "Input volume"
                value: root.source && root.source.audio ? root.source.audio.volume : 0
                valueText: Math.round(value * 100) + "%"
                onMoved: (value) => {
                    if (root.source && root.source.audio) {
                        root.source.audio.volume = value;
                        root.source.audio.muted = false;
                    }
                }
            }

            StyledSlider {
                id: outputVolumeSlider

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 5
                visible: root.displayedSection === "output"
                enabled: visible && root.sink && root.sink.audio
                filled: true
                icon: root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾"
                accessibleName: "Output volume"
                value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                valueText: Math.round(value * 100) + "%"
                onMoved: (value) => {
                    if (root.sink && root.sink.audio) {
                        root.sink.audio.volume = value;
                        root.sink.audio.muted = false;
                    }
                }
            }

            Row {
                id: wifiLists

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.bottom: wifiPasswordRow.top
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 5
                anchors.bottomMargin: wifiPasswordRow.height > 0 ? 5 : 0
                visible: root.displayedSection === "wifi"
                spacing: 4

                component WifiDelegate: ConnectionRow {
                    required property var modelData
                    readonly property var network: modelData

                    width: ListView.view.width
                    height: 42
                    icon: root.wifiSignalIcon(network.signalStrength)
                    title: network.name
                    subtitle: root.wifiSecurityLabel(network.security) + "  ·  " + root.wifiSignalPercent(network.signalStrength) + "%"
                    titleFontSize: 11
                    subtitleFontSize: 9
                    actionFontSize: 9
                    active: network.connected
                    busy: network.stateChanging
                    actionText: network.connected ? "Disconnect" : (!network.known && root.wifiUsesPsk(network.security) ? "Password" : "Connect")
                    secondaryActionVisible: network.known
                    secondaryActionName: "Forget " + network.name
                    onClicked: root.selectWifi(network)
                    onSecondaryClicked: {
                        if (root.pendingWifiNetwork === network) {
                            root.pendingWifiNetwork = null;
                            wifiPasswordInput.clear();
                        }
                        network.forget();
                    }

                    Connections {
                        function onConnectionFailed(reason) {
                            root.wifiConnectionFailed(network, reason);
                        }

                        function onConnectedChanged() {
                            if (network.connected) {
                                root.wifiError = "";
                                root.pendingWifiNetwork = null;
                                wifiPasswordInput.clear();
                            }
                        }

                        target: network
                    }
                }

                ListView {
                    id: knownWifiList

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    clip: true
                    spacing: 4
                    model: root.knownWifiNetworks
                    delegate: WifiDelegate {}

                    WheelHandler {
                        target: null
                        onWheel: (event) => root.scrollDetailList(knownWifiList, event)
                    }
                }

                ListView {
                    id: availableWifiList

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    clip: true
                    spacing: 4
                    model: root.availableWifiNetworks
                    delegate: WifiDelegate {}

                    WheelHandler {
                        target: null
                        onWheel: (event) => root.scrollDetailList(availableWifiList, event)
                    }
                }
            }

            Rectangle {
                id: wifiPasswordRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: pendingWifiNetwork ? 7 : 0
                height: pendingWifiNetwork ? 39 : 0
                visible: height > 0 && root.displayedSection === "wifi"
                radius: Theme.radiusSmall
                color: Theme.bg1
                border.width: wifiPasswordInput.activeFocus ? 1 : 0
                border.color: Theme.primary

                TextInput {
                    id: wifiPasswordInput

                    anchors.left: parent.left
                    anchors.right: wifiConnectButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    activeFocusOnTab: visible
                    Keys.onReturnPressed: root.connectPendingWifi()
                    Keys.onEnterPressed: root.connectPendingWifi()

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !parent.text
                        text: "Password for " + (root.pendingWifiNetwork ? root.pendingWifiNetwork.name : "network")
                        color: Theme.mutedDark
                        font.pixelSize: 9
                    }

                }

                FocusScope {
                    id: wifiConnectButton

                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 67
                    activeFocusOnTab: visible
                    Keys.onReturnPressed: root.connectPendingWifi()
                    Keys.onEnterPressed: root.connectPendingWifi()
                    Keys.onSpacePressed: root.connectPendingWifi()

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: Theme.primary
                    }

                    ShellText {
                        anchors.centerIn: parent
                        text: "Connect"
                        color: Theme.bgDim
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.connectPendingWifi()
                    }

                }

            }

            ListView {
                id: audioList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: inputVolumeSlider.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 7
                anchors.topMargin: 5
                visible: root.displayedSection === "audio"
                clip: true
                spacing: 4
                model: root.audioSources

                delegate: ConnectionRow {
                    required property var modelData
                    readonly property bool isDefault: root.source && modelData.id === root.source.id

                    width: audioList.width
                    height: 42
                    icon: "󰍬"
                    title: modelData.description || modelData.nickname || modelData.name
                    subtitle: modelData.nickname && modelData.nickname !== title ? modelData.nickname : "Audio input"
                    active: isDefault
                    actionText: isDefault ? "Selected" : "Select"
                    onClicked: Pipewire.preferredDefaultAudioSource = modelData
                }

            }

            Row {
                id: outputTabRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: outputVolumeSlider.bottom
                anchors.margins: 7
                anchors.topMargin: 4
                height: 26
                visible: root.displayedSection === "output"
                spacing: 6

                Rectangle {
                    width: (parent.width - 6) / 2
                    height: parent.height
                    radius: Theme.radiusSmall
                    color: root.audioOutputTab === "devices" ? Theme.primaryContainer : Theme.bg1

                    ShellText {
                        anchors.centerIn: parent
                        text: "Devices (" + root.audioSinks.length + ")"
                        font.pixelSize: 10
                        font.weight: root.audioOutputTab === "devices" ? Font.Bold : Font.Normal
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.audioOutputTab = "devices"
                    }
                }

                Rectangle {
                    width: (parent.width - 6) / 2
                    height: parent.height
                    radius: Theme.radiusSmall
                    color: root.audioOutputTab === "apps" ? Theme.primaryContainer : Theme.bg1

                    ShellText {
                        anchors.centerIn: parent
                        text: "App Streams (" + root.appAudioStreams.length + ")"
                        font.pixelSize: 10
                        font.weight: root.audioOutputTab === "apps" ? Font.Bold : Font.Normal
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.audioOutputTab = "apps";
                            streamCoalesceTimer.start();
                        }
                    }
                }
            }

            ListView {
                id: outputAudioList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: outputTabRow.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 7
                anchors.topMargin: 5
                visible: root.displayedSection === "output" && root.audioOutputTab === "devices"
                clip: true
                spacing: 4
                model: root.audioSinks

                delegate: ConnectionRow {
                    required property var modelData
                    readonly property bool isDefault: root.sink && modelData.id === root.sink.id

                    width: outputAudioList.width
                    height: 42
                    icon: "󰕾"
                    title: modelData.description || modelData.nickname || modelData.name
                    subtitle: modelData.nickname && modelData.nickname !== title ? modelData.nickname : "Audio output"
                    active: isDefault
                    actionText: isDefault ? "Selected" : "Select"
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }

            }

            ListView {
                id: appStreamList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: outputTabRow.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 7
                anchors.topMargin: 5
                visible: root.displayedSection === "output" && root.audioOutputTab === "apps"
                clip: true
                spacing: 6
                model: root.appAudioStreams

                delegate: Rectangle {
                    id: streamRow
                    required property var modelData
                    readonly property var audioObj: modelData.audio
                    readonly property string appName: modelData.description || modelData.name || "App Stream"

                    width: appStreamList.width
                    height: 48
                    radius: Theme.radiusSmall
                    color: Theme.bg1

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.topMargin: 5
                        height: 16

                        ShellText {
                            text: streamRow.appName
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.foreground
                            elide: Text.ElideRight
                            width: parent.width - 50
                        }

                        ShellText {
                            text: (streamRow.audioObj && streamRow.audioObj.muted) ? "Muted" : (Math.round((streamRow.audioObj ? streamRow.audioObj.volume : 0) * 100) + "%")
                            font.pixelSize: 10
                            color: Theme.muted
                            horizontalAlignment: Text.AlignRight
                            width: 50
                        }
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.bottomMargin: 6
                        height: 16

                        Rectangle {
                            id: streamRail
                            anchors.left: parent.left
                            anchors.right: streamMuteBtn.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            height: 6
                            radius: 3
                            color: Theme.bg2

                            Rectangle {
                                width: Math.max(0, Math.min(parent.width, parent.width * (streamRow.audioObj ? streamRow.audioObj.volume : 0)))
                                height: parent.height
                                radius: 3
                                color: (streamRow.audioObj && streamRow.audioObj.muted) ? Theme.muted : Theme.primary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (streamRow.audioObj) {
                                        streamRow.audioObj.volume = Math.max(0, Math.min(1.0, mouse.x / width));
                                        streamRow.audioObj.muted = false;
                                    }
                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed && streamRow.audioObj) {
                                        streamRow.audioObj.volume = Math.max(0, Math.min(1.0, mouse.x / width));
                                        streamRow.audioObj.muted = false;
                                    }
                                }
                            }
                        }

                        IconButton {
                            id: streamMuteBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            icon: (streamRow.audioObj && streamRow.audioObj.muted) ? "󰝟" : "󰕾"
                            foregroundColor: (streamRow.audioObj && streamRow.audioObj.muted) ? Theme.error : Theme.muted
                            onClicked: {
                                if (streamRow.audioObj) {
                                    streamRow.audioObj.muted = !streamRow.audioObj.muted;
                                }
                            }
                        }
                    }
                }
            }

            ShellText {
                anchors.centerIn: parent
                visible: root.displayedSection === "output" && root.audioOutputTab === "apps" && root.appAudioStreams.length === 0
                text: "No active application audio streams."
                color: Theme.muted
                font.pixelSize: 11
            }

            Row {
                id: bluetoothLists

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 7
                anchors.topMargin: 5
                anchors.bottomMargin: 0
                visible: root.displayedSection === "bluetooth"
                spacing: 4

                component BluetoothDelegate: ConnectionRow {
                    required property var modelData
                    readonly property var device: modelData

                    width: ListView.view.width
                    height: 42
                    icon: root.bluetoothIcon(device)
                    title: device.name || device.deviceName || device.address
                    subtitle: device.batteryAvailable ? "Battery " + Math.round(device.battery * 100) + "%" : (device.paired ? "Paired" : "Available")
                    titleFontSize: 11
                    subtitleFontSize: 9
                    actionFontSize: 9
                    active: device.connected
                    busy: device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting
                    actionText: device.connected ? "Disconnect" : (device.paired || device.bonded ? "Connect" : "Pair")
                    secondaryActionVisible: device.paired || device.bonded
                    secondaryActionName: "Remove " + (device.name || device.deviceName || device.address)
                    onClicked: root.activateBluetoothDevice(device)
                    onSecondaryClicked: device.forget()
                }

                ListView {
                    id: knownBluetoothList

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    clip: true
                    spacing: 4
                    model: root.knownBluetoothDevices
                    delegate: BluetoothDelegate {}

                    WheelHandler {
                        target: null
                        onWheel: (event) => root.scrollDetailList(knownBluetoothList, event)
                    }
                }

                ListView {
                    id: availableBluetoothList

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    clip: true
                    spacing: 4
                    model: root.availableBluetoothDevices
                    delegate: BluetoothDelegate {}

                    WheelHandler {
                        target: null
                        onWheel: (event) => root.scrollDetailList(availableBluetoothList, event)
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animationNormal
                    easing.type: Easing.OutCubic
                }

            }

        }

        StyledSlider {
            id: volumeSlider

            width: parent.width
            enabled: root.expandedSection === ""
            filled: true
            icon: root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾"
            accessibleName: "Volume"
            value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
            valueText: Math.round(value * 100) + "%"
            onMoved: (value) => {
                if (root.sink && root.sink.audio) {
                    root.sink.audio.volume = value;
                    root.sink.audio.muted = false;
                }
            }
        }

        StyledSlider {
            id: brightnessSlider

            width: parent.width
            enabled: root.expandedSection === ""
            filled: true
            icon: "󰃠"
            accessibleName: "Brightness"
            value: Backend.brightness / 100
            valueText: Math.round(value * 100) + "%"
            onMoved: (value) => {
                return Backend.setBrightness(value * 100);
            }
        }

        Row {
            id: mediaTransport

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            enabled: root.expandedSection === ""

            IconButton {
                width: 28
                height: 28
                anchors.verticalCenter: parent.verticalCenter
                icon: "\uf04ae"
                accessibleName: "Previous track"
                onClicked: {
                    if (root.player && root.player.canGoPrevious)
                        root.player.previous();

                }
            }

            IconButton {
                width: 42
                height: 42
                anchors.verticalCenter: parent.verticalCenter
                icon: root.player && root.player.isPlaying ? "\uf04c" : "\uf04b"
                accessibleName: root.player && root.player.isPlaying ? "Pause" : "Play"
                backgroundColor: Theme.foreground
                foregroundColor: Theme.bgDim
                onClicked: {
                    if (root.player && root.player.canTogglePlaying)
                        root.player.togglePlaying();

                }
            }

            IconButton {
                width: 28
                height: 28
                anchors.verticalCenter: parent.verticalCenter
                icon: "\uf04ad"
                accessibleName: "Next track"
                onClicked: {
                    if (root.player && root.player.canGoNext)
                        root.player.next();

                }
            }

        }

        Row {
            id: trayRow

            width: parent.width
            height: 31
            spacing: 5
            visible: trayRepeater.count > 0
            enabled: root.expandedSection === ""
            layoutDirection: Qt.RightToLeft

            Repeater {
                id: trayRepeater

                model: SystemTray.items

                delegate: IconButton {
                    required property var modelData

                    width: 26
                    height: 26
                    accessibleName: modelData.title || modelData.id
                    onClicked: modelData.activate()

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 16
                        source: modelData.icon
                    }

                }

            }

        }

        Grid {
            id: panelNavGrid

            width: parent.width
            columns: 5
            spacing: 6

            Repeater {
                model: [{
                    key: "clipboard",
                    label: "Clipboard"
                }, {
                    key: "todo",
                    label: "Todo"
                }, {
                    key: "notes",
                    label: "Notes"
                }, {
                    key: "capture",
                    label: "Capture"
                }, {
                    key: "shelf",
                    label: "Shelf"
                }, {
                    key: "notifications",
                    label: "Notifs"
                }, {
                    key: "timer",
                    label: "Timer"
                }, {
                    key: "weather",
                    label: "Weather"
                }, {
                    key: "theme",
                    label: "Theme"
                }, {
                    key: "settings",
                    label: "Settings"
                }]

                delegate: Rectangle {
                    required property var modelData

                    width: (panelNavGrid.width - panelNavGrid.spacing * 4) / 5
                    height: 30
                    radius: 15
                    color: navMouse.containsMouse ? Theme.primaryContainer : Theme.bg1

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animationFast
                        }
                    }

                    ShellText {
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: navMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.show(modelData.key)
                    }

                }

            }

        }

        Row {
            id: displayInfoRow
            width: parent.width
            spacing: 12
            visible: root.expandedSection === ""

            Repeater {
                model: Quickshell.screens
                delegate: ShellText {
                    required property var modelData
                    text: "󰍹 " + modelData.name + ": " + modelData.width + "×" + modelData.height
                    color: Theme.mutedDark
                    font.pixelSize: 10
                }
            }
        }

    }

}
