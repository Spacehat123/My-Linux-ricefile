import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Hyprland
import "components"
import "core"
import "desktop"
import "island" // bare `Theme` in this file = island singleton (do NOT add `import "theme"` here)
import "island/components"
import "panels"
import "wallpaper"

ShellRoot {
    id: shellRoot

    // Idle & Power Intelligence Layer (compositor-wide lifetime)
    IdleManager {
        id: idleManager
    }

    // Compositor intelligence layer singletons (compositor-wide lifetime)
    WorkspaceManager {
        id: workspaceManager
    }

    SurfaceManager {
        id: surfaceManager
    }

    WindowRecovery {
        id: windowRecovery
        surfaceManager: surfaceManager
    }


    // Spatial Workspace Foundation model (compositor-wide lifetime)
    WorkspaceModel {
        id: workspaceModel
        workspaceManager: workspaceManager
        surfaceManager: surfaceManager
    }

    // Surface Intelligence & Application Composition model (compositor-wide lifetime)
    SurfaceModel {
        id: surfaceModel
        surfaceManager: surfaceManager
    }

    // Desktop State & Composition Graph model (compositor-wide lifetime)
    DesktopModel {
        id: desktopModel
        workspaceModel: workspaceModel
        surfaceModel: surfaceModel
    }

    // Compositor Action Layer (Actuator & Security Barrier)
    CompositorActionLayer {
        id: compositorActionLayer
        workspaceManager: workspaceManager
        surfaceManager: surfaceManager
        workspaceModel: workspaceModel
        surfaceModel: surfaceModel
        interactionModel: interactionModel
    }

    // Interaction & Intent Mediation Layer (compositor-wide lifetime)
    InteractionModel {
        id: interactionModel
        desktopModel: desktopModel
        surfaceModel: surfaceModel
        workspaceModel: workspaceModel
        actionLayer: compositorActionLayer
    }

    // Unified Desktop Presentation State (Task 25)
    DesktopState {
        id: desktopState
        desktopModel: desktopModel
        idleManager: idleManager
        ambientEnabled: shellRoot.ambientEnabled
    }

    // Authoritative shell-level aliases
    readonly property alias idleManager: idleManager
    readonly property bool idle: idleManager.idle
    property bool ambientEnabled: true
    property bool ambientAlwaysOn: false
    property bool overviewOpen: false
    property bool birdsEyeOpen: false
    readonly property alias desktopState: desktopState
    readonly property alias workspaceManager: workspaceManager
    readonly property alias surfaceManager: surfaceManager
    readonly property alias workspaceModel: workspaceModel
    readonly property alias surfaceModel: surfaceModel
    readonly property alias desktopModel: desktopModel
    readonly property alias interactionModel: interactionModel
    readonly property alias compositorActionLayer: compositorActionLayer

    // =========================================================================
    // Workspace & Surface Intelligence Integration: Derived Global State
    // =========================================================================
    readonly property int currentWorkspaceId: workspaceManager.focusedWorkspaceId
    readonly property string currentWorkspaceName: workspaceManager.focusedWorkspaceName
    readonly property int workspaceCount: workspaceManager.count
    readonly property int surfaceCount: surfaceManager.count
    readonly property bool hasActiveSurface: surfaceManager.hasActiveToplevel
    readonly property string activeSurfaceTitle: surfaceManager.activeTitle
    readonly property bool isUrgent: workspaceManager.isUrgent || surfaceManager.isUrgent

    // =========================================================================
    // Workspace & Surface Intelligence Integration: Delegated Navigation API
    // =========================================================================
    function getWorkspaceById(id: int) {
        return workspaceManager.getWorkspaceById(id);
    }

    function getWorkspaceByName(name: string) {
        return workspaceManager.getWorkspaceByName(name);
    }

    function getSurfaceByAddress(address: string) {
        return surfaceManager.getToplevelByAddress(address);
    }

    function getSurfacesForWorkspace(workspaceId: int) {
        return surfaceManager.getToplevelsForWorkspace(workspaceId);
    }

    function getSurfacesForMonitor(monitor) {
        return surfaceManager.getToplevelsForMonitor(monitor);
    }

    function getWorkspacesForMonitor(monitor) {
        return workspaceManager.getWorkspacesForMonitor(monitor);
    }

    // Wallpaper state. Renderer is the ported dotarch system (awww-daemon +
    // island/scripts/theme-system.sh). wallpaperEnabled is retained for the
    // sidebar toggle UI; rendering is owned by awww, not a QML layer.
    property bool wallpaperEnabled: true
    property string wallpaperMediaType: "video"
    property string wallpaperMediaSource: ""
    property bool autoPauseOnOpaque: true

    readonly property var seeThroughPatterns: [
        "kitty", "alacritty", "foot", "wezterm", "ghostty",
        "urxvt", "st", "xterm", "terminal", "console",
        "cava", "glava", "peaclock"
    ]

    readonly property int _wallpaperLiveTick: {
        let wsId = workspaceManager ? workspaceManager.focusedWorkspaceId : 0;
        let surfCount = surfaceManager ? surfaceManager.count : 0;
        let activeAddr = surfaceManager ? surfaceManager.activeAddress : "";
        let wsCount = workspaceManager ? workspaceManager.count : 0;
        return wsId * 10000 + surfCount * 100 + (activeAddr ? activeAddr.length : 0) + wsCount;
    }

    function isSurfaceSeeThrough(surface): bool {
        if (!surface) return false;
        let cls = "";
        let initialCls = "";
        let title = "";

        if (surface.windowClass !== undefined) cls = String(surface.windowClass).toLowerCase();
        else if (surface.lastIpcObject && surface.lastIpcObject.class) cls = String(surface.lastIpcObject.class).toLowerCase();

        if (surface.appId !== undefined) {
            let app = String(surface.appId).toLowerCase();
            if (!cls) cls = app;
        }

        if (surface.initialClass !== undefined) initialCls = String(surface.initialClass).toLowerCase();
        else if (surface.lastIpcObject && surface.lastIpcObject.initialClass) initialCls = String(surface.lastIpcObject.initialClass).toLowerCase();

        if (surface.title !== undefined) title = String(surface.title).toLowerCase();

        for (let i = 0; i < shellRoot.seeThroughPatterns.length; ++i) {
            let pat = shellRoot.seeThroughPatterns[i];
            if (cls.includes(pat) || initialCls.includes(pat) || title.includes(pat)) {
                return true;
            }
        }
        return false;
    }

    function shouldWallpaperBeLiveForMonitor(screen): bool {
        if (!shellRoot.wallpaperEnabled || ShellState.gameMode || ShellState.featherMode) return false;
        if (shellRoot.wallpaperMediaType !== "video") return false;
        if (!shellRoot.autoPauseOnOpaque) return true;

        let screenName = (screen && screen.name) ? screen.name : "";
        let activeWsId = -1;

        if (workspaceModel && workspaceModel.workspaces) {
            let wsList = workspaceModel.workspaces;
            for (let i = 0; i < wsList.length; ++i) {
                let ws = wsList[i];
                if (!ws) continue;
                if (screenName === "" || ws.monitorName === screenName || (ws.monitor && ws.monitor.name === screenName)) {
                    if (ws.active || ws.focused) {
                        activeWsId = ws.id;
                        break;
                    }
                }
            }
        }

        if (activeWsId === -1 && workspaceManager) {
            activeWsId = workspaceManager.focusedWorkspaceId;
        }

        if (activeWsId === -1) return true;

        let surfaces = [];
        if (surfaceModel && surfaceModel.surfacesByWorkspace && surfaceModel.surfacesByWorkspace[activeWsId]) {
            surfaces = surfaceModel.surfacesByWorkspace[activeWsId];
        } else if (workspaceManager) {
            surfaces = workspaceManager.getToplevelsForWorkspace(activeWsId) || [];
        }

        if (!surfaces || surfaces.length === 0) {
            return true; // Bare desktop: wallpaper is live
        }

        for (let s = 0; s < surfaces.length; ++s) {
            let surf = surfaces[s];
            if (!surf) continue;
            if (!shellRoot.isSurfaceSeeThrough(surf)) {
                return false; // Found opaque window on workspace: wallpaper is static
            }
        }

        return true; // All windows on workspace are see-through: wallpaper is live
    }

    readonly property string islandThemeHelper: Quickshell.shellPath("island/scripts/theme-system.sh").toString().replace(/^file:\/\//, "")

    function islandSetWallpaper(path) {
        let cleanPath = (path || "").trim().replace(/^file:\/\//, "");
        setWallpaperProc.exec([shellRoot.islandThemeHelper, "wallpaper", cleanPath]);
        let isVid = !!cleanPath.match(/\.(mp4|webm|mkv|mov)$/i);
        shellRoot.wallpaperMediaType = isVid ? "video" : "image";
        shellRoot.wallpaperMediaSource = isVid ? ("file://" + cleanPath) : "";
        console.log("[pranc-shell] Wallpaper set via island system: " + cleanPath + " (" + shellRoot.wallpaperMediaType + ")");
        return JSON.stringify({ success: true, mediaType: shellRoot.wallpaperMediaType, mediaSource: shellRoot.wallpaperMediaSource });
    }

    function islandClearWallpaper() {
        setWallpaperProc.exec(["awww", "clear", "000000"]);
        shellRoot.wallpaperMediaType = "none";
        shellRoot.wallpaperMediaSource = "";
        console.log("[pranc-shell] Wallpaper cleared via awww");
        return JSON.stringify({ success: true, mediaType: "none" });
    }

    function openMediaPicker() {
        ShellState.show("wallpaper");
        return JSON.stringify({ success: true, status: "opened" });
    }

    Process {
        id: setWallpaperProc
    }

    Process {
        id: restoreWallpaperProc
        command: [shellRoot.islandThemeHelper, "restore-wallpaper"]
    }

    // dotarch wallpaper bootstrap: ensure the renderer daemon, then restore
    // the saved wallpaper once it is ready. No Hyprland config change needed.
    Timer {
        id: wallpaperRestoreDelay
        interval: 900
        onTriggered: restoreWallpaperProc.running = true
    }

    Component.onCompleted: {
        IslandHub.notifModel = notificationServer.trackedNotifications;
        Quickshell.execDetached(["sh", "-c", "pgrep -x awww-daemon >/dev/null || exec awww-daemon"]);
        Quickshell.execDetached(["sh", "-c", "pgrep -xf 'wl-paste --type text --watch cliphist store' >/dev/null || wl-paste --type text --watch cliphist store >/dev/null 2>&1 & pgrep -xf 'wl-paste --type image --watch cliphist store' >/dev/null || wl-paste --type image --watch cliphist store >/dev/null 2>&1 &"]);
        wallpaperRestoreDelay.start();
    }

    Connections {
        target: idleManager
        function onIdleChanged() {
            if (!idleManager.idle) {
                IslandHub.notifyWake();
            }
        }
    }

    // Global Shortcuts for Background Media Picker
    GlobalShortcut {
        name: "mediaPickerToggle"
        description: "Open desktop background media picker"
        onPressed: {
            shellRoot.openMediaPicker();
        }
    }

    // NOTE: Super-tap opens the launcher via Hyprland bind (SUPER_L release)
    // straight to `qs ipc call notch toggle launcher`, not via GlobalShortcut.

    GlobalShortcut {
        name: "wallpaperSelectorToggle"
        description: "Toggle wallpaper media selector"
        onPressed: {
            shellRoot.openMediaPicker();
        }
    }

    GlobalShortcut {
        name: "overviewToggle"
        description: "Toggle interactive spatial workspace map"
        onPressed: {
            shellRoot.overviewOpen = !shellRoot.overviewOpen;
        }
    }

    GlobalShortcut {
        name: "birdsEyeToggle"
        description: "Toggle Bird's Eye View for horizontal scrolling layout"
        onPressed: {
            shellRoot.birdsEyeOpen = !shellRoot.birdsEyeOpen;
        }
    }

    // =========================================================================
    // Headless IPC Verification: Dedicated Wallpaper Target
    // =========================================================================
    IpcHandler {
        target: "wallpaper"

        property bool enabled: shellRoot.wallpaperEnabled
        property string mediaType: shellRoot.wallpaperMediaType
        property string mediaSource: shellRoot.wallpaperMediaSource
        property bool autoPauseOnOpaque: shellRoot.autoPauseOnOpaque
        property bool live: {
            let dummy = shellRoot._wallpaperLiveTick;
            return shellRoot.shouldWallpaperBeLiveForMonitor(Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
        }

        onEnabledChanged: {
            if (shellRoot.wallpaperEnabled !== enabled) {
                shellRoot.wallpaperEnabled = enabled;
            }
        }

        function toggle(): string {
            shellRoot.wallpaperEnabled = !shellRoot.wallpaperEnabled;
            return JSON.stringify({ success: true, enabled: shellRoot.wallpaperEnabled });
        }

        function setEnabled(val: bool): string {
            shellRoot.wallpaperEnabled = val;
            return JSON.stringify({ success: true, enabled: shellRoot.wallpaperEnabled });
        }

        function setAutoPause(val: bool): string {
            shellRoot.autoPauseOnOpaque = val;
            return JSON.stringify({ success: true, autoPauseOnOpaque: shellRoot.autoPauseOnOpaque });
        }

        function isLive(): string {
            let isLiveVal = shellRoot.shouldWallpaperBeLiveForMonitor(Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
            return JSON.stringify({
                success: true,
                live: isLiveVal,
                autoPauseOnOpaque: shellRoot.autoPauseOnOpaque,
                mediaType: shellRoot.wallpaperMediaType,
                mediaSource: shellRoot.wallpaperMediaSource,
                focusedWorkspace: workspaceManager.focusedWorkspaceId
            });
        }

        function setMedia(path: string, type: string): string {
            let cleanPath = (path || "").trim().replace(/^file:\/\//, "");
            shellRoot.wallpaperMediaSource = cleanPath ? "file://" + cleanPath : "";
            if (type && type.length > 0) {
                shellRoot.wallpaperMediaType = type;
            } else {
                shellRoot.wallpaperMediaType = cleanPath.match(/\.(mp4|webm|mkv|mov)$/i) ? "video" : "image";
            }
            console.log("[pranc-shell] IPC setMedia:", shellRoot.wallpaperMediaType, shellRoot.wallpaperMediaSource);
            return JSON.stringify({
                success: true,
                mediaType: shellRoot.wallpaperMediaType,
                mediaSource: shellRoot.wallpaperMediaSource
            });
        }
    }

    // =========================================================================
    // Headless IPC Verification: Workspace Intelligence
    // =========================================================================
    IpcHandler {
        target: "workspace"

        // Direct scalar properties for fast CLI query
        property int focusedId: workspaceManager.focusedWorkspaceId
        property string focusedName: workspaceManager.focusedWorkspaceName
        property int count: workspaceManager.count

        property string focusedJson: JSON.stringify({
            id: workspaceManager.focusedWorkspaceId,
            name: workspaceManager.focusedWorkspaceName,
            hasFullscreen: workspaceManager.hasFullscreen,
            urgent: workspaceManager.isUrgent,
            monitorId: workspaceManager.focusedMonitorId,
            monitorName: workspaceManager.focusedMonitorName
        })

        property string listJson: {
            const list = workspaceManager.workspaceList;
            if (!list) return "[]";
            const result = [];
            for (let i = 0; i < list.length; ++i) {
                const ws = list[i];
                if (!ws) continue;
                result.push({
                    id: ws.id,
                    name: ws.name,
                    active: ws.active,
                    focused: ws.focused,
                    urgent: ws.urgent,
                    hasFullscreen: ws.hasFullscreen,
                    monitor: ws.monitor ? ws.monitor.name : null,
                    toplevelCount: ws.toplevels && ws.toplevels.values ? ws.toplevels.values.length : 0
                });
            }
            return JSON.stringify(result);
        }
    }

    // =========================================================================
    // Headless IPC Verification: Surface Intelligence
    // =========================================================================
    IpcHandler {
        target: "surface"

        // Direct scalar properties for fast CLI query
        property string activeAddress: surfaceManager.activeAddress
        property string activeTitle: surfaceManager.activeTitle
        property int count: surfaceManager.count

        property string activeJson: JSON.stringify({
            address: surfaceManager.activeAddress,
            title: surfaceManager.activeTitle,
            workspaceId: surfaceManager.activeWorkspaceId,
            workspaceName: surfaceManager.activeWorkspaceName,
            monitorId: surfaceManager.activeMonitorId,
            monitorName: surfaceManager.activeMonitorName,
            urgent: surfaceManager.isUrgent
        })

        property string listJson: {
            const list = surfaceManager.toplevelList;
            if (!list) return "[]";
            const result = [];
            for (let i = 0; i < list.length; ++i) {
                const tl = list[i];
                if (!tl) continue;
                result.push({
                    address: tl.address,
                    title: tl.title,
                    activated: tl.activated,
                    urgent: tl.urgent,
                    workspaceId: tl.workspace ? tl.workspace.id : null,
                    workspaceName: tl.workspace ? tl.workspace.name : null,
                    monitorName: tl.monitor ? tl.monitor.name : null
                });
            }
            return JSON.stringify(result);
        }
    }

    // =========================================================================
    // Headless IPC Verification: Shell Intelligence Integration Facade
    // =========================================================================
    IpcHandler {
        target: "shell"

        // Direct scalar properties
        property int currentWorkspaceId: shellRoot.currentWorkspaceId

        // Direct scalar accessors
        function getCurrentWorkspaceId(): int {
            return shellRoot.currentWorkspaceId;
        }

        function getCurrentWorkspaceName(): string {
            return shellRoot.currentWorkspaceName;
        }

        function getWorkspaceCount(): int {
            return shellRoot.workspaceCount;
        }

        function getSurfaceCount(): int {
            return shellRoot.surfaceCount;
        }

        function hasActiveSurface(): bool {
            return shellRoot.hasActiveSurface;
        }

        function getActiveSurfaceTitle(): string {
            return shellRoot.activeSurfaceTitle;
        }

        function isUrgent(): bool {
            return shellRoot.isUrgent;
        }

        // Complete state summary snapshot
        function getSummary(): string {
            return JSON.stringify({
                currentWorkspaceId: shellRoot.currentWorkspaceId,
                currentWorkspaceName: shellRoot.currentWorkspaceName,
                workspaceCount: shellRoot.workspaceCount,
                surfaceCount: shellRoot.surfaceCount,
                hasActiveSurface: shellRoot.hasActiveSurface,
                activeSurfaceTitle: shellRoot.activeSurfaceTitle,
                isUrgent: shellRoot.isUrgent
            });
        }

        // Delegated Query Verification
        function getWorkspaceById(id: int): string {
            const ws = shellRoot.getWorkspaceById(id);
            if (!ws) return "null";
            return JSON.stringify({
                id: ws.id,
                name: ws.name,
                active: ws.active,
                focused: ws.focused,
                urgent: ws.urgent,
                hasFullscreen: ws.hasFullscreen,
                monitor: ws.monitor ? ws.monitor.name : null,
                toplevelCount: ws.toplevels && ws.toplevels.values ? ws.toplevels.values.length : 0
            });
        }

        function getSurfaceByAddress(address: string): string {
            const tl = shellRoot.getSurfaceByAddress(address);
            if (!tl) return "null";
            return JSON.stringify({
                address: tl.address,
                title: tl.title,
                activated: tl.activated,
                urgent: tl.urgent,
                workspaceId: tl.workspace ? tl.workspace.id : null,
                workspaceName: tl.workspace ? tl.workspace.name : null,
                monitorName: tl.monitor ? tl.monitor.name : null
            });
        }

        function getSurfacesForWorkspace(workspaceId: int): string {
            const list = shellRoot.getSurfacesForWorkspace(workspaceId);
            if (!list) return "[]";
            const result = [];
            for (let i = 0; i < list.length; ++i) {
                const tl = list[i];
                if (!tl) continue;
                result.push({
                    address: tl.address,
                    title: tl.title,
                    activated: tl.activated,
                    urgent: tl.urgent,
                    monitorName: tl.monitor ? tl.monitor.name : null
                });
            }
            return JSON.stringify(result);
        }

        function getSurfacesForMonitor(monitorName: string): string {
            const list = shellRoot.getSurfacesForMonitor(monitorName);
            if (!list) return "[]";
            const result = [];
            for (let i = 0; i < list.length; ++i) {
                const tl = list[i];
                if (!tl) continue;
                result.push({
                    address: tl.address,
                    title: tl.title,
                    activated: tl.activated,
                    urgent: tl.urgent,
                    workspaceId: tl.workspace ? tl.workspace.id : null
                });
            }
            return JSON.stringify(result);
        }
    }

    // =========================================================================
    // Headless IPC Verification: Spatial Workspace Model
    // =========================================================================
    IpcHandler {
        target: "model"

        property int count: workspaceModel.count
        property int occupiedCount: workspaceModel.occupiedCount
        property int emptyCount: workspaceModel.emptyCount
        property string orderedIdsJson: JSON.stringify(workspaceModel.workspaces.map(w => w.id))
        property string activeIdsJson: JSON.stringify(workspaceModel.activeWorkspaceIds)

        function getSummary(): string {
            return JSON.stringify({
                count: workspaceModel.count,
                occupiedCount: workspaceModel.occupiedCount,
                emptyCount: workspaceModel.emptyCount,
                orderedIds: workspaceModel.workspaces.map(w => w.id),
                focusedWorkspaceId: workspaceModel.focusedWorkspace ? workspaceModel.focusedWorkspace.id : -1
            });
        }

        function getWorkspaceById(id: int): string {
            const ws = workspaceModel.getWorkspaceById(id);
            if (!ws) return "null";
            return JSON.stringify({
                id: ws.id,
                name: ws.name,
                active: ws.active,
                focused: ws.focused,
                urgent: ws.urgent,
                monitorName: ws.monitorName,
                surfaceCount: ws.surfaceCount,
                occupied: ws.occupied,
                empty: ws.empty
            });
        }

        function getAdjacentWorkspace(id: int, offset: int, wrap: bool): string {
            const ws = workspaceModel.getAdjacentWorkspace(id, offset, wrap ?? false);
            if (!ws) return "null";
            return JSON.stringify({
                id: ws.id,
                name: ws.name,
                occupied: ws.occupied
            });
        }

        function getOccupiedWorkspaces(): string {
            const list = workspaceModel.getOccupiedWorkspaces();
            return JSON.stringify(list.map(w => ({ id: w.id, name: w.name, surfaceCount: w.surfaceCount })));
        }

        function getEmptyWorkspaces(): string {
            const list = workspaceModel.getEmptyWorkspaces();
            return JSON.stringify(list.map(w => ({ id: w.id, name: w.name })));
        }

        function getWorkspacesForMonitor(monitorName: string): string {
            const list = workspaceModel.getWorkspacesForMonitor(monitorName);
            return JSON.stringify(list.map(w => ({ id: w.id, name: w.name, active: w.active })));
        }

        function getWorkspaceForSurface(address: string): string {
            const ws = workspaceModel.getWorkspaceForSurface(address);
            if (!ws) return "null";
            return JSON.stringify({ id: ws.id, name: ws.name });
        }
    }

    // =========================================================================
    // Headless IPC Verification: Surface Intelligence & Application Model
    // =========================================================================
    IpcHandler {
        target: "model-surface"

        // Direct scalar properties for fast CLI query
        property int count: surfaceModel.count
        property int urgentCount: surfaceModel.urgentCount
        property int applicationCount: surfaceModel.applicationCount
        property string activeAddress: surfaceModel.focusedSurface ? surfaceModel.focusedSurface.address : ""
        property string activeTitle: surfaceModel.focusedSurface ? surfaceModel.focusedSurface.title : ""
        property string activeAppId: surfaceModel.focusedSurface ? surfaceModel.focusedSurface.appId : ""
        property string activeAppName: surfaceModel.focusedSurface ? surfaceModel.focusedSurface.appName : ""

        // State summary snapshot
        function getSummary(): string {
            return JSON.stringify({
                surfaceCount: surfaceModel.count,
                urgentCount: surfaceModel.urgentCount,
                applicationCount: surfaceModel.applicationCount,
                focusedSurface: surfaceModel.focusedSurface ? {
                    address: surfaceModel.focusedSurface.address,
                    title: surfaceModel.focusedSurface.title,
                    appName: surfaceModel.focusedSurface.appName,
                    appId: surfaceModel.focusedSurface.appId,
                    windowClass: surfaceModel.focusedSurface.windowClass,
                    workspaceId: surfaceModel.focusedSurface.workspaceId,
                    monitorName: surfaceModel.focusedSurface.monitorName
                } : null
            });
        }

        // Query normalized surface by address
        function getSurfaceByAddress(address: string): string {
            const s = surfaceModel.getSurfaceByAddress(address);
            if (!s) return "null";
            return JSON.stringify({
                address: s.address,
                title: s.title,
                appName: s.appName,
                appId: s.appId,
                windowClass: s.windowClass,
                isXWayland: s.isXWayland,
                workspaceId: s.workspaceId,
                monitorName: s.monitorName,
                activated: s.activated,
                urgent: s.urgent,
                fullscreen: s.fullscreen,
                floating: s.floating
            });
        }

        // Query surfaces by workspace
        function getSurfacesForWorkspace(workspaceId: int): string {
            const list = surfaceModel.getSurfacesForWorkspace(workspaceId);
            return JSON.stringify(list.map(s => ({
                address: s.address,
                title: s.title,
                appName: s.appName,
                activated: s.activated,
                urgent: s.urgent
            })));
        }

        // Query surfaces by monitor
        function getSurfacesForMonitor(monitorName: string): string {
            const list = surfaceModel.getSurfacesForMonitor(monitorName);
            return JSON.stringify(list.map(s => ({
                address: s.address,
                title: s.title,
                appName: s.appName,
                workspaceId: s.workspaceId
            })));
        }

        // Query surfaces by application identity
        function getSurfacesForApplication(appIdOrClass: string): string {
            const list = surfaceModel.getSurfacesForApplication(appIdOrClass);
            return JSON.stringify(list.map(s => ({
                address: s.address,
                title: s.title,
                workspaceId: s.workspaceId,
                activated: s.activated
            })));
        }

        // Query urgent surfaces
        function getUrgentSurfaces(): string {
            const list = surfaceModel.getUrgentSurfaces();
            return JSON.stringify(list.map(s => ({
                address: s.address,
                title: s.title,
                appName: s.appName,
                workspaceId: s.workspaceId
            })));
        }

        // Query all application groups
        function getApplications(): string {
            const list = surfaceModel.applications;
            return JSON.stringify(list.map(a => ({
                appId: a.appId,
                appName: a.appName,
                windowClass: a.windowClass,
                count: a.count,
                isFocused: a.isFocused,
                isUrgent: a.isUrgent
            })));
        }
    }

    // =========================================================================
    // Headless IPC Verification: Unified Desktop Composition Model
    // =========================================================================
    IpcHandler {
        target: "desktop"

        // Direct scalar properties for fast CLI inspection
        property int workspaceCount: desktopModel.workspaceCount
        property int occupiedWorkspaceCount: desktopModel.occupiedWorkspaceCount
        property int emptyWorkspaceCount: desktopModel.emptyWorkspaceCount
        property int surfaceCount: desktopModel.surfaceCount
        property int applicationCount: desktopModel.applicationCount
        property int urgentSurfaceCount: desktopModel.urgentSurfaceCount
        property int monitorCount: desktopModel.monitorCount
        property bool isUrgent: desktopModel.isUrgent

        property int focusedWorkspaceId: desktopModel.focusedWorkspaceId
        property string focusedWorkspaceName: desktopModel.focusedWorkspaceName
        property string focusedSurfaceTitle: desktopModel.focusedSurface ? desktopModel.focusedSurface.title : ""
        property string focusedSurfaceAddress: desktopModel.focusedSurface ? desktopModel.focusedSurface.address : ""
        property string focusedAppName: desktopModel.focusedApplication ? desktopModel.focusedApplication.appName : ""
        property string focusedMonitorName: desktopModel.focusedMonitor ? desktopModel.focusedMonitor.name : ""

        // Complete state summary snapshot
        function getSummary(): string {
            return JSON.stringify({
                workspaces: {
                    total: desktopModel.workspaceCount,
                    occupied: desktopModel.occupiedWorkspaceCount,
                    empty: desktopModel.emptyWorkspaceCount,
                    focusedId: desktopModel.focusedWorkspaceId,
                    focusedName: desktopModel.focusedWorkspaceName
                },
                surfaces: {
                    total: desktopModel.surfaceCount,
                    urgent: desktopModel.urgentSurfaceCount,
                    focusedTitle: desktopModel.focusedSurface ? desktopModel.focusedSurface.title : null,
                    focusedAddress: desktopModel.focusedSurface ? desktopModel.focusedSurface.address : null
                },
                applications: {
                    total: desktopModel.applicationCount,
                    focusedApp: desktopModel.focusedApplication ? desktopModel.focusedApplication.appName : null
                },
                monitors: {
                    total: desktopModel.monitorCount,
                    focusedMonitor: desktopModel.focusedMonitor ? desktopModel.focusedMonitor.name : null
                },
                isUrgent: desktopModel.isUrgent
            });
        }

        // Focused composition snapshot
        function getFocused(): string {
            const ctx = desktopModel.getFocusedComposition();
            return JSON.stringify({
                workspace: ctx.workspace ? {
                    id: ctx.workspace.id,
                    name: ctx.workspace.name,
                    surfaceCount: ctx.workspace.surfaceCount,
                    applicationCount: ctx.workspace.applicationCount,
                    monitorName: ctx.workspace.monitorName
                } : null,
                surface: ctx.surface ? {
                    address: ctx.surface.address,
                    title: ctx.surface.title,
                    appName: ctx.surface.appName,
                    appId: ctx.surface.appId,
                    windowClass: ctx.surface.windowClass,
                    isXWayland: ctx.surface.isXWayland
                } : null,
                application: ctx.application ? {
                    appId: ctx.application.appId,
                    appName: ctx.application.appName,
                    surfaceCount: ctx.application.count
                } : null,
                monitor: ctx.monitor ? {
                    id: ctx.monitor.id,
                    name: ctx.monitor.name,
                    activeWorkspaceId: ctx.monitor.activeWorkspaceId
                } : null
            });
        }

        // Workspace composition lookup
        function getWorkspaceComposition(workspaceId: int): string {
            const ws = desktopModel.getWorkspaceComposition(workspaceId);
            if (!ws) return "null";
            return JSON.stringify({
                id: ws.id,
                name: ws.name,
                active: ws.active,
                focused: ws.focused,
                urgent: ws.urgent,
                hasFullscreen: ws.hasFullscreen,
                monitorName: ws.monitorName,
                occupied: ws.occupied,
                empty: ws.empty,
                surfaceCount: ws.surfaceCount,
                applicationCount: ws.applicationCount,
                applications: ws.applications.map(a => ({
                    appId: a.appId,
                    appName: a.appName,
                    count: a.count,
                    isFocused: a.isFocused,
                    isUrgent: a.isUrgent
                })),
                surfaces: ws.surfaces.map(s => ({
                    address: s.address,
                    title: s.title,
                    appName: s.appName,
                    activated: s.activated,
                    urgent: s.urgent
                }))
            });
        }

        // Distinct applications on a workspace
        function getApplicationsForWorkspace(workspaceId: int): string {
            const apps = desktopModel.getApplicationsForWorkspace(workspaceId);
            return JSON.stringify(apps.map(a => ({
                appId: a.appId,
                appName: a.appName,
                count: a.count,
                isFocused: a.isFocused,
                isUrgent: a.isUrgent
            })));
        }

        // Normalized surfaces on a workspace
        function getSurfacesForWorkspace(workspaceId: int): string {
            const surfs = desktopModel.getSurfacesForWorkspace(workspaceId);
            return JSON.stringify(surfs.map(s => ({
                address: s.address,
                title: s.title,
                appName: s.appName,
                activated: s.activated,
                urgent: s.urgent
            })));
        }

        // Monitor composition lookup
        function getMonitorComposition(monitorName: string): string {
            const mon = desktopModel.getMonitorComposition(monitorName);
            if (!mon) return "null";
            return JSON.stringify({
                id: mon.id,
                name: mon.name,
                activeWorkspaceId: mon.activeWorkspaceId,
                activeWorkspaceName: mon.activeWorkspaceName,
                workspaceCount: mon.workspaces.length,
                workspaceIds: mon.workspaces.map(w => w.id),
                surfaceCount: mon.surfaceCount,
                applicationCount: mon.applicationCount,
                isFocused: mon.isFocused,
                hasFullscreen: mon.hasFullscreen,
                applications: mon.applications.map(a => ({
                    appId: a.appId,
                    appName: a.appName,
                    count: a.count,
                    workspaceIds: a.workspaceIds
                }))
            });
        }

        // All monitor topology summary
        function getMonitors(): string {
            const list = desktopModel.monitors;
            return JSON.stringify(list.map(mon => ({
                id: mon.id,
                name: mon.name,
                activeWorkspaceId: mon.activeWorkspaceId,
                activeWorkspaceName: mon.activeWorkspaceName,
                workspaceCount: mon.workspaces.length,
                surfaceCount: mon.surfaceCount,
                applicationCount: mon.applicationCount,
                isFocused: mon.isFocused
            })));
        }

        // Application group lookup
        function getApplicationGroup(appIdOrClass: string): string {
            const app = desktopModel.getApplicationGroup(appIdOrClass);
            if (!app) return "null";
            return JSON.stringify({
                appId: app.appId,
                appName: app.appName,
                windowClass: app.windowClass,
                count: app.count,
                isFocused: app.isFocused,
                isUrgent: app.isUrgent,
                primarySurfaceAddress: app.primarySurface ? app.primarySurface.address : ""
            });
        }
    }

    // =========================================================================
    // Headless IPC Verification: Interaction & Intent Mediation Model
    // =========================================================================
    IpcHandler {
        target: "interaction"

        property int totalRequests: shellRoot.interactionModel ? shellRoot.interactionModel.totalRequestsCount : 0
        property int validRequests: shellRoot.interactionModel ? shellRoot.interactionModel.validRequestsCount : 0
        property int rejectedRequests: shellRoot.interactionModel ? shellRoot.interactionModel.rejectedRequestsCount : 0
        property string lastIntent: shellRoot.interactionModel && shellRoot.interactionModel.lastRequest ? shellRoot.interactionModel.lastRequest.intent : ""
        property bool lastValid: shellRoot.interactionModel && shellRoot.interactionModel.lastRequest ? shellRoot.interactionModel.lastRequest.valid : false

        function getLastRequest(): string {
            return JSON.stringify(shellRoot.interactionModel ? shellRoot.interactionModel.lastRequest : null);
        }

        function isActionAvailable(intent: string, target: string, payloadJson: string): bool {
            if (!shellRoot.interactionModel) return false;
            let payload = null;
            if (payloadJson && payloadJson !== "" && payloadJson !== "null") {
                try { payload = JSON.parse(payloadJson); } catch (e) { payload = null; }
            }
            return shellRoot.interactionModel.isActionAvailable(intent, target, payload);
        }

        function validateTarget(intent: string, target: string, payloadJson: string): string {
            if (!shellRoot.interactionModel) return "{}";
            let payload = null;
            if (payloadJson && payloadJson !== "" && payloadJson !== "null") {
                try { payload = JSON.parse(payloadJson); } catch (e) { payload = null; }
            }
            return JSON.stringify(shellRoot.interactionModel.validateTarget(intent, target, payload));
        }

        function requestAction(intent: string, target: string, payloadJson: string): bool {
            if (!shellRoot.interactionModel) return false;
            let payload = null;
            if (payloadJson && payloadJson !== "" && payloadJson !== "null") {
                try { payload = JSON.parse(payloadJson); } catch (e) { payload = null; }
            }
            return shellRoot.interactionModel.requestAction(intent, target, payload);
        }

        function requestSurfaceFocus(address: string): bool {
            return shellRoot.interactionModel ? shellRoot.interactionModel.requestSurfaceFocus(address) : false;
        }

        function requestWorkspaceSwitch(workspaceId: int): bool {
            return shellRoot.interactionModel ? shellRoot.interactionModel.requestWorkspaceSwitch(workspaceId) : false;
        }

        function requestSurfaceClose(address: string): bool {
            return shellRoot.interactionModel ? shellRoot.interactionModel.requestSurfaceClose(address) : false;
        }

        function requestSurfaceMove(address: string, workspaceId: int): bool {
            return shellRoot.interactionModel ? shellRoot.interactionModel.requestSurfaceMove(address, workspaceId) : false;
        }

        function canFocusSurface(address: string): bool {
            return shellRoot.interactionModel ? shellRoot.interactionModel.canFocusSurface(address) : false;
        }

        function canCloseSurface(address: string): bool {
            return shellRoot.interactionModel ? shellRoot.interactionModel.canCloseSurface(address) : false;
        }

        function canSwitchWorkspace(workspaceId: int): bool {
            return shellRoot.interactionModel ? shellRoot.interactionModel.canSwitchWorkspace(workspaceId) : false;
        }

        function canMoveSurfaceToWorkspace(address: string, workspaceId: int): bool {
            return shellRoot.interactionModel ? shellRoot.interactionModel.canMoveSurfaceToWorkspace(address, workspaceId) : false;
        }

        function canToggleFullscreen(address: string): bool {
            return shellRoot.interactionModel ? shellRoot.interactionModel.canToggleFullscreen(address) : false;
        }

        function canToggleFloating(address: string): bool {
            return shellRoot.interactionModel ? shellRoot.interactionModel.canToggleFloating(address) : false;
        }

        function requestSurfaceToggleFullscreen(address: string): bool {
            return shellRoot.interactionModel ? shellRoot.interactionModel.requestSurfaceToggleFullscreen(address) : false;
        }

        function requestSurfaceToggleFloating(address: string): bool {
            return shellRoot.interactionModel ? shellRoot.interactionModel.requestSurfaceToggleFloating(address) : false;
        }

        function getLastActionResult(): string {
            return JSON.stringify(shellRoot.interactionModel ? shellRoot.interactionModel.lastActionResult : null);
        }
    }

    // =========================================================================
    // Headless IPC Verification: Compositor Action Layer
    // =========================================================================
    IpcHandler {
        target: "action"

        property int totalExecuted: shellRoot.compositorActionLayer ? shellRoot.compositorActionLayer.totalExecuted : 0
        property int totalFailed: shellRoot.compositorActionLayer ? shellRoot.compositorActionLayer.totalFailed : 0
        property string lastActionJson: shellRoot.compositorActionLayer ? shellRoot.compositorActionLayer.lastActionJson : "{}"

        function execute(intent: string, target: string, payloadJson: string): string {
            if (!shellRoot.compositorActionLayer) return JSON.stringify({ success: false, reason: "ERR_NATIVE_API_UNAVAILABLE" });
            let payload = {};
            if (payloadJson && payloadJson !== "" && payloadJson !== "null") {
                try { payload = JSON.parse(payloadJson); } catch (e) { payload = {}; }
            }
            const res = shellRoot.compositorActionLayer.executeAction(intent, target, payload);
            return JSON.stringify(res);
        }

        function switchWorkspace(workspaceId: int): string {
            if (!shellRoot.compositorActionLayer) return JSON.stringify({ success: false, reason: "ERR_NATIVE_API_UNAVAILABLE" });
            return JSON.stringify(shellRoot.compositorActionLayer.switchWorkspace(workspaceId, {}));
        }

        function focusSurface(address: string): string {
            if (!shellRoot.compositorActionLayer) return JSON.stringify({ success: false, reason: "ERR_NATIVE_API_UNAVAILABLE" });
            return JSON.stringify(shellRoot.compositorActionLayer.focusSurface(address, {}));
        }

        function closeSurface(address: string): string {
            if (!shellRoot.compositorActionLayer) return JSON.stringify({ success: false, reason: "ERR_NATIVE_API_UNAVAILABLE" });
            return JSON.stringify(shellRoot.compositorActionLayer.closeSurface(address, {}));
        }

        function moveSurfaceToWorkspace(address: string, workspaceId: int): string {
            if (!shellRoot.compositorActionLayer) return JSON.stringify({ success: false, reason: "ERR_NATIVE_API_UNAVAILABLE" });
            return JSON.stringify(shellRoot.compositorActionLayer.moveSurfaceToWorkspace(address, workspaceId, {}));
        }

        function toggleFullscreen(address: string): string {
            if (!shellRoot.compositorActionLayer) return JSON.stringify({ success: false, reason: "ERR_NATIVE_API_UNAVAILABLE" });
            return JSON.stringify(shellRoot.compositorActionLayer.toggleFullscreen(address, {}));
        }

        function toggleFloating(address: string): string {
            if (!shellRoot.compositorActionLayer) return JSON.stringify({ success: false, reason: "ERR_NATIVE_API_UNAVAILABLE" });
            return JSON.stringify(shellRoot.compositorActionLayer.toggleFloating(address, {}));
        }
    }

    // =========================================================================
    // Headless IPC Verification: Idle State Intelligence (Task 24)
    // =========================================================================
    IpcHandler {
        target: "idle"

        property bool isIdle: idleManager.idle
        property int idleSeconds: idleManager.idleSeconds
        property bool enabled: idleManager.enabled
        property bool respectInhibitors: idleManager.respectInhibitors
        property bool simulated: idleManager.simulationActive

        function getSummary(): string {
            return JSON.stringify({
                idle: idleManager.idle,
                idleSeconds: idleManager.idleSeconds,
                enabled: idleManager.enabled,
                respectInhibitors: idleManager.respectInhibitors,
                simulated: idleManager.simulationActive
            });
        }

        function setIdleTimeout(seconds: int): string {
            idleManager.setIdleSeconds(seconds);
            return JSON.stringify({ success: true, idleSeconds: idleManager.idleSeconds });
        }

        function setEnabled(val: bool): string {
            idleManager.setEnabled(val);
            return JSON.stringify({ success: true, enabled: idleManager.enabled });
        }

        function setRespectInhibitors(val: bool): string {
            idleManager.setRespectInhibitors(val);
            return JSON.stringify({ success: true, respectInhibitors: idleManager.respectInhibitors });
        }

        function setSimulatedIdle(val: bool): string {
            idleManager.setSimulatedIdle(val);
            return JSON.stringify({ success: true, simulated: true, idle: idleManager.idle });
        }

        function clearSimulation(): string {
            idleManager.clearSimulation();
            return JSON.stringify({ success: true, simulated: false, idle: idleManager.idle });
        }
    }

    // =========================================================================
    // Headless IPC Verification: Ambient Layer Control (Task 24)
    // =========================================================================
    IpcHandler {
        target: "ambient"

        property bool enabled: shellRoot.ambientEnabled
        property bool alwaysOn: shellRoot.ambientAlwaysOn
        property bool active: shellRoot.ambientEnabled && (shellRoot.ambientAlwaysOn || shellRoot.idle)

        function getSummary(): string {
            return JSON.stringify({
                enabled: shellRoot.ambientEnabled,
                alwaysOn: shellRoot.ambientAlwaysOn,
                active: shellRoot.ambientEnabled && (shellRoot.ambientAlwaysOn || shellRoot.idle),
                idle: shellRoot.idle
            });
        }

        function toggle(): string {
            shellRoot.ambientEnabled = !shellRoot.ambientEnabled;
            return JSON.stringify({ success: true, enabled: shellRoot.ambientEnabled });
        }

        function toggleAlwaysOn(): string {
            shellRoot.ambientAlwaysOn = !shellRoot.ambientAlwaysOn;
            return JSON.stringify({ success: true, alwaysOn: shellRoot.ambientAlwaysOn });
        }

        function setAlwaysOn(val: bool): string {
            shellRoot.ambientAlwaysOn = val;
            return JSON.stringify({ success: true, alwaysOn: shellRoot.ambientAlwaysOn });
        }

        function setEnabled(val: bool): string {
            shellRoot.ambientEnabled = val;
            return JSON.stringify({ success: true, enabled: shellRoot.ambientEnabled });
        }
    }

    // =========================================================================
    // Headless IPC Verification: Unified Desktop Presentation State (Task 25)
    // =========================================================================
    IpcHandler {
        target: "state"

        property int currentWorkspaceId: desktopState.currentWorkspaceId
        property int previousWorkspaceId: desktopState.previousWorkspaceId
        property string direction: desktopState.workspaceTransitionDirection
        property int directionSign: desktopState.workspaceTransitionDirectionSign
        property bool transitioning: desktopState.workspaceTransitioning
        property int surfaceCount: desktopState.currentSurfaceCount
        property bool hasFullscreen: desktopState.currentWorkspaceHasFullscreen
        property bool isUrgent: desktopState.currentWorkspaceIsUrgent
        property bool ambientActive: desktopState.ambientActive
        property bool leftSidebarOpen: desktopState.leftSidebarOpen
        property bool rightSidebarOpen: desktopState.rightSidebarOpen
        property bool bottomBarOpen: desktopState.bottomBarOpen
        property bool mediaWidgetOpen: desktopState.mediaWidgetOpen

        function getSummary(): string {
            return JSON.stringify({
                currentWorkspaceId: desktopState.currentWorkspaceId,
                previousWorkspaceId: desktopState.previousWorkspaceId,
                workspaceTransitionDirection: desktopState.workspaceTransitionDirection,
                workspaceTransitionDirectionSign: desktopState.workspaceTransitionDirectionSign,
                workspaceTransitioning: desktopState.workspaceTransitioning,
                currentSurfaceCount: desktopState.currentSurfaceCount,
                currentWorkspaceHasFullscreen: desktopState.currentWorkspaceHasFullscreen,
                currentWorkspaceIsUrgent: desktopState.currentWorkspaceIsUrgent,
                ambientActive: desktopState.ambientActive,
                leftSidebarOpen: desktopState.leftSidebarOpen,
                rightSidebarOpen: desktopState.rightSidebarOpen,
                bottomBarOpen: desktopState.bottomBarOpen,
                mediaWidgetOpen: desktopState.mediaWidgetOpen
            });
        }

        function getTransition(): string {
            return JSON.stringify({
                currentWorkspaceId: desktopState.currentWorkspaceId,
                previousWorkspaceId: desktopState.previousWorkspaceId,
                direction: desktopState.workspaceTransitionDirection,
                directionSign: desktopState.workspaceTransitionDirectionSign,
                transitioning: desktopState.workspaceTransitioning,
                progress: desktopState.workspaceTransitionProgress
            });
        }

        function setLeftSidebarOpen(val: bool): string {
            desktopState.setLeftSidebarOpen(val);
            return JSON.stringify({ success: true, leftSidebarOpen: desktopState.leftSidebarOpen });
        }

        function setRightSidebarOpen(val: bool): string {
            desktopState.setRightSidebarOpen(val);
            return JSON.stringify({ success: true, rightSidebarOpen: desktopState.rightSidebarOpen });
        }

        function setBottomBarOpen(val: bool): string {
            desktopState.setBottomBarOpen(val);
            return JSON.stringify({ success: true, bottomBarOpen: desktopState.bottomBarOpen });
        }

        function setMediaWidgetOpen(val: bool): string {
            desktopState.setMediaWidgetOpen(val);
            return JSON.stringify({ success: true, mediaWidgetOpen: desktopState.mediaWidgetOpen });
        }

        property bool gameMode: ShellState.gameMode
        function toggleGameMode(): string {
            ShellState.toggleGameMode();
            return JSON.stringify({ success: true, gameMode: ShellState.gameMode });
        }

        function setGameMode(val: bool): string {
            ShellState.setGameMode(val);
            return JSON.stringify({ success: true, gameMode: val });
        }
    }

    // =========================================================================
    // Headless IPC Verification: Shell Control Center (Task 26)
    // =========================================================================
    IpcHandler {
        target: "control"

        property bool leftSidebarOpen: desktopState.leftSidebarOpen
        property bool rightSidebarOpen: desktopState.rightSidebarOpen
        property bool bottomBarOpen: desktopState.bottomBarOpen
        property bool wallpaperEnabled: shellRoot.wallpaperEnabled
        property bool ambientEnabled: shellRoot.ambientEnabled

        property int focusedWorkspaceId: desktopState.currentWorkspaceId
        property string focusedWorkspaceName: desktopState.currentWorkspace ? (desktopState.currentWorkspace.name || "") : ""
        property int focusedSurfaceCount: desktopState.currentSurfaceCount
        property bool focusedHasFullscreen: desktopState.currentWorkspaceHasFullscreen
        property bool focusedIsUrgent: desktopState.currentWorkspaceIsUrgent

        property int workspaceCount: desktopModel.workspaceCount
        property int totalSurfaceCount: desktopModel.surfaceCount
        property string wallpaperMediaType: shellRoot.wallpaperMediaType
        property string wallpaperMediaSource: shellRoot.wallpaperMediaSource

        function toggleWallpaper(): string {
            shellRoot.wallpaperEnabled = !shellRoot.wallpaperEnabled;
            return JSON.stringify({ success: true, wallpaperEnabled: shellRoot.wallpaperEnabled });
        }

        function toggleAmbient(): string {
            shellRoot.ambientEnabled = !shellRoot.ambientEnabled;
            return JSON.stringify({ success: true, ambientEnabled: shellRoot.ambientEnabled });
        }

        function setWallpaperEnabled(val: bool): string {
            shellRoot.wallpaperEnabled = val;
            return JSON.stringify({ success: true, wallpaperEnabled: shellRoot.wallpaperEnabled });
        }

        function setAmbientEnabled(val: bool): string {
            shellRoot.ambientEnabled = val;
            return JSON.stringify({ success: true, ambientEnabled: shellRoot.ambientEnabled });
        }

        function setLeftSidebarOpen(val: bool): string {
            desktopState.setLeftSidebarOpen(val);
            return JSON.stringify({ success: true, leftSidebarOpen: desktopState.leftSidebarOpen });
        }

        function openMediaPicker(): string {
            return shellRoot.openMediaPicker();
        }

        function setWallpaperMedia(path: string): string {
            return shellRoot.islandSetWallpaper(path);
        }

        function clearWallpaperMedia(): string {
            return shellRoot.islandClearWallpaper();
        }

        function getSummary(): string {
            return JSON.stringify({
                leftSidebarOpen: desktopState.leftSidebarOpen,
                rightSidebarOpen: desktopState.rightSidebarOpen,
                bottomBarOpen: desktopState.bottomBarOpen,
                wallpaperEnabled: shellRoot.wallpaperEnabled,
                wallpaperMediaType: shellRoot.wallpaperMediaType,
                wallpaperMediaSource: shellRoot.wallpaperMediaSource,
                ambientEnabled: shellRoot.ambientEnabled,
                focusedWorkspaceId: desktopState.currentWorkspaceId,
                focusedWorkspaceName: desktopState.currentWorkspace ? (desktopState.currentWorkspace.name || "") : "",
                focusedSurfaceCount: desktopState.currentSurfaceCount,
                focusedHasFullscreen: desktopState.currentWorkspaceHasFullscreen,
                focusedIsUrgent: desktopState.currentWorkspaceIsUrgent,
                workspaceCount: desktopModel.workspaceCount,
                totalSurfaceCount: desktopModel.surfaceCount
            });
        }
    }

    // =========================================================================
    // Dynamic Island + notifications (ported from vyeos/dotarch, lives in island/)
    // =========================================================================
    property string pendingCaptureMode: ""

    NotificationServer {
        id: notificationServer

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        onNotification: (notification) => {
            notification.tracked = true;
            // Feature 4: Enforce 50-item bounded ring buffer & pixmap decoupling
            const tracked = notificationServer.trackedNotifications ? notificationServer.trackedNotifications.values : [];
            if (tracked && tracked.length > 50) {
                const oldest = tracked[0];
                if (oldest) {
                    try {
                        oldest.dismiss();
                    } catch (e) {}
                }
                gc();
            }
            ShellState.noticeTick = ShellState.noticeTick + 1;
            IslandHub.notifModel = notificationServer.trackedNotifications;
            IslandHub.notifyArrived();
            notificationPopups.showToast(notification);
        }
    }

    NotificationPopups {
        id: notificationPopups
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    LowBatteryMonitor {}

    Variants {
        model: Quickshell.screens

        Notch {
            required property var modelData

            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        CaptureSelector {
            required property var modelData

            screen: modelData
        }
    }

    PanelWindow {
        id: onboardingWindow
        visible: onboardingManager.visible
        color: "transparent"
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "vyeos-onboarding"

        anchors {
            top: true
        }
        margins {
            top: 70
        }

        implicitWidth: onboardingManager.width
        implicitHeight: onboardingManager.height

        OnboardingManager {
            id: onboardingManager
            anchors.centerIn: parent
        }
    }

    SettingsWindow {
        id: settingsWindow
        screen: (ShellState.activeScreenName ? Quickshell.screens.find(s => s && s.name === ShellState.activeScreenName) : null) || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    }

    SpatialWorkspaceMap {
        id: spatialWorkspaceMap
        open: shellRoot.overviewOpen && !ShellState.gameMode
        wallpaperSource: shellRoot.wallpaperMediaSource
        workspaceModel: shellRoot.workspaceModel
        surfaceModel: shellRoot.surfaceModel
        compositorActionLayer: shellRoot.compositorActionLayer
        desktopState: shellRoot.desktopState
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        onCloseRequested: shellRoot.overviewOpen = false
    }

    BirdsEyeOverview {
        id: birdsEyeOverview
        open: shellRoot.birdsEyeOpen && !ShellState.gameMode
        workspaceModel: shellRoot.workspaceModel
        surfaceModel: shellRoot.surfaceModel
        compositorActionLayer: shellRoot.compositorActionLayer
        screen: (ShellState.activeScreenName ? Quickshell.screens.find(s => s && s.name === ShellState.activeScreenName) : null) || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        onCloseRequested: shellRoot.birdsEyeOpen = false
    }

    Connections {
        target: ShellState
        function onOpenSettingsRequested(category) {
            if (!ShellState.gameMode) {
                if (desktopState) {
                    desktopState.setLeftSidebarOpen(false);
                    desktopState.setRightSidebarOpen(false);
                    desktopState.setBottomBarOpen(false);
                }
                if (category && category !== "") {
                    settingsWindow.openCategory(category);
                } else {
                    settingsWindow.show();
                }
            }
        }
        function onGameModeToggled(active) {
            if (active) {
                settingsWindow.hide();
                shellRoot.overviewOpen = false;
                shellRoot.birdsEyeOpen = false;
            }
        }
        function onFeatherModeToggled(active) {
            if (active) {
                settingsWindow.hide();
                shellRoot.overviewOpen = false;
                shellRoot.birdsEyeOpen = false;
            }
        }
    }

    IpcHandler {
        target: "feather"

        property bool enabled: ShellState.featherMode
        property int killedCount: ShellState.featherKilledCount

        function toggle(): string {
            ShellState.toggleFeatherMode();
            return JSON.stringify({ success: true, enabled: ShellState.featherMode });
        }

        function setEnabled(val: bool): string {
            ShellState.setFeatherMode(val);
            return JSON.stringify({ success: true, enabled: val });
        }

        function status(): string {
            return JSON.stringify({
                success: true,
                enabled: ShellState.featherMode,
                killedCount: ShellState.featherKilledCount
            });
        }
    }

    IpcHandler {
        target: "overview"

        property bool open: shellRoot.overviewOpen

        function toggle(): string {
            shellRoot.overviewOpen = !shellRoot.overviewOpen;
            return JSON.stringify({ success: true, open: shellRoot.overviewOpen });
        }

        function show(): string {
            shellRoot.overviewOpen = true;
            return JSON.stringify({ success: true, open: true });
        }

        function close(): string {
            shellRoot.overviewOpen = false;
            return JSON.stringify({ success: true, open: false });
        }

        function isOpen(): string {
            return JSON.stringify({ success: true, open: shellRoot.overviewOpen });
        }
    }

    IpcHandler {
        target: "birdseye"

        property bool open: shellRoot.birdsEyeOpen

        function toggle(): string {
            shellRoot.birdsEyeOpen = !shellRoot.birdsEyeOpen;
            return JSON.stringify({ success: true, open: shellRoot.birdsEyeOpen });
        }

        function show(): string {
            shellRoot.birdsEyeOpen = true;
            return JSON.stringify({ success: true, open: true });
        }

        function close(): string {
            shellRoot.birdsEyeOpen = false;
            return JSON.stringify({ success: true, open: false });
        }

        function isOpen(): string {
            return JSON.stringify({ success: true, open: shellRoot.birdsEyeOpen });
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            settingsWindow.toggle();
        }

        function open(category: string): void {
            if (category && category !== "") {
                settingsWindow.openCategory(category);
            } else {
                settingsWindow.show();
            }
        }

        function close(): void {
            settingsWindow.hide();
        }
    }

    IpcHandler {
        target: "notch"

        function toggle(panel: string) {
            ShellState.show(panel);
        }

        function close() {
            ShellState.close();
        }

        function next() {
            ShellState.cycle(1);
        }

        function previous() {
            ShellState.cycle(-1);
        }
    }

    IpcHandler {
        target: "island"

        function getSummary(): string {
            return JSON.stringify({
                unread: IslandHub.unreadCount,
                dnd: IslandHub.dnd,
                recording: IslandHub.recordingActive,
                recElapsedSec: IslandHub.recElapsedSec,
                mediaActive: IslandHub.mediaActive,
                mediaPlaying: IslandHub.mediaPlaying,
                timerActive: TimerState.hasActive,
                timerText: TimerState.compactText,
                micActive: PrivacyState.micActive,
                camActive: PrivacyState.camActive,
                charging: PowerState.charging,
                batteryPercent: Math.round(PowerState.percent * 100),
                btConnected: BtState.connectedNames,
                btPowered: BtState.powered,
                shelfFiles: ShelfState.files.length,
                downloads: ShelfState.activeDownloads.length,
                weather: WeatherState.tempC,
                primaryPanel: IslandHub.primaryPanel(),
                trackedCount: notificationServer.trackedNotifications && notificationServer.trackedNotifications.values ? notificationServer.trackedNotifications.values.length : 0,
                volumePercent: IslandHub.volumePercent,
                volumeActive: IslandHub.volumeActive,
                volumeMuted: IslandHub.volumeMuted
            });
        }

        function adjustVolume(delta: int): string {
            IslandHub.adjustVolume(delta);
            return JSON.stringify({ success: true, volumePercent: IslandHub.volumePercent });
        }

        function mediaNext(): string {
            IslandHub.mediaNext();
            return JSON.stringify({ success: true, action: "next" });
        }

        function mediaPrevious(): string {
            IslandHub.mediaPrevious();
            return JSON.stringify({ success: true, action: "previous" });
        }

        function mediaPlayPause(): string {
            IslandHub.mediaPlayPause();
            return JSON.stringify({ success: true, action: "play-pause" });
        }

        function timerToggle(): string {
            if (TimerState.swRunning)
                TimerState.swPause();
            else
                TimerState.swStart();
            return JSON.stringify({ success: true, running: TimerState.swRunning });
        }

        function timerReset(): string {
            TimerState.swReset();
            return JSON.stringify({ success: true });
        }

        function countdownAdd(minutes: int): string {
            TimerState.addCountdown(minutes, "");
            return JSON.stringify({ success: true, count: TimerState.countdowns.length });
        }

        function focusStart(minutes: int): string {
            TimerState.startFocus(minutes || 25);
            return JSON.stringify({ success: true, focusActive: TimerState.focusActive });
        }

        function focusEnd(): string {
            TimerState.endFocus();
            return JSON.stringify({ success: true });
        }

        function markSeen(): string {
            IslandHub.markSeen();
            return JSON.stringify({ success: true });
        }

        function shelfAdd(path: string): string {
            const added = ShelfState.addFile(path);
            return JSON.stringify({ success: added, files: ShelfState.files.length });
        }

        function weatherRefresh(): string {
            WeatherState.refresh();
            return JSON.stringify({ success: true });
        }

        function showTransient(text: string, ms: int): string {
            IslandHub.showTransient(text, ms || 3500);
            return JSON.stringify({ success: true, text: text });
        }
    }

    IpcHandler {
        target: "theme"

        function reload() {
            Theme.reload();
            AppearanceState.refreshThemes();
            AppearanceState.refreshWallpapers();
        }
    }

    Process {
        id: displayCycleProc
        command: [Quickshell.shellPath("island/scripts/display-switcher.sh"), "cycle"]
    }

    Process {
        id: displayConfirmProc
        command: [Quickshell.shellPath("island/scripts/display-switcher.sh"), "confirm"]
    }

    Process {
        id: displayRevertProc
        command: [Quickshell.shellPath("island/scripts/display-switcher.sh"), "revert"]
    }

    IpcHandler {
        target: "displays"

        function cycle(): string {
            displayCycleProc.running = true;
            return JSON.stringify({ success: true, action: "cycle" });
        }

        function confirm(): string {
            displayConfirmProc.running = true;
            return JSON.stringify({ success: true, action: "confirm" });
        }

        function revert(): string {
            displayRevertProc.running = true;
            return JSON.stringify({ success: true, action: "revert" });
        }
    }

    IpcHandler {
        target: "capture"

        function screenshot(mode: string) {
            if (!["full", "window", "region"].includes(mode))
                return;

            shellRoot.pendingCaptureMode = mode;
            if (mode !== "region")
                ShellState.close();
            captureShortcutDelay.restart();
        }

        function toggleRecording() {
            if (Backend.recording) {
                Backend.toggleRecording();
                return;
            }

            ShellState.close();
            recordingShortcutDelay.restart();
        }
    }

    Timer {
        id: captureShortcutDelay

        interval: Theme.animationNormal + 100
        onTriggered: {
            Backend.capture(shellRoot.pendingCaptureMode);
            shellRoot.pendingCaptureMode = "";
        }
    }

    Timer {
        id: recordingShortcutDelay

        interval: Theme.animationNormal + 100
        onTriggered: Backend.toggleRecording()
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: monitorScope
            required property var modelData

            property bool leftSidebarOpen: false
            property bool rightSidebarOpen: false
            property bool bottomBarOpen: false
            property bool mediaWidgetOpen: false

            // GPU-Accelerated Live MP4 Video Wallpaper (WlrLayer.Background)
            Wallpaper {
                id: wallpaper
                screen: monitorScope.modelData
                enabled: shellRoot.wallpaperEnabled && !ShellState.gameMode && !ShellState.featherMode
                mediaType: shellRoot.wallpaperMediaType
                mediaSource: shellRoot.wallpaperMediaSource
                live: {
                    let dummy = shellRoot._wallpaperLiveTick;
                    return shellRoot.shouldWallpaperBeLiveForMonitor(monitorScope.modelData);
                }
            }

            // Desktop Ambient HUD layer (WlrLayer.Bottom)
            AmbientLayer {
                id: ambientLayer
                screen: monitorScope.modelData
                idle: shellRoot.idle
                alwaysOn: shellRoot.ambientAlwaysOn
                enabled: shellRoot.ambientEnabled && !ShellState.gameMode && !ShellState.featherMode
            }

            // Spatial Workspace Transition HUD (WlrLayer.Top, ephemeral)
            DesktopTransition {
                id: desktopTransition
                screen: monitorScope.modelData
                desktopState: shellRoot.desktopState
            }

            // Edge trigger overlay window
            PanelWindow {
                id: triggerWindow
                visible: !ShellState.gameMode

                screen: monitorScope.modelData

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                exclusionMode: ExclusionMode.Ignore
                aboveWindows: true
                focusable: false
                color: "transparent"

                WlrLayershell.namespace: "pranc-shell"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                mask: Region {
                    Region { item: leftTrigger }
                    Region { item: centerTrigger }
                    Region { item: rightTrigger }
                    Region { item: mediaTrigger }
                }

                // 1. Bottom-left -> controls left sidebar opening
                EdgeTrigger {
                    id: leftTrigger
                    edge: "bottom-left"
                    triggerWidth: 120
                    triggerHeight: 2
                    debugColor: "#00ff88"

                    onActivated: {
                        console.log("[pranc-shell] Bottom-left trigger ACTIVATED")
                        monitorScope.leftSidebarOpen = true
                    }
                    onDeactivated: {
                        console.log("[pranc-shell] Bottom-left trigger DEACTIVATED")
                    }
                }

                // 2. Bottom-center -> controls bottom bar opening
                EdgeTrigger {
                    id: centerTrigger
                    edge: "bottom-center"
                    triggerWidth: 300
                    triggerHeight: 2
                    debugColor: "#00bfff"

                    onActivated: {
                        console.log("[pranc-shell] Bottom-center trigger ACTIVATED")
                        monitorScope.bottomBarOpen = true
                    }
                    onDeactivated: {
                        console.log("[pranc-shell] Bottom-center trigger DEACTIVATED")
                    }
                }

                // 3. Bottom-right -> controls right sidebar opening
                EdgeTrigger {
                    id: rightTrigger
                    edge: "bottom-right"
                    triggerWidth: 120
                    triggerHeight: 2
                    debugColor: "#ff0088"

                    onActivated: {
                        console.log("[pranc-shell] Bottom-right trigger ACTIVATED")
                        monitorScope.rightSidebarOpen = true
                    }
                    onDeactivated: {
                        console.log("[pranc-shell] Bottom-right trigger DEACTIVATED")
                    }
                }

                // 4. Middle-right -> controls independent media widget opening
                EdgeTrigger {
                    id: mediaTrigger
                    edge: "right"
                    triggerWidth: 3
                    triggerHeight: 200
                    debugColor: "#ea9381"

                    onActivated: {
                        console.log("[pranc-shell] Middle-right media trigger ACTIVATED")
                        mediaCloseDebounce.stop()
                        monitorScope.mediaWidgetOpen = true
                        if (shellRoot.desktopState) shellRoot.desktopState.setMediaWidgetOpen(true)
                    }
                    onDeactivated: {
                        console.log("[pranc-shell] Middle-right media trigger DEACTIVATED")
                        if (!mediaWidget.hovered) {
                            mediaCloseDebounce.restart()
                        }
                    }
                }
            }

            // Left sidebar container surface
            LeftSidebar {
                id: leftSidebar
                screen: monitorScope.modelData
                desktopModel: shellRoot.desktopModel
                desktopState: shellRoot.desktopState
                wallpaperEnabled: shellRoot.wallpaperEnabled
                ambientEnabled: shellRoot.ambientEnabled
                ambientAlwaysOn: shellRoot.ambientAlwaysOn
                open: (monitorScope.leftSidebarOpen || (shellRoot.desktopState && shellRoot.desktopState.leftSidebarOpen)) && !ShellState.gameMode

                onToggleWallpaper: shellRoot.wallpaperEnabled = !shellRoot.wallpaperEnabled
                onCycleAmbient: {
                    if (shellRoot.ambientEnabled && !shellRoot.ambientAlwaysOn) {
                        shellRoot.ambientAlwaysOn = true;
                    } else if (shellRoot.ambientEnabled && shellRoot.ambientAlwaysOn) {
                        shellRoot.ambientEnabled = false;
                        shellRoot.ambientAlwaysOn = false;
                    } else {
                        shellRoot.ambientEnabled = true;
                        shellRoot.ambientAlwaysOn = false;
                    }
                }

                onHoveredChanged: {
                    if (!hovered && !leftTrigger.active) {
                        monitorScope.leftSidebarOpen = false
                        if (shellRoot.desktopState) shellRoot.desktopState.setLeftSidebarOpen(false)
                    }
                }
            }

            // Right sidebar container surface
            RightSidebar {
                id: rightSidebar
                screen: monitorScope.modelData
                desktopModel: shellRoot.desktopModel
                surfaceModel: shellRoot.surfaceModel
                interactionModel: shellRoot.interactionModel
                open: (monitorScope.rightSidebarOpen || (shellRoot.desktopState && shellRoot.desktopState.rightSidebarOpen)) && !ShellState.gameMode

                onHoveredChanged: {
                    if (!hovered && !rightTrigger.active) {
                        monitorScope.rightSidebarOpen = false
                        if (shellRoot.desktopState) shellRoot.desktopState.setRightSidebarOpen(false)
                    }
                }
            }

            // Floating bottom bar surface
            BottomBar {
                id: bottomBar
                screen: monitorScope.modelData
                desktopModel: shellRoot.desktopModel
                interactionModel: shellRoot.interactionModel
                desktopState: shellRoot.desktopState
                open: (monitorScope.bottomBarOpen || (shellRoot.desktopState && shellRoot.desktopState.bottomBarOpen)) && !ShellState.gameMode

                onHoveredChanged: {
                    if (!hovered && !centerTrigger.active) {
                        monitorScope.bottomBarOpen = false
                        if (shellRoot.desktopState) shellRoot.desktopState.setBottomBarOpen(false)
                    }
                }
            }

            // Floating independent media widget surface (middle-right edge trigger)
            MediaWidget {
                id: mediaWidget
                screen: monitorScope.modelData
                desktopState: shellRoot.desktopState
                open: (monitorScope.mediaWidgetOpen || (shellRoot.desktopState && shellRoot.desktopState.mediaWidgetOpen)) && !ShellState.gameMode

                Timer {
                    id: mediaCloseDebounce
                    interval: 350
                    repeat: false
                    onTriggered: {
                        if (!mediaWidget.hovered && !mediaTrigger.active) {
                            monitorScope.mediaWidgetOpen = false
                            if (shellRoot.desktopState) shellRoot.desktopState.setMediaWidgetOpen(false)
                        }
                    }
                }

                onHoveredChanged: {
                    if (hovered) {
                        mediaCloseDebounce.stop()
                    } else if (!mediaTrigger.active) {
                        mediaCloseDebounce.restart()
                    }
                }
            }

            // Stash Pocket & Drop Zone on the right edge (special:stash)
            StashPocket {
                id: stashPocket
                screen: monitorScope.modelData
                surfaceModel: shellRoot.surfaceModel
                workspaceManager: shellRoot.workspaceManager
                compositorActionLayer: shellRoot.compositorActionLayer
            }
        }
    }
}
