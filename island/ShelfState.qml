import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// ShelfState: file shelf (stored paths, never moved/copied) + best-effort
// download detection by watching ~/Downloads for partial files.
// LIMITATION: no system-wide download API exists on Linux; browsers expose
// no uniform progress. We show partial-file size/rate honestly (no fake %).
// This file never imports IslandHub (one-way); Notch wires events to the hub.
Singleton {
    id: root

    property string homeDir: Quickshell.env("HOME") || ""
    property string downloadsDir: ""
    property var files: [] // [{path, name, added}]
    property var activeDownloads: [] // [{name, sizeMB, rateMBs}]
    property int eventTick: 0
    property string lastEvent: ""

    readonly property bool hasFiles: files.length > 0
    readonly property bool hasActiveDownload: activeDownloads.length > 0
    readonly property string compactText: {
        if (!hasActiveDownload)
            return "";
        const d = activeDownloads[0];
        const extra = activeDownloads.length > 1 ? " (+" + (activeDownloads.length - 1) + ")" : "";
        const cleanName = d.name.replace(/\.(crdownload|part|aria2|tmp|downloading)$/i, "");
        if (d.isRender) {
            return "🎬 Render: " + cleanName + extra;
        }
        const speed = Number(d.rateMBs) > 0 ? "↓ " + d.rateMBs + " MB/s" : "↓ Active";
        const pctPrefix = (d.percent !== undefined && Number(d.percent) >= 0) ? (d.percent + "% • ") : "";
        const sizeStr = (d.sizeMB && d.sizeMB !== "Active") ? (" • " + d.sizeMB + " MB") : "";
        return pctPrefix + speed + sizeStr + extra + "  (" + cleanName + ")";
    }

    function baseName(path) {
        const clean = String(path).replace(/^file:\/\//, "");
        const parts = clean.split("/");
        return parts[parts.length - 1] || clean;
    }
    function cleanPath(path) {
        // Drop URLs arrive percent-encoded (file:///...%20...); decode them.
        let clean = String(path).trim();
        if (clean.startsWith("file://"))
            clean = clean.slice(7);
        try {
            clean = decodeURIComponent(clean);
        } catch (e) {
        }
        return clean;
    }

    function addFile(path) {
        const clean = cleanPath(path);
        if (!clean)
            return false;
        const next = files.slice();
        for (let i = 0; i < next.length; ++i) {
            if (next[i].path === clean)
                return false;
        }
        next.unshift({ path: clean, name: baseName(clean), added: Date.now() });
        files = next.slice(0, 30);
        lastEvent = "Saved " + baseName(clean);
        eventTick += 1;
        save();
        return true;
    }
    function addUrls(urls) {
        let added = 0;
        for (let i = 0; i < (urls || []).length; ++i) {
            if (addFile(String(urls[i])))
                added += 1;
        }
        return added;
    }
    function removeFile(index) {
        if (index < 0 || index >= files.length)
            return;
        const next = files.slice();
        next.splice(index, 1);
        files = next;
        save();
    }
    function clear() {
        files = [];
        save();
    }
    function openFile(path) {
        Quickshell.execDetached(["xdg-open", cleanPath(path)]);
    }
    // Open-all: launches each shelved file with its default handler.
    // Read-only w.r.t. the shelf (never moves/deletes); non-blocking.
    function openAllFiles() {
        for (let i = 0; i < files.length; ++i) {
            if (files[i] && files[i].path)
                openFile(files[i].path);
        }
    }

    function save() {
        shelfFile.setText(JSON.stringify(files));
    }
    function load() {
        try {
            const parsed = JSON.parse(shelfFile.text());
            if (Array.isArray(parsed))
                files = parsed.filter((f) => f && f.path).slice(0, 30);
        } catch (e) {
        }
    }

    FileView {
        id: shelfFile
        path: Quickshell.shellPath("island/shelf.json")
        preload: true
        atomicWrites: true
        watchChanges: false
        onLoaded: root.load()
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound)
                shelfFile.setText("[]\n");
        }
    }

    // -- download polling: track sizes of partial files, derive rate --
    property var sizeMemo: ({})
    Process {
        id: downloadProbe
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter((l) => l.length > 0);
                const seen = {};
                const next = [];
                const memo = {};
                for (let i = 0; i < lines.length; ++i) {
                    const tab = lines[i].lastIndexOf("\t");
                    if (tab < 0)
                        continue;
                    const size = Number(lines[i].slice(0, tab)) || 0;
                    const name = lines[i].slice(tab + 1);
                    seen[name] = true;
                    const now = Date.now();
                    const prev = root.sizeMemo[name];
                    const dt = prev ? Math.max(0.5, (now - prev.time) / 1000) : (root.hasActiveDownload ? 1.5 : 4.0);
                    const rate = prev ? Math.max(0, (size - prev.size) / 1024 / 1024 / dt) : 0;
                    memo[name] = { size: size, time: now };
                    next.push({ name: name, sizeMB: (size / 1024 / 1024).toFixed(1), rateMBs: rate.toFixed(1) });
                }
                root.sizeMemo = memo;
                // Detect completed downloads (vanished from partial list).
                if (root.activeDownloads.length > next.length) {
                    for (let k = 0; k < root.activeDownloads.length; ++k) {
                        let stillThere = false;
                        for (let j = 0; j < next.length; ++j) {
                            if (next[j].name === root.activeDownloads[k].name) {
                                stillThere = true;
                                break;
                            }
                        }
                        if (!stillThere) {
                            root.lastEvent = "Download complete " + root.activeDownloads[k].name;
                            root.eventTick += 1;
                        }
                    }
                }
                // Detect new downloads.
                if (next.length > root.activeDownloads.length) {
                    for (let j = 0; j < next.length; ++j) {
                        let known = false;
                        for (let k = 0; k < root.activeDownloads.length; ++k) {
                            if (root.activeDownloads[k].name === next[j].name)
                                known = true;
                        }
                        if (!known) {
                            root.lastEvent = "Download started " + next[j].name;
                            root.eventTick += 1;
                        }
                    }
                }
                root.activeDownloads = next;
            }
        }
    }

    Timer {
        interval: root.hasActiveDownload ? 1500 : 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!downloadProbe.running) {
                if (!root.downloadsDir)
                    root.downloadsDir = (root.homeDir ? root.homeDir + "/Downloads" : "");
                if (root.downloadsDir)
                    downloadProbe.exec(["sh", "-c", "find '" + root.downloadsDir.replace(/'/g, "'\\''") + "' -maxdepth 1 -type f \\( -name '*.part' -o -name '*.crdownload' -o -name '*.aria2' -o -name '*.tmp' -o -name '*.downloading' \\) -printf '%s\\t%f\\n' 2>/dev/null"]);
            }
        }
    }
}
