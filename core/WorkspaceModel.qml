import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    // =========================================================================
    // Required Injected Authorities
    // =========================================================================
    required property var workspaceManager
    required property var surfaceManager

    // =========================================================================
    // Internal Reactive State Projection
    // =========================================================================
    readonly property var _projection: {
        const rawWs = (workspaceManager && workspaceManager.workspaceList) ? workspaceManager.workspaceList : [];
        const rawTl = (surfaceManager && surfaceManager.toplevelList) ? surfaceManager.toplevelList : [];
        const focusedId = workspaceManager ? workspaceManager.focusedWorkspaceId : -1;
        const globalUrgent = (workspaceManager && workspaceManager.isUrgent) || (surfaceManager && surfaceManager.isUrgent);

        // O(S) bucket surfaces by workspace ID
        const surfacesByWs = {};
        for (let i = 0; i < rawTl.length; ++i) {
            const tl = rawTl[i];
            if (!tl || !tl.workspace) continue;
            const wsId = tl.workspace.id;
            if (!surfacesByWs[wsId]) surfacesByWs[wsId] = [];
            surfacesByWs[wsId].push(tl);
        }

        const regular = [];
        const special = [];
        let occupied = 0;
        let empty = 0;
        const activeIds = [];

        // O(W) enrich workspace items
        for (let i = 0; i < rawWs.length; ++i) {
            const ws = rawWs[i];
            if (!ws) continue;

            const wsSurfaces = surfacesByWs[ws.id] || [];
            const surfaceCount = wsSurfaces.length;
            const isOccupied = surfaceCount > 0;
            const isEmpty = surfaceCount === 0;

            let hasUrgentSurface = false;
            for (let s = 0; s < surfaceCount; ++s) {
                if (wsSurfaces[s] && wsSurfaces[s].urgent) {
                    hasUrgentSurface = true;
                    break;
                }
            }

            const item = {
                id: ws.id,
                name: ws.name ?? "",
                isSpecial: ws.id < 0,
                active: ws.active,
                focused: ws.focused || (ws.id === focusedId),
                urgent: ws.urgent || hasUrgentSurface,
                hasFullscreen: ws.hasFullscreen,
                monitor: ws.monitor,
                monitorId: ws.monitor ? ws.monitor.id : -1,
                monitorName: ws.monitor ? (ws.monitor.name ?? "") : "",
                surfaces: wsSurfaces,
                surfaceCount: surfaceCount,
                occupied: isOccupied,
                empty: isEmpty,
                rawWorkspace: ws
            };

            if (ws.active) {
                activeIds.push(ws.id);
            }

            if (ws.id < 0) {
                special.push(item);
            } else {
                regular.push(item);
                if (isOccupied) occupied++;
                if (isEmpty) empty++;
            }
        }

        // Deterministic sorting (ID ascending)
        regular.sort((a, b) => a.id - b.id);
        special.sort((a, b) => a.id - b.id);

        return {
            workspaces: regular,
            specialWorkspaces: special,
            allWorkspaces: regular.concat(special),
            occupiedCount: occupied,
            emptyCount: empty,
            activeWorkspaceIds: activeIds
        };
    }

    // =========================================================================
    // Public Reactive Properties
    // =========================================================================
    readonly property var workspaces: _projection ? _projection.workspaces : []
    readonly property var specialWorkspaces: _projection ? _projection.specialWorkspaces : []
    readonly property var allWorkspaces: _projection ? _projection.allWorkspaces : []
    readonly property int count: workspaces ? workspaces.length : 0
    readonly property int occupiedCount: _projection ? _projection.occupiedCount : 0
    readonly property int emptyCount: _projection ? _projection.emptyCount : 0
    readonly property var activeWorkspaceIds: _projection ? _projection.activeWorkspaceIds : []

    readonly property var focusedWorkspace: {
        const fid = workspaceManager ? workspaceManager.focusedWorkspaceId : -1;
        if (fid === -1 || !allWorkspaces) return null;
        for (let i = 0; i < allWorkspaces.length; ++i) {
            if (allWorkspaces[i].id === fid) return allWorkspaces[i];
        }
        return null;
    }

    // =========================================================================
    // Public Read-Only Query API
    // =========================================================================
    function getWorkspaceById(id: int) {
        if (!allWorkspaces) return null;
        for (let i = 0; i < allWorkspaces.length; ++i) {
            if (allWorkspaces[i].id === id) return allWorkspaces[i];
        }
        return null;
    }

    function getWorkspaceByName(name: string) {
        if (!allWorkspaces || !name) return null;
        for (let i = 0; i < allWorkspaces.length; ++i) {
            if (allWorkspaces[i].name === name) return allWorkspaces[i];
        }
        return null;
    }

    function getOccupiedWorkspaces() {
        if (!workspaces) return [];
        return workspaces.filter(w => w.occupied);
    }

    function getEmptyWorkspaces() {
        if (!workspaces) return [];
        return workspaces.filter(w => w.empty);
    }

    function getWorkspacesForMonitor(monitor) {
        if (!workspaces) return [];
        const result = [];
        for (let i = 0; i < workspaces.length; ++i) {
            const ws = workspaces[i];
            if (!ws) continue;
            if (typeof monitor === "number") {
                if (ws.monitorId === monitor) result.push(ws);
            } else if (typeof monitor === "string") {
                if (ws.monitorName === monitor) result.push(ws);
            } else if (ws.monitor === monitor) {
                result.push(ws);
            }
        }
        return result;
    }

    function getSurfacesForWorkspace(workspaceId: int) {
        const ws = getWorkspaceById(workspaceId);
        return ws ? ws.surfaces : [];
    }

    function getWorkspaceForSurface(addressOrToplevel) {
        if (!addressOrToplevel || !surfaceManager) return null;
        let tl = null;
        if (typeof addressOrToplevel === "string") {
            tl = surfaceManager.getToplevelByAddress(addressOrToplevel);
        } else if (typeof addressOrToplevel === "object") {
            tl = addressOrToplevel;
        }
        if (!tl || !tl.workspace) return null;
        return getWorkspaceById(tl.workspace.id);
    }

    function getAdjacentWorkspace(id: int, offset: int, wrap) {
        if (!workspaces || workspaces.length === 0) return null;
        let idx = -1;
        for (let i = 0; i < workspaces.length; ++i) {
            if (workspaces[i].id === id) {
                idx = i;
                break;
            }
        }
        if (idx === -1) return null;

        let targetIdx = idx + offset;
        if (wrap) {
            targetIdx = ((targetIdx % workspaces.length) + workspaces.length) % workspaces.length;
        } else {
            if (targetIdx < 0 || targetIdx >= workspaces.length) return null;
        }
        return workspaces[targetIdx];
    }

    function getNextWorkspace(id: int, wrap) {
        return getAdjacentWorkspace(id, 1, wrap ?? false);
    }

    function getPreviousWorkspace(id: int, wrap) {
        return getAdjacentWorkspace(id, -1, wrap ?? false);
    }
}
