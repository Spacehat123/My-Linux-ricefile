import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    // =========================================================================
    // Raw Models & Collections
    // =========================================================================

    // UntypedObjectModel for direct QML delegate/view consumption (Repeater, ListView)
    readonly property var toplevels: Hyprland.toplevels

    // Direct JS Array of HyprlandToplevel instances (auto-reactive via valuesChanged)
    readonly property var toplevelList: Hyprland.toplevels ? Hyprland.toplevels.values : []

    // Total number of open toplevel surfaces
    readonly property int count: toplevelList ? toplevelList.length : 0

    // =========================================================================
    // Active Surface State (Null-Safe)
    // =========================================================================

    // Bindable reference to active toplevel (null if desktop/unmanaged surface has focus)
    readonly property HyprlandToplevel activeToplevel: Hyprland.activeToplevel

    // Boolean flag indicating presence of an active surface
    readonly property bool hasActiveToplevel: activeToplevel !== null

    // Scalar primitives with strictly null-safe fallback values
    readonly property string activeAddress: activeToplevel ? (activeToplevel.address ?? "") : ""
    readonly property string activeTitle: activeToplevel ? (activeToplevel.title ?? "") : ""
    readonly property bool isUrgent: activeToplevel ? activeToplevel.urgent : false

    // Workspace association of the active toplevel
    readonly property HyprlandWorkspace activeWorkspace: activeToplevel ? activeToplevel.workspace : null
    readonly property int activeWorkspaceId: activeWorkspace ? activeWorkspace.id : -1
    readonly property string activeWorkspaceName: activeWorkspace ? (activeWorkspace.name ?? "") : ""

    // Monitor association of the active toplevel
    readonly property HyprlandMonitor activeMonitor: activeToplevel ? activeToplevel.monitor : null
    readonly property int activeMonitorId: activeMonitor ? activeMonitor.id : -1
    readonly property string activeMonitorName: activeMonitor ? (activeMonitor.name ?? "") : ""

    // =========================================================================
    // Read-Only Query Primitives
    // =========================================================================

    // Lookup surface by hex address string (e.g. "0x55d7a6b2c0")
    function getToplevelByAddress(address: string) {
        if (!toplevelList) return null;
        for (let i = 0; i < toplevelList.length; ++i) {
            const tl = toplevelList[i];
            if (tl && tl.address === address) return tl;
        }
        return null;
    }

    // Retrieve all toplevels belonging to a specific workspace ID
    function getToplevelsForWorkspace(workspaceId: int) {
        if (!toplevelList) return [];
        const result = [];
        for (let i = 0; i < toplevelList.length; ++i) {
            const tl = toplevelList[i];
            if (tl && tl.workspace && tl.workspace.id === workspaceId) {
                result.push(tl);
            }
        }
        return result;
    }

    // Retrieve all toplevels displayed on a monitor (by ID, name, or HyprlandMonitor reference)
    function getToplevelsForMonitor(monitor) {
        if (!toplevelList) return [];
        const result = [];
        for (let i = 0; i < toplevelList.length; ++i) {
            const tl = toplevelList[i];
            if (!tl || !tl.monitor) continue;

            if (typeof monitor === "number") {
                if (tl.monitor.id === monitor) result.push(tl);
            } else if (typeof monitor === "string") {
                if (tl.monitor.name === monitor) result.push(tl);
            } else if (tl.monitor === monitor) {
                result.push(tl);
            }
        }
        return result;
    }

    // Retrieve all surfaces that currently hold the urgent flag
    function getUrgentToplevels() {
        if (!toplevelList) return [];
        return toplevelList.filter(tl => tl && tl.urgent);
    }
}