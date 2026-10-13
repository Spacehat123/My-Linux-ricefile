import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// CaptionState: manages drag-and-dropped media files for ultra-fast local
// subtitle generation (NVIDIA FastConformer-CTC) and existing subtitle extraction.
Singleton {
    id: root

    property string pendingFile: ""
    readonly property string pendingFileName: pendingFile ? ShelfState.baseName(pendingFile) : ""
    
    // Media detection
    readonly property bool isVideo: /\.(mp4|mkv|webm|mov|avi|m4v|flv|ts|wmv)$/i.test(pendingFile)
    readonly property bool isAudio: /\.(mp3|wav|m4a|aac|flac|ogg|opus|wma)$/i.test(pendingFile)
    readonly property bool isMedia: isVideo || isAudio

    property bool isProcessing: false
    property string currentStatus: ""
    property string currentMode: ""
    property string lastOutput: ""

    signal finished(bool success, string message)

    function checkMedia(path) {
        if (!path) return false;
        const clean = ShelfState.cleanPath(path);
        return /\.(mp4|mkv|webm|mov|avi|m4v|flv|ts|wmv|mp3|wav|m4a|aac|flac|ogg|opus|wma)$/i.test(clean);
    }

    function isVideoFile(path) {
        if (!path) return false;
        const clean = ShelfState.cleanPath(path);
        return /\.(mp4|mkv|webm|mov|avi|m4v|flv|ts|wmv)$/i.test(clean);
    }

    function isAudioFile(path) {
        if (!path) return false;
        const clean = ShelfState.cleanPath(path);
        return /\.(mp3|wav|m4a|aac|flac|ogg|opus|wma)$/i.test(clean);
    }

    function setPending(path) {
        pendingFile = ShelfState.cleanPath(path);
    }

    function cancel() {
        pendingFile = "";
        ShellState.close();
    }

    function stash() {
        if (pendingFile) {
            ShelfState.addFile(pendingFile);
            IslandHub.showTransient(ShelfState.lastEvent, 3000);
            IslandHub.flashBorder(Theme.primary, 600);
            pendingFile = "";
        }
        ShellState.close();
    }

    function startCaption(mode) {
        // mode: "embed" (embed into video + save .srt) or "file_only" (save .srt only)
        if (!pendingFile || isProcessing) return;

        const targetFile = pendingFile;
        pendingFile = "";
        isProcessing = true;
        currentMode = mode;
        currentStatus = mode === "embed" ? "Embedding captions into video..." : "Extracting / transcribing captions...";

        ShellState.close();
        IslandHub.showTransient("⚡ " + currentStatus, 3200);
        IslandHub.flashBorder(Theme.primary, 800);

        const helper = Quickshell.env("HOME") + "/.local/bin/fast-caption";
        const args = [helper, targetFile];
        if (mode === "file_only") {
            args.push("--no-embed");
        }

        captionProc.command = args;
        captionProc.running = true;
    }

    Process {
        id: captionProc

        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim().length > 0)
                    root.lastOutput = text.trim();
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim().length > 0)
                    console.warn("[CaptionState stderr]", text.trim());
            }
        }

        onExited: (exitCode) => {
            root.isProcessing = false;
            if (exitCode === 0) {
                IslandHub.showTransient("✔ Captions saved to ~/Music/caption_extracts", 4500);
                IslandHub.flashBorder("#22c55e", 1200);
                IslandHub.burst();
                root.finished(true, "Captions ready");
            } else {
                IslandHub.showTransient("✖ Caption processing failed", 3500);
                IslandHub.flashBorder(Theme.red, 1200);
                root.finished(false, "Failed");
            }
        }
    }
}
