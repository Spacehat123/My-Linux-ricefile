import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    // =========================================================================
    // Required Injected Upstream Authorities
    // =========================================================================
    required property var workspaceManager
    required property var surfaceManager
    property var workspaceModel: null
    property var surfaceModel: null
    property var interactionModel: null

    // =========================================================================
    // Telemetry & Reactive Counters
    // =========================================================================
    property int totalExecuted: 0
    property int totalFailed: 0
    property var lastResult: null
    readonly property string lastActionJson: JSON.stringify(lastResult)

    // =========================================================================
    // Action Event Bus Signals
    // =========================================================================
    signal actionExecuted(string intent, var target, var payload, string reason)
    signal actionFailed(string intent, var target, var payload, string reason)

    // =========================================================================
    // Internal Result Packaging & Logging
    // =========================================================================
    function _result(success: bool, reason: string, intent: string, target, payload) {
        const res = {
            success: success,
            reason: reason,
            intent: intent ?? "",
            target: target,
            payload: payload ?? {},
            timestamp: Date.now()
        };
        root.lastResult = res;

        if (success) {
            root.totalExecuted++;
            root.actionExecuted(res.intent, res.target, res.payload, res.reason);
            console.log("[pranc-shell:action] OK: " + res.intent + " target=" + res.target + " (" + res.reason + ")");
        } else {
            root.totalFailed++;
            root.actionFailed(res.intent, res.target, res.payload, res.reason);
            console.warn("[pranc-shell:action] FAIL: " + res.intent + " target=" + res.target + " (" + res.reason + ")");
        }

        return res;
    }

    function _cleanAddress(addr): string {
        if (!addr) return "";
        let s = String(addr).trim().toLowerCase();
        if (s.startsWith("0x")) s = s.slice(2);
        return s;
    }

    function _findToplevel(addr) {
        if (!addr) return null;
        const clean = _cleanAddress(addr);
        if (!clean) return null;

        // Try raw toplevelList from surfaceManager first
        if (surfaceManager && surfaceManager.toplevelList) {
            const list = surfaceManager.toplevelList;
            for (let i = 0; i < list.length; ++i) {
                const tl = list[i];
                if (!tl || !tl.address) continue;
                if (_cleanAddress(tl.address) === clean) return tl;
            }
        }

        // Try surfaceModel normalized items if available
        if (surfaceModel && typeof surfaceModel.getSurfaceByAddress === "function") {
            const norm = surfaceModel.getSurfaceByAddress(clean);
            if (norm && norm.rawToplevel) return norm.rawToplevel;
        }

        return null;
    }

    function _formatWindowSelector(cleanAddr: string): string {
        return "address:0x" + cleanAddr;
    }

    // =========================================================================
    // Master Execution Router & Capability Barrier
    // =========================================================================
    function executeAction(intent: string, target, payload) {
        const p = payload ?? {};

        switch (intent) {
            case "switchWorkspace": {
                const wsId = typeof target === "number" ? target : parseInt(target, 10);
                return switchWorkspace(wsId, p);
            }

            case "focusSurface": {
                return focusSurface(String(target ?? ""), p);
            }

            case "closeSurface": {
                return closeSurface(String(target ?? ""), p);
            }

            case "moveSurfaceToWorkspace": {
                const wsId = p.workspaceId !== undefined ? (typeof p.workspaceId === "number" ? p.workspaceId : parseInt(p.workspaceId, 10)) : NaN;
                return moveSurfaceToWorkspace(String(target ?? ""), wsId, p);
            }

            case "toggleFullscreen": {
                return toggleFullscreen(String(target ?? ""), p);
            }

            case "moveToSpecialWorkspace": {
                return moveToSpecialWorkspace(target, p);
            }

            case "toggleSpecialWorkspace": {
                return toggleSpecialWorkspace(target, p);
            }

            // Explicitly handled unsupported actions
            case "toggleFloating":
            case "resizeSurface":
            default:
                return _result(false, "ERR_UNSUPPORTED_ACTION", intent, target, p);
        }
    }

    // =========================================================================
    // Approved Action 1: Switch Workspace
    // =========================================================================
    function switchWorkspace(targetId: int, payload) {
        const p = payload ?? {};

        if (isNaN(targetId) || targetId === undefined || targetId === null) {
            return _result(false, "ERR_TARGET_NOT_FOUND", "switchWorkspace", targetId, p);
        }

        if (workspaceManager && workspaceManager.focusedWorkspaceId === targetId) {
            return _result(false, "ERR_ALREADY_ACTIVE", "switchWorkspace", targetId, p);
        }

        const ws = workspaceManager ? workspaceManager.getWorkspaceById(targetId) : null;
        const modelWs = (!ws && workspaceModel) ? workspaceModel.getWorkspaceById(targetId) : null;

        if (!ws && !modelWs) {
            return _result(false, "ERR_TARGET_NOT_FOUND", "switchWorkspace", targetId, p);
        }

        let executed = false;
        // Native HyprlandWorkspace.activate()
        const rawWs = ws ?? (modelWs ? modelWs.rawWorkspace : null);
        if (rawWs && typeof rawWs.activate === "function") {
            try {
                rawWs.activate();
                executed = true;
            } catch (e) {
                console.warn("[pranc-shell:action] rawWs.activate() threw: " + e);
            }
        }

        if (!executed) {
            return _result(false, "ERR_NATIVE_API_UNAVAILABLE", "switchWorkspace", targetId, p);
        }

        return _result(true, "OK", "switchWorkspace", targetId, p);
    }

    // =========================================================================
    // Approved Action 2: Focus Surface
    // =========================================================================
    function focusSurface(targetAddress: string, payload) {
        const p = payload ?? {};
        const clean = _cleanAddress(targetAddress);

        if (!clean) {
            return _result(false, "ERR_TARGET_NOT_FOUND", "focusSurface", targetAddress, p);
        }

        const tl = _findToplevel(clean);
        if (!tl) {
            if (typeof Hyprland !== "undefined" && typeof Hyprland.dispatch === "function") {
                try {
                    Hyprland.dispatch('hl.dsp.focus({ window = "' + _formatWindowSelector(clean) + '" })');
                    return _result(true, "OK_FALLBACK", "focusSurface", targetAddress, p);
                } catch (e) {
                    console.warn("[pranc-shell:action] Hyprland.dispatch focus fallback threw: " + e);
                }
            }
            return _result(false, "ERR_TARGET_NOT_FOUND", "focusSurface", targetAddress, p);
        }

        const activeClean = surfaceManager ? _cleanAddress(surfaceManager.activeAddress) : "";
        if (tl.activated || (activeClean && activeClean === clean)) {
            return _result(false, "ERR_ALREADY_ACTIVE", "focusSurface", targetAddress, p);
        }

        // If the surface is on a different workspace, activate its workspace first
        if (tl.workspace && workspaceManager && tl.workspace.id !== workspaceManager.focusedWorkspaceId) {
            if (typeof tl.workspace.activate === "function") {
                try {
                    tl.workspace.activate();
                } catch (e) {
                    console.warn("[pranc-shell:action] tl.workspace.activate() threw: " + e);
                }
            }
        }

        let executed = false;
        // Primary call: native Wayland toplevel activation
        if (tl.wayland && typeof tl.wayland.activate === "function") {
            try {
                tl.wayland.activate();
                executed = true;
            } catch (e) {
                console.warn("[pranc-shell:action] tl.wayland.activate() threw: " + e);
            }
        }

        // Secondary call: native in-process Hyprland Lua dispatch
        if (!executed && typeof Hyprland !== "undefined" && typeof Hyprland.dispatch === "function") {
            try {
                Hyprland.dispatch('hl.dsp.focus({ window = "' + _formatWindowSelector(clean) + '" })');
                executed = true;
            } catch (e) {
                console.warn("[pranc-shell:action] Hyprland.dispatch focus threw: " + e);
            }
        }

        if (!executed) {
            return _result(false, "ERR_NATIVE_API_UNAVAILABLE", "focusSurface", targetAddress, p);
        }

        return _result(true, "OK", "focusSurface", targetAddress, p);
    }

    // =========================================================================
    // Approved Action 3: Close Surface
    // =========================================================================
    function closeSurface(targetAddress: string, payload) {
        const p = payload ?? {};
        const clean = _cleanAddress(targetAddress);

        if (!clean) {
            return _result(false, "ERR_TARGET_NOT_FOUND", "closeSurface", targetAddress, p);
        }

        const tl = _findToplevel(clean);
        if (!tl) {
            return _result(false, "ERR_TARGET_NOT_FOUND", "closeSurface", targetAddress, p);
        }

        let executed = false;
        // Primary call: native Wayland toplevel close
        if (tl.wayland && typeof tl.wayland.close === "function") {
            try {
                tl.wayland.close();
                executed = true;
            } catch (e) {
                console.warn("[pranc-shell:action] tl.wayland.close() threw: " + e);
            }
        }

        if (!executed) {
            return _result(false, "ERR_NATIVE_API_UNAVAILABLE", "closeSurface", targetAddress, p);
        }

        return _result(true, "OK", "closeSurface", targetAddress, p);
    }

    // =========================================================================
    // Approved Action 4: Move Surface to Workspace
    // =========================================================================
    function moveSurfaceToWorkspace(targetAddress: string, targetWorkspaceId, payload) {
        const p = payload ?? {};
        const clean = _cleanAddress(targetAddress);

        if (!clean) {
            return _result(false, "ERR_TARGET_NOT_FOUND", "moveSurfaceToWorkspace", targetAddress, p);
        }

        if (targetWorkspaceId === undefined || targetWorkspaceId === null) {
            return _result(false, "ERR_TARGET_NOT_FOUND", "moveSurfaceToWorkspace", targetAddress, p);
        }

        const tl = _findToplevel(clean);
        const selector = _formatWindowSelector(clean);
        const isSpecial = typeof targetWorkspaceId === "string" && targetWorkspaceId.startsWith("special:");
        const numWsId = (!isSpecial && !isNaN(parseInt(targetWorkspaceId, 10))) ? parseInt(targetWorkspaceId, 10) : targetWorkspaceId;

        // Same-workspace guard
        if (tl && tl.workspace && tl.workspace.id === numWsId) {
            return _result(false, "ERR_ALREADY_ACTIVE", "moveSurfaceToWorkspace", targetAddress, p);
        }

        let executed = false;
        if (typeof Hyprland !== "undefined" && typeof Hyprland.dispatch === "function") {
            try {
                const wsArg = isSpecial ? ('"' + targetWorkspaceId + '"') : String(numWsId);
                const luaCmd = 'hl.dsp.window.move({ workspace = ' + wsArg + ', window = "' + selector + '" })';
                Hyprland.dispatch(luaCmd);
                executed = true;
            } catch (e) {
                console.warn("[pranc-shell:action] Hyprland.dispatch move threw: " + e);
            }
        }

        if (!executed) {
            return _result(false, "ERR_NATIVE_API_UNAVAILABLE", "moveSurfaceToWorkspace", targetAddress, p);
        }

        const resPayload = Object.assign({}, p, { workspaceId: targetWorkspaceId });
        return _result(true, "OK", "moveSurfaceToWorkspace", targetAddress, resPayload);
    }

    // =========================================================================
    // Approved Action 5: Toggle Fullscreen
    // =========================================================================
    function toggleFullscreen(targetAddress: string, payload) {
        const p = payload ?? {};
        const clean = _cleanAddress(targetAddress);

        if (!clean) {
            return _result(false, "ERR_TARGET_NOT_FOUND", "toggleFullscreen", targetAddress, p);
        }

        const tl = _findToplevel(clean);
        if (!tl) {
            return _result(false, "ERR_TARGET_NOT_FOUND", "toggleFullscreen", targetAddress, p);
        }

        let executed = false;
        const selector = _formatWindowSelector(clean);

        // Primary: native Hyprland Lua dispatch (universal across Wayland and XWayland)
        if (typeof Hyprland !== "undefined" && typeof Hyprland.dispatch === "function") {
            try {
                const luaCmd = 'hl.dsp.window.fullscreen({ window = "' + selector + '" })';
                Hyprland.dispatch(luaCmd);
                executed = true;
            } catch (e) {
                console.warn("[pranc-shell:action] Hyprland.dispatch fullscreen threw: " + e);
            }
        }

        // Secondary fallback: native Wayland toplevel fullscreen property
        if (!executed && tl.wayland && typeof tl.wayland.fullscreen === "boolean") {
            try {
                tl.wayland.fullscreen = !tl.wayland.fullscreen;
                executed = true;
            } catch (e) {
                console.warn("[pranc-shell:action] tl.wayland.fullscreen threw: " + e);
            }
        }

        if (!executed) {
            return _result(false, "ERR_NATIVE_API_UNAVAILABLE", "toggleFullscreen", targetAddress, p);
        }

        return _result(true, "OK", "toggleFullscreen", targetAddress, p);
    }

    // =========================================================================
    // Unsupported Action: Toggle Floating (Quickshell 0.3.1 has no reactive floating property)
    // =========================================================================
    function toggleFloating(targetAddress: string, payload) {
        const p = payload ?? {};
        return _result(false, "ERR_UNSUPPORTED_ACTION", "toggleFloating", targetAddress, p);
    }

    // =========================================================================
    // Approved Action 6: Move To Special Workspace (Stash)
    // =========================================================================
    function moveToSpecialWorkspace(targetAddress, payload) {
        const p = payload ?? {};
        const specialName = p.specialWorkspace ? String(p.specialWorkspace) : "stash";
        const silent = p.silent !== false;
        const clean = targetAddress ? _cleanAddress(targetAddress) : "";

        let executed = false;
        if (typeof Hyprland !== "undefined" && typeof Hyprland.dispatch === "function") {
            try {
                let luaCmd = "";
                if (clean) {
                    const selector = _formatWindowSelector(clean);
                    luaCmd = 'hl.dsp.window.move({ workspace = "special:' + specialName + '", window = "' + selector + '", silent = ' + silent + ' })';
                } else {
                    luaCmd = 'hl.dsp.window.move({ workspace = "special:' + specialName + '", silent = ' + silent + ' })';
                }
                Hyprland.dispatch(luaCmd);
                executed = true;
            } catch (e) {
                console.warn("[pranc-shell:action] Hyprland.dispatch moveToSpecialWorkspace threw: " + e);
            }
        }

        if (!executed) {
            return _result(false, "ERR_NATIVE_API_UNAVAILABLE", "moveToSpecialWorkspace", targetAddress, p);
        }

        return _result(true, "OK", "moveToSpecialWorkspace", targetAddress, p);
    }

    // =========================================================================
    // Approved Action 7: Toggle Special Workspace
    // =========================================================================
    function toggleSpecialWorkspace(specialName: string, payload) {
        const p = payload ?? {};
        const name = specialName ? String(specialName).replace(/^special:/i, "") : "stash";

        let executed = false;
        if (typeof Hyprland !== "undefined" && typeof Hyprland.dispatch === "function") {
            try {
                const luaCmd = 'hl.dsp.workspace.toggle_special("' + name + '")';
                Hyprland.dispatch(luaCmd);
                executed = true;
            } catch (e) {
                console.warn("[pranc-shell:action] Hyprland.dispatch toggleSpecialWorkspace threw: " + e);
            }
        }

        if (!executed) {
            return _result(false, "ERR_NATIVE_API_UNAVAILABLE", "toggleSpecialWorkspace", specialName, p);
        }

        return _result(true, "OK", "toggleSpecialWorkspace", specialName, p);
    }
}
