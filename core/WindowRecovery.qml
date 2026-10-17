import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root

    required property var surfaceManager

    readonly property string stateDir: {
        const xdgState = Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state");
        return xdgState + "/cool-shell";
    }
    readonly property string recoveryFilePath: stateDir + "/window-recovery.json"

    property var windowCache: ({})
    property bool dirty: false

    Timer {
        id: flushDebounceTimer
        interval: 5000
        repeat: false
        onTriggered: root.commitToStorage()
    }

    // Process to ensure state directory exists on startup
    Process {
        id: mkdirProcess
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    FileView {
        id: recoveryFile
        path: root.recoveryFilePath
        preload: true
        atomicWrites: true
        watchChanges: false
        onLoaded: root.loadRecoveryData()
        onLoadFailed: (error) => {
            // If file does not exist yet, write valid initial JSON structure
            if (error === FileViewError.FileNotFound) {
                recoveryFile.setText(JSON.stringify({
                    "version": 1,
                    "timestamp": Date.now(),
                    "windows": []
                }, null, 2) + "\n");
            }
        }
    }

    function loadRecoveryData() {
        try {
            const raw = recoveryFile.text();
            if (!raw || !raw.trim()) return;
            const parsed = JSON.parse(raw);
            if (parsed && Array.isArray(parsed.windows)) {
                // Initial seed
                for (let i = 0; i < parsed.windows.length; ++i) {
                    const w = parsed.windows[i];
                    if (w && w.address) {
                        windowCache[w.address] = w;
                    }
                }
            }
        } catch (err) {
            console.warn("[WindowRecovery] Failed to parse recovery file, preserving without crash:", err);
        }
    }

    function updateFromSurfaces() {
        if (!surfaceManager || !surfaceManager.toplevelList) return;

        const toplevels = surfaceManager.toplevelList;
        const currentAddresses = new Set();
        let changed = false;

        for (let i = 0; i < toplevels.length; ++i) {
            const tl = toplevels[i];
            if (!tl) continue;

            const addr = tl.address ?? "";
            if (!addr) continue;
            currentAddresses.add(addr);

            const wsId = tl.workspace ? tl.workspace.id : 1;
            const rawTitle = tl.title ?? (tl.wayland ? (tl.wayland.title ?? "") : "");
            const rawClass = (tl.lastIpcObject && tl.lastIpcObject.class) ? tl.lastIpcObject.class : (tl.wayland ? (tl.wayland.appId ?? "") : "");
            const isFullscreen = Boolean(
                (tl.wayland && tl.wayland.fullscreen) ||
                (tl.lastIpcObject && tl.lastIpcObject.fullscreen)
            );
            const isFloating = Boolean(tl.lastIpcObject && tl.lastIpcObject.floating);
            const geom = (tl.lastIpcObject && tl.lastIpcObject.at && tl.lastIpcObject.size) ? {
                "x": tl.lastIpcObject.at[0] || 0,
                "y": tl.lastIpcObject.at[1] || 0,
                "width": tl.lastIpcObject.size[0] || 0,
                "height": tl.lastIpcObject.size[1] || 0
            } : { "x": 0, "y": 0, "width": 0, "height": 0 };

            const record = {
                "address": addr,
                "title": rawTitle,
                "class": rawClass,
                "workspaceId": wsId,
                "geometry": geom,
                "fullscreen": isFullscreen,
                "floating": isFloating
            };

            const existing = windowCache[addr];
            if (!existing || existing.workspaceId !== wsId || existing.fullscreen !== isFullscreen || existing.floating !== isFloating) {
                windowCache[addr] = record;
                changed = true;
            }
        }

        // Clean out closed windows
        for (const addr in windowCache) {
            if (!currentAddresses.has(addr)) {
                delete windowCache[addr];
                changed = true;
            }
        }

        if (changed) {
            dirty = true;
            flushDebounceTimer.restart();
        }
    }

    Connections {
        target: surfaceManager
        function onToplevelListChanged() {
            root.updateFromSurfaces();
        }
    }

    function commitToStorage() {
        if (!dirty) return;

        const windowsArray = [];
        for (const addr in windowCache) {
            windowsArray.push(windowCache[addr]);
        }

        const payload = {
            "version": 1,
            "timestamp": Date.now(),
            "windows": windowsArray
        };

        try {
            recoveryFile.setText(JSON.stringify(payload, null, 2) + "\n");
            dirty = false;
        } catch (err) {
            console.warn("[WindowRecovery] Atomic write failed, discarding to avoid corruption:", err);
        }
    }

    Component.onCompleted: {
        root.updateFromSurfaces();
    }

    Component.onDestruction: {
        if (dirty) {
            root.commitToStorage();
        }
    }
}
