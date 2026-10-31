import QtQuick
import Quickshell.Services.UPower
import "components"
import "." as Island

Item {
    id: root

    property int unread: 0
    property string label: ""
    property bool micActive: false
    property bool camActive: false
    property bool recActive: false
    property int shelfCount: 0
    property string weatherMini: ""
    property bool volumeActive: false
    property string volumeText: ""
    property bool volumeMuted: false
    property string btConnected: ""
    property bool mediaPlaying: false
    property bool hasLyrics: false
    property var player: null

    implicitHeight: 36

    // UPower battery integration
    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercent: battery ? Math.round(battery.percentage * 100) : 100
    readonly property bool isCharging: battery ? (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged) : false

    // Volume Meter Takeover View
    Item {
        anchors.fill: parent
        anchors.margins: 6
        visible: root.volumeActive

        Row {
            anchors.centerIn: parent
            spacing: 8

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                source: root.volumeMuted
                    ? "assets/nectar/speaker.slash.fill.svg"
                    : (root.volumeText.replace("%","") > 50 ? "assets/nectar/speaker.wave.3.fill.svg" : "assets/nectar/speaker.wave.1.fill.svg")
                asynchronous: true
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 70
                height: 5
                radius: 2.5
                color: Qt.rgba(1, 1, 1, 0.22)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: 2.5
                    color: Island.Theme ? Island.Theme.primary : "#ffffff"
                    width: Math.max(0, Math.min(parent.width, parent.width * (parseInt(root.volumeText) || 0) / 100))

                    Behavior on width {
                        NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.volumeText
                font.family: Island.Theme ? Island.Theme.fontFamily : "Inter"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: "#ffffff"
            }
        }
    }

    // Standard 3-Segment Nectar Main Row
    Item {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        visible: !root.volumeActive

        // LEFT SEGMENT: Visualizer, Weather, Recording, or Unread Badge
        Row {
            id: leftSection
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Recording Dot with smooth pulse
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: "#ff3b30"
                visible: root.recActive

                SequentialAnimation on opacity {
                    running: root.recActive
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.3; duration: 500; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                }
            }

            // Unread Notifications Badge
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 17
                height: 17
                radius: 8.5
                color: Island.Theme ? Island.Theme.primary : "#e8799e"
                visible: root.unread > 0 && !root.recActive

                Text {
                    anchors.centerIn: parent
                    text: root.unread > 9 ? "9+" : String(root.unread)
                    font.family: Island.Theme ? Island.Theme.fontFamily : "Inter"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: "#000000"
                }
            }

            // 5-Bar Spring Audio Visualizer (when media is playing)
            NectarVisualizer {
                anchors.verticalCenter: parent.verticalCenter
                isPlaying: root.mediaPlaying
                visible: root.mediaPlaying && !root.recActive
            }

            // Weather status pill (when idle / no media playing)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                visible: !root.mediaPlaying && !root.recActive && root.weatherMini !== ""

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰖐"
                    font.family: Island.Theme ? Island.Theme.iconFontFamily : "JetBrainsMonoNL Nerd Font"
                    font.pixelSize: 12
                    color: Island.Theme ? Island.Theme.muted : "#cda3b8"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.weatherMini
                    font.family: Island.Theme ? Island.Theme.fontFamily : "Inter"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: "#ffffff"
                }
            }

            // Privacy Indicators: Mic / Cam dots
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: "#ff9500" // Orange for Mic
                visible: root.micActive
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: "#34c759" // Green for Cam
                visible: root.camActive
            }
        }

        // CENTER SEGMENT: Nectar 3D Flip Clock / Timer Counter
        NectarFlipClock {
            id: centerClock
            anchors.centerIn: parent
        }

        // RIGHT SEGMENT: Album Art Thumbnail OR Battery Shell OR Stash/Quota indicator
        Row {
            id: rightSection
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Entertainment Activity / Chess / Hotstar Dual Live Activity Quota Countdown
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 20
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.12)
                visible: Island.ShellState ? (Island.ShellState.detectedChessOpen || Island.ShellState.detectedHotstarOpen || Island.ShellState.studyPauseActive) : false
                width: Math.min(110, quotaText.implicitWidth + 16)

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!Island.ShellState) return "";
                            if (Island.ShellState.studyPauseActive) return "⏸";
                            if (Island.ShellState.detectedChessOpen) return "♟";
                            return "🍿";
                        }
                        font.pixelSize: 10
                        color: Island.Theme ? Island.Theme.yellow : "#f6c48e"
                    }
                    Text {
                        id: quotaText
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!Island.ShellState) return "";
                            if (Island.ShellState.studyPauseActive) {
                                return Island.ShellState.formatQuotaTime(Island.ShellState.studyPausedRemaining);
                            }
                            if (Island.ShellState.detectedChessOpen) {
                                return Island.ShellState.formatQuotaTime(Island.ShellState.studyChessQuotaRemaining);
                            }
                            if (Island.ShellState.detectedHotstarOpen) {
                                return Island.ShellState.formatQuotaTime(Island.ShellState.studyHotstarQuotaRemaining);
                            }
                            return "";
                        }
                        font.family: Island.Theme ? Island.Theme.fontFamily : "Inter"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                }
            }

            // Miniature Album Art (when media is active)
            Rectangle {
                id: artThumb
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: 6
                color: "#1a1a24"
                clip: true
                visible: root.mediaPlaying && root.player && root.player.trackArtUrl

                Image {
                    anchors.fill: parent
                    source: (root.player && root.player.trackArtUrl) ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            // Apple-Style Battery Icon (when not displaying album art or when plugged in)
            NectarBatteryIcon {
                anchors.verticalCenter: parent.verticalCenter
                level: root.batteryPercent
                charging: root.isCharging
                visible: !artThumb.visible || root.isCharging
            }
        }
    }
}
