import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../island" as Island

Item {
    id: root

    property bool active: true
    implicitWidth: 520
    implicitHeight: 180

    // Authoritative Media State from IslandHub and MPRIS
    readonly property var activePlayer: Mpris.players ? Mpris.players.values.find(p => p && p.playbackState === MprisPlaybackState.Playing) || (Mpris.players.values.length > 0 ? Mpris.players.values[0] : null) : null
    readonly property bool isPlaying: Island.IslandHub ? Island.IslandHub.mediaPlaying : (activePlayer ? activePlayer.playbackState === MprisPlaybackState.Playing : false)
    readonly property string trackTitle: Island.IslandHub && Island.IslandHub.mediaTitle ? Island.IslandHub.mediaTitle : (activePlayer ? (activePlayer.trackTitle || "") : "")
    readonly property string trackArtist: Island.IslandHub && Island.IslandHub.mediaArtist ? Island.IslandHub.mediaArtist : (activePlayer ? (activePlayer.trackArtist || "") : "")
    readonly property string liveLyric: Island.IslandHub ? Island.IslandHub.liveLyric : ""

    property string currentLyricDisplay: ""
    property string previousLyricDisplay: ""

    onLiveLyricChanged: {
        if (liveLyric && liveLyric.trim() !== "" && liveLyric !== currentLyricDisplay) {
            previousLyricDisplay = currentLyricDisplay;
            currentLyricDisplay = liveLyric.trim();
            slideAnim.restart();
        }
    }

    // =========================================================================
    // BORDERLESS LIVE MUSIC LYRICS & AMBIENT HUD
    // (ZERO CARDS, FLOATING ETHEREAL TYPOGRAPHY)
    // =========================================================================
    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: 10

        // TOP ROW: Track metadata & Equalizer / Wave indicator
        Row {
            anchors.right: parent.right
            spacing: 10

            // Equalizer Wave bars when playing
            Row {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                visible: root.isPlaying

                Repeater {
                    model: 4
                    Rectangle {
                        id: eqBar
                        width: 3
                        height: 12
                        radius: 1.5
                        color: Island.Theme.primary
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on height {
                            loops: Animation.Infinite
                            running: root.isPlaying && root.active
                            NumberAnimation { to: 4 + (index * 3); duration: 250 + (index * 70); easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 16 - (index * 2); duration: 280 + (index * 50); easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 8; duration: 200 + (index * 60); easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }

            // Track & Artist Tag (Borderless, floating)
            Row {
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: root.isPlaying ? "󰎆" : "󰓇"
                    font.family: Island.Theme.iconFontFamily
                    font.pixelSize: 13
                    color: root.isPlaying ? Island.Theme.primary : Island.Theme.muted
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: root.trackTitle !== "" ? (root.trackTitle + (root.trackArtist !== "" ? ("  •  " + root.trackArtist) : "")) : "Ambient Audio"
                    font.family: Island.Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: Island.Theme.foreground
                    elide: Text.ElideLeft
                    maximumLineCount: 1
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // MIDDLE / PRIMARY: Live Kinetic Synchronized Lyric
        Item {
            anchors.right: parent.right
            width: parent.width
            height: 64
            clip: true

            Item {
                id: lyricContainer
                anchors.fill: parent

                // Primary glowing live lyric line
                Text {
                    id: currLyricText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (root.isPlaying) {
                            if (root.currentLyricDisplay !== "") return root.currentLyricDisplay;
                            if (root.liveLyric !== "") return root.liveLyric;
                            return "♪ Instrumental or syncing lyrics...";
                        }
                        return "Silence is the space between notes";
                    }
                    font.family: Island.Theme.fontFamily
                    font.pixelSize: 22
                    font.bold: true
                    color: root.isPlaying ? Island.Theme.foreground : Island.Theme.muted
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    maximumLineCount: 2
                    wrapMode: Text.Wrap

                    transform: Translate {
                        id: lyricTranslate
                        y: 0
                    }
                }
            }

            ParallelAnimation {
                id: slideAnim
                NumberAnimation {
                    target: lyricTranslate
                    property: "y"
                    from: 14
                    to: 0
                    duration: 240
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: currLyricText
                    property: "opacity"
                    from: 0.3
                    to: 1.0
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
        }

        // SUBTITLE / FOOTER: Ethereal hint or previous lyric
        Text {
            anchors.right: parent.right
            text: {
                if (root.isPlaying && root.previousLyricDisplay !== "") {
                    return root.previousLyricDisplay;
                }
                return root.isPlaying ? "STREAMING LIVE LYRICS" : "PLAY MEDIA TO STREAM SYNCED LYRICS";
            }
            font.family: Island.Theme.fontFamily
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 1.8
            color: Island.Theme.muted
            opacity: 0.65
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
    }
}
