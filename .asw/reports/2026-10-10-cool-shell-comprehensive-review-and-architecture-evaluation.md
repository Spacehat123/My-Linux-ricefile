# Cool-Shell Comprehensive System Review & Architectural Evaluation

- **Date**: 2026-10-10
- **Workspace**: `/home/pranc/.config/quickshell/cool-shell`
- **Target Platform**: Hyprland / Wayland / Linux
- **Framework**: Quickshell 0.3.1 / Qt 6
- **Review Scope**: Custom Shell Architecture, Dynamic Island, Sidebars, Bottom Bar, Video Wallpaper, Telemetry, Resource Footprint, UX & Ergonomics
- **Classification**: Deep Technical Exploration, Good / Bad / Better Analysis

---

## 1. Executive Summary & Shell Heritage

`cool-shell` represents an extraordinary, highly ambitious synthesis of two distinct desktop shell paradigms running natively on Linux Wayland:
1. **The Cyber-Tactical Instrument HUD** (originated from `pranc-shell`): A mission-control surface featuring edge-triggered slide-out drawers, Wayland idle-triggered ambient orbital reticles, ephemeral spatial workspace transition HUDs, and a strict unidirectional reactive pipeline separating compositor observation from allowlist mutation.
2. **The Morphing Dynamic Island / Notch** (integrated from `vyeos`): A top-anchored overlay capsule driven by second-order spring physics that morphs fluidly between a collapsed status pill ($145 \times 24\text{ px}$) and 15 distinct modal panels, complete with PipeWire audio level visualizers, download tickers, and drop-target file shelving.
3. **Recent Avant-Garde Additions**: The Ukishima floating bottom dock with expandable popovers, the VALENCE cybernetic right sidebar with 16-segment LED VU meters, the Stash Pocket window drawer (`special:stash`), and the BirdsEye horizontal scrolling layout viewer.

The result is one of the most visually stunning, technologically advanced, and feature-dense custom Wayland shells developed to date. However, this aggressive feature velocity has introduced architectural drift, file monoliths, and significant resource overhead (idling at ~20% CPU and ~670 MB RSS).

Below is the definitive review categorized by **The Good**, **The Bad**, and **The Better**.

---

## 2. System Architecture & Topology

```text
/home/pranc/.config/quickshell/cool-shell/
├── shell.qml                     # Central shell root (2,134 lines), 23 IPC targets, variant scopes
├── theme/
│   └── Theme.qml                 # Desktop tactical theme adapter (delegates to island/Theme.qml)
├── core/                         # Authoritative models & action barrier
│   ├── WorkspaceManager.qml      # C++ Hyprland.workspaces wrapper
│   ├── SurfaceManager.qml        # C++ Hyprland.toplevels wrapper
│   ├── WorkspaceModel.qml        # Deterministic sorting & adjacency
│   ├── SurfaceModel.qml          # Application grouping & normalization
│   ├── DesktopModel.qml          # Multi-head monitor composition graph
│   ├── DesktopState.qml          # Presentation state & kinetic drivers
│   ├── CompositorActionLayer.qml # Allowlist execution barrier (5 approved intents)
│   ├── InteractionModel.qml      # Target validation & stale target gate
│   ├── IdleManager.qml           # Wayland ext_idle_notification_v1 listener
│   └── WindowRecovery.qml        # Atomic debounced window snapshotting
├── components/                   # Composite HUD elements
│   ├── BirdsEyeOverview.qml      # Horizontal scroller layout ribbon
│   ├── ControlCenter.qml         # Left sidebar HUD telemetry & toggles
│   ├── EdgeTrigger.qml           # Low-cost edge sensor with hover continuity
│   ├── SpatialWorkspaceMap.qml   # Fullscreen 3D cover-flow workspace overview
│   ├── SpotifyWidget.qml         # Standalone desktop music widget
│   ├── StashPocket.qml           # Sliding drawer for special:stash
│   └── TodayCenter.qml           # Calendar, todo list, scratchpad, alerts
├── panels/                       # Wayland layer surfaces
│   ├── BottomBar.qml             # Ukishima expandable floating dock (1,609 lines)
│   ├── LeftSidebar.qml           # Control center container (360px drawer)
│   ├── MediaWidget.qml           # Middle-right 40-col bottom-up audio visualizer
│   ├── RightSidebar.qml          # VALENCE command surface (1,900 lines)
│   └── SettingsWindow.qml        # 12-category settings modal (2,488 lines)
├── island/                       # Morphing Dynamic Island ecosystem
│   ├── Notch.qml                 # Overlay window, spring physics, morphing pill (1,604 lines)
│   ├── IslandHub.qml             # State coordinator, PipeWire audio levels, priorities
│   ├── Theme.qml                 # Dynamic color palette singleton (Cherry theme)
│   ├── CollapsedStatus.qml       # Compact pill layout & real-time equalizer bars
│   └── panels/                   # 15 modal panels (Launcher, Media, Todo, Notes, etc.)
└── wallpaper/
    └── Wallpaper.qml             # QtMultimedia MP4 hardware-accelerated video layer
```

---

## 3. The Good: Architectural & Visual Triumphs

### 1. Distinctive Cyber-Tactical & Organic Aesthetic Synthesis
Unlike generic Linux desktop setups that simply wrap Waybar or Dunst with stock styling, `cool-shell` achieves an unmistakable, cohesive personality:
- **VALENCE Right Sidebar**: The switch from generic dashboard cards to 16-segment illuminated LED VU meters, studio-grade PipeWire audio faders, and tactile glass session buttons is visually breathtaking.
- **Dynamic Island Fluidity**: The second-order spring physics (`spring: 4.2`, `damping: 0.32`), corner wings, and perimeter progress border rings make the top notch feel alive and tactile.
- **Ambient Tactical HUD**: When the compositor idles, `AmbientLayer` projects cardinal tick brackets and a 120-second orbital reticle onto `WlrLayer.Bottom`, turning an idle desktop into a mission-control instrument display.

### 2. Deep Native Wayland / C++ Protocol Integration
- **Zero-Polling Compositor Observation**: Workspaces, monitors, and toplevel surfaces are tracked via direct C++ event signals from `Hyprland.workspaces` and `Hyprland.toplevels` through `WorkspaceManager.qml` and `SurfaceManager.qml`.
- **Protocol Idle Monitoring**: The shell utilizes `ext_idle_notification_v1` via `Quickshell.Wayland.IdleMonitor` in `core/IdleManager.qml`, waking instantaneously on any pointer or keyboard activity.
- **Click-Through Transparency**: Background layers (`Wallpaper.qml`, `AmbientLayer.qml`, `DesktopTransition.qml`) specify `mask: Region {}`, guaranteeing 100% pointer click-through to underlying application windows.
- **Keyboard Focus Immunity**: Panels specify `WlrKeyboardFocus.None` to prevent accidental focus stealing from active terminal sessions and IDEs.

### 3. Comprehensive Headless Automation & IPC Infrastructure
`shell.qml` registers over 20 distinct `IpcHandler` targets (`shell`, `workspace`, `surface`, `model`, `desktop`, `interaction`, `action`, `idle`, `ambient`, `wallpaper`, `bottombar`, `rightsidebar`, `notch`, `island`, `feather`, `settings`, `capture`, etc.). Every critical property and action is scriptable headlessly from the CLI via `quickshell ipc -c cool-shell call <target> <method>`, enabling automated testing and external scripting.

### 4. Extreme Power & Performance Optimization Engines
- **Feather Mode (`island/scripts/feather-mode.py`)**: An absolute battery mode that suspends compositor blur shaders, halts animations, forces Hyprland Variable Frame Rate (`misc:vfr 1`), and prunes bloat while rigorously whitelisting PAM, systemd, Hyprland, audio, and coding assistants (`antigravity`, `agy`, `python3`).
- **Game Mode (`island/scripts/game-mode.py`)**: Aggressively minimizes system RAM footprint by suspending background processes using recursive ancestor process-tree verification.

---

## 4. The Bad: Flaws, Anti-Patterns & Bottlenecks

### 1. Severe Idle CPU Overhead (~20% CPU at Rest)
During live diagnostic evaluation on the running process (`PID 24475`), `quickshell` consistently consumed **19.9% – 21.0% CPU** while completely idling:
- **Root Cause A: FFmpeg Decoder Worker Thread Swarm in `Wallpaper.qml`**:
  Even though `live` evaluates to `false` and video playback is paused (`pause()`), `QtMultimedia`'s FFmpeg backend spawns and maintains **13 active decoding threads** (`av:h264:df0..12`, `QFFmpeg::VideoR`, `data-loop.0`, `cuda-EvtHandlr`). Pausing does not unbind the video pipeline; the worker threads continue looping.
- **Root Cause B: Redundant Audio Tap Processes & 80ms Property Floods**:
  Diagnostics revealed **two instances of `level-meter.py` running simultaneously** (PID 13167 and PID 24991). Both tap PipeWire at ~12.5Hz and write to `$XDG_RUNTIME_DIR/cool-shell-levels`. In `IslandHub.qml` line 303, `root.levels = next; root.levelUpdatedAt = Date.now()` fires every 80ms, triggering continuous reactive binding invalidations across multiple QML items even when the media widget is closed.
- **Root Cause C: Continuous Ambient Orbital Animation**:
  In `desktop/AmbientReticle.qml`, `NumberAnimation` loops infinitely (`duration: 120000`, `loops: Animation.Infinite`) as long as `root.active` is true, forcing continuous compositor layer re-renders on `WlrLayer.Bottom`.

### 2. Memory Consumption (~670 MB RSS)
The shell consumes **670,988 KB (~655 MB)** resident memory. For a desktop UI overlay, this is substantial. The primary culprits are:
1. Video frame decoding buffers and GPU surface allocations in `Wallpaper.qml`.
2. Massive QML scene graph allocations across hundreds of items in unpartitioned monolithic components.
3. Multiple background daemon processes (`awww-daemon`, two `level-meter.py` instances, `wl-paste` watchers).

### 3. The "IPC-Back-To-Self" Anti-Pattern
In multiple UI components, actions trigger by spawning a detached subprocess that calls `qs ipc` against itself:
- `panels/BottomBar.qml:391`: `Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "overview", "toggle"])`
- `panels/BottomBar.qml:863`: `Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "displays", "cycle"])`
- `panels/BottomBar.qml:1028`: `Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "settings", "toggle"])`
- `panels/RightSidebar.qml:732`: `Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "overview", "toggle"])`
- `components/ControlCenter.qml:831`: `Quickshell.execDetached(["sh", "-c", "sleep 0.2; quickshell ipc -c cool-shell call capture screenshot region"])`

**Why this is an anti-pattern**:
Launching an external CLI binary to send an IPC request through a UNIX domain socket back to the current running process introduces process fork overhead, UNIX socket serialization, context switches, and latency (50–150ms). A direct QML property binding or signal emission completes in <0.01ms with zero allocations.

### 4. Compositor Action Layer Erosion & Direct `hyprctl` Calls
The architecture in `README.md` specified that all compositor mutations must pass through `core/CompositorActionLayer.qml` and `core/InteractionModel.qml` for pre-flight validation and telemetry. In practice:
- `components/StashPocket.qml`: Directly calls `Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move..."])`
- `panels/BottomBar.qml`: Directly calls `Quickshell.execDetached(["hyprctl", "dispatch", "workspace", ...])`
- `panels/RightSidebar.qml`: Directly calls `Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspacesilent", ...])`
- `components/BirdsEyeOverview.qml`: Directly calls `Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus..."])`

This bypasses the `CompositorActionLayer` allowlist barrier, breaks action telemetry, and creates inconsistent mutation pathways across the shell.

### 5. Monolithic File Sizes & Maintenance Friction
Several core files have grown to unmaintainable sizes:
- `panels/SettingsWindow.qml`: **2,488 lines** (140 KB)
- `shell.qml`: **2,134 lines** (85 KB)
- `panels/RightSidebar.qml`: **1,900 lines** (102 KB)
- `panels/BottomBar.qml`: **1,609 lines** (67 KB)
- `island/Notch.qml`: **1,604 lines** (53 KB)

These monolithic files mix UI presentation, low-level system processes, IPC definitions, and data models into single files, causing high LSP overhead, difficult code navigation, and tight coupling.

### 6. Theme Namespace Hazard (`theme/Theme.qml` vs `island/Theme.qml`)
Two files share the identical name `Theme.qml`:
- `island/Theme.qml`: A dynamic `pragma Singleton` driven by `theme-system.sh`.
- `theme/Theme.qml`: A static `QtObject` adapter.
Because QML treats filenames as types, `shell.qml` contains an explicit warning: `import "island" // bare Theme in this file = island singleton (do NOT add import "theme" here)`. This creates subtle naming shadowing bugs for any developer or agent touching the code.

---

## 5. The Better: Strategic Recommendations & Action Plan

### Tier 1: Performance & Resource Optimization (Immediate Impact)

1. **Tame Idle CPU from 20% to < 1%**:
   - **Video Wallpaper Unloading**: When opaque windows cover the screen, do not merely call `mediaPlayer.pause()`. Set `mediaPlayer.source = ""` and restore it when live, or use `awww` as the primary static wallpaper daemon and only instantiate `MediaPlayer` when explicitly in animated mode. This terminates the 13 FFmpeg decoder worker threads immediately.
   - **Singleton Guard for `level-meter.py`**: Add a lockfile (`/run/user/1000/cool-shell-level-meter.pid`) or `pgrep` check in `island/IslandHub.qml` and `level-meter.py` to prevent duplicate concurrent audio capture daemons.
   - **Sleep the Audio Tap When Visualizer is Closed**: Stop streaming `root.levels` when neither `MediaWidget` nor `Notch` is visible or expanded.

2. **Eliminate IPC-Back-To-Self**:
   - In `panels/BottomBar.qml` and `panels/RightSidebar.qml`, replace:
     ```qml
     Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "overview", "toggle"]);
     ```
     with direct property toggles:
     ```qml
     shellRoot.overviewOpen = !shellRoot.overviewOpen;
     ```
   - Wire `settingsWindow.toggle()` and `displaySwitcher.cycle()` directly via root aliases.

### Tier 2: Architectural Integrity & Security (Medium Term)

3. **Restore the Compositor Action Layer Barrier**:
   - Extend `core/CompositorActionLayer.qml` with approved intents for:
     - `moveToSpecialWorkspace(addr, specialName)`
     - `toggleSpecialWorkspace(specialName)`
     - `focusWindowAddress(addr)`
   - Refactor `StashPocket.qml`, `BottomBar.qml`, `RightSidebar.qml`, and `BirdsEyeOverview.qml` to route all mutations through `compositorActionLayer.executeAction(...)`, restoring strict auditability and telemetry.

4. **De-duplicate and Rename Theme Authorities**:
   - Rename `theme/Theme.qml` to `theme/TacticalMetrics.qml` or merge its motion tokens (`animDurationFast`, `springStiffness`) directly into `island/Theme.qml`.
   - Remove the `do NOT add import "theme"` constraint in `shell.qml`.

### Tier 3: Code Modularity & Component Architecture (Long Term)

5. **Deconstruct Monolithic Files**:
   - **`SettingsWindow.qml` (2,488 lines)**: Break into individual tab components under `panels/settings/` (`NetworkTab.qml`, `BluetoothTab.qml`, `DisplayTab.qml`, `PerformanceTab.qml`, etc.) loaded on-demand via `Loader`.
   - **`shell.qml` (2,134 lines)**: Extract the 23 `IpcHandler` definitions into a modular `core/IpcRegistry.qml` or individual handler files.
   - **`RightSidebar.qml` (1,900 lines)**: Separate Deck 1 (Surfaces) and Deck 2 (Telemetry) into dedicated component files under `panels/valence/`.

6. **Edge-Trigger Ergonomics & Hysteresis**:
   - The 2px bottom edge triggers (`triggerHeight: 2`) can be difficult to hit on high-DPI displays or trackpads. Implement an invisible 8px activation trigger zone with a 400ms entrance debounce and visual hover glow indicators to prevent accidental triggers while guaranteeing effortless activation.

---

## 6. Live Telemetry & Verification Matrix

| Metric / Subsystem | Measured / Observed Value | Evaluation | Target / Recommendation |
| :--- | :--- | :--- | :--- |
| **Quickshell Process RSS** | `670 MB` | **High** | `< 250 MB` (via dynamic video unloading) |
| **Idle CPU Utilization** | `19.9% – 21.0%` | **High** | `< 1.0%` (kill duplicate tap, pause reticle) |
| **Active `level-meter.py` Daemons** | `2 instances` (PID 13167, 24991) | **Bad** | Strict single instance (`1 instance`) |
| **Active Video Decoder Threads** | `13 FFmpeg threads` | **Inefficient** | 0 threads when desktop covered |
| **IPC Registration Coverage** | `23 targets` responsive | **Excellent** | Maintain full CLI headless control |
| **Compositor Protocol Flow** | C++ Wayland streams | **Excellent** | Zero polling on workspaces/windows |
| **Mutation Barrier Compliance** | `~25%` (bypassed in 4 components) | **Degraded** | `100%` routing through `CompositorActionLayer` |
| **Visual Polish & Cohesion** | High (VALENCE, Notch, Ukishima) | **Exceptional** | Preserve unique cybernetic identity |

---

## 7. Conclusion

`cool-shell` is an extraordinary technical achievement: a Linux Wayland desktop environment that looks and feels like a bespoke cybernetic operating system from the future. Its core architectural foundations (Wayland C++ object models, layer-shell integration, headless IPC, and spring-physics dynamic island) are remarkably solid.

By addressing the **three primary friction points** — taming the idle CPU drain from 20% to <1%, eliminating internal IPC-back-to-self subprocess forks, and decomposing the 2,000+ line file monoliths into clean subcomponents — `cool-shell` will achieve production-grade stability, efficiency, and developer joy without sacrificing a single drop of its breathtaking visual identity.
