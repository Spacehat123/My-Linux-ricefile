import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../island" as Island

Rectangle {
    id: root

    width: parent ? parent.width : 340
    implicitHeight: hasTrack ? 148 : 110
    radius: Island.Theme.radiusCard
    color: Island.Theme.glassCard
    border.color: Island.Theme.glassBorderSubtle
    border.width: 1
    clip: true

    Behavior on implicitHeight {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // =========================================================================
    // Player Resolution & State Invariants
    // =========================================================================
    readonly property var spotifyPlayer: {
        const players = Mpris.players.values;
        // 1. Prefer explicit Spotify player
        for (let i = 0; i < players.length; ++i) {
            const p = players[i];
            if (p && ((p.identity && p.identity.toLowerCase().indexOf("spotify") !== -1) ||
                      (p.desktopEntry && p.desktopEntry.toLowerCase().indexOf("spotify") !== -1))) {
                return p;
            }
        }
        // 2. Fallback to any active playing player
        for (let i = 0; i < players.length; ++i) {
            if (players[i] && players[i].isPlaying) return players[i];
        }
        // 3. Fallback to first player
        return players.length > 0 ? players[0] : null;
    }

    readonly property bool isPlaying: spotifyPlayer ? spotifyPlayer.isPlaying : false
    readonly property bool hasTrack: spotifyPlayer && (Boolean(spotifyPlayer.trackTitle) || spotifyPlayer.isPlaying)
    readonly property string trackTitle: (spotifyPlayer && spotifyPlayer.trackTitle) ? spotifyPlayer.trackTitle : "Spotify"
    readonly property string trackArtist: (spotifyPlayer && spotifyPlayer.trackArtist) ? spotifyPlayer.trackArtist : "Ready to play"
    readonly property string trackArtUrl: (spotifyPlayer && spotifyPlayer.trackArtUrl) ? spotifyPlayer.trackArtUrl : ""
    readonly property real position: (spotifyPlayer && spotifyPlayer.position) ? spotifyPlayer.position : 0
    readonly property real length: (spotifyPlayer && spotifyPlayer.length > 0) ? spotifyPlayer.length : 0

    function formatDuration(sec) {
        if (!Number.isFinite(sec) || sec < 0) return "0:00";
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Timer {
        interval: 1000
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.spotifyPlayer && root.spotifyPlayer.positionChanged) {
                root.spotifyPlayer.positionChanged();
            }
        }
    }

    // Launch & focus processes
    Process {
        id: launchProcess
        command: ["sh", "-c", "spotify-launcher &"]
    }

    Process {
        id: focusProcess
        command: ["hyprctl", "dispatch", "focuswindow", "class:spotify"]
    }

    function launchOrFocusSpotify() {
        if (root.spotifyPlayer) {
            focusProcess.running = true;
        } else {
            launchProcess.running = true;
        }
    }

    // Ambient glow gradient behind widget
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        opacity: root.isPlaying ? 0.08 : 0.03
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Island.Theme.primary }
            GradientStop { position: 1.0; color: Island.Theme.green }
        }
    }

    // =========================================================================
    // CONTENT: ACTIVE PLAYBACK CARD
    // =========================================================================
    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10
        visible: root.hasTrack

        // Top Row: Album Art + Track Info + Launch Button
        Row {
            width: parent.width
            height: 64
            spacing: 12

            // Squircle Album Art Container
            Rectangle {
                id: artBox
                width: 64
                height: 64
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: Island.Theme.glassBorderSubtle
                border.width: 1
                clip: true

                Image {
                    id: albumCover
                    anchors.fill: parent
                    source: root.trackArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                // Fallback / Loading Spotify Icon
                Text {
                    anchors.centerIn: parent
                    visible: albumCover.status !== Image.Ready
                    text: "󰓇"
                    font.family: Island.Theme.iconFontFamily
                    font.pixelSize: 28
                    color: Island.Theme.primary
                }

                // Subtle inner gloss border
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1
                }
            }

            // Middle Column: Title & Artist + Spotify Tag
            Column {
                width: parent.width - 64 - 12 - 32
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Row {
                    spacing: 6
                    Text {
                        text: "󰓇"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 11
                        color: Island.Theme.green
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Spotify • Spicetify"
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                        color: Island.Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    width: parent.width
                    text: root.trackTitle
                    font.family: Island.Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: Island.Theme.foreground
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.trackArtist
                    font.family: Island.Theme.fontFamily
                    font.pixelSize: 11
                    color: Island.Theme.muted
                    elide: Text.ElideRight
                }
            }

            // Quick App Focus Button
            Rectangle {
                width: 28
                height: 28
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: appFocusHover.hovered ? Island.Theme.glassCardHover : "transparent"
                border.color: appFocusHover.hovered ? Island.Theme.glassBorder : "transparent"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰄛"
                    font.family: Island.Theme.iconFontFamily
                    font.pixelSize: 13
                    color: appFocusHover.hovered ? Island.Theme.primary : Island.Theme.muted
                }

                HoverHandler { id: appFocusHover }
                TapHandler {
                    onTapped: root.launchOrFocusSpotify()
                }
            }
        }

        // Middle Row: Interactive Progress Slider
        Row {
            width: parent.width
            height: 14
            spacing: 8

            Text {
                text: root.formatDuration(root.position)
                font.family: Island.Theme.fontFamily
                font.pixelSize: 9
                color: Island.Theme.muted
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                horizontalAlignment: Text.AlignRight
            }

            // Scrub Bar Track
            Rectangle {
                id: scrubBar
                width: parent.width - 56 - 16
                height: 4
                radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.12)

                // Fill Bar
                Rectangle {
                    width: parent.width * (root.length > 0 ? Math.min(1.0, Math.max(0.0, root.position / root.length)) : 0.0)
                    height: parent.height
                    radius: parent.radius
                    color: scrubHover.hovered ? Island.Theme.primary : Island.Theme.foreground

                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                HoverHandler { id: scrubHover }
                TapHandler {
                    onTapped: (event) => {
                        if (root.spotifyPlayer && root.spotifyPlayer.positionSupported && root.length > 0) {
                            const newPos = root.length * (event.position.x / scrubBar.width);
                            root.spotifyPlayer.position = Math.max(0, Math.min(root.length, newPos));
                        }
                    }
                }
            }

            Text {
                text: root.formatDuration(root.length)
                font.family: Island.Theme.fontFamily
                font.pixelSize: 9
                color: Island.Theme.muted
                anchors.verticalCenter: parent.verticalCenter
                width: 28
            }
        }

        // Bottom Row: Media Control Buttons
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            // Previous Button
            Rectangle {
                width: 30
                height: 30
                radius: 15
                anchors.verticalCenter: parent.verticalCenter
                color: prevHover.hovered ? Island.Theme.glassCardHover : "transparent"
                border.color: prevHover.hovered ? Island.Theme.glassBorder : "transparent"
                border.width: 1
                scale: prevTap.pressed ? 0.92 : (prevHover.hovered ? 1.08 : 1.0)
                Behavior on scale { NumberAnimation { duration: 80 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    font.family: Island.Theme.iconFontFamily
                    font.pixelSize: 15
                    color: prevHover.hovered ? Island.Theme.foreground : Island.Theme.muted
                }

                HoverHandler { id: prevHover }
                TapHandler {
                    id: prevTap
                    onTapped: {
                        if (root.spotifyPlayer && root.spotifyPlayer.canGoPrevious) {
                            root.spotifyPlayer.previous();
                        }
                    }
                }
            }

            // Play / Pause Button (Prominent)
            Rectangle {
                width: 38
                height: 38
                radius: 19
                anchors.verticalCenter: parent.verticalCenter
                color: playHover.hovered ? Island.Theme.primary : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.88)
                scale: playTap.pressed ? 0.92 : (playHover.hovered ? 1.06 : 1.0)
                Behavior on scale { NumberAnimation { duration: 80 } }
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: root.isPlaying ? "󰏤" : "󰐊"
                    font.family: Island.Theme.iconFontFamily
                    font.pixelSize: 17
                    color: Island.Theme.bg0
                }

                HoverHandler { id: playHover }
                TapHandler {
                    id: playTap
                    onTapped: {
                        if (root.spotifyPlayer && root.spotifyPlayer.canTogglePlaying) {
                            root.spotifyPlayer.togglePlaying();
                        } else if (root.spotifyPlayer && root.spotifyPlayer.canPlay) {
                            root.spotifyPlayer.play();
                        }
                    }
                }
            }

            // Next Button
            Rectangle {
                width: 30
                height: 30
                radius: 15
                anchors.verticalCenter: parent.verticalCenter
                color: nextHover.hovered ? Island.Theme.glassCardHover : "transparent"
                border.color: nextHover.hovered ? Island.Theme.glassBorder : "transparent"
                border.width: 1
                scale: nextTap.pressed ? 0.92 : (nextHover.hovered ? 1.08 : 1.0)
                Behavior on scale { NumberAnimation { duration: 80 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    font.family: Island.Theme.iconFontFamily
                    font.pixelSize: 15
                    color: nextHover.hovered ? Island.Theme.foreground : Island.Theme.muted
                }

                HoverHandler { id: nextHover }
                TapHandler {
                    id: nextTap
                    onTapped: {
                        if (root.spotifyPlayer && root.spotifyPlayer.canGoNext) {
                            root.spotifyPlayer.next();
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // CONTENT: STANDBY / LAUNCH CARD (WHEN IDLE OR STOPPED)
    // =========================================================================
    Row {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14
        visible: !root.hasTrack

        // Spotify Logo Capsule
        Rectangle {
            width: 56
            height: 56
            radius: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.14)
            border.color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.3)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "󰓇"
                font.family: Island.Theme.iconFontFamily
                font.pixelSize: 28
                color: Island.Theme.primary
            }
        }

        // Info & Action Column
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 56 - 14
            spacing: 5

            Row {
                spacing: 6
                Text {
                    text: "Spotify"
                    font.family: Island.Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    color: Island.Theme.foreground
                }
                Rectangle {
                    height: 16
                    width: 54
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.2)
                    border.color: Island.Theme.green
                    border.width: 0.5
                    Text {
                        anchors.centerIn: parent
                        text: "Spicetify"
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                        color: Island.Theme.green
                    }
                }
            }

            Text {
                text: "Sleek Cherry theme ready • High fidelity audio"
                font.family: Island.Theme.fontFamily
                font.pixelSize: 10
                color: Island.Theme.muted
                elide: Text.ElideRight
                width: parent.width
            }

            Row {
                spacing: 8
                topPadding: 2

                Rectangle {
                    height: 26
                    implicitWidth: launchText.implicitWidth + 24
                    radius: 13
                    color: launchBtnHover.hovered ? Island.Theme.primary : Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.85)
                    scale: launchBtnTap.pressed ? 0.94 : 1.0

                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: root.spotifyPlayer ? "󰐊" : "󰐊"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 10
                            color: Island.Theme.bg0
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: launchText
                            text: root.spotifyPlayer ? "Resume Playback" : "Open Spotify"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: Island.Theme.bg0
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: launchBtnHover }
                    TapHandler {
                        id: launchBtnTap
                        onTapped: {
                            if (root.spotifyPlayer && root.spotifyPlayer.canPlay) {
                                root.spotifyPlayer.play();
                            } else {
                                root.launchOrFocusSpotify();
                            }
                        }
                    }
                }
            }
        }
    }
}
