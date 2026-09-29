import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
pragma Singleton

// PrivacyState: real mic/camera usage indicators.
// Mic: any PipeWire stream node capturing (isStream && !isSink) while the
// default source is unmuted. Camera: any process holding /dev/video* (fuser).
// Dots appear ONLY while the device is actually in use.
// This file never imports IslandHub (one-way).
Singleton {
    id: root

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool sourceMuted: source && source.audio ? source.audio.muted : true
    readonly property bool micStreamActive: {
        if (!source || sourceMuted)
            return false;
        const all = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (let i = 0; i < all.length; ++i) {
            const n = all[i];
            // Capture streams: stream nodes that are not sinks.
            if (n && n.isStream && !n.isSink)
                return true;
        }
        return false;
    }
    property bool micActive: false

    property bool camActive: false

    // Debounce mic so blips don't flicker the dot.
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: root.micActive = root.micStreamActive
    }

    Process {
        id: camProbe
        stdout: StdioCollector {
            onStreamFinished: root.camActive = text.trim().length > 0
        }
        onExited: (code) => {
            if (code !== 0 && code !== 1)
                root.camActive = false;
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!camProbe.running)
                camProbe.exec(["sh", "-c", "fuser /dev/video* 2>/dev/null || true"]);
        }
    }
}
