import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import ".."
import "../components"

FocusScope {
    id: root

    readonly property var player: (() => {
        const players = Mpris.players.values;
        for (let i = 0; i < players.length; ++i) {
            if (players[i] && players[i].isPlaying)
                return players[i];
        }
        return players.length > 0 ? players[0] : null;
    })()
    readonly property var sink: Pipewire.defaultAudioSink

    function takeInitialFocus() {
        playButton.forceActiveFocus(Qt.TabFocusReason);
    }

    function formatDuration(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0)
            return "0:00";

        const minutes = Math.floor(seconds / 60);
        return minutes + ":" + String(Math.floor(seconds % 60)).padStart(2, "0");
    }

    implicitWidth: 492
    implicitHeight: content.implicitHeight

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

        ShellText {
            text: "Now Playing"
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        Rectangle {
            id: mediaCard

            width: parent.width
            height: 190
            radius: Theme.radius
            clip: true

            Image {
                id: mediaArtwork

                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                opacity: status === Image.Ready ? 0.26 : 0
                layer.enabled: status === Image.Ready

                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    maskEnabled: true

                    maskSource: Rectangle {
                        width: mediaArtwork.width
                        height: mediaArtwork.height
                        radius: Theme.radius
                        layer.enabled: mediaArtwork.status === Image.Ready
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationNormal
                    }

                }

            }

            Column {
                id: trackInfo
                anchors.left: parent.left
                anchors.right: controls.left
                anchors.top: parent.top
                anchors.bottom: progress.top
                anchors.margins: 12
                spacing: 3

                transform: Translate {
                    id: trackSlide
                }

                ShellText {
                    text: root.sink ? "  " + (root.sink.description || "Default output") : "  No audio output"
                    color: Theme.muted
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    width: parent.width
                }

                Item {
                    width: 1
                    height: 5
                }

                ShellText {
                    width: parent.width
                    text: root.player ? (root.player.trackTitle || "Unknown title") : "Nothing playing"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                ShellText {
                    width: parent.width
                    text: root.player ? (root.player.trackArtist || root.player.identity || "Unknown artist") : "Open a media player to begin"
                    color: Theme.muted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

            }

            Row {
                id: controls

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                IconButton {
                    width: 28
                    height: 28
                    icon: "\uf04ae"
                    accessibleName: "Previous track"
                    onClicked: {
                        if (root.player && root.player.canGoPrevious)
                            root.player.previous();

                    }
                }

                IconButton {
                    id: playButton

                    width: 42
                    height: 42
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
                    icon: "\uf04ad"
                    accessibleName: "Next track"
                    onClicked: {
                        if (root.player && root.player.canGoNext)
                            root.player.next();

                    }
                }

            }

            // Track swap: quick dip + slide so new artwork/text glides in.
            SequentialAnimation {
                id: trackSwap

                ParallelAnimation {
                    NumberAnimation {
                        target: trackInfo
                        property: "opacity"
                        to: 0
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: trackSlide
                        property: "x"
                        to: -14
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }

                PropertyAction {
                    target: trackSlide
                    property: "x"
                    value: 14
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: trackInfo
                        property: "opacity"
                        to: 1
                        duration: 180
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: trackSlide
                        property: "x"
                        to: 0
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Connections {
                target: root.player
                function onTrackTitleChanged() {
                    // Binding already swapped artwork/text; the dip covers it.
                    if (!trackSwap.running)
                        trackSwap.restart();
                }
            }

            Row {
                id: progress

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                height: 12
                spacing: 8

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.player ? root.formatDuration(root.player.position) : "0:00"
                    color: Theme.muted
                    font.pixelSize: 8
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 68
                    height: 3
                    radius: 2
                    color: Qt.rgba(0.83, 0.78, 0.67, 0.25)

                    Rectangle {
                        width: parent.width * (root.player && root.player.length > 0 ? Math.min(1, root.player.position / root.player.length) : 0)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.foreground
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.player && root.player.positionSupported && root.player.length > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPressed: (mouse) => {
                            root.player.position = root.player.length * mouse.x / width;
                        }
                    }

                }

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.player ? root.formatDuration(root.player.length) : "0:00"
                    color: Theme.muted
                    font.pixelSize: 8
                }

            }

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Theme.primaryContainer
                }

                GradientStop {
                    position: 1
                    color: Theme.bgYellow
                }

            }

        }

    }

}
