import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    readonly property string helper: Quickshell.shellPath("island/scripts/theme-system.sh")
    readonly property string currentSlug: Theme.slug
    readonly property string currentTheme: Theme.slug
    property var themes: []
    property var wallpapers: []
    property string error: ""
    property bool busy: applyProcess.running || wallpaperProcess.running
    property bool wallpaperRefreshPending: false

    signal wallpaperApplied(string path, string mediaType)

    function refreshThemes() {
        if (!themeListProcess.running)
            themeListProcess.running = true;
    }

    function refreshWallpapers() {
        if (wallpaperListProcess.running) {
            wallpaperRefreshPending = true;
            return;
        }
        wallpaperListProcess.running = true;
    }

    function applyTheme(slug) {
        if (!applyProcess.running && slug)
            applyProcess.exec([helper, "apply", slug]);
    }

    function setTheme(slug) {
        applyTheme(slug);
    }

    function setWallpaper(path) {
        if (!path)
            return;
        const cleanPath = String(path).trim().replace(/^file:\/\//, "");
        if (!cleanPath)
            return;
        const isVid = /\.(mp4|webm|mkv|mov)$/i.test(cleanPath);
        root.wallpaperApplied(isVid ? cleanPath : "", isVid ? "video" : "image");
        if (wallpaperProcess.running)
            wallpaperProcess.running = false;
        wallpaperProcess.exec([helper, "wallpaper", cleanPath]);
    }

    function openWallpaperFolder() {
        if (!folderProcess.running)
            folderProcess.exec([helper, "open-wallpapers"]);
    }

    function openLiveWallpaperFolder() {
        if (!folderProcess.running)
            folderProcess.exec([helper, "open-live-wallpapers"]);
    }

    Component.onCompleted: {
        refreshThemes();
        refreshWallpapers();
    }

    Process {
        id: themeListProcess
        command: [root.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.themes = JSON.parse(text || "[]");
                    root.error = "";
                } catch (error) {
                    root.error = "Unable to read themes";
                }
            }
        }
    }

    Process {
        id: wallpaperListProcess
        command: [root.helper, "wallpapers"]
        onExited: {
            if (root.wallpaperRefreshPending) {
                root.wallpaperRefreshPending = false;
                wallpaperListProcess.running = true;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.wallpapers = JSON.parse(text || "[]");
                    root.error = "";
                } catch (error) {
                    root.error = "Unable to read wallpapers";
                }
            }
        }
    }

    Process {
        id: applyProcess
        onExited: (exitCode) => {
            if (exitCode === 0) {
                Theme.reload();
                root.refreshWallpapers();
            } else {
                root.error = "Theme switch failed";
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim()
        }
    }

    Process {
        id: wallpaperProcess
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.error = "Wallpaper switch failed";
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim()
        }
    }

    Process {
        id: folderProcess
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim()
        }
    }
}
