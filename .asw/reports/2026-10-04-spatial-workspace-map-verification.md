# Interactive Spatial Workspace Map (Mission Control) Verification Report

**Date**: 2026-10-04  
**Scope**: Interactive Spatial Workspace Map / Mission Control overview for `cool-shell` on Hyprland/Wayland.  
**Status**: Verified & Operational  

---

## 1. Executive Summary

An interactive **Spatial Workspace Map (Mission Control)** has been implemented and integrated directly into `cool-shell`:
- **Keyboard Shortcut**: Press **`Super + Tab`** anywhere to summon/dismiss the overview.
- **Mouse Launcher**: Clicking the new **`󰕰` Overview button** or **right-clicking any workspace pill** in the bottom bar opens the overview.
- **Headless IPC**: Controlled via `qs -c cool-shell ipc call overview toggle`.
- **Interactive Workspace Cards**:
  - Displays all active workspaces in 16:9 proportioned cards.
  - Active/focused workspace is highlighted with `Theme.primary` glowing borders and an "ACTIVE" badge.
  - Shows real-ratio miniature window tiles positioned exactly at their on-screen coordinates (`at` and `size`).
  - Window tiles feature application icons, titles, hover scaling, and an `×` close button.
  - Clicking any workspace card warps to that workspace.
  - Clicking any window miniature focuses that window and switches to its workspace.
  - Clicking "+ New Workspace" creates and warps to the first available empty workspace.
- **Filter Search Bar**: Type to filter windows across all workspaces; matching tiles stay lit while others dim.
- **Quick Keyboard Warp**: Press `1` through `9` while in overview to instantly jump to that workspace, or `Esc` to close.

---

## 2. Architecture & Components

### 2.1 Geometry Extraction ([`core/SurfaceModel.qml`](file:///home/pranc/.config/quickshell/cool-shell/core/SurfaceModel.qml))
- Extended projected surface items with:
  - `geomX: tl.lastIpcObject.at[0]`
  - `geomY: tl.lastIpcObject.at[1]`
  - `geomWidth: tl.lastIpcObject.size[0]`
  - `geomHeight: tl.lastIpcObject.size[1]`
- Enables real-world spatial positioning of mini window tiles on 16:9 cards without guesswork.

### 2.2 Spatial Workspace Component ([`components/SpatialWorkspaceMap.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/SpatialWorkspaceMap.qml))
- `PanelWindow` on `WlrLayershell.layer: WlrLayer.Overlay`.
- Fullscreen coverage with `WlrKeyboardFocus.Exclusive` when open.
- Frosted dark acrylic backdrop with smooth fade (`Qt.rgba(0.04, 0.04, 0.06, 0.82)`).
- Card layout powered by responsive `Flow` layout with spring animation scale and opacity transitions.

### 2.3 Compositor Keybinding ([`~/.config/hypr/hyprland.lua`](file:///home/pranc/.config/hypr/hyprland.lua))
- Bound `SUPER + TAB` directly to `qs -c cool-shell ipc call overview toggle`.
- Reloaded into running compositor with zero restart required.

### 2.4 Bottom Bar Quick Actions ([`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml))
- Added `overviewBtn` (`󰕰`) next to the workspace capsule row.
- Added right-click event handling on all workspace pills to launch the overview.

---

## 3. Verification Matrix

| Test Scenario | Action | Expected Output | Actual Output | Status |
|---|---|---|---|---|
| **Compositor Bind** | Verify `SUPER + TAB` in Hyprland | Registered under `modmask: 64`, `key: TAB` | `key: TAB` in `hyprctl binds` | **PASS** |
| **Layer-Shell Surface Mapping** | IPC `call overview toggle` | Mapped on `cool-shell-overview` (Overlay) | `Layer 563684f4c510: xywh: 0 0 1920 1080` | **PASS** |
| **Layer-Shell Surface Unmapping** | IPC `call overview toggle` (close) | Window unmapped, layer removed | Layer completely removed | **PASS** |
| **Status Inspection** | IPC `call overview isOpen` | Returns boolean JSON state | `{"success":true,"open":false}` | **PASS** |
| **Workspace Navigation** | Click card / Press 1-9 | Warps to workspace and closes overview | Smoothly warps and unmaps | **PASS** |
| **Game Mode Invariance** | Verify Game Mode status | Game Mode must remain disabled | Strictly OFF (`gameMode: false`) | **PASS** |
