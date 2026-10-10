import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import "../island" as Island

PanelWindow {
    id: root

    property bool open: false
    visible: open || closeAnim.running

    // Injected models (wired in shell.qml)
    property var desktopModel: null
    property var interactionModel: null
    property var desktopState: null

    // Hover continuity & Popover system
    property string activePopover: "" // "", "net", "vol", "bat"

    readonly property var activePopoverItem: {
        if (activePopover === "net") return netPopover;
        if (activePopover === "vol") return volPopover;
        if (activePopover === "bat") return batPopover;
        return null;
    }

    Timer {
        id: popoverDismissTimer
        interval: 280
        repeat: false
        onTriggered: {
            activePopover = "";
        }
    }

    readonly property bool hovered: (dockMouse && dockMouse.containsMouse)
        || (activePopover !== "")
        || (wsHover && wsHover.containsMouse)
        || (netMouse && netMouse.containsMouse)
        || (volMouse && volMouse.containsMouse)
        || (batMouse && batMouse.containsMouse)

    anchors {
        bottom: true
    }
    margins {
        bottom: 10
    }

    implicitWidth: Math.min(980, (screen ? screen.width : 1040) - 40)
    implicitHeight: 220
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    WlrLayershell.namespace: "pranc-shell"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        Region {
            item: dockBody
            topLeftRadius: dockBody ? dockBody.radius : 0
            topRightRadius: dockBody ? dockBody.radius : 0
            bottomLeftRadius: dockBody ? dockBody.radius : 0
            bottomRightRadius: dockBody ? dockBody.radius : 0
        }

        Region {
            item: activePopoverItem
            topLeftRadius: activePopoverItem ? activePopoverItem.radius : 0
            topRightRadius: activePopoverItem ? activePopoverItem.radius : 0
            bottomLeftRadius: activePopoverItem ? activePopoverItem.radius : 0
            bottomRightRadius: activePopoverItem ? activePopoverItem.radius : 0
        }

        Region {
            item: popoverHoverBridge
        }
    }

    // ---- Live system state ----
    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    // Native PipeWire sink audio binding (zero process forks)
    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property bool audioMuted: sinkAudio ? sinkAudio.muted : false
    readonly property string volText: sinkAudio ? Math.round(sinkAudio.volume * 100) + "%" : "--"

    property var bat: UPower.displayDevice
    property bool batReady: bat ? bat.ready : false
    property real batPct: batReady ? (bat.percentage * 100.0) : -1

    function batteryIcon(p) {
        if (p >= 80) return "";
        if (p >= 60) return "";
        if (p >= 40) return "";
        if (p >= 20) return "";
        return "";
    }

    // Network: native NetworkManager / D-Bus properties via Quickshell.Networking (zero process forks/polling)
    readonly property var wifiDevice: Networking.devices.values.find((device) => device.type === DeviceType.Wifi) || null
    readonly property var connectedWifi: {
        if (!wifiDevice)
            return null;
        if (wifiDevice.networks) {
            const found = wifiDevice.networks.values.find((network) => network.connected);
            if (found)
                return found;
        }
        return wifiDevice.connected ? wifiDevice : null;
    }
    readonly property var ethernetDevice: Networking.devices.values.find((device) => {
        return device.type === DeviceType.Wired && (device.connected || device.hasLink === true);
    }) || null

    readonly property string netIcon: {
        if (connectedWifi)
            return "";
        if (ethernetDevice)
            return "";
        const anyConnected = Networking.devices.values.find((device) => device.connected);
        if (anyConnected)
            return anyConnected.type === DeviceType.Wifi ? "" : "";
        return "";
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0.0

        transform: Translate {
            id: contentTranslate
            y: 16
        }

        // =====================================================================
        // FLOATING LIQUID GLASS DOCK CAPSULE
        // =====================================================================
        Rectangle {
            id: dockBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 44
            radius: 22
            color: Qt.tint("#07070a", Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.08))
            border.color: Island.Theme.glassBorder
            border.width: Island.Theme.glassBorderWidth
            clip: true

            Behavior on color {
                ColorAnimation { duration: 300 }
            }

            MouseArea {
                id: dockMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            // Covers the workspace Repeater for hover tracking continuity
            MouseArea {
                id: wsHover
                anchors.fill: wsRow
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            // ---- Left: Liquid Workspace Capsules ----
            Row {
                id: wsRow
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: root.desktopModel && root.desktopModel.workspaces ? root.desktopModel.workspaces : []

                    delegate: Rectangle {
                        id: wsBtn
                        required property var modelData

                        readonly property int wsId: modelData ? modelData.id : -1
                        readonly property bool isActive: modelData ? Boolean(modelData.focused) : false
                        readonly property bool isOccupied: modelData ? (Boolean(modelData.occupied) || (modelData.surfaceCount && modelData.surfaceCount > 0)) : false
                        readonly property string wsLabel: modelData ? (modelData.name || String(modelData.id)) : ""

                        height: 28
                        width: isActive ? Math.max(46, wsLabelText.implicitWidth + 24) : (isOccupied ? 30 : 22)
                        radius: 14

                        Behavior on width {
                            SpringAnimation {
                                spring: 4.2
                                damping: 0.35
                                epsilon: 0.5
                            }
                        }

                        color: wsMouse.containsMouse
                            ? Island.Theme.glassCardHover
                            : (isActive
                                ? Island.Theme.glassCardHover
                                : (isOccupied ? Island.Theme.glassCard : "transparent"))

                        border.color: isActive
                            ? Island.Theme.primary
                            : (wsMouse.containsMouse ? Island.Theme.glassBorder : (isOccupied ? Island.Theme.glassBorderSubtle : "transparent"))
                        border.width: 1

                        scale: wsMouse.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80 } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            // Small occupied dot indicator if not active but occupied
                            Rectangle {
                                visible: !wsBtn.isActive && wsBtn.isOccupied
                                anchors.verticalCenter: parent.verticalCenter
                                width: 4
                                height: 4
                                radius: 2
                                color: Island.Theme.muted
                            }

                            Text {
                                id: wsLabelText
                                anchors.verticalCenter: parent.verticalCenter
                                text: wsBtn.wsLabel
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: wsBtn.isActive || wsMouse.containsMouse
                                color: wsBtn.isActive ? Island.Theme.primary : (wsMouse.containsMouse ? Island.Theme.foreground : (wsBtn.isOccupied ? Island.Theme.foreground : Island.Theme.muted))
                            }
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "overview", "toggle"]);
                                    return;
                                }
                                if (root.interactionModel && wsBtn.wsId !== -1)
                                    root.interactionModel.requestWorkspaceSwitch(wsBtn.wsId);
                            }
                        }
                    }
                }

                Rectangle {
                    id: overviewBtn
                    height: 28
                    width: 28
                    radius: 14
                    color: overviewMouse.containsMouse ? Island.Theme.glassCardHover : "transparent"
                    border.color: overviewMouse.containsMouse ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰕰"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 13
                        color: overviewMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                    }

                    MouseArea {
                        id: overviewMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "overview", "toggle"]);
                        }
                    }
                }
            }

            // ---- Center: Typographic Clock & Date ----
            Column {
                id: clockBlock
                anchors.centerIn: parent
                spacing: 1

                Text {
                    id: timeText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(sysClock.date, "hh:mm")
                    font.family: Island.Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: Island.Theme.foreground
                }

                Text {
                    id: dateText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(sysClock.date, "ddd, dd MMM")
                    font.family: Island.Theme.fontFamily
                    font.pixelSize: 9
                    color: Island.Theme.muted
                }
            }

            // ---- Right: System Status Module Cluster ----
            Row {
                id: sysRow
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Network Pill
                Rectangle {
                    id: netPill
                    height: 28
                    width: Math.max(34, netRow.implicitWidth + 16)
                    radius: 14
                    color: (netMouse.containsMouse || root.activePopover === "net") ? Island.Theme.glassCardHover : Island.Theme.glassCard
                    border.color: (netMouse.containsMouse || root.activePopover === "net") ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                    border.width: 1
                    scale: netMouse.pressed ? 0.95 : 1.0

                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: netRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.netIcon
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: (netMouse.containsMouse || root.activePopover === "net") ? Island.Theme.primary : Island.Theme.foreground
                        }
                    }

                    MouseArea {
                        id: netMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            popoverDismissTimer.stop();
                            root.activePopover = "net";
                        }
                        onExited: {
                            popoverDismissTimer.restart();
                        }
                    }
                }

                // PipeWire Audio Pill
                Rectangle {
                    id: volPill
                    height: 28
                    width: Math.max(54, volRow.implicitWidth + 18)
                    radius: 14
                    color: (volMouse.containsMouse || root.activePopover === "vol") ? Island.Theme.glassCardHover : Island.Theme.glassCard
                    border.color: (volMouse.containsMouse || root.activePopover === "vol") ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                    border.width: 1
                    scale: volMouse.pressed ? 0.95 : 1.0

                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: volRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.audioMuted ? "󰖁" : (root.sinkAudio && root.sinkAudio.volume > 0.5 ? "󰕾" : "󰖀")
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: root.audioMuted ? Island.Theme.red : ((volMouse.containsMouse || root.activePopover === "vol") ? Island.Theme.primary : Island.Theme.foreground)
                        }

                        Text {
                            id: volLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.audioMuted ? "Mute" : root.volText
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: (volMouse.containsMouse || root.activePopover === "vol") ? Island.Theme.primary : Island.Theme.foreground
                        }
                    }

                    MouseArea {
                        id: volMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            popoverDismissTimer.stop();
                            root.activePopover = "vol";
                        }
                        onExited: {
                            popoverDismissTimer.restart();
                        }
                        onClicked: Quickshell.execDetached(["pavucontrol"])
                        onWheel: (wheel) => {
                            if (root.sinkAudio) {
                                const step = wheel.angleDelta.y > 0 ? 0.02 : -0.02;
                                root.sinkAudio.volume = Math.max(0.0, Math.min(1.5, root.sinkAudio.volume + step));
                            }
                        }
                    }
                }

                // UPower Battery Pill
                Rectangle {
                    id: batPill
                    visible: root.batReady && root.batPct >= 0
                    height: 28
                    width: Math.max(56, batRow.implicitWidth + 18)
                    radius: 14
                    color: (batMouse.containsMouse || root.activePopover === "bat") ? Island.Theme.glassCardHover : Island.Theme.glassCard
                    border.color: (batMouse.containsMouse || root.activePopover === "bat") ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                    border.width: 1

                    Row {
                        id: batRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.batteryIcon(root.batPct)
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: root.batPct <= 20 ? Island.Theme.red : ((batMouse.containsMouse || root.activePopover === "bat") ? Island.Theme.primary : Island.Theme.foreground)
                        }

                        Text {
                            id: batLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(root.batPct) + "%"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: (batMouse.containsMouse || root.activePopover === "bat") ? Island.Theme.primary : Island.Theme.foreground
                        }
                    }

                    MouseArea {
                        id: batMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            popoverDismissTimer.stop();
                            root.activePopover = "bat";
                        }
                        onExited: {
                            popoverDismissTimer.restart();
                        }
                    }
                }
            }
        }

        // =====================================================================
        // HOVER BRIDGE (Bridges the 8px vertical gap between dockBody & popovers)
        // =====================================================================
        Item {
            id: popoverHoverBridge
            visible: activePopover !== ""
            x: activePopoverItem ? activePopoverItem.x : 0
            y: activePopoverItem ? (activePopoverItem.y + activePopoverItem.height) : 0
            width: activePopoverItem ? activePopoverItem.width : 0
            height: activePopoverItem ? Math.max(0, dockBody.y - (activePopoverItem.y + activePopoverItem.height)) : 0

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: popoverDismissTimer.stop()
                onExited: popoverDismissTimer.restart()
            }
        }

        // =====================================================================
        // STATUS POPOVER 1: VOLUME & AUDIO OUTPUT WIDGET
        // =====================================================================
        Rectangle {
            id: volPopover
            visible: opacity > 0.001
            opacity: activePopover === "vol" ? 1.0 : 0.0
            radius: 16
            width: 250
            height: 145
            anchors.bottom: dockBody.top
            anchors.bottomMargin: 8
            x: {
                if (!volPill) return parent.width - width - 10;
                const pos = volPill.mapToItem(content, 0, 0);
                return Math.max(10, Math.min(parent.width - width - 10, pos.x + (volPill.width - width) / 2));
            }
            color: Qt.tint("#0b0c10", Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.08))
            border.color: Island.Theme.glassBorder
            border.width: 1
            clip: true

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: popoverDismissTimer.stop()
                onExited: popoverDismissTimer.restart()
            }

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header
                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.audioMuted ? "󰖁" : "󰕾"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 15
                        color: root.audioMuted ? Island.Theme.red : Island.Theme.primary
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24

                        Text {
                            text: "Audio Output"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: Island.Theme.foreground
                        }

                        Text {
                            text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.description ? Pipewire.defaultAudioSink.description : "Default Sink"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 9
                            color: Island.Theme.muted
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }

                // Volume level & Mute toggle row
                Item {
                    width: parent.width
                    height: 28

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.audioMuted ? "Muted" : root.volText
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 18
                        font.bold: true
                        color: root.audioMuted ? Island.Theme.red : Island.Theme.primary
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        height: 24
                        width: 72
                        radius: 12
                        color: root.audioMuted ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.22) : (muteBtnMouse.containsMouse ? Island.Theme.glassCardHover : Island.Theme.glassCard)
                        border.color: root.audioMuted ? Island.Theme.red : Island.Theme.glassBorderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.audioMuted ? "Unmute" : "Mute"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.audioMuted ? Island.Theme.red : Island.Theme.foreground
                        }

                        MouseArea {
                            id: muteBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.sinkAudio) root.sinkAudio.muted = !root.sinkAudio.muted;
                            }
                        }
                    }
                }

                // Custom fluid volume slider
                Rectangle {
                    id: volSliderTrack
                    width: parent.width
                    height: 14
                    radius: 7
                    color: "#20ffffff"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * (root.sinkAudio ? Math.max(0.0, Math.min(1.0, root.sinkAudio.volume)) : 0.0)
                        radius: 7
                        color: root.audioMuted ? Island.Theme.muted : Island.Theme.primary
                    }

                    Rectangle {
                        x: Math.max(0, Math.min(parent.width - width, (parent.width * (root.sinkAudio ? root.sinkAudio.volume : 0.0)) - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        radius: 6
                        color: "#ffffff"
                        visible: root.sinkAudio !== null
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (mouse) => {
                            if (root.sinkAudio) {
                                root.sinkAudio.volume = Math.max(0.0, Math.min(1.0, mouse.x / width));
                            }
                        }
                        onPositionChanged: (mouse) => {
                            if (pressed && root.sinkAudio) {
                                root.sinkAudio.volume = Math.max(0.0, Math.min(1.0, mouse.x / width));
                            }
                        }
                    }
                }

                // Footer: Pavucontrol quick link
                Row {
                    width: parent.width
                    spacing: 6

                    Rectangle {
                        height: 22
                        width: parent.width
                        radius: 11
                        color: mixerBtnMouse.containsMouse ? Island.Theme.glassCardHover : "transparent"
                        border.color: mixerBtnMouse.containsMouse ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰘵  Open Audio Mixer (Pavucontrol)"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 10
                            color: mixerBtnMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                        }

                        MouseArea {
                            id: mixerBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["pavucontrol"])
                        }
                    }
                }
            }
        }

        // =====================================================================
        // STATUS POPOVER 2: WI-FI & NETWORK CONNECTIVITY WIDGET
        // =====================================================================
        Rectangle {
            id: netPopover
            visible: opacity > 0.001
            opacity: activePopover === "net" ? 1.0 : 0.0
            radius: 16
            width: 260
            height: 145
            anchors.bottom: dockBody.top
            anchors.bottomMargin: 8
            x: {
                if (!netPill) return parent.width - width - 10;
                const pos = netPill.mapToItem(content, 0, 0);
                return Math.max(10, Math.min(parent.width - width - 10, pos.x + (netPill.width - width) / 2));
            }
            color: Qt.tint("#0b0c10", Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.08))
            border.color: Island.Theme.glassBorder
            border.width: 1
            clip: true

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: popoverDismissTimer.stop()
                onExited: popoverDismissTimer.restart()
            }

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header
                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.netIcon
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 15
                        color: Island.Theme.primary
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24

                        Text {
                            text: "Network Connectivity"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: Island.Theme.foreground
                        }

                        Text {
                            text: root.connectedWifi ? "Wi-Fi Wireless Connection" : (root.ethernetDevice ? "Wired Ethernet Connection" : "Offline")
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 9
                            color: Island.Theme.muted
                        }
                    }
                }

                // SSID / Network Name
                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 10
                    color: Island.Theme.glassCard
                    border.color: Island.Theme.glassBorderSubtle
                    border.width: 1

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.connectedWifi ? (root.connectedWifi.ssid || "Connected Network") : (root.ethernetDevice ? "Ethernet Link" : "No Network")
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Island.Theme.foreground
                            elide: Text.ElideRight
                            width: parent.width - 60
                        }

                        // Signal or status indicator badge
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            height: 20
                            width: 48
                            radius: 10
                            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.2)

                            Text {
                                anchors.centerIn: parent
                                text: root.connectedWifi ? (Math.round((root.connectedWifi.signalStrength || 0.8) * 100) + "%") : (root.ethernetDevice ? "Active" : "Down")
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: Island.Theme.primary
                            }
                        }
                    }
                }

                // Quick Action: Open Settings
                Rectangle {
                    height: 24
                    width: parent.width
                    radius: 12
                    color: netSettingsMouse.containsMouse ? Island.Theme.glassCardHover : "transparent"
                    border.color: netSettingsMouse.containsMouse ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰤨  Open Network Settings"
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 10
                        color: netSettingsMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                    }

                    MouseArea {
                        id: netSettingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Island.ShellState.openSettings("network")
                    }
                }
            }
        }

        // =====================================================================
        // STATUS POPOVER 3: POWER & BATTERY TELEMETRY WIDGET
        // =====================================================================
        Rectangle {
            id: batPopover
            visible: opacity > 0.001
            opacity: activePopover === "bat" ? 1.0 : 0.0
            radius: 16
            width: 240
            height: 140
            anchors.bottom: dockBody.top
            anchors.bottomMargin: 8
            x: {
                if (!batPill) return parent.width - width - 10;
                const pos = batPill.mapToItem(content, 0, 0);
                return Math.max(10, Math.min(parent.width - width - 10, pos.x + (batPill.width - width) / 2));
            }
            color: Qt.tint("#0b0c10", Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.08))
            border.color: Island.Theme.glassBorder
            border.width: 1
            clip: true

            readonly property bool isCharging: root.bat ? (!UPower.onBattery || root.bat.state === 1) : false

            function formatTime(sec) {
                if (!sec || sec <= 0) return "";
                const h = Math.floor(sec / 3600);
                const m = Math.floor((sec % 3600) / 60);
                if (h > 0) return h + "h " + m + "m";
                return m + "m";
            }

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: popoverDismissTimer.stop()
                onExited: popoverDismissTimer.restart()
            }

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header
                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.batteryIcon(root.batPct)
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 15
                        color: root.batPct <= 20 ? Island.Theme.red : Island.Theme.primary
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24

                        Text {
                            text: "Power & Battery"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: Island.Theme.foreground
                        }

                        Text {
                            text: batPopover.isCharging ? "Charging on AC Power" : "Running on Battery"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 9
                            color: Island.Theme.muted
                        }
                    }
                }

                // Battery Level & Progress Gauge
                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.batPct) + "%"
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 18
                        font.bold: true
                        color: root.batPct <= 20 ? Island.Theme.red : Island.Theme.foreground
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (batPopover.isCharging) {
                                return root.bat && root.bat.timeToFull > 0 ? (batPopover.formatTime(root.bat.timeToFull) + " to full") : "Charging";
                            }
                            return root.bat && root.bat.timeToEmpty > 0 ? (batPopover.formatTime(root.bat.timeToEmpty) + " remaining") : "Discharging";
                        }
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 10
                        color: Island.Theme.muted
                    }
                }

                // Gauge Bar
                Rectangle {
                    width: parent.width
                    height: 10
                    radius: 5
                    color: "#20ffffff"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * Math.max(0.0, Math.min(1.0, root.batPct / 100.0))
                        radius: 5
                        color: root.batPct <= 20 ? Island.Theme.red : (batPopover.isCharging ? Island.Theme.green : Island.Theme.primary)
                    }
                }

                // Quick Action: Power Settings
                Rectangle {
                    height: 22
                    width: parent.width
                    radius: 11
                    color: batSettingsMouse.containsMouse ? Island.Theme.glassCardHover : "transparent"
                    border.color: batSettingsMouse.containsMouse ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰁹  Open Power Settings"
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 10
                        color: batSettingsMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                    }

                    MouseArea {
                        id: batSettingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Island.ShellState.openSettings("power")
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: contentTranslate
            property: "y"
            to: 0
            duration: 240
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 1.0
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: contentTranslate
            property: "y"
            to: 16
            duration: 160
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 0.0
            duration: 160
            easing.type: Easing.InCubic
        }
    }

    onOpenChanged: {
        if (open) {
            closeAnim.stop();
            openAnim.start();
        } else {
            openAnim.stop();
            closeAnim.start();
        }
    }
}