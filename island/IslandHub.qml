import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
pragma Singleton

// IslandHub: central state + border-indication arbitration for the pill.
// Layered border model (lowest to highest priority):
//   idle (transparent) < notification flash < media ring (separate item)
//   < recording blink (red, persistent) < transient flash (volume/screenshot/...)
// Transient flashes temporarily override and then fall back automatically,
// so the underlying activity state is never destroyed.
Singleton {
    id: root

    // -- unread notifications (bumped from shell.qml NotificationServer) --
    property int unreadCount: 0
    property var notifModel: null
    function notifyArrived() {
        unreadCount += 1;
    }
    function markSeen() {
        unreadCount = 0;
    }

    // -- do-not-disturb (set by focus sessions) --
    property bool dnd: false

    // -- media mirror (same source as Notch.islandPlayer, no extra deps) --
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property bool mediaActive: player !== null && player.length > 0
    readonly property bool mediaPlaying: player !== null && player.isPlaying

    // -- recording mirror (Backend owns wf-recorder truth) --
    property bool recordingActive: Backend.recording
    property int recElapsedSec: 0
    property double recStartEpoch: 0
    onRecordingActiveChanged: {
        if (recordingActive) {
            recStartEpoch = Date.now() / 1000;
            recElapsedSec = 0;
        }
    }

    function formatElapsed(totalSec) {
        const s = Math.max(0, Math.floor(totalSec));
        const m = Math.floor(s / 60);
        return String(m).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
    }

    // -- transient border flash (volume 500ms, screenshot white, bt, ...) --
    property color flashColor: "white"
    property bool flashActive: false
    function flashBorder(color, ms) {
        flashColor = color;
        flashActive = true;
        restoreTimer.interval = Math.max(50, ms || 500);
        restoreTimer.restart();
    }

    // -- transient collapsed text (bt connect, shelf drop, plug events) --
    property string transientText: ""
    function showTransient(text, ms) {
        transientText = text;
        transientTimer.interval = Math.max(500, ms || 3000);
        transientTimer.restart();
    }

    // -- click routing: most prominent live activity wins --
    function primaryPanel() {
        if (recordingActive)
            return "capture";
        if (TimerState.hasActive)
            return "timer";
        if (mediaPlaying)
            return "media";
        if (unreadCount > 0)
            return "notifications";
        if (ShelfState.hasActiveDownload)
            return "shelf";
        if (mediaActive)
            return "media";
        return "control";
    }

    // -- collapsed primary label (single slot; secondary items are dots) --
    function primaryLabel(playerTitle, playerArtist) {
        if (transientText)
            return transientText;
        if (recordingActive)
            return "REC " + formatElapsed(recElapsedSec);
        if (TimerState.hasActive)
            return TimerState.compactText;
        if (mediaPlaying && playerTitle)
            return playerTitle + (playerArtist ? " - " + playerArtist : "");
        if (PowerState.charging)
            return "Charging " + Math.round(PowerState.percent * 100) + "%";
        if (unreadCount > 0)
            return unreadCount === 1 ? "1 notification" : unreadCount + " notifications";
        if (ShelfState.hasActiveDownload)
            return ShelfState.compactText;
        if (mediaActive && playerTitle)
            return playerTitle;
        return "";
    }

    Timer {
        id: restoreTimer
        interval: 500
        onTriggered: root.flashActive = false
    }

    Timer {
        id: transientTimer
        interval: 3000
        onTriggered: root.transientText = ""
    }

    Timer {
        interval: 1000
        running: root.recordingActive
        repeat: true
        onTriggered: root.recElapsedSec = Math.floor(Date.now() / 1000 - root.recStartEpoch)
    }

    // -- volume watcher: 500ms border override, then automatic restore --
    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    Connections {
        target: root.sinkAudio
        function onVolumeChanged() {
            root.flashBorder(Theme.blue, 500);
        }
        function onMutedChanged() {
            root.flashBorder(Theme.blue, 500);
        }
    }

    // -- screenshot watcher: brief white flash overriding current border --
    Connections {
        target: Backend
        function onLastCaptureChanged() {
            if (Backend.lastCapture)
                root.flashBorder("white", 700);
        }
    }
}
