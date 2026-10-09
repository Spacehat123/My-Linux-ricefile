import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import "../island" as Island

PanelWindow {
    id: root

    property bool open: false
    visible: open || closeAnim.running

    property var desktopState: null
    property var screen: null

    // Anchored to the middle of the right screen edge (vertically centered by LayerShell)
    anchors {
        right: true
    }
    // Zero right margin on the window guarantees unbreakable hover continuity from the screen edge
    margins {
        right: 0
    }

    implicitWidth: 420
    implicitHeight: 250
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    WlrLayershell.namespace: "pranc-shell-media"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Mask strictly to cardBody so clicks outside the floating card pass through 100% to background windows
    mask: Region {
        item: cardBody
        topLeftRadius: cardBody.radius
        topRightRadius: cardBody.radius
        bottomLeftRadius: cardBody.radius
        bottomRightRadius: cardBody.radius
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: {
            if (desktopState) desktopState.setMediaWidgetOpen(false)
            root.open = false
        }
    }

    // =========================================================================
    // DUAL-LAYER UNBREAKABLE HOVER CONTINUITY
    // HoverHandler directly on cardBody tracks cursor presence across all child items
    // =========================================================================
    readonly property bool hovered: cardHoverHandler.hovered

    // =========================================================================
    // MULTI-MEDIA RESOLUTION & STATE
    // =========================================================================
    readonly property var allPlayers: Mpris.players.values
    property int selectedPlayerIndex: 0

    // Auto-select playing player if the currently selected one is idle/stopped
    function syncPlayingPlayer() {
        if (!allPlayers || allPlayers.length === 0) return;
        const current = activePlayer;
        if (current && current.isPlaying) return;
        for (let i = 0; i < allPlayers.length; ++i) {
            if (allPlayers[i] && allPlayers[i].isPlaying) {
                selectedPlayerIndex = i;
                return;
            }
        }
    }

    readonly property var activePlayer: {
        if (!allPlayers || allPlayers.length === 0) return null;
        const validIndex = Math.max(0, Math.min(selectedPlayerIndex, allPlayers.length - 1));
        return allPlayers[validIndex] || null;
    }

    function selectPreviousPlayer() {
        if (!allPlayers || allPlayers.length <= 1) return;
        selectedPlayerIndex = (selectedPlayerIndex - 1 + allPlayers.length) % allPlayers.length;
    }

    function selectNextPlayer() {
        if (!allPlayers || allPlayers.length <= 1) return;
        selectedPlayerIndex = (selectedPlayerIndex + 1) % allPlayers.length;
    }

    function playerIcon(identity) {
        if (!identity) return "󰎆";
        const id = identity.toLowerCase();
        if (id.indexOf("spotify") !== -1) return "󰓇";
        if (id.indexOf("brave") !== -1) return "󰖟";
        if (id.indexOf("firefox") !== -1) return "󰈹";
        if (id.indexOf("chrom") !== -1) return "󰊯";
        if (id.indexOf("vlc") !== -1) return "󰕼";
        if (id.indexOf("mpv") !== -1) return "󰕼";
        return "󰎆";
    }

    function formatDuration(sec) {
        if (!Number.isFinite(sec) || sec <= 0) return "0:00";
        if (sec > 1000000) sec = sec / 1000000;
        const totalSec = Math.floor(sec);
        const m = Math.floor(totalSec / 60);
        const s = totalSec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Timer {
        interval: 100
        running: root.open && Boolean(root.activePlayer && root.activePlayer.isPlaying)
        repeat: true
        onTriggered: {
            if (root.activePlayer && root.activePlayer.positionChanged) {
                root.activePlayer.positionChanged();
            }
            if (curvyProgressCanvas) {
                curvyProgressCanvas.requestPaint();
            }
        }
    }

    Process {
        id: launchSpotifyProc
        command: ["sh", "-c", "spotify-launcher &"]
    }

    // =========================================================================
    // SLIDE-IN / SLIDE-OUT ANIMATION CONTROLLERS
    // =========================================================================
    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: contentTranslate
            property: "x"
            to: 0
            duration: 220
            easing.type: Easing.OutBack
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 1.0
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: contentTranslate
            property: "x"
            to: 430
            duration: 180
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 0.0
            duration: 140
            easing.type: Easing.InQuad
        }
    }

    onOpenChanged: {
        if (open) {
            syncPlayingPlayer();
            closeAnim.stop();
            openAnim.start();
        } else {
            openAnim.stop();
            closeAnim.start();
        }
    }

    // =========================================================================
    // VISIBLE FLOATING CARD CONTAINER
    // =========================================================================
    Item {
        id: content
        anchors.fill: parent
        opacity: 0.0

        transform: Translate {
            id: contentTranslate
            x: 430
        }

        // Floating Card Body (solid opaque surface, 12px inset from screen edge)
        Rectangle {
            id: cardBody
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 12
            height: parent.height
            radius: Island.Theme.radiusCard
            color: Island.Theme.glassBackground
            border.color: Island.Theme.glassBorder
            border.width: 1
            clip: true

            HoverHandler {
                id: cardHoverHandler
            }

            // =================================================================
            // FULL-WIDGET BOTTOM-UP AUDIO VISUALIZER
            // Spans the entire width and covers the card from the bottom up!
            // =================================================================
            Item {
                id: visualizerLayer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.88
                clip: true
                z: 0
                opacity: (root.activePlayer && root.activePlayer.isPlaying) ? 0.38 : 0.08

                Behavior on opacity {
                    NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                }

                Canvas {
                    id: visualizerCanvas
                    anchors.fill: parent
                    anchors.margins: 4
                    renderTarget: Canvas.FramebufferObject
                    renderStrategy: Canvas.Threaded

                    property real animPhase: 0.0
                    property var barHeights: []

                    Component.onCompleted: {
                        const arr = [];
                        for (let i = 0; i < 40; ++i) arr.push(6.0);
                        barHeights = arr;
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        const isPlaying = Boolean(root.activePlayer && root.activePlayer.isPlaying);
                        const count = 40;
                        const spacing = 3;
                        const barW = Math.max(3, (width - (count - 1) * spacing) / count);
                        const lvls = (Island.IslandHub && Island.IslandHub.levels) ? Island.IslandHub.levels : [0.1, 0.1, 0.1, 0.1];

                        for (let i = 0; i < count; ++i) {
                            const x = i * (barW + spacing);
                            const slot = Math.min(3, Math.floor(i / 10));
                            const audioLvl = lvls[slot] || 0.1;

                            let targetH = 6;
                            if (isPlaying) {
                                const h1 = Math.sin((i * 0.28) + animPhase);
                                const h2 = Math.cos((i * 0.42) - (animPhase * 0.7));
                                const wave = (h1 * 0.5 + h2 * 0.3 + 0.8) * 0.5;
                                const amp = Math.max(0.08, Math.min(1.0, (audioLvl * 0.75) + (wave * 0.45)));
                                targetH = Math.max(8, height * amp);
                            }

                            let currentH = barHeights[i] || 6;
                            if (targetH > currentH) {
                                currentH = currentH * 0.45 + targetH * 0.55;
                            } else {
                                currentH = currentH * 0.86 + targetH * 0.14;
                            }
                            barHeights[i] = currentH;

                            const y = height - currentH;

                            const grad = ctx.createLinearGradient(0, y, 0, height);
                            grad.addColorStop(0.0, Island.Theme.aqua);
                            grad.addColorStop(0.45, Island.Theme.primary);
                            grad.addColorStop(1.0, "rgba(184, 104, 180, 0.2)");

                            ctx.fillStyle = grad;

                            ctx.beginPath();
                            const r = barW / 2;
                            ctx.moveTo(x + r, y);
                            ctx.lineTo(x + barW - r, y);
                            ctx.quadraticCurveTo(x + barW, y, x + barW, y + r);
                            ctx.lineTo(x + barW, height);
                            ctx.lineTo(x, height);
                            ctx.lineTo(x, y + r);
                            ctx.quadraticCurveTo(x, y, x + r, y);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }
                }

                // Smooth 60 FPS animation ticker (16ms)
                Timer {
                    id: visualizerTimer
                    interval: 16 // 60 FPS
                    running: root.open && Boolean(root.activePlayer && root.activePlayer.isPlaying)
                    repeat: true
                    onTriggered: {
                        visualizerCanvas.animPhase += 0.08;
                        visualizerCanvas.requestPaint();
                    }
                }
            }

            // Subtle dark-gradient scrim to preserve contrast on upper text & buttons
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                z: 1
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(Island.Theme.bg0.r, Island.Theme.bg0.g, Island.Theme.bg0.b, 0.75) }
                    GradientStop { position: 0.45; color: Qt.rgba(Island.Theme.bg0.r, Island.Theme.bg0.g, Island.Theme.bg0.b, 0.40) }
                    GradientStop { position: 1.0; color: Qt.rgba(Island.Theme.bg0.r, Island.Theme.bg0.g, Island.Theme.bg0.b, 0.15) }
                }
            }

            // =================================================================
            // FOREGROUND UI CONTROLS & CONTENT
            // =================================================================
            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                z: 2

                // -------------------------------------------------------------
                // 1. MEDIA SOURCE SWITCHER BAR (TABS / PILLS)
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: 28

                    // Left: Section Title or Multi-Media Pills
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // Source pill list
                        Repeater {
                            model: root.allPlayers

                            delegate: Rectangle {
                                id: playerPill
                                required property var modelData
                                required property int index

                                readonly property bool isSelected: root.selectedPlayerIndex === index
                                readonly property bool isPlaying: modelData ? modelData.isPlaying : false
                                readonly property string pName: modelData ? (modelData.identity || modelData.desktopEntry || "Media") : "Media"

                                height: 26
                                implicitWidth: pillContent.implicitWidth + 16
                                radius: 13
                                color: isSelected 
                                    ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.28)
                                    : (pillHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard)
                                border.color: isSelected ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                border.width: 1
                                scale: pillTap.pressed ? 0.94 : 1.0

                                Behavior on scale { NumberAnimation { duration: 70 } }
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Row {
                                    id: pillContent
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: root.playerIcon(playerPill.pName)
                                        font.family: Island.Theme.iconFontFamily
                                        font.pixelSize: 12
                                        color: playerPill.isSelected ? Island.Theme.primary : (playerPill.isPlaying ? Island.Theme.green : Island.Theme.muted)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: playerPill.pName
                                        font.family: Island.Theme.fontFamily
                                        font.pixelSize: 10
                                        font.bold: playerPill.isSelected
                                        color: playerPill.isSelected ? Island.Theme.foreground : Island.Theme.muted
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // Active Playing Pulsing Dot
                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: Island.Theme.green
                                        visible: playerPill.isPlaying
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                HoverHandler { id: pillHover }
                                TapHandler {
                                    id: pillTap
                                    onTapped: {
                                        root.selectedPlayerIndex = playerPill.index;
                                    }
                                }
                            }
                        }

                        // Fallback Title when no players are detected
                        Text {
                            visible: root.allPlayers.length === 0
                            text: "Media Control"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: Island.Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Right: Cycle Controls (< > arrows when 2+ players exist)
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        visible: root.allPlayers.length > 1

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: prevSrcHover.hovered ? Island.Theme.glassCardHover : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰅁"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 11
                                color: prevSrcHover.hovered ? Island.Theme.foreground : Island.Theme.muted
                            }
                            HoverHandler { id: prevSrcHover }
                            TapHandler { onTapped: root.selectPreviousPlayer() }
                        }

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: nextSrcHover.hovered ? Island.Theme.glassCardHover : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 11
                                color: nextSrcHover.hovered ? Island.Theme.foreground : Island.Theme.muted
                            }
                            HoverHandler { id: nextSrcHover }
                            TapHandler { onTapped: root.selectNextPlayer() }
                        }
                    }
                }

                // -------------------------------------------------------------
                // 2. ACTIVE TRACK DISPLAY & ARTWORK
                // -------------------------------------------------------------
                Item {
                    width: parent.width
                    height: 74
                    visible: root.activePlayer !== null

                    Row {
                        anchors.fill: parent
                        spacing: 12

                        // Cover Artwork (68x68 Squircle)
                        Rectangle {
                            id: albumBox
                            width: 68
                            height: 68
                            radius: 16
                            color: Qt.rgba(1, 1, 1, 0.08)
                            border.color: Island.Theme.glassBorderSubtle
                            border.width: 1
                            clip: true
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                id: coverImg
                                anchors.fill: parent
                                source: root.activePlayer ? (root.activePlayer.trackArtUrl || "") : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            // Fallback Icon when artwork is unavailable
                            Text {
                                anchors.centerIn: parent
                                visible: coverImg.status !== Image.Ready
                                text: root.playerIcon(root.activePlayer ? root.activePlayer.identity : "")
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 30
                                color: Island.Theme.primary
                            }
                        }

                        // Track Metadata Column
                        Column {
                            width: parent.width - 68 - 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            // Player Badge
                            Row {
                                spacing: 5
                                Text {
                                    text: root.playerIcon(root.activePlayer ? root.activePlayer.identity : "")
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 11
                                    color: Island.Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.activePlayer ? (root.activePlayer.identity || "Media Player") : "Media"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Island.Theme.muted
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Track Title
                            Text {
                                width: parent.width
                                text: root.activePlayer ? (root.activePlayer.trackTitle || "Untitled Track") : "Nothing Playing"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                color: Island.Theme.foreground
                                elide: Text.ElideRight
                            }

                            // Track Artist
                            Text {
                                width: parent.width
                                text: root.activePlayer ? (root.activePlayer.trackArtist || root.activePlayer.trackAlbum || "Unknown Artist") : "Standby"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 11
                                color: Island.Theme.muted
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Standby Card when no player exists
                Item {
                    width: parent.width
                    height: 74
                    visible: root.activePlayer === null

                    Row {
                        anchors.fill: parent
                        spacing: 14

                        Rectangle {
                            width: 60
                            height: 60
                            radius: 16
                            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.12)
                            border.color: Island.Theme.glassBorderSubtle
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "󰎆"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 28
                                color: Island.Theme.primary
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 60 - 14
                            spacing: 4

                            Text {
                                text: "No Active Media"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: Island.Theme.foreground
                            }

                            Text {
                                text: "Start playing music in Spotify or browser."
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 10
                                color: Island.Theme.muted
                            }

                            Rectangle {
                                height: 24
                                implicitWidth: launchBtnText.implicitWidth + 20
                                radius: 12
                                color: launchHover.hovered ? Island.Theme.primary : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.85)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        text: "󰓇"
                                        font.family: Island.Theme.iconFontFamily
                                        font.pixelSize: 10
                                        color: Island.Theme.bg0
                                    }
                                    Text {
                                        id: launchBtnText
                                        text: "Open Spotify"
                                        font.family: Island.Theme.fontFamily
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: Island.Theme.bg0
                                    }
                                }

                                HoverHandler { id: launchHover }
                                TapHandler {
                                    onTapped: launchSpotifyProc.running = true
                                }
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // 3. CURVY FLUID PROGRESS LINE (CANVAS S-CURVE SPLINE)
                // -------------------------------------------------------------
                Row {
                    width: parent.width
                    height: 22
                    spacing: 8
                    visible: root.activePlayer !== null

                    // Current Position
                    Text {
                        text: root.formatDuration(root.activePlayer ? root.activePlayer.position : 0)
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 9
                        color: Island.Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        horizontalAlignment: Text.AlignRight
                    }

                    // Curvy Canvas Progress Track
                    Canvas {
                        id: curvyProgressCanvas
                        width: parent.width - 60 - 16
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter

                        readonly property real currentPosition: root.activePlayer ? root.activePlayer.position : 0
                        readonly property real totalLength: root.activePlayer ? root.activePlayer.length : 0
                        readonly property real fraction: (totalLength > 0) ? Math.max(0.0, Math.min(1.0, currentPosition / totalLength)) : 0.0

                        onFractionChanged: requestPaint()
                        onWidthChanged: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            const midY = height / 2;
                            const totalW = width;
                            const headX = totalW * fraction;

                            // 1. Draw Curvy Background Guide Wave
                            ctx.beginPath();
                            for (let x = 0; x <= totalW; x += 3) {
                                // Gentle smooth sinusoidal wave
                                const y = midY + Math.sin((x / totalW) * Math.PI * 4) * 3.5;
                                if (x === 0) ctx.moveTo(x, y);
                                else ctx.lineTo(x, y);
                            }
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.16)";
                            ctx.lineWidth = 3.5;
                            ctx.lineCap = "round";
                            ctx.stroke();

                            // 2. Draw Active Curvy Progress Line
                            if (headX > 0) {
                                ctx.beginPath();
                                for (let x = 0; x <= headX; x += 2) {
                                    const y = midY + Math.sin((x / totalW) * Math.PI * 4) * 3.5;
                                    if (x === 0) ctx.moveTo(x, y);
                                    else ctx.lineTo(x, y);
                                }
                                const grad = ctx.createLinearGradient(0, 0, headX, 0);
                                grad.addColorStop(0, Island.Theme.primary);
                                grad.addColorStop(1, Island.Theme.aqua);
                                ctx.strokeStyle = grad;
                                ctx.lineWidth = 4.5;
                                ctx.lineCap = "round";
                                ctx.stroke();

                                // 3. Curvy Glowing Scrubber Head Thumb
                                const headY = midY + Math.sin((headX / totalW) * Math.PI * 4) * 3.5;
                                ctx.beginPath();
                                ctx.arc(headX, headY, 5, 0, Math.PI * 2);
                                ctx.fillStyle = "#ffffff";
                                ctx.fill();

                                // Outer subtle glow ring
                                ctx.beginPath();
                                ctx.arc(headX, headY, 8, 0, Math.PI * 2);
                                ctx.fillStyle = Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.35);
                                ctx.fill();
                            }
                        }

                        HoverHandler { id: curvyHover }
                        TapHandler {
                            onTapped: (event) => {
                                if (root.activePlayer && root.activePlayer.positionSupported && root.activePlayer.length > 0) {
                                    const clickFrac = Math.max(0, Math.min(1, event.position.x / curvyProgressCanvas.width));
                                    root.activePlayer.position = root.activePlayer.length * clickFrac;
                                    curvyProgressCanvas.requestPaint();
                                }
                            }
                        }
                    }

                    // Total Length
                    Text {
                        text: root.formatDuration(root.activePlayer ? root.activePlayer.length : 0)
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 9
                        color: Island.Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                    }
                }

                // -------------------------------------------------------------
                // 4. PLAYBACK CONTROLS (OPTIONS: BACK, PAUSE, NEXT)
                // -------------------------------------------------------------
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 20
                    visible: root.activePlayer !== null

                    // Back / Previous track
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool canPrev: root.activePlayer ? root.activePlayer.canGoPrevious : false
                        color: prevHover.hovered ? Island.Theme.glassCardHover : Qt.rgba(1, 1, 1, 0.04)
                        border.color: prevHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle
                        border.width: 1
                        opacity: canPrev ? 1.0 : 0.4
                        scale: prevTap.pressed ? 0.92 : (prevHover.hovered ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 80 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒮"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 16
                            color: prevHover.hovered ? Island.Theme.foreground : Island.Theme.muted
                        }

                        HoverHandler { id: prevHover }
                        TapHandler {
                            id: prevTap
                            enabled: parent.canPrev
                            onTapped: {
                                if (root.activePlayer && root.activePlayer.canGoPrevious) {
                                    root.activePlayer.previous();
                                }
                            }
                        }
                    }

                    // Pause / Play toggle (Prominent center button)
                    Rectangle {
                        width: 44
                        height: 44
                        radius: 22
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool isPlaying: root.activePlayer ? root.activePlayer.isPlaying : false
                        color: playHover.hovered ? Island.Theme.primary : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.90)
                        scale: playTap.pressed ? 0.92 : (playHover.hovered ? 1.06 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 80 } }
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: parent.isPlaying ? "󰏤" : "󰐊"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 19
                            color: Island.Theme.bg0
                        }

                        HoverHandler { id: playHover }
                        TapHandler {
                            id: playTap
                            onTapped: {
                                if (!root.activePlayer) return;
                                if (root.activePlayer.canTogglePlaying) {
                                    root.activePlayer.togglePlaying();
                                } else if (root.activePlayer.isPlaying && root.activePlayer.canPause) {
                                    root.activePlayer.pause();
                                } else if (!root.activePlayer.isPlaying && root.activePlayer.canPlay) {
                                    root.activePlayer.play();
                                }
                            }
                        }
                    }

                    // Next track
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool canNext: root.activePlayer ? root.activePlayer.canGoNext : false
                        color: nextHover.hovered ? Island.Theme.glassCardHover : Qt.rgba(1, 1, 1, 0.04)
                        border.color: nextHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle
                        border.width: 1
                        opacity: canNext ? 1.0 : 0.4
                        scale: nextTap.pressed ? 0.92 : (nextHover.hovered ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 80 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒭"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 16
                            color: nextHover.hovered ? Island.Theme.foreground : Island.Theme.muted
                        }

                        HoverHandler { id: nextHover }
                        TapHandler {
                            id: nextTap
                            enabled: parent.canNext
                            onTapped: {
                                if (root.activePlayer && root.activePlayer.canGoNext) {
                                    root.activePlayer.next();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
