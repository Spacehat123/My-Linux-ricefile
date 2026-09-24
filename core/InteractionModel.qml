import QtQuick

QtObject {
    id: root

    // =========================================================================
    // Required Injected Upstream Authorities
    // =========================================================================
    required property var desktopModel
    required property var surfaceModel
    required property var workspaceModel

    // =========================================================================
    // Reactive Telemetry & Audit Counters
    // =========================================================================
    property var lastRequest: null
    property var lastActionResult: null
    property var actionLayer: null
    property int totalRequestsCount: 0
    property int validRequestsCount: 0
    property int rejectedRequestsCount: 0

    // =========================================================================
    // Interaction Signals (Compositor Event Bus)
    // =========================================================================
    signal actionRequested(string intent, var target, var payload, bool valid)
    signal surfaceInteractionRequested(string intent, string address, bool valid)
    signal workspaceInteractionRequested(string intent, int workspaceId, bool valid)

    // =========================================================================
    // Target Validation & Action Availability (Dynamic Stale-Target Protection)
    // =========================================================================

    function canFocusSurface(address: string): bool {
        if (!address || !surfaceModel) return false;
        const surf = surfaceModel.getSurfaceByAddress(address);
        return Boolean(surf && !surf.activated);
    }

    function canCloseSurface(address: string): bool {
        if (!address || !surfaceModel) return false;
        const surf = surfaceModel.getSurfaceByAddress(address);
        return Boolean(surf);
    }

    function canSwitchWorkspace(workspaceId: int): bool {
        if (workspaceId === undefined || workspaceId === null || isNaN(workspaceId)) return false;
        if (!workspaceModel || !desktopModel) return false;
        const ws = workspaceModel.getWorkspaceById(workspaceId);
        if (!ws) return false;
        return ws.id !== desktopModel.focusedWorkspaceId;
    }

    function canMoveSurfaceToWorkspace(address: string, workspaceId: int): bool {
        if (!address || !surfaceModel || !workspaceModel) return false;
        const surf = surfaceModel.getSurfaceByAddress(address);
        if (!surf) return false;
        const ws = workspaceModel.getWorkspaceById(workspaceId);
        if (!ws) return false;
        return surf.workspaceId !== ws.id;
    }

    function canToggleFullscreen(address: string): bool {
        if (!address || !surfaceModel) return false;
        const surf = surfaceModel.getSurfaceByAddress(address);
        return Boolean(surf);
    }

    function canToggleFloating(address: string): bool {
        // Quickshell 0.3.1 does not provide reactive floating property; unsupported per Task 22
        return false;
    }
    function _sanitizeSurface(s) {
        if (!s) return null;
        return {
            address: s.address,
            title: s.title,
            appName: s.appName,
            appId: s.appId,
            workspaceId: s.workspaceId,
            workspaceName: s.workspaceName,
            activated: s.activated,
            urgent: s.urgent,
            fullscreen: s.fullscreen,
            floating: s.floating
        };
    }

    function _sanitizeWorkspace(ws) {
        if (!ws) return null;
        return {
            id: ws.id,
            name: ws.name,
            occupied: ws.occupied,
            surfaceCount: ws.surfaceCount,
            monitorName: ws.monitorName
        };
    }

    function validateTarget(intent: string, target, payload) {
        const p = payload ?? {};
        const res = {
            valid: false,
            reason: "UNKNOWN",
            intent: intent ?? "",
            target: target,
            payload: p,
            targetItem: null
        };

        if (!intent) {
            res.reason = "ERR_MISSING_INTENT";
            return res;
        }

        switch (intent) {
            case "focusSurface": {
                const addr = String(target ?? "");
                if (!addr || !surfaceModel) {
                    res.reason = "ERR_SURFACE_NOT_FOUND";
                    return res;
                }
                const s = surfaceModel.getSurfaceByAddress(addr);
                if (!s) {
                    res.reason = "ERR_SURFACE_NOT_FOUND";
                    return res;
                }
                if (s.activated) {
                    res.reason = "ERR_SURFACE_ALREADY_FOCUSED";
                    res.targetItem = _sanitizeSurface(s);
                    return res;
                }
                res.valid = true;
                res.reason = "OK";
                res.targetItem = _sanitizeSurface(s);
                return res;
            }

            case "switchWorkspace": {
                const wsId = typeof target === "number" ? target : parseInt(target, 10);
                if (isNaN(wsId) || !workspaceModel || !desktopModel) {
                    res.reason = "ERR_INVALID_WORKSPACE_ID";
                    return res;
                }
                const ws = workspaceModel.getWorkspaceById(wsId);
                if (!ws) {
                    res.reason = "ERR_WORKSPACE_NOT_FOUND";
                    return res;
                }
                if (ws.id === desktopModel.focusedWorkspaceId) {
                    res.reason = "ERR_WORKSPACE_ALREADY_FOCUSED";
                    res.targetItem = _sanitizeWorkspace(ws);
                    return res;
                }
                res.valid = true;
                res.reason = "OK";
                res.targetItem = _sanitizeWorkspace(ws);
                return res;
            }

            case "closeSurface": {
                const addr = String(target ?? "");
                if (!addr || !surfaceModel) {
                    res.reason = "ERR_SURFACE_NOT_FOUND";
                    return res;
                }
                const s = surfaceModel.getSurfaceByAddress(addr);
                if (!s) {
                    res.reason = "ERR_SURFACE_NOT_FOUND";
                    return res;
                }
                res.valid = true;
                res.reason = "OK";
                res.targetItem = _sanitizeSurface(s);
                return res;
            }

            case "moveSurfaceToWorkspace": {
                const addr = String(target ?? "");
                if (!addr || !surfaceModel) {
                    res.reason = "ERR_SURFACE_NOT_FOUND";
                    return res;
                }
                const s = surfaceModel.getSurfaceByAddress(addr);
                if (!s) {
                    res.reason = "ERR_SURFACE_NOT_FOUND";
                    return res;
                }
                if (p.workspaceId === undefined || p.workspaceId === null) {
                    res.reason = "ERR_MISSING_PAYLOAD";
                    return res;
                }
                const targetWsId = typeof p.workspaceId === "number" ? p.workspaceId : parseInt(p.workspaceId, 10);
                const ws = workspaceModel.getWorkspaceById(targetWsId);
                if (!ws) {
                    res.reason = "ERR_TARGET_WORKSPACE_NOT_FOUND";
                    return res;
                }
                if (s.workspaceId === ws.id) {
                    res.reason = "ERR_SURFACE_ALREADY_ON_WORKSPACE";
                    res.targetItem = _sanitizeSurface(s);
                    return res;
                }
                res.valid = true;
                res.reason = "OK";
                res.targetItem = _sanitizeSurface(s);
                return res;
            }

            case "toggleFullscreen": {
                const addr = String(target ?? "");
                if (!addr || !surfaceModel) {
                    res.reason = "ERR_SURFACE_NOT_FOUND";
                    return res;
                }
                const s = surfaceModel.getSurfaceByAddress(addr);
                if (!s) {
                    res.reason = "ERR_SURFACE_NOT_FOUND";
                    return res;
                }
                res.valid = true;
                res.reason = "OK";
                res.targetItem = _sanitizeSurface(s);
                return res;
            }

            case "toggleFloating": {
                res.valid = false;
                res.reason = "ERR_UNSUPPORTED_ACTION";
                return res;
            }

            default:
                res.reason = "ERR_INVALID_INTENT";
                return res;
        }
    }

    function isActionAvailable(intent: string, target, payload): bool {
        return validateTarget(intent, target, payload).valid;
    }

    // =========================================================================
    // Request Dispatch Protocol (Zero Hyprland Mutation)
    // =========================================================================

    function requestAction(intent: string, target, payload): bool {
        const normPayload = payload ?? {};
        const val = validateTarget(intent, target, normPayload);

        const record = {
            intent: intent,
            target: target,
            payload: normPayload,
            valid: val.valid,
            reason: val.reason,
            timestamp: Date.now()
        };

        lastRequest = record;
        totalRequestsCount++;
        if (val.valid) {
            validRequestsCount++;
        } else {
            rejectedRequestsCount++;
        }

        // Emit general intent signal
        actionRequested(intent, target, normPayload, val.valid);

        // Emit domain-specific signals
        if (intent === "switchWorkspace") {
            const wsId = typeof target === "number" ? target : parseInt(target, 10);
            workspaceInteractionRequested(intent, wsId, val.valid);
        } else if (intent === "focusSurface" || intent === "closeSurface" ||
                   intent === "moveSurfaceToWorkspace" || intent === "toggleFullscreen" ||
                   intent === "toggleFloating") {
            surfaceInteractionRequested(intent, String(target), val.valid);
        }

        console.log("[pranc-shell:interaction] Intent: " + intent + " target: " + target + " valid: " + val.valid + " (" + val.reason + ")");

        if (!val.valid) {
            return false;
        }

        // Delegate to CompositorActionLayer if connected
        if (actionLayer && typeof actionLayer.executeAction === "function") {
            const result = actionLayer.executeAction(intent, target, normPayload);
            root.lastActionResult = result;
            return Boolean(result && result.success);
        }

        return true;
    }

    function requestSurfaceFocus(address: string): bool {
        return requestAction("focusSurface", address, {});
    }

    function requestWorkspaceSwitch(workspaceId: int): bool {
        return requestAction("switchWorkspace", workspaceId, {});
    }

    function requestSurfaceClose(address: string): bool {
        return requestAction("closeSurface", address, {});
    }

    function requestSurfaceMove(address: string, workspaceId: int): bool {
        return requestAction("moveSurfaceToWorkspace", address, { workspaceId: workspaceId });
    }

    function requestSurfaceToggleFullscreen(address: string): bool {
        return requestAction("toggleFullscreen", address, {});
    }

    function requestSurfaceToggleFloating(address: string): bool {
        return requestAction("toggleFloating", address, {});
    }
}
