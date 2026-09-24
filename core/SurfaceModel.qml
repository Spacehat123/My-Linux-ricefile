import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    // =========================================================================
    // Required Injected Authorities
    // =========================================================================
    required property var surfaceManager

    // =========================================================================
    // Internal Helper: Human-Friendly Application Name Resolution
    // =========================================================================
    function _resolveAppName(rawAppId: string, rawClass: string): string {
        const id = (rawClass || rawAppId || "").trim();
        if (!id) return "Unknown";

        // 1. Canonical overrides for common Linux desktop applications
        const overrides = {
            "code-oss": "VS Code",
            "vscode": "VS Code",
            "vscodium": "VSCodium",
            "org.wezfurlong.wezterm": "WezTerm",
            "wezterm": "WezTerm",
            "kitty": "Kitty",
            "alacritty": "Alacritty",
            "foot": "Foot",
            "firefox": "Firefox",
            "google-chrome": "Google Chrome",
            "chromium": "Chromium",
            "brave-browser": "Brave",
            "discord": "Discord",
            "vesktop": "Vesktop",
            "spotify": "Spotify",
            "pavucontrol": "Volume Control",
            "org.kde.dolphin": "Dolphin",
            "org.gnome.nautilus": "Files",
            "thunar": "Thunar",
            "wofi": "Wofi",
            "rofi": "Rofi",
            "mpv": "MPV",
            "steam": "Steam"
        };

        const lowerId = id.toLowerCase();
        if (overrides[lowerId]) {
            return overrides[lowerId];
        }

        // 2. Reverse-DNS truncation (e.g. "org.gnome.Nautilus" -> "Nautilus")
        let baseName = id;
        if (baseName.indexOf(".") !== -1) {
            const segments = baseName.split(".");
            baseName = segments[segments.length - 1] || baseName;
        }

        // 3. Word tokenization and capitalization (e.g. "google-chrome" -> "Google Chrome")
        const tokens = baseName.replace(/[-_]+/g, " ").trim().split(" ");
        for (let i = 0; i < tokens.length; ++i) {
            const t = tokens[i];
            if (t.length > 0) {
                tokens[i] = t.charAt(0).toUpperCase() + t.slice(1);
            }
        }
        const formatted = tokens.join(" ").trim();
        return formatted.length > 0 ? formatted : id;
    }

    // =========================================================================
    // Internal Reactive State Projection
    // =========================================================================
    readonly property var _projection: {
        const rawTl = (surfaceManager && surfaceManager.toplevelList) ? surfaceManager.toplevelList : [];
        const activeAddr = surfaceManager ? surfaceManager.activeAddress : "";
        const globalUrgent = surfaceManager ? surfaceManager.isUrgent : false;

        const surfaceList = [];
        const addressLookup = {};
        const byWorkspace = {};
        const byMonitor = {};
        const byApp = {};

        let focusedItem = null;
        let urgentTotal = 0;

        // O(N) single-pass projection
        for (let i = 0; i < rawTl.length; ++i) {
            const tl = rawTl[i];
            if (!tl) continue;

            const addr = tl.address ?? "";
            const rawTitle = tl.title ?? (tl.wayland ? (tl.wayland.title ?? "") : "");
            const rawClass = (tl.lastIpcObject && tl.lastIpcObject.class) ? tl.lastIpcObject.class : "";
            const rawAppId = (tl.wayland && tl.wayland.appId) ? tl.wayland.appId : rawClass;
            const appDisplayName = _resolveAppName(rawAppId, rawClass);
            const isXWayland = Boolean((tl.lastIpcObject && tl.lastIpcObject.xwayland) || !tl.wayland);

            const wsId = tl.workspace ? tl.workspace.id : -1;
            const wsName = tl.workspace ? (tl.workspace.name ?? "") : "";
            const monId = tl.monitor ? tl.monitor.id : -1;
            const monName = tl.monitor ? (tl.monitor.name ?? "") : "";

            const isActivated = Boolean(tl.activated || (addr !== "" && addr === activeAddr));
            const isItemUrgent = Boolean(tl.urgent);
            if (isItemUrgent) urgentTotal++;

            const isFullscreen = Boolean(
                (tl.wayland && tl.wayland.fullscreen) ||
                (tl.lastIpcObject && tl.lastIpcObject.fullscreen)
            );
            const isFloating = Boolean(tl.lastIpcObject && tl.lastIpcObject.floating);
            const pid = (tl.lastIpcObject && tl.lastIpcObject.pid !== undefined) ? tl.lastIpcObject.pid : -1;

            const item = {
                address: addr,
                rawToplevel: tl,
                title: rawTitle,
                initialTitle: (tl.lastIpcObject && tl.lastIpcObject.initialTitle) ? tl.lastIpcObject.initialTitle : rawTitle,
                appId: rawAppId,
                windowClass: rawClass,
                appName: appDisplayName,
                isXWayland: isXWayland,
                workspaceId: wsId,
                workspaceName: wsName,
                isSpecialWorkspace: wsId < 0,
                monitorId: monId,
                monitorName: monName,
                activated: isActivated,
                urgent: isItemUrgent,
                fullscreen: isFullscreen,
                floating: isFloating,
                pid: pid
            };

            surfaceList.push(item);
            if (addr !== "") {
                addressLookup[addr] = item;
            }

            if (isActivated) {
                focusedItem = item;
            }

            // Bucket by workspace ID
            if (!byWorkspace[wsId]) byWorkspace[wsId] = [];
            byWorkspace[wsId].push(item);

            // Bucket by monitor name
            if (monName !== "") {
                if (!byMonitor[monName]) byMonitor[monName] = [];
                byMonitor[monName].push(item);
            }

            // Bucket by application identity
            const appKey = rawAppId || rawClass || "unknown";
            if (!byApp[appKey]) byApp[appKey] = [];
            byApp[appKey].push(item);
        }

        // Aggregate application groups
        const appGroupList = [];
        const appKeys = Object.keys(byApp);
        for (let k = 0; k < appKeys.length; ++k) {
            const key = appKeys[k];
            const groupSurfaces = byApp[key];
            if (!groupSurfaces || groupSurfaces.length === 0) continue;

            let appGroupFocused = false;
            let appGroupUrgent = false;
            let primarySurf = groupSurfaces[0];

            for (let g = 0; g < groupSurfaces.length; ++g) {
                const s = groupSurfaces[g];
                if (s.activated) {
                    appGroupFocused = true;
                    primarySurf = s;
                }
                if (s.urgent) {
                    appGroupUrgent = true;
                }
            }

            appGroupList.push({
                appId: key,
                appName: groupSurfaces[0].appName,
                windowClass: groupSurfaces[0].windowClass,
                count: groupSurfaces.length,
                surfaces: groupSurfaces,
                isFocused: appGroupFocused,
                isUrgent: appGroupUrgent,
                primarySurface: primarySurf
            });
        }

        return {
            surfaces: surfaceList,
            addressMap: addressLookup,
            surfacesByWorkspace: byWorkspace,
            surfacesByMonitor: byMonitor,
            surfacesByApplication: byApp,
            applications: appGroupList,
            focusedSurface: focusedItem,
            urgentCount: urgentTotal,
            applicationCount: appGroupList.length
        };
    }

    // =========================================================================
    // Public Reactive Properties
    // =========================================================================
    readonly property var surfaces: _projection ? _projection.surfaces : []
    readonly property int count: surfaces ? surfaces.length : 0
    readonly property var focusedSurface: _projection ? _projection.focusedSurface : null
    readonly property bool hasFocusedSurface: focusedSurface !== null
    readonly property int urgentCount: _projection ? _projection.urgentCount : 0
    readonly property bool hasUrgentSurfaces: urgentCount > 0
    readonly property int applicationCount: _projection ? _projection.applicationCount : 0
    readonly property var applications: _projection ? _projection.applications : []

    readonly property var surfacesByWorkspace: _projection ? _projection.surfacesByWorkspace : ({})
    readonly property var surfacesByMonitor: _projection ? _projection.surfacesByMonitor : ({})
    readonly property var surfacesByApplication: _projection ? _projection.surfacesByApplication : ({})

    // =========================================================================
    // Public Read-Only Query API
    // =========================================================================

    // O(1) surface lookup by hex address
    function getSurfaceByAddress(address: string) {
        if (!address || !_projection || !_projection.addressMap) return null;
        return _projection.addressMap[address] || null;
    }

    // Retrieve all normalized surfaces belonging to a workspace ID
    function getSurfacesForWorkspace(workspaceId: int) {
        if (!_projection || !_projection.surfacesByWorkspace) return [];
        return _projection.surfacesByWorkspace[workspaceId] || [];
    }

    // Retrieve all normalized surfaces displayed on a monitor
    function getSurfacesForMonitor(monitor) {
        if (!_projection || !_projection.surfacesByMonitor) return [];
        if (typeof monitor === "string") {
            return _projection.surfacesByMonitor[monitor] || [];
        } else if (typeof monitor === "number") {
            const all = surfaces;
            return all.filter(s => s && s.monitorId === monitor);
        } else if (monitor && monitor.name) {
            return _projection.surfacesByMonitor[monitor.name] || [];
        }
        return [];
    }

    // Retrieve all surfaces belonging to an application (by appId or windowClass)
    function getSurfacesForApplication(appIdOrClass: string) {
        if (!appIdOrClass || !_projection || !_projection.surfacesByApplication) return [];
        const direct = _projection.surfacesByApplication[appIdOrClass];
        if (direct && direct.length > 0) return direct;

        const lowerTarget = appIdOrClass.toLowerCase();
        const all = surfaces;
        return all.filter(s => s && (
            (s.appId && s.appId.toLowerCase() === lowerTarget) ||
            (s.windowClass && s.windowClass.toLowerCase() === lowerTarget) ||
            (s.appName && s.appName.toLowerCase() === lowerTarget)
        ));
    }

    // Retrieve the currently active/focused normalized surface
    function getFocusedSurface() {
        return focusedSurface;
    }

    // Retrieve all surfaces currently holding the urgent flag
    function getUrgentSurfaces() {
        if (!surfaces) return [];
        return surfaces.filter(s => s && s.urgent);
    }

    // Retrieve composite application summary for a given app ID or class
    function getApplicationSummary(appIdOrClass: string) {
        if (!appIdOrClass || !applications) return null;
        const lower = appIdOrClass.toLowerCase();
        for (let i = 0; i < applications.length; ++i) {
            const app = applications[i];
            if (app.appId.toLowerCase() === lower ||
                app.windowClass.toLowerCase() === lower ||
                app.appName.toLowerCase() === lower) {
                return app;
            }
        }
        return null;
    }
}
