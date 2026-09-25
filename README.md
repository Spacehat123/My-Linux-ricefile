# pranc-shell

A high-performance, cyber-tactical desktop shell built natively for **Hyprland** on **Wayland** using **Quickshell 0.3.1** and **Qt 6**.

`pranc-shell` provides a unified instrument surface featuring live procedural shader wallpaper, native idle-triggered ambient telemetry, spatial workspace navigation, and an application surface overview with strictly validated compositor mutations.

---

## Architecture Overview

`pranc-shell` enforces a strict unidirectional reactive architecture that separates compositor observation from compositor mutation:

### Observation Pipeline (Read-Only)
```text
Hyprland / Wayland (C++ singletons)
       ↓
WorkspaceManager / SurfaceManager (core/ authoritative wrappers)
       ↓
WorkspaceModel / SurfaceModel (normalized projections & groupings)
       ↓
DesktopModel (multi-level composition graph)
       ↓
DesktopState (presentation state & spatial transition driver)
       ↓
Shell UI Surfaces (LeftSidebar, RightSidebar, BottomBar, Ambient, Transitions)
```

### Mutation Pipeline (Actuation & Security Barrier)
```text
User Interaction (UI HUD Elements / TapHandler)
       ↓
InteractionModel (pre-flight validation & stale-target protection)
       ↓
CompositorActionLayer (allowlist barrier & native execution)
       ↓
Native Quickshell C++ APIs (HyprlandWorkspace.activate, Toplevel.activate/close, Hyprland.dispatch)
       ↓
Hyprland Compositor
       ↓
Reactive C++ Event Stream (triggers automatic observation update)
```

---

## Directory Structure

```text
~/.config/quickshell/pranc-shell/
├── shell.qml                     # Root entry point, singletons, and IPC registration
├── theme/
│   └── Theme.qml                 # Single semantic token authority (metrics, colors, durations)
├── core/
│   ├── WorkspaceManager.qml      # Authoritative raw Hyprland workspace tracker
│   ├── SurfaceManager.qml        # Authoritative raw Hyprland toplevel surface tracker
│   ├── WorkspaceModel.qml        # Deterministic ordering, occupancy, and spatial adjacency
│   ├── SurfaceModel.qml          # Application identity, multi-window grouping, normalized records
│   ├── DesktopModel.qml          # Unified desktop composition graph and monitor topology
│   ├── DesktopState.qml          # Presentation state, panel flags, and spatial transition progress
│   ├── InteractionModel.qml      # Intent mediation, target validation, availability checks
│   ├── CompositorActionLayer.qml # Mutation authority executing approved native Wayland/Hyprland actions
│   └── IdleManager.qml           # Native ext_idle_notification_v1 idle monitor wrapper
├── components/
│   ├── ControlCenter.qml         # Left sidebar HUD: system modes, toggles, workspace & topology telemetry
│   ├── ApplicationOverview.qml   # Right sidebar HUD: application cards, window lists, and action controls
│   ├── WorkspaceNavigator.qml    # Bottom bar HUD: workspace pills, activity pips, and contextual summary
│   ├── EdgeTrigger.qml           # Screen-edge hover sensor with automatic geometry calculation
│   ├── PanelSurface.qml          # Reusable translucent panel backdrop rectangle bound to Theme
│   └── PanelContent.qml          # Standardized padding and layout insets
├── panels/
│   ├── LeftSidebar.qml           # Slide-out container hosting ControlCenter
│   ├── RightSidebar.qml          # Slide-out container hosting ApplicationOverview
│   └── BottomBar.qml             # Bottom floating container hosting WorkspaceNavigator
├── desktop/
│   ├── AmbientLayer.qml          # Idle-triggered layer surface on WlrLayer.Bottom
│   ├── AmbientCornerBrackets.qml # Screen-corner tactical alignment brackets
│   ├── AmbientReticle.qml        # Central orbital telemetry rings with linear drift
│   ├── AmbientTelemetry.qml      # Floating monitor, workspace, and power status node
│   └── DesktopTransition.qml     # Ephemeral spatial HUD indicating workspace switch direction
└── wallpaper/
    ├── Wallpaper.qml             # GPU shader surface on WlrLayer.Background
    ├── README.md                 # Wallpaper pipeline and shader compilation instructions
    └── shaders/
        ├── wallpaper.frag        # GLSL fragment shader source (harmonic interference)
        └── wallpaper.frag.qsb    # Qt 6 Shader Baker compiled binary
```

---

## Launching & Running

Launch `pranc-shell` directly using the Quickshell CLI:

```bash
quickshell -c pranc-shell
```

Quickshell monitors the directory for changes and provides real-time hot reloading during QML editing.

---

## Major Shell Features

### 1. Edge-Triggered Sliding Panels & Hover Continuity
- **Bottom-Left Edge**: Activates `LeftSidebar` (Control Center).
- **Bottom-Center Edge**: Activates `BottomBar` (Workspace Navigator).
- **Bottom-Right Edge**: Activates `RightSidebar` (Application Overview).
- **Dual-Layer Hover Continuity**: Moving the cursor across the edge trigger into the panel maintains continuous hover. The panel remains open until the pointer moves completely outside both the panel and trigger.
- **Resource Discipline**: Panels use `visible: open || closeAnim.running` to completely unmap from the Wayland compositor when closed, reducing CPU/GPU overhead to zero.

### 2. Control Center (`LeftSidebar`)
- **System Modes**: Instant toggle switches for Wallpaper Engine and Ambient Overlay with tactile capsule switches.
- **Focused Workspace Telemetry**: Real-time identifier, surface count, fullscreen status, and urgency alerts.
- **Desktop Topology**: Aggregate totals for workspaces, occupied workspaces, active surfaces, applications, and screen resolution.

### 3. Application Surface Overview (`RightSidebar`)
- **Application Grouping**: Collates multiple windows from the same application into unified cards with status pips (cyan for focus, crimson for urgent).
- **Window Actions**:
  - `→` Focus surface (cross-workspace focus handoff).
  - `⛶` Toggle fullscreen.
  - `⇄` Move surface to another workspace (inline relocation drawer).
  - `✕` Close surface.
- **Floating Guard**: Floating mode is explicitly unsupported to prevent compositor instability (`ERR_UNSUPPORTED_ACTION`).

### 4. Spatial Workspace Navigator (`BottomBar`)
- **Compact HUD**: Contextual telemetry box displaying active workspace ID, window count, fullscreen tag, and monitor identifier.
- **Pill Strip**: Deterministically sorted workspace pills with activity slivers (pips) representing window occupancy and overflow.
- **Focal Cursor**: High-contrast neon cyan cursor indicating the active workspace.
- **Spatial Transitions**: When switching workspaces, `DesktopTransition` displays an ephemeral 280ms directional indicator showing the exit of the previous workspace and entry of the new workspace.

### 5. Ambient Idle System (`desktop/`)
- Powered by the native Wayland `ext_idle_notification_v1` protocol via `Quickshell.Wayland.IdleMonitor`.
- Zero polling and zero timers.
- Emerges after inactivity with a smooth 1000ms cubic fade-in.
- Dismisses instantly (180ms) upon any mouse movement or keyboard event anywhere in Hyprland.
- Completely unmaps from the layer graph when dismissed (`visible: opacity > 0.0`).

### 6. Procedural Live Wallpaper (`wallpaper/`)
- GPU-accelerated harmonic procedural shader running on `WlrLayer.Background` at 60 FPS VSync.
- Driven by a pure C++ `NumberAnimation` cycling over $[0, 2\pi]$. Zero per-frame JavaScript overhead.
- Independently toggled on or off via Control Center or IPC.

---

## Headless IPC API Reference

`pranc-shell` exposes 13 comprehensive IPC targets for headless automation, testing, and scriptable control:

```bash
# General Shell Status & Query
quickshell ipc -c pranc-shell prop get shell currentWorkspaceId
quickshell ipc -c pranc-shell prop get shell surfaceCount

# Control Center Summary & Toggles
quickshell ipc -c pranc-shell call control getSummary
quickshell ipc -c pranc-shell call control toggleWallpaper
quickshell ipc -c pranc-shell call control toggleAmbient

# Presentation State & Spatial Transitions
quickshell ipc -c pranc-shell call state getSummary
quickshell ipc -c pranc-shell call state getTransition

# Compositor Action Execution (Allowlist Barrier)
quickshell ipc -c pranc-shell call action switchWorkspace <workspaceId>
quickshell ipc -c pranc-shell call action focusSurface <surfaceAddress>
quickshell ipc -c pranc-shell call action toggleFullscreen <surfaceAddress>
quickshell ipc -c pranc-shell call action moveSurfaceToWorkspace <surfaceAddress> <targetWorkspaceId>
quickshell ipc -c pranc-shell call action closeSurface <surfaceAddress>

# Interaction Pre-Flight Validation
quickshell ipc -c pranc-shell call interaction canFocusSurface <surfaceAddress>
quickshell ipc -c pranc-shell call interaction canToggleFloating <surfaceAddress>
quickshell ipc -c pranc-shell call interaction validateTarget <intent> <target> <payloadJson>

# Desktop & Application Composition Queries
quickshell ipc -c pranc-shell call desktop getSummary
quickshell ipc -c pranc-shell call desktop getMonitors
quickshell ipc -c pranc-shell call desktop getWorkspaceComposition <workspaceId>
quickshell ipc -c pranc-shell call model-surface getSurfacesForApplication <appNameOrClass>

# Idle Monitor & Power Management
quickshell ipc -c pranc-shell prop get idle idle
quickshell ipc -c pranc-shell call idle setIdleSeconds <seconds>
```

---

## Safety & Layer Boundaries

- **Zero Forbidden Constructs**: Strictly 0 instances of `Timer`, `setInterval`, `setTimeout`, `hyprctl` execution, or `Quickshell.Io.Process` in production code.
- **Layer Arrangement**:
  - `Wallpaper`: `WlrLayer.Background` (layer 0)
  - `AmbientLayer`: `WlrLayer.Bottom` (layer 1)
  - Applications: Normal Hyprland client windows
  - `DesktopTransition`: `WlrLayer.Top` (ephemeral)
  - `Sidebars & BottomBar`: `WlrLayer.Top` (overlay mode with `ExclusionMode.Ignore`)
  - `EdgeTriggers`: `WlrLayer.Overlay` with scoped subregion mask
- **Pointer Transparency**: Background, ambient, and transition layers use `mask: Region {}` to guarantee 100% click-through to underlying application windows.
- **Keyboard Focus Immunity**: All panels specify `WlrKeyboardFocus.None` and `focusable: false`. The shell will never steal keyboard focus from active terminals or editors.

---

## Independence & Relationship to `ii/`

`pranc-shell` is an entirely independent, standalone desktop environment. It resides strictly within `~/.config/quickshell/pranc-shell/` and maintains zero dependencies, shared files, or coupling with `~/.config/quickshell/ii/`.
