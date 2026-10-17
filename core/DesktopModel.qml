import QtQuick
import Quickshell

QtObject {
    id: root

    // =========================================================================
    // Required Injected Upstream Model Authorities
    // =========================================================================
    required property var workspaceModel
    required property var surfaceModel

    // =========================================================================
    // Internal Reactive State Projection
    // Single-pass O(W + S) derivation combining spatial workspaces and normalized
    // surfaces into an authoritative desktop composition graph.
    // =========================================================================
    readonly property var _projection: {
        const allWs = (workspaceModel && workspaceModel.allWorkspaces) ? workspaceModel.allWorkspaces : [];
        const surfByWs = (surfaceModel && surfaceModel.surfacesByWorkspace) ? surfaceModel.surfacesByWorkspace : {};
        const surfByMon = (surfaceModel && surfaceModel.surfacesByMonitor) ? surfaceModel.surfacesByMonitor : {};
        const allApps = (surfaceModel && surfaceModel.applications) ? surfaceModel.applications : [];
        const focusedSurf = (surfaceModel && surfaceModel.focusedSurface) ? surfaceModel.focusedSurface : null;
        const focusedWs = (workspaceModel && workspaceModel.focusedWorkspace) ? workspaceModel.focusedWorkspace : null;
        const focusedWsId = focusedWs ? focusedWs.id : -1;

        const regularWorkspaces = [];
        const specialWorkspaces = [];
        const workspaceMap = {};
        const monitorMap = {};
        let occupiedTotal = 0;
        let emptyTotal = 0;

        // O(W + S) Single-pass synthesis of workspaces with normalized surfaces
        for (let i = 0; i < allWs.length; ++i) {
            const ws = allWs[i];
            if (!ws) continue;

            const wsSurfaces = surfByWs[ws.id] || [];
            const surfaceCount = wsSurfaces.length;
            const isOccupied = surfaceCount > 0;
            const isEmpty = surfaceCount === 0;

            // Synthesize distinct application composition for this workspace
            const wsAppMap = {};
            const wsAppList = [];
            let hasUrgent = ws.urgent || false;
            let hasFullscreen = ws.hasFullscreen || false;

            for (let s = 0; s < surfaceCount; ++s) {
                const surf = wsSurfaces[s];
                if (!surf) continue;

                if (surf.urgent) hasUrgent = true;
                if (surf.fullscreen) hasFullscreen = true;

                const appKey = surf.appId || surf.windowClass || "unknown";
                if (!wsAppMap[appKey]) {
                    const appEntry = {
                        appId: appKey,
                        appName: surf.appName,
                        windowClass: surf.windowClass,
                        count: 0,
                        surfaces: [],
                        isFocused: false,
                        isUrgent: false,
                        primarySurface: surf
                    };
                    wsAppMap[appKey] = appEntry;
                    wsAppList.push(appEntry);
                }

                const entry = wsAppMap[appKey];
                entry.count++;
                entry.surfaces.push(surf);
                if (surf.activated) {
                    entry.isFocused = true;
                    entry.primarySurface = surf;
                }
                if (surf.urgent) {
                    entry.isUrgent = true;
                }
            }

            const isWsFocused = ws.focused || (ws.id === focusedWsId);

            const wsComp = {
                id: ws.id,
                name: ws.name ?? "",
                isSpecial: ws.isSpecial ?? (ws.id < 0),
                active: ws.active ?? false,
                focused: isWsFocused,
                urgent: hasUrgent,
                hasFullscreen: hasFullscreen,
                monitor: ws.monitor,
                monitorId: ws.monitorId ?? -1,
                monitorName: ws.monitorName ?? "",
                surfaces: wsSurfaces,
                surfaceCount: surfaceCount,
                occupied: isOccupied,
                empty: isEmpty,
                applications: wsAppList,
                applicationCount: wsAppList.length,
                rawWorkspace: ws.rawWorkspace
            };

            workspaceMap[ws.id] = wsComp;

            if (wsComp.isSpecial) {
                specialWorkspaces.push(wsComp);
            } else {
                regularWorkspaces.push(wsComp);
                if (isOccupied) occupiedTotal++;
                if (isEmpty) emptyTotal++;
            }

            // Bucket workspace under its host monitor
            const monName = wsComp.monitorName;
            if (monName) {
                if (!monitorMap[monName]) {
                    monitorMap[monName] = {
                        id: wsComp.monitorId,
                        name: monName,
                        monitor: ws.monitor,
                        workspaces: [],
                        activeWorkspace: null,
                        activeWorkspaceId: -1,
                        activeWorkspaceName: "",
                        surfaces: surfByMon[monName] || [],
                        surfaceCount: (surfByMon[monName] || []).length,
                        applications: [],
                        applicationCount: 0,
                        isFocused: false,
                        hasFullscreen: false
                    };
                }
                const monRecord = monitorMap[monName];
                monRecord.workspaces.push(wsComp);
                if (wsComp.active) {
                    monRecord.activeWorkspace = wsComp;
                    monRecord.activeWorkspaceId = wsComp.id;
                    monRecord.activeWorkspaceName = wsComp.name;
                }
                if (wsComp.focused) {
                    monRecord.isFocused = true;
                }
                if (wsComp.hasFullscreen) {
                    monRecord.hasFullscreen = true;
                }
            }
        }

        // Deterministic workspace sorting (ID ascending)
        regularWorkspaces.sort((a, b) => a.id - b.id);
        specialWorkspaces.sort((a, b) => a.id - b.id);

        // Synthesize monitor topology and distinct monitor applications
        const monitorList = [];
        const monNames = Object.keys(monitorMap);
        for (let m = 0; m < monNames.length; ++m) {
            const monName = monNames[m];
            const mon = monitorMap[monName];

            mon.workspaces.sort((a, b) => a.id - b.id);

            const monAppMap = {};
            const monAppList = [];
            const monSurfs = mon.surfaces;

            for (let s = 0; s < monSurfs.length; ++s) {
                const surf = monSurfs[s];
                if (!surf) continue;

                if (surf.fullscreen) mon.hasFullscreen = true;

                const appKey = surf.appId || surf.windowClass || "unknown";
                if (!monAppMap[appKey]) {
                    const appEntry = {
                        appId: appKey,
                        appName: surf.appName,
                        windowClass: surf.windowClass,
                        count: 0,
                        surfaces: [],
                        workspaceIds: [],
                        isFocused: false,
                        isUrgent: false,
                        primarySurface: surf
                    };
                    monAppMap[appKey] = appEntry;
                    monAppList.push(appEntry);
                }

                const entry = monAppMap[appKey];
                entry.count++;
                entry.surfaces.push(surf);
                if (entry.workspaceIds.indexOf(surf.workspaceId) === -1) {
                    entry.workspaceIds.push(surf.workspaceId);
                }
                if (surf.activated) {
                    entry.isFocused = true;
                    entry.primarySurface = surf;
                }
                if (surf.urgent) {
                    entry.isUrgent = true;
                }
            }

            mon.applications = monAppList;
            mon.applicationCount = monAppList.length;
            monitorList.push(mon);
        }

        // Deterministic monitor sorting (by ID ascending)
        monitorList.sort((a, b) => a.id - b.id);

        // Resolve focused application group
        let focusedApp = null;
        if (focusedSurf) {
            const targetKey = focusedSurf.appId || focusedSurf.windowClass || "";
            for (let i = 0; i < allApps.length; ++i) {
                const app = allApps[i];
                if (app.appId === targetKey || app.isFocused) {
                    focusedApp = app;
                    break;
                }
            }
        }

        // Resolve focused workspace composition
        const focusedWsComp = (focusedWsId !== -1 && workspaceMap[focusedWsId]) ? workspaceMap[focusedWsId] : null;

        // Resolve focused monitor composition
        const focusedMon = (focusedWsComp && focusedWsComp.monitorName && monitorMap[focusedWsComp.monitorName])
            ? monitorMap[focusedWsComp.monitorName]
            : null;

        return {
            workspaces: regularWorkspaces,
            specialWorkspaces: specialWorkspaces,
            allWorkspaces: regularWorkspaces.concat(specialWorkspaces),
            workspaceMap: workspaceMap,
            monitors: monitorList,
            monitorMap: monitorMap,
            occupiedCount: occupiedTotal,
            emptyCount: emptyTotal,
            focusedWorkspace: focusedWsComp,
            focusedApplication: focusedApp,
            focusedMonitor: focusedMon
        };
    }

    // =========================================================================
    // Public Reactive Properties: Unified Desktop Snapshot
    // =========================================================================

    // Workspaces
    readonly property var workspaces: _projection ? _projection.workspaces : []
    readonly property var specialWorkspaces: _projection ? _projection.specialWorkspaces : []
    readonly property var allWorkspaces: _projection ? _projection.allWorkspaces : []
    readonly property int workspaceCount: workspaces ? workspaces.length : 0
    readonly property int occupiedWorkspaceCount: _projection ? _projection.occupiedCount : 0
    readonly property int emptyWorkspaceCount: _projection ? _projection.emptyCount : 0

    // Surfaces & Applications
    readonly property var surfaces: surfaceModel ? surfaceModel.surfaces : []
    readonly property int surfaceCount: surfaceModel ? surfaceModel.count : 0
    readonly property var applications: surfaceModel ? surfaceModel.applications : []
    readonly property int applicationCount: surfaceModel ? surfaceModel.applicationCount : 0
    readonly property int urgentSurfaceCount: surfaceModel ? surfaceModel.urgentCount : 0
    readonly property bool isUrgent: urgentSurfaceCount > 0 || (focusedWorkspace !== null && focusedWorkspace.urgent)

    // Focus State
    readonly property var focusedWorkspace: _projection ? _projection.focusedWorkspace : null
    readonly property int focusedWorkspaceId: focusedWorkspace ? focusedWorkspace.id : -1
    readonly property string focusedWorkspaceName: focusedWorkspace ? focusedWorkspace.name : ""
    readonly property var focusedSurface: surfaceModel ? surfaceModel.focusedSurface : null
    readonly property bool hasFocusedSurface: surfaceModel ? surfaceModel.hasFocusedSurface : false
    readonly property var focusedApplication: _projection ? _projection.focusedApplication : null
    readonly property var focusedMonitor: _projection ? _projection.focusedMonitor : null

    // Monitor Topology & Matrix
    readonly property var monitors: _projection ? _projection.monitors : []
    readonly property int monitorCount: monitors ? monitors.length : 0

    // =========================================================================
    // Public Read-Only Query API
    // =========================================================================

    // O(1) Workspace composition lookup by integer ID
    function getWorkspaceComposition(workspaceId: int) {
        if (!_projection || !_projection.workspaceMap) return null;
        return _projection.workspaceMap[workspaceId] || null;
    }

    // Retrieve distinct applications present on a specific workspace
    function getApplicationsForWorkspace(workspaceId: int) {
        const comp = getWorkspaceComposition(workspaceId);
        return comp ? comp.applications : [];
    }

    // Retrieve normalized surfaces contained on a specific workspace
    function getSurfacesForWorkspace(workspaceId: int) {
        const comp = getWorkspaceComposition(workspaceId);
        return comp ? comp.surfaces : [];
    }

    // Retrieve monitor composition by name string, integer ID, or monitor object
    function getMonitorComposition(monitor) {
        if (!_projection || !_projection.monitors) return null;

        if (typeof monitor === "string") {
            return _projection.monitorMap ? (_projection.monitorMap[monitor] || null) : null;
        }

        const targetId = (typeof monitor === "number") ? monitor : (monitor && monitor.id !== undefined ? monitor.id : -1);
        const targetName = (monitor && typeof monitor === "object" && monitor.name) ? monitor.name : "";

        for (let i = 0; i < _projection.monitors.length; ++i) {
            const m = _projection.monitors[i];
            if (targetId !== -1 && m.id === targetId) return m;
            if (targetName !== "" && m.name === targetName) return m;
        }
        return null;
    }

    // Retrieve unified snapshot of current desktop focus context
    function getFocusedComposition() {
        return {
            workspace: focusedWorkspace,
            surface: focusedSurface,
            application: focusedApplication,
            monitor: focusedMonitor
        };
    }

    // Look up global ApplicationGroup by appId, class, or display name (case-insensitive)
    function getApplicationGroup(appIdOrClass: string) {
        if (!appIdOrClass || !surfaceModel) return null;
        return surfaceModel.getApplicationSummary(appIdOrClass);
    }

    // Convenience: Retrieve all occupied workspace compositions
    function getOccupiedWorkspaces() {
        if (!workspaces) return [];
        return workspaces.filter(w => w.occupied);
    }

    // Convenience: Retrieve all empty workspace compositions
    function getEmptyWorkspaces() {
        if (!workspaces) return [];
        return workspaces.filter(w => w.empty);
    }

    // Convenience: Retrieve workspace compositions hosted by a monitor
    function getWorkspacesForMonitor(monitor) {
        const mon = getMonitorComposition(monitor);
        return mon ? mon.workspaces : [];
    }

    // Convenience: Retrieve applications present on a monitor
    function getApplicationsForMonitor(monitor) {
        const mon = getMonitorComposition(monitor);
        return mon ? mon.applications : [];
    }
}
