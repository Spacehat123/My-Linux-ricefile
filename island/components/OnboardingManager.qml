import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: root

    readonly property int currentVersion: 1
    readonly property string stateDir: {
        const xdgState = Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state");
        return xdgState + "/cool-shell";
    }
    readonly property string stateFilePath: stateDir + "/onboarding.json"

    width: onboardingLoader.item ? onboardingLoader.item.width : 0
    height: onboardingLoader.item ? onboardingLoader.item.height : 0
    visible: onboardingLoader.active

    Process {
        id: mkdirProcess
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    FileView {
        id: onboardingStateFile
        path: root.stateFilePath
        preload: true
        atomicWrites: true
        watchChanges: false
        onLoaded: {
            try {
                const raw = onboardingStateFile.text();
                if (raw && raw.trim()) {
                    const parsed = JSON.parse(raw);
                    if (parsed && typeof parsed.version === "number" && parsed.version >= root.currentVersion) {
                        onboardingLoader.active = false;
                        return;
                    }
                }
            } catch (e) {
            }
            // If version is missing or outdated, activate onboarding
            onboardingLoader.active = true;
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                // First run: show onboarding
                onboardingLoader.active = true;
            }
        }
    }

    Loader {
        id: onboardingLoader
        active: false

        sourceComponent: OnboardingCard {
            onFinished: {
                try {
                    onboardingStateFile.setText(JSON.stringify({ "version": root.currentVersion }) + "\n");
                } catch (e) {}
                onboardingLoader.active = false;
                IslandHub.showTransient("Ready to go!", 2000);
            }
        }
    }
}
