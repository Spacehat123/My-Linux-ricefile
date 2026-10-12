import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
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

    // Game Mode State directly synchronized with Island.ShellState single source of truth
    readonly property bool gameModeActive: Island.ShellState ? Island.ShellState.gameMode : false
    readonly property int gameModeKilledCount: Island.ShellState ? Island.ShellState.gameModeKilledCount : 0

    function toggleGameMode() {
        if (Island.ShellState) Island.ShellState.toggleGameMode();
    }

    // The Feather Mode State (Absolute Battery Optimization)
    readonly property bool featherModeActive: Island.ShellState ? Island.ShellState.featherMode : false
    readonly property int featherModeKilledCount: Island.ShellState ? Island.ShellState.featherKilledCount : 0

    function toggleFeatherMode() {
        if (Island.ShellState) Island.ShellState.toggleFeatherMode();
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

    property int studyModalStep: 0 // 0: Hidden, 1: Warning 1, 2: Warning 2, 3: Password
    property string studyPasswordInput: ""
    property string studyPasswordError: ""

    function formatStudyDuration(sec) {
        const m = Math.floor(sec / 60);
        const s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function triggerStudyModeClick() {
        if (studyActive) {
            if (studyOvertime) {
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

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    Column {
        anchors.fill: parent
        spacing: 16

        // =====================================================================
        // SECTION 1: HEADER & GREETING
        // =====================================================================
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

            // Settings Gear Icon
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
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

        // =====================================================================
        // SECTION 2: QUICK CONTROLS GRID (2x2 SQUIRCLE TILES)
        // =====================================================================
        Grid {
            width: parent.width
            columns: 2
            spacing: 10

            // 1. Wallpaper Toggle
            Rectangle {
                width: (parent.width - 10) / 2
                height: 72
                radius: 16
                color: root.wallpaperEnabled
                    ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.16)
                    : (wpTileHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard)
                border.color: root.wallpaperEnabled ? Island.Theme.primary : (wpTileHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                border.width: root.wallpaperEnabled ? 1.5 : 1
                scale: wpTileTap.pressed ? 0.96 : 1.0

                Behavior on scale { NumberAnimation { duration: 80 } }
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                HoverHandler { id: wpTileHover }
                TapHandler {
                    id: wpTileTap
                    onTapped: root.toggleWallpaper()
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Text {
                        text: "󰸉"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 18
                        color: root.wallpaperEnabled ? Island.Theme.primary : Island.Theme.muted
                    }

                    Text {
                        text: "Wallpaper"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                    }

                    Text {
                        text: root.wallpaperEnabled ? "Dynamic" : "Paused"
                        font.pixelSize: 9
                        font.family: Island.Theme.fontFamily
                        color: root.wallpaperEnabled ? Island.Theme.primary : Island.Theme.muted
                    }
                }
            }

            // 2. Ambient Overlay Toggle (Cycles Dynamic -> Always On -> Disabled)
            Rectangle {
                width: (parent.width - 10) / 2
                height: 72
                radius: 16
                readonly property color activeColor: root.ambientAlwaysOn ? Island.Theme.cyan : Island.Theme.blue
                color: root.ambientEnabled
                    ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, root.ambientAlwaysOn ? 0.22 : 0.16)
                    : (ambTileHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard)
                border.color: root.ambientEnabled ? activeColor : (ambTileHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                border.width: root.ambientEnabled ? 1.5 : 1
                scale: ambTileTap.pressed ? 0.96 : 1.0

                Behavior on scale { NumberAnimation { duration: 80 } }
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                HoverHandler { id: ambTileHover }
                TapHandler {
                    id: ambTileTap
                    onTapped: root.cycleAmbient()
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Text {
                        text: root.ambientAlwaysOn ? "󰈈" : "󰍹"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 18
                        color: root.ambientEnabled ? parent.parent.activeColor : Island.Theme.muted
                    }

                    Text {
                        text: "Ambient HUD"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                    }

                    Text {
                        text: !root.ambientEnabled ? "Disabled" : (root.ambientAlwaysOn ? "Always On" : "Dynamic")
                        font.pixelSize: 9
                        font.family: Island.Theme.fontFamily
                        color: root.ambientEnabled ? parent.parent.activeColor : Island.Theme.muted
                    }
                }
            }

            // 3. Do Not Disturb Toggle
            Rectangle {
                width: (parent.width - 10) / 2
                height: 72
                radius: 16
                readonly property bool dndActive: Island.IslandHub ? Island.IslandHub.dnd : false
                color: dndActive
                    ? Qt.rgba(Island.Theme.purple.r, Island.Theme.purple.g, Island.Theme.purple.b, 0.16)
                    : (dndTileHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard)
                border.color: dndActive ? Island.Theme.purple : (dndTileHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                border.width: dndActive ? 1.5 : 1
                scale: dndTileTap.pressed ? 0.96 : 1.0

                Behavior on scale { NumberAnimation { duration: 80 } }
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                HoverHandler { id: dndTileHover }
                TapHandler {
                    id: dndTileTap
                    onTapped: {
                        if (Island.IslandHub)
                            Island.IslandHub.dnd = !Island.IslandHub.dnd;
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Text {
                        text: "󰂛"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 18
                        color: parent.parent.dndActive ? Island.Theme.purple : Island.Theme.muted
                    }

                    Text {
                        text: "Do Not Disturb"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                    }

                    Text {
                        text: parent.parent.dndActive ? "Silenced" : "Alerts On"
                        font.pixelSize: 9
                        font.family: Island.Theme.fontFamily
                        color: parent.parent.dndActive ? Island.Theme.purple : Island.Theme.muted
                    }
                }
            }

            // 4. Night Light Toggle
            Rectangle {
                width: (parent.width - 10) / 2
                height: 72
                radius: 16
                readonly property bool nightLightActive: Island.Backend ? Island.Backend.nightLightStatus === "on" : false
                color: nightLightActive
                    ? Qt.rgba(Island.Theme.orange.r, Island.Theme.orange.g, Island.Theme.orange.b, 0.16)
                    : (nlTileHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard)
                border.color: nightLightActive ? Island.Theme.orange : (nlTileHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                border.width: nightLightActive ? 1.5 : 1
                scale: nlTileTap.pressed ? 0.96 : 1.0

                Behavior on scale { NumberAnimation { duration: 80 } }
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                HoverHandler { id: nlTileHover }
                TapHandler {
                    id: nlTileTap
                    onTapped: {
                        if (Island.Backend) {
                            Island.Backend.toggleNightLight();
                        }
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Text {
                        text: "󰖔"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 18
                        color: parent.parent.nightLightActive ? Island.Theme.orange : Island.Theme.muted
                    }

                    Text {
                        text: "Night Light"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                    }

                    Text {
                        text: parent.parent.nightLightActive ? "Warm 4200K" : "Standard 6500K"
                        font.pixelSize: 9
                        font.family: Island.Theme.fontFamily
                        color: parent.parent.nightLightActive ? Island.Theme.orange : Island.Theme.muted
                    }
                }
            }
        }

        // =====================================================================
        // SECTION 2B: PERFORMANCE MODE (HIGH-PERFORMANCE BLOAT KILLER)
        // =====================================================================
        Rectangle {
            width: parent.width
            height: 64
            radius: 16
            color: root.gameModeActive
                ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.16)
                : (gameTileHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard)
            border.color: root.gameModeActive 
                ? Island.Theme.red 
                : (gameTileHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
            border.width: root.gameModeActive ? 1.5 : 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            HoverHandler { id: gameTileHover }

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Main clickable toggle zone (Badge + Text)
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 84
                    height: parent.height

                    scale: mainTap.pressed ? 0.98 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    HoverHandler { id: mainHover }
                    TapHandler {
                        id: mainTap
                        onTapped: root.toggleGameMode()
                    }

                    Row {
                        anchors.fill: parent
                        spacing: 10

                        // Glowing speedometer / performance badge
                        Rectangle {
                            width: 36
                            height: 36
                            radius: 10
                            color: root.gameModeActive 
                                ? Island.Theme.red 
                                : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.15)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "󰓅"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 18
                                color: root.gameModeActive ? "#0a0a0f" : Island.Theme.primary
                            }
                        }

                        // Text labels
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 46
                            spacing: 2

                            Text {
                                text: "Performance"
                                font.pixelSize: 13
                                font.bold: true
                                font.family: Island.Theme.fontFamily
                                color: Island.Theme.foreground
                            }

                            Text {
                                text: root.gameModeActive
                                    ? "Active • " + root.gameModeKilledCount + " killed"
                                    : "Kill bloat • 0 latency"
                                font.pixelSize: 10
                                font.family: Island.Theme.fontFamily
                                color: root.gameModeActive ? Island.Theme.red : Island.Theme.muted
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Action controls (Exceptions gear + Toggle switch)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Exceptions settings button
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        color: exceptHover.hovered ? Island.Theme.glassCardHover : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.12)
                        border.color: exceptHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle
                        border.width: 1
                        scale: exceptTap.pressed ? 0.92 : 1.0

                        Behavior on scale { NumberAnimation { duration: 80 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒓"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: exceptHover.hovered ? Island.Theme.primary : Island.Theme.muted
                        }

                        HoverHandler { id: exceptHover }
                        TapHandler {
                            id: exceptTap
                            onTapped: {
                                Island.ShellState.close();
                                Island.ShellState.openSettingsRequested("gamemode");
                            }
                        }
                    }

                    // Toggle pill switch
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 22
                        radius: 11
                        color: root.gameModeActive ? Island.Theme.red : Island.Theme.glassCardHover
                        border.color: root.gameModeActive ? Island.Theme.red : Island.Theme.glassBorderSubtle
                        border.width: 1

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.gameModeActive ? parent.width - width - 2 : 2
                            width: 18
                            height: 18
                            radius: 9
                            color: root.gameModeActive ? "#0a0a0f" : Island.Theme.muted

                            Behavior on x {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                        }

                        TapHandler {
                            onTapped: root.toggleGameMode()
                        }
                    }
                }
            }
        }

        // =====================================================================
        // SECTION 2C: THE FEATHER (ABSOLUTE BATTERY MODE)
        // =====================================================================
        Rectangle {
            width: parent.width
            height: 64
            radius: 16
            color: root.featherModeActive
                ? Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.16)
                : (featherTileHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard)
            border.color: root.featherModeActive 
                ? Island.Theme.green 
                : (featherTileHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
            border.width: root.featherModeActive ? 1.5 : 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            HoverHandler { id: featherTileHover }

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Main clickable toggle zone (Badge + Text)
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 50
                    height: parent.height

                    scale: featherMainTap.pressed ? 0.98 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    HoverHandler { id: featherMainHover }
                    TapHandler {
                        id: featherMainTap
                        onTapped: root.toggleFeatherMode()
                    }

                    Row {
                        anchors.fill: parent
                        spacing: 10

                        // Glowing leaf / feather badge
                        Rectangle {
                            width: 36
                            height: 36
                            radius: 10
                            color: root.featherModeActive 
                                ? Island.Theme.green 
                                : Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.15)
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰌪"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 18
                                color: root.featherModeActive ? "#0a0a0f" : Island.Theme.green
                            }
                        }

                        // Text labels
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 46
                            spacing: 2

                            Row {
                                spacing: 6
                                Text {
                                    text: "The Feather"
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: Island.Theme.fontFamily
                                    color: Island.Theme.foreground
                                }

                                Rectangle {
                                    visible: root.featherModeActive
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
                                text: root.featherModeActive
                                    ? "Active • " + root.featherModeKilledCount + " pruned • Bare Hyprland"
                                    : "Absolute battery • Bare-minimum Hyprland"
                                font.pixelSize: 10
                                font.family: Island.Theme.fontFamily
                                color: root.featherModeActive ? Island.Theme.green : Island.Theme.muted
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Toggle pill switch
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 22
                    radius: 11
                    color: root.featherModeActive ? Island.Theme.green : Island.Theme.glassCardHover
                    border.color: root.featherModeActive ? Island.Theme.green : Island.Theme.glassBorderSubtle
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.featherModeActive ? parent.width - width - 2 : 2
                        width: 18
                        height: 18
                        radius: 9
                        color: root.featherModeActive ? "#0a0a0f" : Island.Theme.muted

                        Behavior on x {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }

                    TapHandler {
                        onTapped: root.toggleFeatherMode()
                    }
                }
            }
        }

        // =====================================================================
        // SECTION 2D: AI IMAGE STUDIO DAEMON (WARM RAM • 0 VRAM • 3M AUTO-EXIT)
        // =====================================================================
        Rectangle {
            width: parent.width
            height: 64
            radius: 16
            readonly property bool aiActive: Island.ShellState ? Island.ShellState.aiDaemonLoaded : false
            color: aiActive
                ? Qt.rgba(Island.Theme.purple.r, Island.Theme.purple.g, Island.Theme.purple.b, 0.16)
                : (aiTileHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard)
            border.color: aiActive
                ? Island.Theme.purple
                : (aiTileHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
            border.width: aiActive ? 1.5 : 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            HoverHandler { id: aiTileHover }

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Main clickable toggle zone (Badge + Text)
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 50
                    height: parent.height

                    scale: aiMainTap.pressed ? 0.98 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    HoverHandler { id: aiMainHover }
                    TapHandler {
                        id: aiMainTap
                        onTapped: {
                            if (Island.ShellState) Island.ShellState.toggleAiDaemon();
                        }
                    }

                    Row {
                        anchors.fill: parent
                        spacing: 10

                        // Glowing AI / Studio badge
                        Rectangle {
                            width: 36
                            height: 36
                            radius: 10
                            color: parent.parent.parent.parent.aiActive
                                ? Island.Theme.purple
                                : Qt.rgba(Island.Theme.purple.r, Island.Theme.purple.g, Island.Theme.purple.b, 0.15)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "󱨊"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 18
                                color: parent.parent.parent.parent.parent.aiActive ? "#0a0a0f" : Island.Theme.purple
                            }
                        }

                        // Text labels
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 46
                            spacing: 2

                            Row {
                                spacing: 6
                                anchors.left: parent.left

                                Text {
                                    text: "AI Image Engine"
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: Island.Theme.fontFamily
                                    color: Island.Theme.foreground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    visible: parent.parent.parent.parent.parent.parent.aiActive
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 48
                                    height: 16
                                    radius: 8
                                    color: Qt.rgba(Island.Theme.purple.r, Island.Theme.purple.g, Island.Theme.purple.b, 0.25)
                                    border.color: Island.Theme.purple
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "WARM"
                                        font.pixelSize: 8
                                        font.bold: true
                                        font.family: Island.Theme.fontFamily
                                        color: Island.Theme.purple
                                    }
                                }
                            }

                            Text {
                                text: parent.parent.parent.parent.parent.aiActive
                                    ? "Loaded in RAM • 0 VRAM • 3m auto-exit"
                                    : "Unloaded • 0 MB RAM • Preload on Super+G"
                                font.pixelSize: 10
                                font.family: Island.Theme.fontFamily
                                color: parent.parent.parent.parent.parent.aiActive ? Island.Theme.purple : Island.Theme.muted
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Toggle pill switch
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 22
                    radius: 11
                    color: parent.parent.aiActive ? Island.Theme.purple : Island.Theme.glassCardHover
                    border.color: parent.parent.aiActive ? Island.Theme.purple : Island.Theme.glassBorderSubtle
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.parent.parent.aiActive ? parent.width - width - 2 : 2
                        width: 18
                        height: 18
                        radius: 9
                        color: parent.parent.parent.aiActive ? "#0a0a0f" : Island.Theme.muted

                        Behavior on x {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }

                    TapHandler {
                        onTapped: {
                            if (Island.ShellState) Island.ShellState.toggleAiDaemon();
                        }
                    }
                }
            }
        }

        // =====================================================================
        // SECTION 2E: GOD'S EYE (LIVE 3D OSINT & SATELLITE GLOBE)
        // =====================================================================
        Rectangle {
            width: parent.width
            height: 64
            radius: 16
            readonly property bool godsEyeOn: root.godsEyeActive
            color: godsEyeOn
                ? Qt.rgba(Island.Theme.blue.r, Island.Theme.blue.g, Island.Theme.blue.b, 0.16)
                : (godsEyeTileHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard)
            border.color: godsEyeOn
                ? Island.Theme.blue
                : (godsEyeTileHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
            border.width: godsEyeOn ? 1.5 : 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            HoverHandler { id: godsEyeTileHover }

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Main clickable toggle zone (Badge + Text)
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (root.godsEyeActive ? 84 : 50)
                    height: parent.height

                    scale: godsEyeMainTap.pressed ? 0.98 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    HoverHandler { id: godsEyeMainHover }
                    TapHandler {
                        id: godsEyeMainTap
                        onTapped: root.toggleGodsEye()
                    }

                    Row {
                        anchors.fill: parent
                        spacing: 10

                        // Glowing Satellite / Globe badge
                        Rectangle {
                            width: 36
                            height: 36
                            radius: 10
                            color: root.godsEyeActive
                                ? Island.Theme.blue
                                : Qt.rgba(Island.Theme.blue.r, Island.Theme.blue.g, Island.Theme.blue.b, 0.15)
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰝊"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 18
                                color: root.godsEyeActive ? "#0a0a0f" : Island.Theme.blue
                            }
                        }

                        // Text labels
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 46
                            spacing: 2

                            Row {
                                spacing: 6
                                anchors.left: parent.left

                                Text {
                                    text: "God's Eye"
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: Island.Theme.fontFamily
                                    color: Island.Theme.foreground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    visible: root.godsEyeActive
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 42
                                    height: 16
                                    radius: 8
                                    color: Qt.rgba(Island.Theme.blue.r, Island.Theme.blue.g, Island.Theme.blue.b, 0.25)
                                    border.color: Island.Theme.blue
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "LIVE"
                                        font.pixelSize: 8
                                        font.bold: true
                                        font.family: Island.Theme.fontFamily
                                        color: Island.Theme.blue
                                    }
                                }
                            }

                            Text {
                                text: root.godsEyeActive
                                    ? "Live 3D Globe • Port 4173 • Online"
                                    : "Live 3D OSINT Globe & Satellite Tracker"
                                font.pixelSize: 10
                                font.family: Island.Theme.fontFamily
                                color: root.godsEyeActive ? Island.Theme.blue : Island.Theme.muted
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Action controls (Open browser button + Toggle pill switch)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Direct Open / Focus Tab button (visible when online)
                    Rectangle {
                        visible: root.godsEyeActive
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        color: openTabHover.hovered ? Island.Theme.glassCardHover : Qt.rgba(Island.Theme.blue.r, Island.Theme.blue.g, Island.Theme.blue.b, 0.15)
                        border.color: openTabHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle
                        border.width: 1
                        scale: openTabTap.pressed ? 0.92 : 1.0

                        Behavior on scale { NumberAnimation { duration: 80 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰖟"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: openTabHover.hovered ? Island.Theme.foreground : Island.Theme.blue
                        }

                        HoverHandler { id: openTabHover }
                        TapHandler {
                            id: openTabTap
                            onTapped: root.openGodsEyeBrowser()
                        }
                    }

                    // Toggle pill switch
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 22
                        radius: 11
                        color: root.godsEyeActive ? Island.Theme.blue : Island.Theme.glassCardHover
                        border.color: root.godsEyeActive ? Island.Theme.blue : Island.Theme.glassBorderSubtle
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.godsEyeActive ? parent.width - width - 2 : 2
                            width: 18
                            height: 18
                            radius: 9
                            color: root.godsEyeActive ? "#0a0a0f" : Island.Theme.muted

                            Behavior on x {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                        }

                        TapHandler {
                            onTapped: root.toggleGodsEye()
                        }
                    }
                }
            }
        }

        // =====================================================================
        // SECTION 2F: STUDY MODE (HARD-LOCKOUT DEEP WORK & WHITELIST)
        // =====================================================================
        Rectangle {
            width: parent.width
            height: 64
            radius: 16
            readonly property bool isStudyOn: root.studyActive
            readonly property color accentColor: root.studyOvertime ? Island.Theme.purple : Island.Theme.green
            color: isStudyOn
                ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.16)
                : (studyTileHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard)
            border.color: isStudyOn
                ? accentColor
                : (studyTileHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
            border.width: isStudyOn ? 1.5 : 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            HoverHandler { id: studyTileHover }

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Main clickable toggle zone (Badge + Text)
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 50
                    height: parent.height

                    scale: studyMainTap.pressed ? 0.98 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    HoverHandler { id: studyMainHover }
                    TapHandler {
                        id: studyMainTap
                        onTapped: root.triggerStudyModeClick()
                    }

                    Row {
                        anchors.fill: parent
                        spacing: 10

                        // Glowing Book / Study badge
                        Rectangle {
                            width: 36
                            height: 36
                            radius: 10
                            color: root.studyActive
                                ? parent.parent.parent.parent.accentColor
                                : Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.15)
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: root.studyOvertime ? "󰐊" : "󰑴"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 18
                                color: root.studyActive ? "#0a0a0f" : Island.Theme.green
                            }
                        }

                        // Text labels
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 46
                            spacing: 2

                            Row {
                                spacing: 6
                                anchors.left: parent.left

                                Text {
                                    text: "Study Mode"
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: Island.Theme.fontFamily
                                    color: Island.Theme.foreground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    visible: root.studyActive
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.studyOvertime ? 42 : 54
                                    height: 16
                                    radius: 8
                                    color: Qt.rgba(parent.parent.parent.parent.parent.accentColor.r, parent.parent.parent.parent.parent.accentColor.g, parent.parent.parent.parent.parent.accentColor.b, 0.25)
                                    border.color: parent.parent.parent.parent.parent.accentColor
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.studyOvertime ? "FLOW" : "LOCKED"
                                        font.pixelSize: 8
                                        font.bold: true
                                        font.family: Island.Theme.fontFamily
                                        color: parent.parent.parent.parent.parent.parent.accentColor
                                    }
                                }
                            }

                            Text {
                                text: {
                                    if (!root.studyActive) {
                                        return "Hard lockout • ICAI & Notes whitelist";
                                    }
                                    if (root.studyOvertime) {
                                        return "Flow State (+" + root.formatStudyDuration(root.studyOvertimeSeconds) + ") • Tap to finish";
                                    }
                                    return "Locked in Focus • " + root.formatStudyDuration(root.studyRemaining) + " left";
                                }
                                font.pixelSize: 10
                                font.family: Island.Theme.fontFamily
                                color: root.studyActive ? parent.parent.parent.parent.accentColor : Island.Theme.muted
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Toggle pill switch
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 22
                    radius: 11
                    color: root.studyActive ? parent.parent.accentColor : Island.Theme.glassCardHover
                    border.color: root.studyActive ? parent.parent.accentColor : Island.Theme.glassBorderSubtle
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.studyActive ? parent.width - width - 2 : 2
                        width: 18
                        height: 18
                        radius: 9
                        color: root.studyActive ? "#0a0a0f" : Island.Theme.muted

                        Behavior on x {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }

                    TapHandler {
                        onTapped: root.triggerStudyModeClick()
                    }
                }
            }
        }

        // =====================================================================
        // SECTION 3: SOUND & VOLUME CONTROL CARD
        // =====================================================================
        Rectangle {
            width: parent.width
            height: 118
            radius: 16
            color: Island.Theme.glassCard
            border.color: Island.Theme.glassBorderSubtle
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Item {
                    width: parent.width
                    height: 18

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Master Volume"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.audioMuted ? "Muted" : Math.round(root.currentVolume * 100) + "%"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: root.audioMuted ? Island.Theme.red : Island.Theme.primary
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        color: muteHover.hovered ? Island.Theme.glassCardHover : "transparent"
                        border.color: muteHover.hovered ? Island.Theme.glassBorder : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.audioMuted ? "󰖁" : "󰕾"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 14
                            color: root.audioMuted ? Island.Theme.red : Island.Theme.muted
                        }

                        HoverHandler { id: muteHover }
                        TapHandler {
                            onTapped: {
                                if (root.sinkAudio)
                                    root.sinkAudio.muted = !root.sinkAudio.muted;
                            }
                        }
                    }

                    // Interactive Volume Slider
                    StyledSlider {
                        width: parent.width - 36
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.currentVolume
                        onMoved: {
                            if (root.sinkAudio) {
                                root.sinkAudio.volume = value;
                            }
                        }
                    }
                }

                // Media Island Telemetry & Compute Toggles
                Row {
                    width: parent.width
                    spacing: 8

                    // 1. Live Lyrics Toggle
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 30
                        radius: 10
                        readonly property bool active: Island.IslandHub ? Island.IslandHub.lyricsEnabled : false
                        color: active
                            ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.14)
                            : (lyricsHover.hovered ? Island.Theme.glassCardHover : "transparent")
                        border.color: active
                            ? Island.Theme.primary
                            : (lyricsHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                        border.width: 1
                        scale: lyricsTap.pressed ? 0.97 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80 } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        HoverHandler { id: lyricsHover }
                        TapHandler {
                            id: lyricsTap
                            onTapped: {
                                if (Island.IslandHub)
                                    Island.IslandHub.toggleLyrics();
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "♪"
                                font.pixelSize: 12
                                font.bold: true
                                color: parent.parent.active ? Island.Theme.primary : Island.Theme.muted
                            }
                            Text {
                                text: parent.parent.active ? "Lyrics On" : "Lyrics Off"
                                font.pixelSize: 10
                                font.bold: true
                                font.family: Island.Theme.fontFamily
                                color: parent.parent.active ? Island.Theme.foreground : Island.Theme.muted
                            }
                        }
                    }

                    // 2. Waveform Meter Toggle
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 30
                        radius: 10
                        readonly property bool active: Island.IslandHub ? Island.IslandHub.visualizerEnabled : false
                        color: active
                            ? Qt.rgba(Island.Theme.aqua.r, Island.Theme.aqua.g, Island.Theme.aqua.b, 0.14)
                            : (vizHover.hovered ? Island.Theme.glassCardHover : "transparent")
                        border.color: active
                            ? Island.Theme.aqua
                            : (vizHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                        border.width: 1
                        scale: vizTap.pressed ? 0.97 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80 } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        HoverHandler { id: vizHover }
                        TapHandler {
                            id: vizTap
                            onTapped: {
                                if (Island.IslandHub)
                                    Island.IslandHub.toggleVisualizer();
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰎆"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 12
                                color: parent.parent.active ? Island.Theme.aqua : Island.Theme.muted
                            }
                            Text {
                                text: parent.parent.active ? "Waveform On" : "Waveform Off"
                                font.pixelSize: 10
                                font.bold: true
                                font.family: Island.Theme.fontFamily
                                color: parent.parent.active ? Island.Theme.foreground : Island.Theme.muted
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // SECTION 4: DISPLAY & WORKSPACE TELEMETRY
        // =====================================================================
        Rectangle {
            width: parent.width
            height: 84
            radius: 16
            color: Island.Theme.glassCard
            border.color: Island.Theme.glassBorderSubtle
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Row {
                    spacing: 8
                    Rectangle {
                        height: 20
                        width: wsLabel.implicitWidth + 14
                        radius: 10
                        color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.2)
                        border.color: Island.Theme.glassBorderActive
                        border.width: 1

                        Text {
                            id: wsLabel
                            anchors.centerIn: parent
                            text: "Workspace " + (root.desktopState ? root.desktopState.currentWorkspaceId : "1")
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
                            if (count === 0) return "No windows open";
                            return count === 1 ? "1 active window" : count + " active windows";
                        }
                        font.pixelSize: 10
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.muted
                    }
                }

                Row {
                    spacing: 6
                    Text {
                        text: "🖥️ " + (root.screen ? root.screen.name : "Display") + ":"
                        font.pixelSize: 10
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.muted
                    }
                    Text {
                        text: (root.screen ? root.screen.width + "×" + root.screen.height : "1920×1080") + " @ 60Hz"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                    }
                }
            }
        }

        // =====================================================================
        // SECTION 5: ACTION SHORTCUTS (SCREENSHOT, RECORD, TOUR)
        // =====================================================================
        Row {
            width: parent.width
            spacing: 8

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
                        Island.Backend.capture("region");
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "󰄀"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 13
                        color: Island.Theme.foreground
                    }
                    Text {
                        text: "Capture"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
                    }
                }
            }

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

            Rectangle {
                width: (parent.width - 16) / 3
                height: 36
                radius: 12
                color: prefHover.hovered ? Island.Theme.primaryContainer : Island.Theme.glassCard
                border.color: prefHover.hovered ? Island.Theme.glassBorderActive : Island.Theme.glassBorderSubtle
                border.width: 1
                scale: prefTap.pressed ? 0.95 : 1.0
                Behavior on scale { NumberAnimation { duration: 80 } }

                HoverHandler { id: prefHover }
                TapHandler {
                    id: prefTap
                    onTapped: {
                        if (root.desktopState) root.desktopState.setLeftSidebarOpen(false);
                        Island.ShellState.openSettings("");
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "󰒓"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 13
                        color: Island.Theme.primary
                    }
                    Text {
                        text: "Settings"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: Island.Theme.fontFamily
                        color: Island.Theme.foreground
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
        command: ["python3", Quickshell.shellPath("scripts/study-mode.py"), "prompt-and-start", "--duration", (Island.ShellState ? Island.ShellState.studyTargetDuration.toString() : "10")]
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
                            text: "• Duration: 30 minutes. After countdown, overtime counts UP with no exit penalty."
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
