# Interactive Spatial Workspace Map (Mission Control) Implementation Plan

**Date**: 2026-10-04  
**Feature**: Interactive Spatial Workspace Map / Mission Control Overview  
**Target Path**: `components/SpatialWorkspaceMap.qml` (integrated into `shell.qml` & `hyprland.lua`)  

---

## 1. Executive Summary & Objective

Provide a macOS Mission Control / GNOME Overview style fullscreen spatial workspace map for `cool-shell`:
- Triggered by `Super + Tab` (or IPC `qs -c cool-shell ipc call overview toggle`).
- Displays an interactive grid of all active workspaces.
- Each workspace card is a 16:9 proportioned miniature preview containing real-ratio window tiles placed at their exact on-screen geometry (`at` and `size`).
- Window tiles display application icons, titles, and live hover states.
- Click any workspace card to warp to that workspace; click any window miniature to warp to that workspace and focus that window.
- Click the `×` button on a window hover to close that window (`compositorActionLayer.closeSurface`).
- "+ New Workspace" card at the end to jump to the next empty workspace.
- Full keyboard navigation: `Esc` to close, `1`-`9` for instant workspace warp, `Arrow` keys / `Tab` to navigate, `Enter` to confirm.
- Frosted glass backdrop with smooth spring scale and fade animations.

---

## 2. Architectural Blueprint

```
[ Super + Tab ]  OR  [ IPC: overview toggle ]
                      ↓
               shell.qml (overviewOpen: true)
                      ↓
     components/SpatialWorkspaceMap.qml (WlrLayer.Overlay)
    ┌──────────────────────────────────────────────────────────┐
    │  Header: "Workspaces" • [Esc] Close • [1-9] Quick Jump  │
    │  Search Filter Bar: type to highlight matching windows  │
    ├──────────────────────────────────────────────────────────┤
    │  Grid of Workspace Miniatures (16:9 Aspect Ratio)        │
    │                                                          │
    │  ┌ Workspace 1 ──────────┐  ┌ Workspace 2 ──────────┐   │
    │  │ [ 1 ]  Brave          │  │ [ 2 ]  Kitty          │   │
    │  │ ┌───────────────────┐ │  │ ┌─────────┐ ┌─────────┐│   │
    │  │ │ 🌐 Brave Browser  │ │  │ │  Kitty │ │  Kitty ││   │
    │  │ └───────────────────┘ │  │ └─────────┘ └─────────┘│   │
    │  └───────────────────────┘  └───────────────────────┘   │
    │                                                          │
    │  ┌ Workspace 3 ──────────┐  ┌ + New Workspace ──────┐   │
    │  │ [ 3 ]  Code           │  │                       │   │
    │  │ ┌───────────────────┐ │  │        󰐕 Create       │   │
    │  │ │  VS Code         │ │  │       Workspace 4     │   │
    │  │ └───────────────────┘ │  │                       │   │
    │  └───────────────────────┘  └───────────────────────┘   │
    └──────────────────────────────────────────────────────────┘
```

---

## 3. Implementation Tasks

### Task 1: Expose Spatial Geometry in `core/SurfaceModel.qml`
- Add `geomX`, `geomY`, `geomWidth`, `geomHeight` to each projected surface item extracted from `tl.lastIpcObject.at` and `tl.lastIpcObject.size`.
- Provide fallback values (0, 0, 1920, 1080) if window IPC object is initializing.

### Task 2: Build `components/SpatialWorkspaceMap.qml`
- Create `PanelWindow` on `WlrLayer.Overlay`:
  - Fullscreen coverage (`anchors.fill: parent`).
  - `focusable: true`, `WlrKeyboardFocus.Exclusive` when open.
  - Escape key handling to close.
  - Backdrop: `Theme.glassBackground` with 85% opacity and smooth fade.
  - Header: Title, search input, shortcuts legend.
  - Workspace Grid: `Flow` or `Grid` view iterating `workspaceModel.workspaces`.
  - Workspace Card:
    - 16:9 aspect ratio (`width: 320`, `height: 180` or responsive based on screen).
    - Glowing border for focused workspace (`Theme.primary`).
    - Mini window tiles positioned via `(geomX / 1920) * cardWidth`, `(geomY / 1080) * cardHeight`.
    - Window tile hover: tooltips, glow, and close button.
  - Plus "+ New Workspace" card for empty workspace navigation.

### Task 3: Shell Integration in `shell.qml`
- Add `property bool overviewOpen: false` on `shellRoot`.
- Instantiate `SpatialWorkspaceMap` in `shell.qml`.
- Add `IpcHandler { target: "overview" }` with `toggle()`, `open()`, `close()`, `isOpen()`.

### Task 4: Compositor Keybinding in `~/.config/hypr/hyprland.lua`
- Bind `SUPER + Tab` to `qs -c cool-shell ipc call overview toggle`.

### Task 5: End-to-End Verification
- Test `overview toggle` via IPC.
- Verify workspace cards layout.
- Verify window clicking, workspace switching, close buttons, and keyboard shortcuts.
- Check resource usage and ensure Game Mode is untouched.
