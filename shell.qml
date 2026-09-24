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

    // Authoritative shell-level aliases
    readonly property alias workspaceManager: workspaceManager
    readonly property alias surfaceManager: surfaceManager

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
