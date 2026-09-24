import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components"
import "core"
import "panels"
import "wallpaper"

ShellRoot {
    id: shellRoot

    // Compositor intelligence layer singletons (compositor-wide lifetime)
    WorkspaceManager {
        id: workspaceManager
    }

    SurfaceManager {
        id: surfaceManager
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

    // Authoritative shell-level aliases
    readonly property alias workspaceManager: workspaceManager
    readonly property alias surfaceManager: surfaceManager
    readonly property alias workspaceModel: workspaceModel
    readonly property alias surfaceModel: surfaceModel

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

    // Authoritative shell-level state for live wallpaper
    property bool wallpaperEnabled: true

    // Temporary development IPC control for toggling/managing wallpaper
    IpcHandler {
        target: "wallpaper"

        property bool enabled: shellRoot.wallpaperEnabled

        function toggle() {
            shellRoot.wallpaperEnabled = !shellRoot.wallpaperEnabled;
            console.log("[pranc-shell] IPC: wallpaperEnabled toggled to " + shellRoot.wallpaperEnabled);
        }

        function setEnabled(val: bool) {
            shellRoot.wallpaperEnabled = val;
            console.log("[pranc-shell] IPC: wallpaperEnabled set to " + shellRoot.wallpaperEnabled);
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

    Variants {
        model: Quickshell.screens

        Scope {
            id: monitorScope
            required property var modelData

            property bool leftSidebarOpen: false
            property bool rightSidebarOpen: false
            property bool bottomBarOpen: false

            // Live wallpaper rendering surface (WlrLayer.Background)
            Wallpaper {
                id: wallpaper
                screen: monitorScope.modelData
                enabled: shellRoot.wallpaperEnabled
            }

            // Edge trigger overlay window
            PanelWindow {
                id: triggerWindow

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
                }

                // Temporary visual test & debug indicator row (top-left)
                Row {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    spacing: 3

                    // Shell alive indicator (from Task 1)
                    Rectangle {
                        width: 8
                        height: 8
                        color: "#80ffffff"
                    }

                    // Left trigger debug indicator
                    Rectangle {
                        width: 8
                        height: 8
                        color: leftTrigger.active ? "#00ff88" : "#30ffffff"
                    }

                    // Center trigger debug indicator
                    Rectangle {
                        width: 8
                        height: 8
                        color: centerTrigger.active ? "#00bfff" : "#30ffffff"
                    }

                    // Right trigger debug indicator
                    Rectangle {
                        width: 8
                        height: 8
                        color: rightTrigger.active ? "#ff0088" : "#30ffffff"
                    }
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
            }

            // Left sidebar container surface
            LeftSidebar {
                id: leftSidebar
                screen: monitorScope.modelData
                open: monitorScope.leftSidebarOpen

                onHoveredChanged: {
                    if (!hovered && !leftTrigger.active) {
                        monitorScope.leftSidebarOpen = false
                    }
                }
            }

            // Right sidebar container surface
            RightSidebar {
                id: rightSidebar
                screen: monitorScope.modelData
                open: monitorScope.rightSidebarOpen

                onHoveredChanged: {
                    if (!hovered && !rightTrigger.active) {
                        monitorScope.rightSidebarOpen = false
                    }
                }
            }

            // Floating bottom bar surface
            BottomBar {
                id: bottomBar
                screen: monitorScope.modelData
                open: monitorScope.bottomBarOpen

                onHoveredChanged: {
                    if (!hovered && !centerTrigger.active) {
                        monitorScope.bottomBarOpen = false
                    }
                }
            }
        }
    }
}
