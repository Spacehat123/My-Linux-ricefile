import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../island" as Island

PanelWindow {
    id: root

    property var screen: null
    property bool open: false
    property bool isPinned: false
    property bool isLockedOpen: false

    // =========================================================================
    // KITTY "MIDNIGHT GLASS" PALETTE & TYPOGRAPHY (~/.config/kitty/kitty.conf)
    // =========================================================================
    // Load Fredoka Bold Variable Font for wide lyrics
    FontLoader {
        id: fredokaFont
        source: "file:///home/pranc/.local/share/fonts/Fredoka-VariableFont_wdth,wght.ttf"
    }

    readonly property string monoFont: "JetBrainsMono Nerd Font"

    readonly property color kittyBg: "#171824"
    // Keep the surface translucent so Hyprland's layer blur remains visible.
    // The compositor provides the backdrop blur; this is only the Kitty tint.
    readonly property real kittyBgOpacity: 0.56
    readonly property color kittyFg: "#e2e4f0"
    readonly property color kittyActiveBorder: "#a5b4fc"
    readonly property color kittyInactiveBorder: "#34364a"
    readonly property color kittyBellBorder: "#f38ba8"
    readonly property color kittySelectionBg: "#a5b4fc"
    readonly property color kittySelectionFg: "#171824"
    readonly property color kittyCursor: "#c4b5fd"
    readonly property color kittyUrl: "#93c5fd"

    // Kitty ANSI Colors
    readonly property color kittyColor0: "#242638"
    readonly property color kittyColor1: "#f38ba8"
    readonly property color kittyColor2: "#a6e3a1"
    readonly property color kittyColor3: "#f9e2af"
    readonly property color kittyColor4: "#89b4fa"
    readonly property color kittyColor5: "#cba6f7"
    readonly property color kittyColor6: "#94e2d5"
    readonly property color kittyColor7: "#dce0f0"
    readonly property color kittyColor8: "#585b70"
    readonly property color kittyColor15: "#ffffff"

    // Default anchor position: floats directly beneath the top-bar left visualizer
    readonly property real defaultX: 140
    readonly property real defaultY: 52

    property real pillX: defaultX
    property real pillY: defaultY

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    focusable: false
    visible: open || capsuleCard.opacity > 0.001

    WlrLayershell.namespace: "pranc-shell-media-companion"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Clean single-layer Wayland input mask: zero full-screen leakage or top-border damage glitching
    mask: Region {
        item: root.open ? capsuleCard : null
    }

    // =========================================================================
    // MPRIS DATA MODEL & AUDIO BINDINGS
    // =========================================================================
    readonly property var allPlayers: Mpris.players ? Mpris.players.values : []
    readonly property var activePlayer: {
        if (Island.IslandHub && Island.IslandHub.player) return Island.IslandHub.player;
        if (!allPlayers || allPlayers.length === 0) return null;
        for (let i = 0; i < allPlayers.length; ++i) {
            if (allPlayers[i] && allPlayers[i].isPlaying)
                return allPlayers[i];
        }
        return allPlayers[0] || null;
    }

    readonly property bool isPlaying: activePlayer ? activePlayer.isPlaying : (Island.IslandHub ? Island.IslandHub.mediaPlaying : false)
    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "No Media Playing") : "No Media Playing"
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string trackArtUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property real trackPosition: activePlayer ? (activePlayer.position || 0) : 0
    readonly property real trackLength: activePlayer ? (activePlayer.length || 0) : 0
    readonly property real progressFraction: trackLength > 0 ? Math.max(0, Math.min(1, trackPosition / trackLength)) : 0

    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec < 0) return "0:00";
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // =========================================================================
    // KINETIC 3-LINE SYNCHRONIZED LYRICS ENGINE
    // =========================================================================
    property var syncedLines: []
    property int currentLineIndex: -1
    property string lyricsPrev: ""
    property string lyricsCurr: ""
    property string lyricsNext: ""
    readonly property bool hasSyncedLyrics: syncedLines.length > 0 || lyricsCurr.length > 0

    readonly property string fetcherScript: Quickshell.shellPath("island/scripts/lyrics-fetcher.py").toString().replace(/^file:\/\//, "")

    Process {
        id: lyricsFetchProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const trimmed = line.trim();
                if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
                    try {
                        const parsed = JSON.parse(trimmed);
                        if (Array.isArray(parsed) && parsed.length > 0) {
                            root.syncedLines = parsed;
                            root.updateSyncedLyrics();
                        }
                    } catch (e) {}
                }
            }
        }
    }

    function fetchLyricsForTrack() {
        syncedLines = [];
        currentLineIndex = -1;
        lyricsPrev = "";
        lyricsCurr = "";
        lyricsNext = "";
        if (!root.trackTitle || root.trackTitle === "No Media Playing") return;

        if (lyricsFetchProc.running)
            lyricsFetchProc.running = false;
        lyricsFetchProc.exec(["python3", root.fetcherScript, root.trackTitle, root.trackArtist]);
    }

    onTrackTitleChanged: fetchLyricsForTrack()
    onTrackArtistChanged: fetchLyricsForTrack()
    Component.onCompleted: fetchLyricsForTrack()

    function updateSyncedLyrics() {
        if (!syncedLines || syncedLines.length === 0) return;
        const pos = root.trackPosition;
        let idx = -1;
        for (let i = 0; i < syncedLines.length; ++i) {
            if (syncedLines[i].t <= pos + 0.25) {
                idx = i;
            } else {
                break;
            }
        }
        if (idx !== currentLineIndex && idx >= 0) {
            currentLineIndex = idx;
            lyricsPrev = idx > 0 ? syncedLines[idx - 1].text : "";
            const nextCurr = syncedLines[idx].text;
            if (nextCurr !== lyricsCurr) {
                lyricsCurr = nextCurr;
                lyricsSlideAnim.restart();
            }
            lyricsNext = idx < syncedLines.length - 1 ? syncedLines[idx + 1].text : "";
        }
    }

    onTrackPositionChanged: {
        if (syncedLines.length > 0) {
            updateSyncedLyrics();
        }
    }

    // Fallback: Rolling 3-line queue from IslandHub.liveLyric if no LRCLIB match
    Connections {
        target: Island.IslandHub || null
        function onLiveLyricChanged() {
            if (root.syncedLines.length === 0 && Island.IslandHub && Island.IslandHub.liveLyric !== "") {
                const nextL = Island.IslandHub.liveLyric;
                if (nextL !== root.lyricsCurr) {
                    root.lyricsPrev = root.lyricsCurr;
                    root.lyricsCurr = nextL;
                    root.lyricsNext = "";
                    lyricsSlideAnim.restart();
                }
            }
        }
    }

    // =========================================================================
    // REAL CAVA AUDIO EQUALIZER (PipeWire FFT Visualizer Stream)
    // Only spawns when companion is open AND audio is playing. 0% CPU when closed.
    // 14 frequency bars @ 30 FPS for silky-smooth motion with minimal resource usage.
    // =========================================================================
    property var cavaBars: [0,0,0,0,0,0,0,0,0,0,0,0,0,0]

    readonly property string cavaBinPath: Quickshell.shellPath("island/scripts/cava").toString().replace(/^file:\/\//, "")
    readonly property string cavaConfPath: Quickshell.shellPath("island/scripts/cava-companion.conf").toString().replace(/^file:\/\//, "")

    Process {
        id: cavaProc
        command: [root.cavaBinPath, "-p", root.cavaConfPath]
        running: root.open && root.isPlaying
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const parts = line.trim().split(";");
                if (parts.length >= 14) {
                    const arr = new Array(14);
                    for (let i = 0; i < 14; ++i) {
                        const val = parseInt(parts[i], 10);
                        arr[i] = isNaN(val) ? 0 : Math.max(0, Math.min(100, val)) / 100.0;
                    }
                    root.cavaBars = arr;
                }
            }
        }
    }

    // =========================================================================
    // LIFECYCLE & STATE MACHINE (UNMOVED vs PINNED)
    // =========================================================================
    function toggle() {
        if (open && isLockedOpen) {
            closeAndReset();
        } else {
            if (!isPinned) {
                pillX = defaultX;
                pillY = defaultY;
                capsuleCard.x = defaultX;
                capsuleCard.y = defaultY;
            }
            isLockedOpen = true;
            open = true;
        }
    }

    function closeAndReset() {
        open = false;
        isPinned = false;
        isLockedOpen = false;
        pillX = defaultX;
        pillY = defaultY;
        capsuleCard.x = defaultX;
        capsuleCard.y = defaultY;
    }

    // Playback state transitions: No auto-reveal! Stays closed until top-bar hover or click.
    onOpenChanged: {
        if (!open) {
            cavaBars = [0,0,0,0,0,0,0,0,0,0,0,0,0,0];
        }
    }

    onIsPlayingChanged: {
        if (isPlaying) {
            pauseGraceTimer.stop();
        } else {
            cavaBars = [0,0,0,0,0,0,0,0,0,0,0,0,0,0];
            if (!isPinned && !isLockedOpen) {
                pauseGraceTimer.restart();
            }
        }
    }

    Timer {
        id: pauseGraceTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!root.isPlaying && !root.isPinned && !root.isLockedOpen) {
                root.open = false;
            }
        }
    }

    // Hover reveal logic from Top Bar
    property bool cardHovered: cardDragMouse.containsMouse

    Timer {
        id: hoverCloseTimer
        interval: 380
        repeat: false
        onTriggered: {
            if (!root.isPinned && !root.isLockedOpen && !root.cardHovered && !(Island.ShellState && Island.ShellState.mediaCompanionHovered)) {
                root.open = false;
            }
        }
    }

    Connections {
        target: Island.ShellState || null
        function onMediaCompanionHoveredChanged() {
            if (Island.ShellState && Island.ShellState.mediaCompanionHovered) {
                hoverCloseTimer.stop();
                if (!root.isPinned) {
                    root.pillX = root.defaultX;
                    root.pillY = root.defaultY;
                    capsuleCard.x = root.defaultX;
                    capsuleCard.y = root.defaultY;
                }
                root.open = true;
            } else {
                if (!root.isPinned && !root.isLockedOpen) {
                    hoverCloseTimer.restart();
                }
            }
        }
    }

    onCardHoveredChanged: {
        if (cardHovered) {
            hoverCloseTimer.stop();
        } else {
            if (!isPinned && !isLockedOpen && !(Island.ShellState && Island.ShellState.mediaCompanionHovered)) {
                hoverCloseTimer.restart();
            }
        }
    }

    // Listen to ShellState's toggle request (triggered by Super+M and top bar click)
    Connections {
        target: Island.ShellState || null
        function onToggleMediaCompanionRequested() {
            root.toggle();
        }
    }

    // IPC Endpoint Registration
    IpcHandler {
        target: "media_companion"

        function toggle(): string {
            root.toggle();
            return JSON.stringify({ success: true, open: root.open, isPinned: root.isPinned });
        }

        function getThemeDebug(): string {
            return JSON.stringify({
                hasTheme: !!Island.Theme,
                themeName: Island.Theme ? Island.Theme.name : null,
                mode: Island.Theme ? Island.Theme.mode : null,
                primary: Island.Theme ? Island.Theme.primary.toString() : null,
                bg0: Island.Theme ? Island.Theme.bg0.toString() : null,
            });
        }

        function setOpen(val: bool): string {
            if (val) {
                if (!root.isPinned) {
                    root.pillX = root.defaultX;
                    root.pillY = root.defaultY;
                    capsuleCard.x = root.defaultX;
                    capsuleCard.y = root.defaultY;
                }
                root.open = true;
            } else {
                root.closeAndReset();
            }
            return JSON.stringify({ success: true, open: root.open, isPinned: root.isPinned });
        }

        function moveTo(targetX: real, targetY: real): string {
            root.pillX = targetX;
            root.pillY = targetY;
            capsuleCard.x = targetX;
            capsuleCard.y = targetY;
            root.isPinned = true;
            return JSON.stringify({ success: true, x: targetX, y: targetY });
        }

        function getState(): string {
            return JSON.stringify({
                open: root.open,
                isPinned: root.isPinned,
                x: root.pillX,
                y: root.pillY,
                title: root.trackTitle,
                artist: root.trackArtist,
                isPlaying: root.isPlaying,
                cavaRunning: cavaProc.running,
                cavaSample: root.cavaBars ? root.cavaBars.slice(0, 6) : []
            });
        }
    }

    // =========================================================================
    // ELEVATED TRANSLUCENT MEDIA COMPANION CAPSULE
    // Compact squarish proportions (380x234), luxurious frosted depth
    // =========================================================================
    Item {
        id: capsuleCard
        x: root.pillX
        y: root.pillY
        width: 380
        height: 234
        property real radius: 16

        opacity: root.open ? 1.0 : 0.0
        scale: root.open ? 1.0 : 0.94
        transformOrigin: Item.Center

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 240; easing.type: Easing.OutBack }
        }

        // Elevated Card Body - Glass Midnight Palette from ~/.config/kitty/kitty.conf (Borderless)
        Rectangle {
            id: cardBody
            anchors.fill: parent
            radius: capsuleCard.radius
            color: Qt.rgba(root.kittyBg.r, root.kittyBg.g, root.kittyBg.b, root.kittyBgOpacity)
            border.color: Qt.rgba(root.kittyActiveBorder.r, root.kittyActiveBorder.g, root.kittyActiveBorder.b, 0.34)
            border.width: 1
            clip: true

            Behavior on color {
                ColorAnimation { duration: 260 }
            }

            // Interactive Drag Area (Header and Card Background)
            MouseArea {
                id: cardDragMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
                acceptedButtons: Qt.LeftButton

                property real startMouseX: 0
                property real startMouseY: 0

                onPressed: (mouse) => {
                    startMouseX = mouse.x;
                    startMouseY = mouse.y;
                }

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        root.pauseGraceTimer.stop();
                        const dx = mouse.x - startMouseX;
                        const dy = mouse.y - startMouseY;

                        const minX = 12;
                        const maxX = (root.screen ? root.screen.width : 1920) - capsuleCard.width - 12;
                        const minY = 48;
                        const maxY = (root.screen ? root.screen.height : 1080) - capsuleCard.height - 12;

                        const newX = Math.max(minX, Math.min(maxX, capsuleCard.x + dx));
                        const newY = Math.max(minY, Math.min(maxY, capsuleCard.y + dy));

                        capsuleCard.x = newX;
                        capsuleCard.y = newY;
                        root.pillX = newX;
                        root.pillY = newY;

                        const dist = Math.hypot(capsuleCard.x - root.defaultX, capsuleCard.y - root.defaultY);
                        root.isPinned = dist > 35;
                    }
                }
            }

            // =================================================================
            // CONTENT LAYER
            // =================================================================
            Item {
                id: cardContent
                anchors.fill: parent
                anchors.margins: 16

                // Scale slightly on press for tactile feedback
                scale: cardDragMouse.pressed ? 0.988 : 1.0
                transformOrigin: Item.Center
                Behavior on scale {
                    NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                }

                // -------------------------------------------------------------
                // SECTION 1: HEADER (Grab Handle, Pin & Close)
                // -------------------------------------------------------------
                Item {
                    id: headerRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 20


                    // Header Right Actions (Pin Status & Close Button)
                    Row {
                        id: headerActions
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // Pinned Indicator Badge
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 19
                            width: pinText.implicitWidth + 10
                            radius: 2
                            color: Qt.rgba(root.kittySelectionBg.r, root.kittySelectionBg.g, root.kittySelectionBg.b, 0.16)
                            border.width: 1
                            border.color: root.kittyActiveBorder
                            visible: root.isPinned

                            Text {
                                id: pinText
                                anchors.centerIn: parent
                                text: "PIN"
                                font.family: root.monoFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: root.kittyActiveBorder
                            }
                        }

                        // Close Button
                        Rectangle {
                            id: closeBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9
                            height: 9
                            radius: 4
                            color: closeMouse.containsMouse
                                ? Qt.rgba(root.kittyColor1.r, root.kittyColor1.g, root.kittyColor1.b, 0.25)
                                : root.kittyColor0
                            border.width: 1
                            border.color: closeMouse.containsMouse ? root.kittyColor1 : root.kittyInactiveBorder

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                font.family: root.monoFont
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: closeMouse.containsMouse ? root.kittyColor1 : root.kittyColor8
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeAndReset()
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // SECTION 2: MAIN BODY (CIRCULAR MEDIA DISC + 3-LINE LYRICS)
                // -------------------------------------------------------------
                Item {
                    id: bodyContainer
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: headerRow.bottom
                    anchors.topMargin: 12
                    anchors.bottom: parent.bottom

                    // =========================================================
                    // LEFT COLUMN: CIRCULAR MEDIA DISC WITH PROGRESS BORDER
                    // =========================================================
                    Item {
                        id: discContainer
                        width: 130
                        height: 130
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -30
                        Rectangle {
                            id: innerDisc
                            anchors.centerIn: parent
                            width: 118
                            height: 118
                            radius: 59
                            clip: true
                            color: root.kittyColor0

                            Image {
                                id: discArtImage
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                source: root.trackArtUrl
                                sourceSize.width: 160
                                sourceSize.height: 160
                                asynchronous: true
                                visible: false
                            }

                            Rectangle {
                                id: discCircleMask
                                anchors.fill: parent
                                radius: 59
                                color: "#ffffff"
                                visible: false
                            }

                            OpacityMask {
                                anchors.fill: parent
                                source: discArtImage
                                maskSource: discCircleMask
                                visible: discArtImage.status === Image.Ready
                            }

                            // Fallback Music Disc Graphic if no art
                            Item {
                                anchors.fill: parent
                                visible: !root.trackArtUrl || root.trackArtUrl === "" || discArtImage.status !== Image.Ready

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 118
                                    height: 118
                                    radius: 59
                                    color: root.kittyColor0
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰎆"
                                    font.pixelSize: 34
                                    font.family: root.monoFont
                                    font.weight: Font.Bold
                                    color: root.kittyActiveBorder
                                    opacity: 0.45
                                }
                            }

                            // Interactive click on disc to play/pause
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.activePlayer) root.activePlayer.playPause();
                                }
                            }

                        }

                        // Track Time Progress Pill — positioned below the album art
                        Rectangle {
                            id: trackTimePill
                            anchors.horizontalCenter: innerDisc.horizontalCenter
                            anchors.top: innerDisc.bottom
                            anchors.topMargin: 6
                            z: 2

                            width: timeLabel.implicitWidth + 14
                            height: 19
                            radius: 5
                            color: Qt.rgba(root.kittyBg.r, root.kittyBg.g, root.kittyBg.b, 0.88)
                            border.width: 1
                            border.color: root.kittyInactiveBorder

                            Text {
                                id: timeLabel
                                anchors.centerIn: parent
                                text: root.formatTime(root.trackPosition) + " - " + root.formatTime(root.trackLength)
                                font.family: root.monoFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: root.kittyFg
                            }
                        }

                        // Circular Progress Line Border (GPU Accelerated via QtQuick.Shapes)
                        Shape {
                            id: progressRingShape
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            // Background Inactive Track Ring
                            ShapePath {
                                strokeWidth: 2.5
                                strokeColor: root.kittyInactiveBorder
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap

                                PathAngleArc {
                                    centerX: progressRingShape.width / 2
                                    centerY: progressRingShape.height / 2
                                    radiusX: (progressRingShape.width - 5) / 2
                                    radiusY: (progressRingShape.height - 5) / 2
                                    startAngle: 0
                                    sweepAngle: 360
                                }
                            }

                            // Active Progress Arc Sweeping Clockwise as Track Plays
                            ShapePath {
                                strokeWidth: 2.5
                                strokeColor: root.kittyActiveBorder
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap

                                PathAngleArc {
                                    centerX: progressRingShape.width / 2
                                    centerY: progressRingShape.height / 2
                                    radiusX: (progressRingShape.width - 5) / 2
                                    radiusY: (progressRingShape.height - 5) / 2
                                    startAngle: -90
                                    sweepAngle: Math.max(0.1, Math.min(360, root.progressFraction * 360))
                                }
                            }
                        }

                        // Interactive Scrubber on the Circular Progress Line
                        MouseArea {
                            id: ringScrubMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function scrubToMouse(mouseX, mouseY) {
                                if (!root.activePlayer || root.trackLength <= 0) return;
                                const cx = width / 2;
                                const cy = height / 2;
                                const dx = mouseX - cx;
                                const dy = mouseY - cy;
                                let angleDeg = Math.atan2(dy, dx) * 180 / Math.PI;
                                let norm = (angleDeg + 90 + 360) % 360;
                                let ratio = norm / 360.0;
                                root.activePlayer.position = ratio * root.trackLength;
                            }

                            onPressed: (mouse) => scrubToMouse(mouse.x, mouse.y)
                            onPositionChanged: (mouse) => {
                                if (pressed) scrubToMouse(mouse.x, mouse.y);
                            }
                        }
                    }

                    // =========================================================
                    // RIGHT COLUMN: METADATA & 3-LINE SYNCHRONIZED TRANSCRIPTION
                    // =========================================================
                    Item {
                        id: rightColumn
                        anchors.left: discContainer.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                        // Track Title & Artist Block
                        Column {
                            id: metaBlock
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: 3

                            Row {
                                width: parent.width
                                spacing: 8
                                clip: true

                                Text {
                                    id: titleLabel
                                    text: root.trackTitle
                                    font.family: root.monoFont
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, parent.width - (miniVisualizer.visible ? (miniVisualizer.width + 8) : 0))
                                }

                                // Mini Centered Bidirectional Visualizer (lines expanding up & down)
                                Item {
                                    id: miniVisualizer
                                    width: 38
                                    height: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.isPlaying

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 2.5

                                        Repeater {
                                            model: 7

                                            Rectangle {
                                                id: waveBar
                                                required property int index
                                                width: 2.5
                                                radius: 1.25
                                                anchors.verticalCenter: parent.verticalCenter

                                                readonly property real level: (root.cavaBars && root.cavaBars.length > index * 2)
                                                    ? root.cavaBars[index * 2]
                                                    : 0

                                                height: Math.max(3, Math.min(18, Math.round(level * 18)))
                                                color: root.kittyActiveBorder

                                                Behavior on height {
                                                    NumberAnimation { duration: 45 }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: root.trackArtist !== "" ? root.trackArtist : (root.isPlaying ? "Active Playback" : "Idle")
                                font.family: root.monoFont
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.kittyFg
                                elide: Text.ElideRight
                            }
                        }

                        // Divider Hairline
                        Rectangle {
                            id: metaDivider
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: metaBlock.bottom
                            anchors.topMargin: 8
                            height: 1
                            color: root.kittyInactiveBorder
                        }

                        // 3-Line Kinetic Synced Lyrics Container
                        Item {
                            id: lyricsViewport
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: metaDivider.bottom
                            anchors.topMargin: 8
                            anchors.bottom: parent.bottom
                            clip: true

                            Column {
                                id: lyricsContent
                                width: parent.width
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5.5

                                transform: Translate {
                                    id: lyricsSlide
                                    y: 0
                                }

                                // 1. PREVIOUS LINE (Wide / Fredoka Bold)
                                Text {
                                    width: parent.width
                                    visible: root.lyricsPrev.length > 0
                                    text: root.lyricsPrev
                                    font.family: fredokaFont.name ? fredokaFont.name : "Fredoka"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: root.kittyFg
                                    opacity: 0.68
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                // 2. CURRENT ACTIVE LINE (Wide / Fredoka Bold, Prominent)
                                Row {
                                    width: parent.width
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "›"
                                        font.family: fredokaFont.name ? fredokaFont.name : "Fredoka"
                                        font.pixelSize: 15
                                        font.weight: Font.Bold
                                        color: root.kittyCursor
                                        visible: root.hasSyncedLyrics
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - (root.hasSyncedLyrics ? 16 : 0)
                                        text: root.lyricsCurr !== ""
                                            ? root.lyricsCurr
                                            : (root.isPlaying ? "♪ Instrumental or no lyrics found" : "Ready to play")
                                        font.family: fredokaFont.name ? fredokaFont.name : "Fredoka"
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.5
                                        color: root.lyricsCurr !== ""
                                            ? "#ffffff"
                                            : root.kittyFg
                                        opacity: root.lyricsCurr !== "" ? 1.0 : 0.78
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                }

                                // 3. NEXT LINE (Upcoming Preview Wide / Fredoka Bold)
                                Text {
                                    width: parent.width
                                    visible: root.lyricsNext.length > 0
                                    text: root.lyricsNext
                                    font.family: fredokaFont.name ? fredokaFont.name : "Fredoka"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: root.kittyFg
                                    opacity: 0.84
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            NumberAnimation {
                                id: lyricsSlideAnim
                                target: lyricsSlide
                                property: "y"
                                from: 8
                                to: 0
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
