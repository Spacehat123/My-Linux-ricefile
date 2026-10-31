import QtQuick
import Quickshell.Services.Mpris
import "components"
import "." as Island

Item {
    id: root

    property var player: null
    property bool volumeExpanded: false

    implicitWidth: 320
    implicitHeight: volumeExpanded ? 156 : 120

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 360
            easing.type: Easing.OutBack
            easing.overshoot: 1.22
        }
    }

    readonly property string trackTitle: player ? (player.trackTitle || "No Media Playing") : "No Media Playing"
    readonly property string trackArtist: player ? (player.trackArtist || "Unknown Artist") : "Apple Dynamic Island"
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property bool isPlaying: player ? player.isPlaying : false
    readonly property real durationSec: player && player.length > 0 ? (player.length / 1000.0) : 0
    readonly property real positionSec: player && player.position >= 0 ? (player.position / 1000.0) : 0
    readonly property real progressFraction: durationSec > 0 ? Math.max(0, Math.min(1.0, positionSec / durationSec)) : 0

    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec <= 0) return "0:00";
        let m = Math.floor(sec / 60);
        let s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" + s : s);
    }

    function formatRemaining(pos, dur) {
        if (!dur || dur <= 0) return "-0:00";
        let rem = Math.max(0, dur - pos);
        return "-" + formatTime(rem);
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // ROW 1: Album Art + Track Info + 5-Bar Visualizer
        Row {
            width: parent.width
            height: 48
            spacing: 10

            // Album Art with 3D Y-Axis Flip
            Rectangle {
                id: artBox
                width: 48
                height: 48
                radius: 10
                color: "#181822"
                clip: true

                transform: Rotation {
                    id: artRotY
                    origin.x: 24
                    origin.y: 24
                    axis { x: 0; y: 1; z: 0 }
                    angle: 0
                }

                Image {
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                // Placeholder if no art
                Item {
                    anchors.fill: parent
                    visible: root.artUrl === ""

                    Image {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: "assets/nectar/music.note.svg"
                    }
                }

                Connections {
                    target: root
                    function onArtUrlChanged() {
                        flipAnim.restart();
                    }
                }

                SequentialAnimation {
                    id: flipAnim
                    NumberAnimation { target: artRotY; property: "angle"; to: 90; duration: 140; easing.type: Easing.InCubic }
                    NumberAnimation { target: artRotY; property: "angle"; from: -90; to: 0; duration: 160; easing.type: Easing.OutCubic }
                }
            }

            // Track Title & Artist (Marquee if needed)
            Column {
                width: parent.width - 48 - 10 - visualizerBox.width - 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                clip: true

                Item {
                    width: parent.width
                    height: 18
                    clip: true

                    Text {
                        id: titleText
                        text: root.trackTitle
                        font.family: Island.Theme ? Island.Theme.fontFamily : "Inter"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: "#ffffff"

                        readonly property bool overflows: implicitWidth > parent.width

                        SequentialAnimation on x {
                            running: titleText.overflows
                            loops: Animation.Infinite
                            PauseAnimation { duration: 1500 }
                            NumberAnimation {
                                from: 0
                                to: -(titleText.implicitWidth - titleText.parent.width)
                                duration: Math.max(2000, (titleText.implicitWidth - titleText.parent.width) * 35)
                                easing.type: Easing.Linear
                            }
                            PauseAnimation { duration: 1500 }
                            NumberAnimation {
                                to: 0
                                duration: 500
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: root.trackArtist
                    font.family: Island.Theme ? Island.Theme.fontFamily : "Inter"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Qt.rgba(1, 1, 1, 0.60)
                    elide: Text.ElideRight
                }
            }

            // Visualizer Container
            Item {
                id: visualizerBox
                width: 28
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                NectarVisualizer {
                    anchors.centerIn: parent
                    isPlaying: root.isPlaying
                }
            }
        }

        // ROW 2: Live Progress Bar with Time Stamps
        Column {
            width: parent.width
            spacing: 4

            Rectangle {
                id: progressBar
                width: parent.width
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.18)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: 2
                    color: Island.Theme ? Island.Theme.primary : "#ffffff"
                    width: Math.max(0, Math.min(parent.width, parent.width * root.progressFraction))

                    Behavior on width {
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (root.player && root.durationSec > 0) {
                            let frac = mouse.x / parent.width;
                            let newPosMs = frac * (root.durationSec * 1000);
                            try {
                                root.player.position = newPosMs;
                            } catch (e) {}
                        }
                    }
                }
            }

            Row {
                width: parent.width
                Text {
                    text: root.formatTime(root.positionSec)
                    font.family: Island.Theme ? Island.Theme.fontFamily : "Inter"
                    font.pixelSize: 9
                    color: Qt.rgba(1, 1, 1, 0.50)
                }
                Item { width: parent.width - 60 }
                Text {
                    text: root.formatRemaining(root.positionSec, root.durationSec)
                    font.family: Island.Theme ? Island.Theme.fontFamily : "Inter"
                    font.pixelSize: 9
                    color: Qt.rgba(1, 1, 1, 0.50)
                }
            }
        }

        // ROW 3: Interactive Controls (Previous, Play/Pause, Next, Volume Drawer Toggle)
        Row {
            width: parent.width
            height: 32
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24

            // Skip Back Button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: "assets/nectar/backward.fill.svg"
                }

                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Island.IslandHub) Island.IslandHub.mediaPrevious();
                    }
                }
            }

            // Play / Pause Floating Pill
            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: playArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                anchors.verticalCenter: parent.verticalCenter
                scale: playArea.pressed ? 0.92 : (playArea.containsMouse ? 1.06 : 1.0)

                Behavior on scale {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.30
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: root.isPlaying ? "assets/nectar/pause.fill.svg" : "assets/nectar/play.fill.svg"
                }

                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Island.IslandHub) Island.IslandHub.mediaPlayPause();
                    }
                }
            }

            // Skip Forward Button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: "assets/nectar/forward.fill.svg"
                }

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Island.IslandHub) Island.IslandHub.mediaNext();
                    }
                }
            }

            // Volume Drawer Toggle Button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: root.volumeExpanded ? Qt.rgba(1, 1, 1, 0.18) : (volBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.centerIn: parent
                    width: 15
                    height: 15
                    source: "assets/nectar/speaker.wave.2.fill.svg"
                }

                MouseArea {
                    id: volBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.volumeExpanded = !root.volumeExpanded
                }
            }
        }

        // ROW 4: Collapsible Volume Slider Drawer
        Row {
            width: parent.width
            height: 28
            spacing: 8
            visible: root.volumeExpanded
            opacity: root.volumeExpanded ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                source: "assets/nectar/speaker.wave.1.fill.svg"
            }

            Rectangle {
                id: volTrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.18)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: 3
                    color: Island.Theme ? Island.Theme.primary : "#ffffff"
                    width: Math.max(0, Math.min(parent.width, parent.width * (Island.IslandHub ? Island.IslandHub.volumePercent : 50) / 100))
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        let pct = Math.round((mouse.x / parent.width) * 100);
                        if (Island.IslandHub) Island.IslandHub.adjustVolume(pct - Island.IslandHub.volumePercent);
                    }
                }
            }

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                source: "assets/nectar/speaker.wave.3.fill.svg"
            }
        }
    }
}
