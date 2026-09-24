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

    // Authoritative shell-level aliases
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
                desktopModel: shellRoot.desktopModel
                surfaceModel: shellRoot.surfaceModel
                interactionModel: shellRoot.interactionModel
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
                desktopModel: shellRoot.desktopModel
                interactionModel: shellRoot.interactionModel
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
