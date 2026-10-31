import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: spacer

    // Notch collapsed pill height is 36px (or 38px with live lyrics).
    // An exclusive reserve of 42px provides a clean 6px clearance beneath the pill
    // so no window borders, tab bars, or headers are obscured.
    readonly property int reservedHeight: 42

    readonly property HyprlandMonitor activeMonitor: {
        if (typeof Hyprland !== "undefined") {
            if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor)
                return Hyprland.focusedWorkspace.monitor;
            if (Hyprland.focusedMonitor)
                return Hyprland.focusedMonitor;
        }
        return null;
    }

    readonly property bool screenHasFullscreen: {
        if (typeof Hyprland === "undefined") return false;
        if (activeMonitor && spacer.screen && spacer.screen.name === activeMonitor.name) {
            return Hyprland.focusedWorkspace ? Boolean(Hyprland.focusedWorkspace.hasFullscreen) : false;
        }
        if (Hyprland.workspaces) {
            const list = Hyprland.workspaces.values;
            for (let i = 0; i < list.length; ++i) {
                const ws = list[i];
                if (ws && ws.active && ws.monitor && spacer.screen && ws.monitor.name === spacer.screen.name) {
                    return Boolean(ws.hasFullscreen);
                }
            }
        }
        return Hyprland.focusedWorkspace ? Boolean(Hyprland.focusedWorkspace.hasFullscreen) : false;
    }

    // Do not carve out space in Game Mode or when an application is in true fullscreen
    readonly property bool shouldReserve: !ShellState.gameMode && !screenHasFullscreen

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: reservedHeight
    color: "transparent"
    aboveWindows: false
    focusable: false
    visible: shouldReserve
    exclusionMode: shouldReserve ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: shouldReserve ? reservedHeight : 0
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "island-workarea-spacer"
}
