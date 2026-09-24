import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    // =========================================================================
    // Raw Models & Collections
    // =========================================================================

    // UntypedObjectModel for direct QML delegate/view consumption (Repeater, ListView)
    readonly property var workspaces: Hyprland.workspaces

    // Direct JS Array of HyprlandWorkspace instances (auto-reactive via valuesChanged)
    readonly property var workspaceList: Hyprland.workspaces ? Hyprland.workspaces.values : []

    // Total number of open workspaces
    readonly property int count: workspaceList ? workspaceList.length : 0

    // =========================================================================
    // Focused / Active Workspace State (Null-Safe)
    // =========================================================================

    // Direct bindable reference to the currently focused HyprlandWorkspace
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace

    // Scalar primitives with strictly null-safe fallback values
    readonly property int focusedWorkspaceId: focusedWorkspace ? focusedWorkspace.id : -1
    readonly property string focusedWorkspaceName: focusedWorkspace ? (focusedWorkspace.name ?? "") : ""
    readonly property bool hasFullscreen: focusedWorkspace ? focusedWorkspace.hasFullscreen : false
    readonly property bool isUrgent: focusedWorkspace ? focusedWorkspace.urgent : false

    // Monitor association for the focused workspace
    readonly property HyprlandMonitor focusedMonitor: focusedWorkspace ? focusedWorkspace.monitor : Hyprland.focusedMonitor
    readonly property int focusedMonitorId: focusedMonitor ? focusedMonitor.id : -1
    readonly property string focusedMonitorName: focusedMonitor ? (focusedMonitor.name ?? "") : ""

    // Toplevel model of the currently focused workspace (UntypedObjectModel or null)
    readonly property var focusedToplevels: focusedWorkspace ? focusedWorkspace.toplevels : null

    // =========================================================================
    // Read-Only Query Primitives
    // =========================================================================

    // Lookup workspace by integer ID
    function getWorkspaceById(id: int) {
        if (!workspaceList) return null;
        for (let i = 0; i < workspaceList.length; ++i) {
            const ws = workspaceList[i];
            if (ws && ws.id === id) return ws;
        }
        return null;
    }

    // Lookup workspace by string name
    function getWorkspaceByName(name: string) {
        if (!workspaceList) return null;
        for (let i = 0; i < workspaceList.length; ++i) {
            const ws = workspaceList[i];
            if (ws && ws.name === name) return ws;
        }
        return null;
    }

    // Retrieve all toplevels residing on a specific workspace ID
    function getToplevelsForWorkspace(workspaceId: int) {
        const ws = getWorkspaceById(workspaceId);
        if (!ws || !ws.toplevels || !ws.toplevels.values) return [];
        return ws.toplevels.values;
    }

    // Retrieve all workspaces bound to a monitor (by ID, name, or HyprlandMonitor reference)
    function getWorkspacesForMonitor(monitor) {
        if (!workspaceList) return [];
        const result = [];
        for (let i = 0; i < workspaceList.length; ++i) {
            const ws = workspaceList[i];
            if (!ws || !ws.monitor) continue;

            if (typeof monitor === "number") {
                if (ws.monitor.id === monitor) result.push(ws);
            } else if (typeof monitor === "string") {
                if (ws.monitor.name === monitor) result.push(ws);
            } else if (ws.monitor === monitor) {
                result.push(ws);
            }
        }
        return result;
    }
}