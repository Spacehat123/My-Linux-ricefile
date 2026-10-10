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

    property bool hoverLatching: false

    Timer {
        id: hoverGraceTimer
        interval: 400
        repeat: false
        onTriggered: {
            hoverLatching = false;
        }
    }

    function pingHover() {
        hoverLatching = true;
        hoverGraceTimer.stop();
    }

    function releaseHover() {
        hoverGraceTimer.restart();
    }

    readonly property bool hovered: (dockMouse && dockMouse.containsMouse)
        || (dockHover && dockHover.hovered)
        || hoverLatching
        || (activePopover !== "")
        || (wsHover && wsHover.containsMouse)
        || (netMouse && netMouse.containsMouse)
        || (volMouse && volMouse.containsMouse)
        || (batMouse && batMouse.containsMouse)

    readonly property var workspaceList: {
        const list = [];
        const activeId = (root.desktopState && root.desktopState.currentWorkspaceId > 0)
            ? root.desktopState.currentWorkspaceId
            : ((root.desktopModel && root.desktopModel.focusedWorkspaceId > 0) ? root.desktopModel.focusedWorkspaceId : 1);
        let maxId = 4;
        const existing = {};
        if (root.desktopModel && root.desktopModel.workspaces) {
            for (let i = 0; i < root.desktopModel.workspaces.length; ++i) {
                const w = root.desktopModel.workspaces[i];
                existing[w.id] = w;
                if (w.id > maxId) maxId = w.id;
            }
        }
        if (activeId > maxId) maxId = activeId;
        for (let id = 1; id <= maxId; ++id) {
            const item = existing[id];
            list.push({
                id: id,
                name: String(id),
                focused: id === activeId,
                occupied: item ? Boolean(item.occupied) : false
            });
        }
        return list;
    }

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
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: dockRow.implicitWidth + 30
            height: 38
            radius: 19
            color: Qt.tint("#07070a", Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.08))
            border.color: Island.Theme.glassBorder
            border.width: 1
            clip: false

            Behavior on color {
                ColorAnimation { duration: 300 }
            }

            HoverHandler {
                id: dockHover
                onHoveredChanged: {
                    if (hovered) pingHover();
                    else releaseHover();
                }
            }

            MouseArea {
                id: dockMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: pingHover()
                onExited: releaseHover()
            }

            // Covers the workspace dots for hover tracking continuity
            MouseArea {
                id: wsHover
                anchors.fill: wsRow
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: pingHover()
                onExited: releaseHover()
            }

            Row {
                id: dockRow
                anchors.centerIn: parent
                spacing: 12

                // 1. Minimalist Workspaces (• • • —)
                Row {
                    id: wsRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    Repeater {
                        model: root.workspaceList

                        delegate: Item {
                            id: wsSlot
                            required property var modelData
                            readonly property int wsId: modelData ? modelData.id : -1
                            readonly property bool isActive: modelData ? Boolean(modelData.focused) : false
                            readonly property bool isOccupied: modelData ? Boolean(modelData.occupied) : false

                            width: isActive ? 18 : 6
                            height: 22
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on width {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: wsSlot.isActive ? 18 : 6
                                height: 6
                                radius: 3
                                color: wsSlot.isActive ? Island.Theme.primary : (wsMouse.containsMouse ? Island.Theme.foreground : Island.Theme.muted)
                                opacity: wsSlot.isActive ? 1.0 : (wsMouse.containsMouse ? 0.8 : (wsSlot.isOccupied ? 0.55 : 0.3))

                                Behavior on width {
                                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: 120 }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }
                            }

                            MouseArea {
                                id: wsMouse
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "overview", "toggle"]);
                                        return;
                                    }
                                    if (root.interactionModel && wsSlot.wsId !== -1)
                                        root.interactionModel.requestWorkspaceSwitch(wsSlot.wsId);
                                    else
                                        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(wsSlot.wsId)]);
                                }
                            }
                        }
                    }
                }

                // Divider 1
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 18
                    color: Island.Theme.glassBorder
                    opacity: 0.6
                }

                // 2. Stacked Typographic Clock & Date
                Item {
                    id: clockItem
                    anchors.verticalCenter: parent.verticalCenter
                    width: clockCol.implicitWidth
                    height: clockCol.implicitHeight

                    Column {
                        id: clockCol
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(sysClock.date, "hh:mm")
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: Island.Theme.foreground
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(sysClock.date, "ddd d MMM").toUpperCase()
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.Medium
                            font.letterSpacing: 1.4
                            color: Island.Theme.muted
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "island", "panel", "today"])
                    }
                }

                // Divider 2
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 18
                    color: Island.Theme.glassBorder
                    opacity: 0.6
                }

                // 3. Status & Quick Actions Cluster
                // Weather
                Item {
                    id: weatherItem
                    anchors.verticalCenter: parent.verticalCenter
                    width: weatherRow.implicitWidth
                    height: weatherRow.implicitHeight

                    Row {
                        id: weatherRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "☁"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 12
                            color: weatherMouse.containsMouse ? Island.Theme.foreground : Island.Theme.muted
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (Island.WeatherState.tempC !== "" ? Island.WeatherState.tempC.replace("+", "").replace("C", "").trim() : "29°")
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: weatherMouse.containsMouse ? Island.Theme.foreground : Island.Theme.muted
                        }
                    }

                    MouseArea {
                        id: weatherMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "island", "panel", "weather"])
                    }
                }

                // PipeWire Audio Pill
                Item {
                    id: volPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: root.audioMuted ? "󰖁" : (root.sinkAudio && root.sinkAudio.volume > 0.5 ? "󰕾" : "󰖀")
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 14
                        color: root.audioMuted ? Island.Theme.red : ((volMouse.containsMouse || root.activePopover === "vol") ? Island.Theme.primary : Island.Theme.muted)
                    }

                    MouseArea {
                        id: volMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            popoverDismissTimer.stop();
                            root.activePopover = "vol";
                        }
                        onExited: {
                            popoverDismissTimer.restart();
                        }
                        onClicked: {
                            if (root.sinkAudio) root.sinkAudio.muted = !root.sinkAudio.muted;
                        }
                        onWheel: (wheel) => {
                            if (root.sinkAudio) {
                                const step = wheel.angleDelta.y > 0 ? 0.02 : -0.02;
                                root.sinkAudio.volume = Math.max(0.0, Math.min(1.5, root.sinkAudio.volume + step));
                            }
                        }
                    }
                }

                // Network Pill
                Item {
                    id: netPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: root.netIcon
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 14
                        color: (netMouse.containsMouse || root.activePopover === "net") ? Island.Theme.primary : Island.Theme.muted
                    }

                    MouseArea {
                        id: netMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            popoverDismissTimer.stop();
                            root.activePopover = "net";
                        }
                        onExited: {
                            popoverDismissTimer.restart();
                        }
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "island", "panel", "control"])
                    }
                }

                // Bluetooth
                Item {
                    id: btPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: "󰂯"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 14
                        color: btMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                    }

                    MouseArea {
                        id: btMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "island", "panel", "control"])
                    }
                }

                // UPower Battery Pill
                Item {
                    id: batPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(18, batLabel.implicitWidth)
                    height: 18
                    visible: root.batReady && root.batPct >= 0

                    Text {
                        id: batLabel
                        anchors.centerIn: parent
                        text: Math.round(root.batPct) + "%"
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: root.batPct <= 20
                            ? Island.Theme.red
                            : ((batMouse.containsMouse || root.activePopover === "bat") ? Island.Theme.primary : "#f5a97f")
                    }

                    MouseArea {
                        id: batMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            popoverDismissTimer.stop();
                            root.activePopover = "bat";
                        }
                        onExited: {
                            popoverDismissTimer.restart();
                        }
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "island", "panel", "power"])
                    }
                }

                // Notification Bell
                Item {
                    id: notifPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: "󰂚"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 14
                        color: notifMouse.containsMouse ? Island.Theme.foreground : Island.Theme.muted
                    }

                    Rectangle {
                        visible: Island.IslandHub.unreadCount > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 0
                        anchors.rightMargin: 0
                        width: 5
                        height: 5
                        radius: 2.5
                        color: Island.Theme.primary
                    }

                    MouseArea {
                        id: notifMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "island", "panel", "notifcenter"])
                    }
                }

                // Control Center / Quick Sliders
                Item {
                    id: controlPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: "󰅒"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 14
                        color: controlMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                    }

                    MouseArea {
                        id: controlMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "island", "panel", "control"])
                    }
                }

                // Display Switcher
                Item {
                    id: displayPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: "󰍹"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 14
                        color: displayMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                    }

                    MouseArea {
                        id: displayMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "control", "displays"])
                    }
                }

                // Screen Recording
                Item {
                    id: recPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: Island.Backend.recording ? "󰓛" : "󰕧"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 14
                        color: Island.Backend.recording ? Island.Theme.red : (recMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted)
                    }

                    MouseArea {
                        id: recMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "island", "panel", "capture"])
                    }
                }

                // Wallpaper
                Item {
                    id: wallPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: "󰸉"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 14
                        color: wallMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                    }

                    MouseArea {
                        id: wallMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "island", "panel", "wallpaper"])
                    }
                }

                // Clipboard
                Item {
                    id: clipPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: "󰅍"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 14
                        color: clipMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                    }

                    MouseArea {
                        id: clipMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "island", "panel", "clipboard"])
                    }
                }

                // App Launcher
                Item {
                    id: launcherPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: "󰀻"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 14
                        color: launcherMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                    }

                    MouseArea {
                        id: launcherMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "island", "panel", "launcher"])
                    }
                }

                // Settings
                Item {
                    id: settingsPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: "󰒓"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 14
                        color: settingsMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                    }

                    MouseArea {
                        id: settingsMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "settings", "toggle"])
                    }
                }

                // Power
                Item {
                    id: powerPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: "󰐥"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 14
                        color: powerMouse.containsMouse ? Island.Theme.red : Island.Theme.muted
                    }

                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "island", "panel", "power"])
                    }
                }

                // Red Recording Halo Dot
                Rectangle {
                    id: recHalo
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    radius: 6
                    color: Island.Backend.recording ? Island.Theme.red : "transparent"
                    border.color: Island.Backend.recording ? Qt.rgba(1, 0, 0, 0.4) : Island.Theme.glassBorderSubtle
                    border.width: 1.5

                    Rectangle {
                        anchors.centerIn: parent
                        width: 6
                        height: 6
                        radius: 3
                        color: Island.Backend.recording ? "#ffffff" : Island.Theme.muted
                        opacity: Island.Backend.recording ? 1.0 : 0.35
                    }

                    SequentialAnimation on scale {
                        running: Island.Backend.recording
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.25; duration: 600; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 0.95; duration: 600; easing.type: Easing.InOutQuad }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (Island.Backend.recording) {
                                Island.Backend.stopRecording();
                            } else {
                                Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "island", "panel", "capture"]);
                            }
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
            width: 240
            height: 96
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
                spacing: 8

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

                // Volume level
                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.audioMuted ? "Muted" : root.volText
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 16
                        font.bold: true
                        color: root.audioMuted ? Island.Theme.red : Island.Theme.primary
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.audioMuted ? "(Muted)" : ""
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 10
                        color: Island.Theme.red
                        visible: root.audioMuted
                    }
                }

                // Volume level gauge
                Rectangle {
                    width: parent.width
                    height: 8
                    radius: 4
                    color: "#20ffffff"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * (root.sinkAudio ? Math.max(0.0, Math.min(1.0, root.sinkAudio.volume)) : 0.0)
                        radius: 4
                        color: root.audioMuted ? Island.Theme.muted : Island.Theme.primary
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
            width: 240
            height: 96
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
                spacing: 8

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

                // SSID / Network Name & Signal Badge
                Rectangle {
                    width: parent.width
                    height: 38
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
                            font.pixelSize: 12
                            font.bold: true
                            color: Island.Theme.foreground
                            elide: Text.ElideRight
                            width: parent.width - 55
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
            height: 96
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
                spacing: 8

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
                        font.pixelSize: 16
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
                    height: 8
                    radius: 4
                    color: "#20ffffff"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * Math.max(0.0, Math.min(1.0, root.batPct / 100.0))
                        radius: 4
                        color: root.batPct <= 20 ? Island.Theme.red : (batPopover.isCharging ? Island.Theme.green : Island.Theme.primary)
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
            pingHover();
            hoverGraceTimer.restart();
            closeAnim.stop();
            openAnim.start();
        } else {
            hoverLatching = false;
            openAnim.stop();
            closeAnim.start();
        }
    }
}