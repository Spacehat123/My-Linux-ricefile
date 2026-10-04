import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property bool screenReaderMode: false
    property bool daemonConnected: false
    property bool daemonAvailable: true

    function toggleScreenReader() {
        screenReaderMode = !screenReaderMode;
        if (screenReaderMode) {
            ensureDaemonRunning();
        } else {
            announce("Screen reader disabled");
        }
    }

    function ensureDaemonRunning() {
        if (daemonConnected) {
            announce("Screen reader enabled");
            return;
        }

        // Try user systemd start asynchronously with zero main-thread block
        systemdStartProcess.exec(["systemctl", "--user", "start", "speech-dispatcher"]);
    }

    Process {
        id: systemdStartProcess

        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.daemonConnected = true;
                root.announce("Screen reader enabled");
            } else {
                root.daemonAvailable = false;
                root.screenReaderMode = false;
                IslandHub.showTransient("Install speech-dispatcher for screen reader", 3500);
            }
        }
    }

    Process {
        id: speechProcess
    }

    function announce(text) {
        if (!screenReaderMode || !text)
            return;

        // Cancel previous speech (-C) to avoid audio backlog and speak immediately
        if (speechProcess.running) {
            speechProcess.kill();
        }
        speechProcess.exec(["spd-say", "-C", "-e", String(text)]);
    }
}
