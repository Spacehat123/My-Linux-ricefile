
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../island" as Island

PanelWindow {
    id: root

    property var screen: null
    property bool showing: false
    property string osdType: "volume"
    property real osdValue: 0.0
    property bool osdMuted: false
    property bool initialized: false

    anchors {
        bottom: true
    }

    margins {
        bottom: 84
    }

    implicitWidth: 180
    implicitHeight: 38

    color: "transparent"
    visible: showing || osdCard.opacity > 0.01

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false

    WlrLayershell.namespace: "pranc-shell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {}

    readonly property var sinkAudio:
    Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

    Timer {
        id: dismissTimer
        interval: 1500
        repeat: false
        onTriggered: root.showing = false
    }

    Timer {
        interval: 1200
        running: true
        repeat: false
        onTriggered: root.initialized = true
    }

    function triggerOsd(type, val, muted) {
        if (!root.initialized) return;

        root.osdType = type;
        root.osdValue = Math.max(0.0, Math.min(1.0, val));
        root.osdMuted = Boolean(muted);
        root.showing = true;
        dismissTimer.restart();
    }

    Connections {
        target: typeof shellRoot !== "undefined" ? shellRoot : null

        function onRequestOsd(type, val, muted) {
            root.triggerOsd(type, val, muted);
        }
    }

    Connections {
        target: root.sinkAudio

        function onVolumeChanged() {
            if (root.sinkAudio) {
                root.triggerOsd(
                    "volume",
                    root.sinkAudio.volume,
                    root.sinkAudio.muted
                );
            }
        }

        function onMutedChanged() {
            if (root.sinkAudio) {
                root.triggerOsd(
                    "volume",
                    root.sinkAudio.volume,
                    root.sinkAudio.muted
                );
            }
        }
    }

    Process {
        id: backlightMonitor
        command: ["bash", "-c", "udevadm monitor -u -s backlight"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                if (data.indexOf("change") !== -1 ||
                    data.indexOf("backlight") !== -1) {
                    if (!brightnessFetchProc.running)
                        brightnessFetchProc.running = true;
                    }
            }
        }
    }

    Process {
        id: brightnessFetchProc

        command: [
            "bash",
            Quickshell.shellPath("island/scripts/shell-actions.sh"),
            "brightness-get"
        ]

        running: false

        stdout: SplitParser {
            onRead: data => {
                const b = parseInt(data.trim(), 10);

                if (!isNaN(b)) {
                    if (Island.Backend)
                        Island.Backend.brightness = b;

                    root.triggerOsd("brightness", b / 100.0, false);
                }
            }
        }
    }

    // Compact frosted-glass OSD

    Rectangle {
        id: osdCard

        anchors.centerIn: parent

        width: 180
        height: 38
        radius: 15

        // Midnight glass tint — 80% opacity
        color: "#99171824"

        border.color: Qt.rgba(0.72, 0.69, 1.0, 0.24)
        border.width: 1

        opacity: root.showing ? 1.0 : 0.0
        scale: root.showing ? 1.0 : 0.90

        transformOrigin: Item.Center

        Behavior on opacity {
            NumberAnimation {
                duration: root.showing ? 110 : 180
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: root.showing ? 110 : 180
                easing.type: Easing.OutCubic
            }
        }

        // Inner refractive rim

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 14
            color: "transparent"

            border.color: Qt.rgba(1, 1, 1, 0.075)
            border.width: 1
        }

        // Subtle upper glass highlight

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.topMargin: 1

            height: 1
            radius: 1

            color: Qt.rgba(1, 1, 1, 0.13)
        }

        Row {
            anchors.centerIn: parent

            width: childrenRect.width
            height: parent.height

            spacing: 8

            // Icon badge

            Rectangle {
                width: 12
                height: 12
                radius: 7

                anchors.verticalCenter: parent.verticalCenter

                color: root.osdMuted
                ? Qt.rgba(
                    Island.Theme.red.r,
                    Island.Theme.red.g,
                    Island.Theme.red.b,
                    0.18
                )
                : Qt.rgba(
                    Island.Theme.primary.r,
                    Island.Theme.primary.g,
                    Island.Theme.primary.b,
                    0.16
                )

                border.color: root.osdMuted
                ? Island.Theme.red
                : Island.Theme.primary

                border.width: 1

                Text {
                    anchors.centerIn: parent

                    text: {
                        if (root.osdType === "volume") {
                            if (root.osdMuted) return "󰖁";
                            if (root.osdValue > 0.5) return "󰕾";
                            if (root.osdValue > 0.0) return "󰖀";
                            return "󰕿";
                        }

                        return root.osdValue > 0.5 ? "󰃠" : "󰃟";
                    }

                    font.family: Island.Theme.iconFontFamily
                    font.pixelSize: 11

                    color: root.osdMuted
                    ? Island.Theme.red
                    : Island.Theme.primary
                }
            }

            // Slider track

            Rectangle {
                id: barTrack

                anchors.verticalCenter: parent.verticalCenter

                width: 48
                height: 3
                radius: 3

                color: "#343444"
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    width: barTrack.width *
                    Math.max(0.0, Math.min(1.0, root.osdValue))

                    radius: 3

                    color: root.osdMuted
                    ? Island.Theme.muted
                    : Island.Theme.primary

                    Behavior on width {
                        NumberAnimation {
                            duration: 90
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                        width: 2
                        radius: 1

                        color: "#ffffff"
                        opacity: root.osdMuted ? 0.3 : 0.8
                        visible: root.osdValue > 0.02
                    }
                }
            }

            // Numeric readout

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: root.osdMuted
                ? "Muted"
                : Math.round(root.osdValue * 100) + "%"

                font.family: Island.Theme.fontFamily
                font.bold: true
                font.pixelSize: 9

                color: root.osdMuted
                ? Island.Theme.muted
                : Island.Theme.foreground
            }
        }
    }
}
