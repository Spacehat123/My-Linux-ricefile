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

    // Navigation Tab state: 0 = Glance, 1 = Spaces, 2 = System
    property int currentTab: 0

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

    // Hardware Telemetry (CPU & RAM) - only polled when on System tab and open
    property real memUsedGb: 0.0
    property real memTotalGb: 0.0
    property int memPct: 0
    property int cpuPct: 0
    property var prevCpuIdle: 0
    property var prevCpuTotal: 0

    Process {
        id: sysStatsProc
        command: [
            "sh", "-c",
            "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.2f %.2f %d\\n\", (t-a)/1048576, t/1048576, int((t-a)*100/t)}' /proc/meminfo; awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line || line.trim() === "") return;
                const parts = line.trim().split(" ");
                if (parts.length === 3) {
                    root.memUsedGb = parseFloat(parts[0]);
                    root.memTotalGb = parseFloat(parts[1]);
                    root.memPct = parseInt(parts[2]);
                } else if (parts.length === 2) {
                    const total = parseInt(parts[0]);
                    const idle = parseInt(parts[1]);
                    if (root.prevCpuTotal > 0) {
                        const totalDiff = total - root.prevCpuTotal;
                        const idleDiff = idle - root.prevCpuIdle;
                        if (totalDiff > 0) {
                            root.cpuPct = Math.max(0, Math.min(100, Math.round((1 - idleDiff / totalDiff) * 100)));
                        }
                    }
                    root.prevCpuTotal = total;
                    root.prevCpuIdle = idle;
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
        Rectangle {
            anchors.fill: parent
            radius: 24
            color: Qt.tint("#07070a", Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.08))
            border.color: Island.Theme.glassBorder
            border.width: 1
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // =============================================================
                // 1. TOP HEADER & CLOSE BUTTON
                // =============================================================
                Item {
                    width: parent.width
                    height: 40

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: Island.Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            spacing: 1
                            Text {
                                text: "NEXUS HUB"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                font.letterSpacing: 1.2
                                color: Island.Theme.foreground
                            }
                            Text {
                                text: Qt.formatDateTime(new Date(), "ddd d MMM") + (Island.WeatherState.tempC !== "" ? (" • " + Island.WeatherState.tempC) : "")
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                color: Island.Theme.muted
                            }
                        }
                    }

                    // Close Button
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        color: closeBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: Island.Theme.glassBorderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 11
                            color: closeBtnMouse.containsMouse ? Island.Theme.foreground : Island.Theme.muted
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

                // =============================================================
                // 2. SEGMENTED TAB SWITCHER PILL BAR
                // =============================================================
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: 18
                    color: Qt.rgba(0, 0, 0, 0.35)
                    border.color: Island.Theme.glassBorderSubtle
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 3

                        // Tab 0: Glance
                        Rectangle {
                            width: (parent.width - 6) / 3
                            height: parent.height
                            radius: 15
                            color: root.currentTab === 0 ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25) : (tab0Mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            border.color: root.currentTab === 0 ? Island.Theme.primary : "transparent"
                            border.width: root.currentTab === 0 ? 1 : 0

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "󰸗"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 12
                                    color: root.currentTab === 0 ? Island.Theme.primary : (tab0Mouse.containsMouse ? Island.Theme.foreground : Island.Theme.muted)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Glance"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: root.currentTab === 0
                                    color: root.currentTab === 0 ? Island.Theme.foreground : (tab0Mouse.containsMouse ? Island.Theme.foreground : Island.Theme.muted)
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

                        // Tab 1: Spaces
                        Rectangle {
                            width: (parent.width - 6) / 3
                            height: parent.height
                            radius: 15
                            color: root.currentTab === 1 ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25) : (tab1Mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            border.color: root.currentTab === 1 ? Island.Theme.primary : "transparent"
                            border.width: root.currentTab === 1 ? 1 : 0

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "󰕰"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 12
                                    color: root.currentTab === 1 ? Island.Theme.primary : (tab1Mouse.containsMouse ? Island.Theme.foreground : Island.Theme.muted)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Spaces"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: root.currentTab === 1
                                    color: root.currentTab === 1 ? Island.Theme.foreground : (tab1Mouse.containsMouse ? Island.Theme.foreground : Island.Theme.muted)
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

                        // Tab 2: System
                        Rectangle {
                            width: (parent.width - 6) / 3
                            height: parent.height
                            radius: 15
                            color: root.currentTab === 2 ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25) : (tab2Mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            border.color: root.currentTab === 2 ? Island.Theme.primary : "transparent"
                            border.width: root.currentTab === 2 ? 1 : 0

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "󰍛"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 12
                                    color: root.currentTab === 2 ? Island.Theme.primary : (tab2Mouse.containsMouse ? Island.Theme.foreground : Island.Theme.muted)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "System"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: root.currentTab === 2
                                    color: root.currentTab === 2 ? Island.Theme.foreground : (tab2Mouse.containsMouse ? Island.Theme.foreground : Island.Theme.muted)
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
                    // DECK 1: SPACES & WINDOW HUB
                    // ---------------------------------------------------------
                    Flickable {
                        id: spacesDeck
                        anchors.fill: parent
                        visible: root.currentTab === 1
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
                                height: 50
                                radius: 14
                                color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.12)
                                border.color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.35)
                                border.width: 1

                                Item {
                                    anchors.fill: parent
                                    anchors.margins: 12

                                    Column {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            text: (root.activeSurfaces.length) + " Active Windows"
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: Island.Theme.foreground
                                        }
                                        Text {
                                            text: "Workspace: " + (root.desktopModel && root.desktopModel.focusedWorkspaceName ? root.desktopModel.focusedWorkspaceName : "1")
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Island.Theme.muted
                                        }
                                    }

                                    // Launch Overview Button
                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 28
                                        width: 100
                                        radius: 14
                                        color: overviewBtnMouse.containsMouse ? Island.Theme.primary : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25)

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Text {
                                                text: "󰕰"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 11
                                                color: overviewBtnMouse.containsMouse ? "#ffffff" : Island.Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: "Overview"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: overviewBtnMouse.containsMouse ? "#ffffff" : Island.Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: overviewBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "overview", "toggle"])
                                        }
                                    }
                                }
                            }

                            // Active Windows List Header
                            Text {
                                text: "ACTIVE SURFACES (" + root.activeSurfaces.length + ")"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 1.2
                                color: Island.Theme.muted
                            }

                            // Active Windows Repeater
                            Repeater {
                                model: root.activeSurfaces

                                delegate: Rectangle {
                                    id: winCard
                                    width: spacesCol.width
                                    height: 52
                                    radius: 12
                                    color: (modelData.activated || winCardMouse.containsMouse) ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                                    border.color: modelData.activated ? Island.Theme.primary : (winCardMouse.containsMouse ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                                    border.width: 1

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 10

                                        // Left: App Icon
                                        Rectangle {
                                            id: appIconRect
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 32
                                            height: 32
                                            radius: 8
                                            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.15)

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.getAppIcon(modelData.appId, modelData.windowClass)
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 15
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
                                                // Workspace Badge
                                                Rectangle {
                                                    height: 14
                                                    width: wsTagText.implicitWidth + 8
                                                    radius: 7
                                                    color: Qt.rgba(1, 1, 1, 0.08)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text {
                                                        id: wsTagText
                                                        anchors.centerIn: parent
                                                        text: "WS " + (modelData.workspaceId || "?")
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
                                            spacing: 6

                                            // Focus Button
                                            Rectangle {
                                                width: 24
                                                height: 24
                                                radius: 6
                                                color: actFocusMouse.containsMouse ? Island.Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰍹"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 11
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
                                                width: 24
                                                height: 24
                                                radius: 6
                                                color: actStashMouse.containsMouse ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.3) : Qt.rgba(1, 1, 1, 0.08)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅍"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 11
                                                    color: actStashMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                                                }
                                                MouseArea {
                                                    id: actStashMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (modelData.address) {
                                                            Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspacesilent", "special:stash,address:" + modelData.address]);
                                                        }
                                                    }
                                                }
                                            }

                                            // Close Button
                                            Rectangle {
                                                width: 24
                                                height: 24
                                                radius: 6
                                                color: actCloseMouse.containsMouse ? Island.Theme.red : Qt.rgba(1, 1, 1, 0.08)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅖"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 11
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
                            Text {
                                text: "STASH POCKET (" + root.stashedSurfaces.length + ")"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 1.2
                                color: Island.Theme.muted
                            }

                            Repeater {
                                model: root.stashedSurfaces

                                delegate: Rectangle {
                                    width: spacesCol.width
                                    height: 44
                                    radius: 10
                                    color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.08)
                                    border.color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25)
                                    border.width: 1

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 10

                                        Row {
                                            anchors.left: parent.left
                                            anchors.right: restoreBtn.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 8

                                            Text {
                                                text: "󰅍"
                                                font.family: Island.Theme.iconFontFamily
                                                font.pixelSize: 13
                                                color: Island.Theme.primary
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
                                            height: 24
                                            width: 64
                                            radius: 6
                                            color: restoreMouse.containsMouse ? Island.Theme.primary : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.2)

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Restore"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 9
                                                font.bold: true
                                                color: restoreMouse.containsMouse ? "#ffffff" : Island.Theme.primary
                                            }

                                            MouseArea {
                                                id: restoreMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const targetWs = (root.desktopModel && root.desktopModel.focusedWorkspaceId > 0) ? String(root.desktopModel.focusedWorkspaceId) : "1";
                                                    Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspace", targetWs + ",address:" + modelData.address]);
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

                    // ---------------------------------------------------------
                    // DECK 2: SYSTEM TELEMETRY & HARDWARE HUB
                    // ---------------------------------------------------------
                    Flickable {
                        id: systemDeck
                        anchors.fill: parent
                        visible: root.currentTab === 2
                        contentWidth: width
                        contentHeight: systemCol.implicitHeight + 20
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        Column {
                            id: systemCol
                            width: parent.width
                            spacing: 14

                            // 1. HARDWARE TELEMETRY GAUGES CARD
                            Rectangle {
                                width: parent.width
                                height: 146
                                radius: 14
                                color: Qt.rgba(0, 0, 0, 0.25)
                                border.color: Island.Theme.glassBorderSubtle
                                border.width: 1

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 12

                                    Text {
                                        text: "HARDWARE TELEMETRY"
                                        font.family: Island.Theme.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.letterSpacing: 1.2
                                        color: Island.Theme.muted
                                    }

                                    // CPU Gauge
                                    Column {
                                        width: parent.width
                                        spacing: 4
                                        Item {
                                            width: parent.width
                                            height: 16
                                            Text {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "CPU Load"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.cpuPct + "%"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: root.cpuPct > 80 ? Island.Theme.red : Island.Theme.primary
                                            }
                                        }
                                        Rectangle {
                                            width: parent.width
                                            height: 6
                                            radius: 3
                                            color: "#20ffffff"
                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: parent.width * Math.max(0.0, Math.min(1.0, root.cpuPct / 100.0))
                                                radius: 3
                                                color: root.cpuPct > 80 ? Island.Theme.red : Island.Theme.primary
                                                Behavior on width { NumberAnimation { duration: 300 } }
                                            }
                                        }
                                    }

                                    // RAM Gauge
                                    Column {
                                        width: parent.width
                                        spacing: 4
                                        Item {
                                            width: parent.width
                                            height: 16
                                            Text {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "RAM Usage"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: (root.memUsedGb > 0 ? (root.memUsedGb.toFixed(1) + " / " + root.memTotalGb.toFixed(1) + " GB (" + root.memPct + "%)") : "Analyzing...")
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 9
                                                color: Island.Theme.muted
                                            }
                                        }
                                        Rectangle {
                                            width: parent.width
                                            height: 6
                                            radius: 3
                                            color: "#20ffffff"
                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: parent.width * Math.max(0.0, Math.min(1.0, root.memPct / 100.0))
                                                radius: 3
                                                color: root.memPct > 85 ? Island.Theme.red : Island.Theme.primary
                                                Behavior on width { NumberAnimation { duration: 300 } }
                                            }
                                        }
                                    }

                                    // Battery Gauge
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        Text {
                                            text: root.batCharging ? "󰂄" : "󰁹"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 13
                                            color: root.batCharging ? Island.Theme.green : Island.Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "Battery: " + (root.batPct >= 0 ? (Math.round(root.batPct) + "%") : "AC Power") + (root.batCharging ? " (Charging)" : "")
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: Island.Theme.foreground
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            // 2. PIPEWIRE AUDIO OUTPUT CARD
                            Rectangle {
                                width: parent.width
                                height: 96
                                radius: 14
                                color: Qt.rgba(0, 0, 0, 0.25)
                                border.color: Island.Theme.glassBorderSubtle
                                border.width: 1

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 8

                                    Item {
                                        width: parent.width
                                        height: 32

                                        Text {
                                            id: audioIcon
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.audioMuted ? "󰖁" : "󰕾"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 14
                                            color: root.audioMuted ? Island.Theme.red : Island.Theme.primary
                                        }

                                        Column {
                                            anchors.left: audioIcon.right
                                            anchors.leftMargin: 8
                                            anchors.right: muteToggleBtn.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1

                                            Text {
                                                text: "Audio Output Master"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: root.sinkName
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 9
                                                color: Island.Theme.muted
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                        }

                                        // Mute Toggle Button
                                        Rectangle {
                                            id: muteToggleBtn
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 24
                                            width: 48
                                            radius: 6
                                            color: root.audioMuted ? Qt.rgba(1, 0, 0, 0.2) : Qt.rgba(1, 1, 1, 0.08)

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.audioMuted ? "Unmute" : "Mute"
                                                font.family: Island.Theme.fontFamily
                                                font.pixelSize: 8
                                                font.bold: true
                                                color: root.audioMuted ? Island.Theme.red : Island.Theme.foreground
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.sinkAudio) root.sinkAudio.muted = !root.sinkAudio.muted;
                                                }
                                            }
                                        }
                                    }

                                    // Volume Slider / Bar
                                    Rectangle {
                                        width: parent.width
                                        height: 8
                                        radius: 4
                                        color: "#20ffffff"

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: parent.width * root.audioVolume
                                            radius: 4
                                            color: root.audioMuted ? Island.Theme.muted : Island.Theme.primary
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
                                }
                            }

                            // 3. QUICK SESSION & POWER ACTIONS GRID
                            Text {
                                text: "SESSION CONTROLS"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 1.2
                                color: Island.Theme.muted
                            }

                            Grid {
                                width: parent.width
                                columns: 2
                                spacing: 8

                                // Action 1: Lock
                                Rectangle {
                                    width: (systemCol.width - 8) / 2
                                    height: 44
                                    radius: 10
                                    color: actLockMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04)
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text {
                                            text: "󰌾"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 14
                                            color: Island.Theme.foreground
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "Lock Screen"
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: Island.Theme.foreground
                                            anchors.verticalCenter: parent.verticalCenter
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
                                    height: 44
                                    radius: 10
                                    color: actSuspMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04)
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text {
                                            text: "󰤄"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 14
                                            color: Island.Theme.foreground
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "Sleep / Suspend"
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: Island.Theme.foreground
                                            anchors.verticalCenter: parent.verticalCenter
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
                                    height: 44
                                    radius: 10
                                    color: actRebootMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04)
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text {
                                            text: "󰜉"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 14
                                            color: Island.Theme.foreground
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "Restart"
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: Island.Theme.foreground
                                            anchors.verticalCenter: parent.verticalCenter
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
                                    height: 44
                                    radius: 10
                                    color: actPowerMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.25) : Qt.rgba(1, 1, 1, 0.04)
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text {
                                            text: "󰐥"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 14
                                            color: actPowerMouse.containsMouse ? Island.Theme.red : Island.Theme.foreground
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "Shut Down"
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: actPowerMouse.containsMouse ? Island.Theme.red : Island.Theme.foreground
                                            anchors.verticalCenter: parent.verticalCenter
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