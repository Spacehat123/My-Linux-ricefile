import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
pragma Singleton

// IslandHub: central state + border-indication arbitration for the pill.
// Layered border model (lowest to highest priority):
//   idle (transparent) < notification flash < media ring (separate item)
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
    readonly property var player: (() => {
        const players = Mpris.players.values;
        for (let i = 0; i < players.length; ++i) {
            if (players[i] && players[i].isPlaying)
                return players[i];
        }
        return players.length > 0 ? players[0] : null;
    })()
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

    // -- volume takeover: exclusive 1000ms island state, restarts on change --
    property bool volumeActive: false
    property int volumePercent: 0
    property bool volumeMuted: false
    readonly property string volumeText: volumeMuted ? "Muted" : volumePercent + "%"
    function showVolume() {
        if (sinkAudio) {
            volumePercent = Math.round((sinkAudio.volume || 0) * 100);
            volumeMuted = sinkAudio.muted === true;
        }
        volumeActive = true;
        volumeTimer.restart();
    }
    // -- transient border flash (screenshot white, bt, ...) --
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

    // -- micro particle burst trigger (major events only) --
    property int burstTick: 0
    function burst() {
        burstTick += 1;
    }

    // -- screenshot sweep trigger --
    property int sweepTick: 0
    function sweep() {
        sweepTick += 1;
    }

    // -- idle wake brighten --
    // Triggered by shell.qml watching the shared IdleManager
    property int wakeTick: 0
    function notifyWake() {
        wakeTick += 1;
        flashBorder(Theme.primary, 1500);
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
        id: volumeTimer
        interval: 1000
        onTriggered: root.volumeActive = false
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

    // -- volume watcher: 1000ms exclusive takeover, then automatic restore --
    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    Connections {
        target: root.sinkAudio
        function onVolumeChanged() {
            root.showVolume();
        }
        function onMutedChanged() {
            root.showVolume();
        }
    }

    // -- real audio levels for the waveform (level-meter.py daemon) --
    readonly property string levelHelper: Quickshell.shellPath("island/scripts/level-meter.py").toString().replace(/^file:\/\//, "")
    readonly property string levelFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/cool-shell-levels"
    property var levels: [0, 0, 0, 0]

    function startLevels() {
        if (!levelProc.running)
            levelProc.exec(["python3", root.levelHelper]);
    }
    function stopLevels() {
        if (levelProc.running)
            levelProc.running = false;
        root.levels = [0, 0, 0, 0];
    }

    onMediaPlayingChanged: {
        if (root.mediaPlaying)
            root.startLevels();
        else
            root.stopLevels();
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            // Monitor source follows the default sink; restart the tap.
            if (root.mediaPlaying) {
                root.stopLevels();
                root.startLevels();
            }
        }
    }

    Process {
        id: levelProc
        onExited: {
            // Watchdog: daemon died while music plays -> restart after 2s.
            if (root.mediaPlaying)
                levelRestart.restart();
        }
    }

    Timer {
        id: levelRestart
        interval: 2000
        onTriggered: {
            if (root.mediaPlaying && !levelProc.running)
                root.startLevels();
        }
    }

    Timer {
        id: levelPoll
        interval: 150
        running: root.mediaPlaying
        repeat: true
        onTriggered: {
            if (!levelCat.running)
                levelCat.exec(["cat", root.levelFile]);
        }
    }

    Process {
        id: levelCat
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                if (parts.length >= 4) {
                    const next = [];
                    for (let i = 0; i < 4; ++i) {
                        const v = Number(parts[i]);
                        next.push(Number.isFinite(v) ? Math.max(0, Math.min(1, v)) : 0);
                    }
                    root.levels = next;
                    root.levelUpdatedAt = Date.now();
                }
            }
        }
    }

    // Staleness: daemon dead/file gone while playing -> decay to silence.
    property double levelUpdatedAt: 0
    Timer {
        interval: 500
        running: root.mediaPlaying
        repeat: true
        onTriggered: {
            if (Date.now() - root.levelUpdatedAt > 1200)
                root.levels = [0, 0, 0, 0];
        }
    }

    // -- screenshot watcher: brief white flash overriding current border --
    Connections {
        target: Backend
        function onLastCaptureChanged() {
            if (Backend.lastCapture) {
                root.flashBorder("white", 700);
                root.burst();
                root.sweep();
            }
        }
    }
}
