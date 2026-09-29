# COOL-SHELL: COMPLETE RECONNAISSANCE & ARCHITECTURAL REVIEW

**Target Path:** `~/.config/quickshell/cool-shell/`  
**Host Environment:** Linux / Wayland / Hyprland (0.47+ Lua dispatch)  
**Framework:** Quickshell 0.3.1 (Qt 6 / QML / Wayland Layer Shell)  
**External Config Inspected:** `~/.config/hypr/hyprland.lua`  
**Scope of Action:** Read-only inspection, verification, and comprehensive architectural briefing. Zero code or configuration files were modified during this investigation.

---

## 1. EXECUTIVE SUMMARY

`cool-shell` is a high-performance, dual-heritage Wayland desktop shell running natively on Hyprland via Quickshell 0.3.1. Totaling **19,486 lines of code** across **77 files** (QML, Python, Bash, and GLSL), the codebase represents a fusion of two fundamentally distinct desktop shell philosophies:

1. **The `pranc-shell` Instrument Surface:** A cyber-tactical desktop telemetry system (`core/`, `components/`, `panels/`, `desktop/`, `theme/`) featuring edge-triggered slide-out sidebars (Control Center and Application Overview), bottom workspace bar, idle-activated ambient telemetry HUD ([`desktop/AmbientLayer.qml`](file:///home/pranc/.config/quickshell/cool-shell/desktop/AmbientLayer.qml)), directional spatial workspace transitions ([`desktop/DesktopTransition.qml`](file:///home/pranc/.config/quickshell/cool-shell/desktop/DesktopTransition.qml)), and a 16-target headless IPC query/mutation pipeline.
2. **The `vyeos` / `dotarch` Dynamic Island:** A macOS-inspired "Live Activities" dynamic pill at the top of the screen ([`island/Notch.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml)), mediated by a central state arbiter ([`island/IslandHub.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/IslandHub.qml)) and a unified backend singleton ([`island/Backend.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/Backend.qml)). It hosts 14 feature panels (launcher, clipboard manager, markdown notes, todo list, media player, notification center, timers/stopwatch, file shelf/downloads, weather, themes, wallpapers, capture, power), an interactive region/window capture overlay ([`island/CaptureSelector.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/CaptureSelector.qml)), and real-time audio waveform level meters ([`island/scripts/level-meter.py`](file:///home/pranc/.config/quickshell/cool-shell/island/scripts/level-meter.py)).

### Critical Architectural Findings
- **Island Click Routing Bug:** In [`island/Notch.qml` line 789](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml#L789), clicking the collapsed Dynamic Island unconditionally executes `ShellState.show("control")`. Although `IslandHub.qml` defines an intelligent `primaryPanel()` priority router (mapping active media to `media`, recording to `capture`, timers to `timer`, and unread alerts to `notifications`), the click handler never invokes it.
- **Tri-Theme Schism:** Three separate styling authorities operate independently: [`theme/Theme.qml`](file:///home/pranc/.config/quickshell/cool-shell/theme/Theme.qml) (cyber-tactical cyan/crimson tokens), [`island/Theme.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/Theme.qml) (dynamic Everforest pastel tokens loaded via `theme-system.sh`), and [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml) (hardcoded Waybar CSS colors). Changing themes in the island does not affect the sidebars, ambient layer, or bottom bar.
- **Process Polling Overhead:** Several background timers repeatedly fork external subshells:
  - Spawning `/bin/cat` every **150ms** (~6.7 forks/sec) in `IslandHub.qml` to read audio levels from tmpfs while music plays.
  - Spawning `wpctl get-volume` every **2,000ms** in `BottomBar.qml` despite `Quickshell.Services.Pipewire` already being linked into the process.
  - Spawning `wl-paste | md5sum` every **2,000ms** in `Backend.qml` to detect external screenshots.
  - Spawning `fuser /dev/video*` every **2,000ms** in `PrivacyState.qml` to check webcam activity.
  - Spawning `find ~/Downloads` every **5,000ms** in `ShelfState.qml` to track browser downloads.
- **Disabled Organic Bézier Shoulders:** In [`island/Notch.qml` lines 662 and 703](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml#L662), two `PathCubic` Bézier curves designed to flare the top corners of the pill smoothly into the monitor bezel are hardcoded to `visible: false`.
- **Permanent Debug Artifacts:** Four 8x8 colored debug rectangles (`#80ffffff`, `#00ff88`, `#00bfff`, `#ff0088`) are permanently rendered in the top-left corner of the layer window in [`shell.qml` lines 1407–1440](file:///home/pranc/.config/quickshell/cool-shell/shell.qml#L1407-L1440).

---

## 2. PROJECT STRUCTURE

The project encompasses **19,486 lines of code** across **77 files**:

```text
~/.config/quickshell/cool-shell/
├── shell.qml                         # Global orchestrator, singletons, 16 IPC handlers, layer windows (1,551 L)
├── README.md                         # Legacy "pranc-shell" documentation (274 L)
├── .qmlls.ini                        # QML Language Server configuration (6 L)
│
├── island/                           # Dynamic Island & Notification Subsystem (ported from dotarch/vyeos)
│   ├── Notch.qml                     # Island container, pill geometry, surface washes, 14 panel hosts (1,342 L)
│   ├── Backend.qml                   # Primary singleton: brightness, night light, cliphist, grim, rec (530 L)
│   ├── IslandHub.qml                 # Central state coordinator, priority router, transient flashes, level reader (298 L)
│   ├── CollapsedStatus.qml           # Collapsed pill HUD: unread badge, rec pulse, label morph, wave, privacy (644 L)
│   ├── CaptureSelector.qml           # Interactive window picker & drag-box region screenshot overlay (167 L)
│   ├── NotificationPopups.qml        # Layer shell notification banner manager ("vyeos-notifications") (50 L)
│   ├── NotificationCard.qml          # Notification bubble delegate with action buttons and dismiss timer (181 L)
│   ├── LowBatteryMonitor.qml         # Background UPower monitor invoking gdbus notification when < 10% (47 L)
│   ├── Theme.qml                     # Dynamic theme singleton loaded from theme-system.sh current-json (75 L)
│   ├── ShellState.qml                # Panel open/close router, legacy "clock" state, todo persistence (232 L)
│   ├── TimerState.qml                # Stopwatch, countdown timers, pomodoro focus session state (178 L)
│   ├── PrivacyState.qml              # PipeWire mic stream detection + /dev/video* fuser probing (63 L)
│   ├── PowerState.qml                # UPower battery, on-battery, and plug/unplug transient event detector (51 L)
│   ├── BtState.qml                   # BlueZ adapter status, connected device diff tracker (77 L)
│   ├── ShelfState.qml                # Dropped file shelf (shelf.json) + ~/Downloads partial file watcher (194 L)
│   ├── WeatherState.qml              # wttr.in weather fetcher with 30-minute disk cache (78 L)
│   ├── NotesState.qml                # Markdown notes manager backing quick-notes via notes-helper.py (116 L)
│   ├── AppearanceState.qml           # Theme and wallpaper listing/switching mediator (97 L)
│   ├── AiState.qml                   # [DEAD STUB] Unbound extension stub for local LLM integration (26 L)
│   ├── CallState.qml                 # [DEAD STUB] Unbound extension stub for telephony/calls (41 L)
│   ├── Expression.js                 # Pure JS recursive-descent math parser for launcher calculator (93 L)
│   ├── MarkdownBlocks.js             # Block-level markdown parser/serializer for quick notes (67 L)
│   ├── shelf.json                    # Persistent JSON store for shelved files
│   ├── todos.json                    # Persistent JSON store for todo list
│   ├── components/                   # Island reusable widgets (7 files, 726 L)
│   │   ├── ActionTile.qml            # Big tactical toggle card (WiFi, Bluetooth, etc.)
│   │   ├── ConnectionRow.qml         # Device row for Bluetooth/WiFi lists
│   │   ├── IconButton.qml            # Circular clickable icon button
│   │   ├── PanelHeader.qml           # Standardized panel titlebar with close trigger
│   │   ├── PanelNav.qml              # Breadcrumb header for subpanel navigation
│   │   ├── ShellText.qml             # Standardized text element with Geist font binding
│   │   └── StyledSlider.qml          # Tactile horizontal slider for volume and brightness
│   ├── panels/                       # 14 Island Expandable Panels (14 files, 5,584 L)
│   │   ├── ControlPanel.qml          # Quick settings, volume/mic sinks, wifi, bluetooth, system tray (1,191 L)
│   │   ├── LauncherPanel.qml         # App launcher with inline math evaluation (230 L)
│   │   ├── ClipboardPanel.qml        # Cliphist history with image preview and paste (305 L)
│   │   ├── TodoPanel.qml             # Task manager with tags, priorities, due dates (792 L)
│   │   ├── QuickNotesPanel.qml       # Block-based markdown editor with command palette (904 L)
│   │   ├── ThemePanel.qml            # Theme selector card grid (113 L)
│   │   ├── WallpaperPanel.qml        # Theme-scoped wallpaper thumbnail picker (176 L)
│   │   ├── CapturePanel.qml          # Full/window/region screenshot + wf-recorder toggle (625 L)
│   │   ├── PowerPanel.qml            # Lock, suspend, logout, reboot, shutdown (129 L)
│   │   ├── MediaPanel.qml            # MPRIS player with artwork blur, seeker, controls (248 L)
│   │   ├── NotifCenterPanel.qml      # Notification history with dismiss-all (62 L)
│   │   ├── TimerPanel.qml            # Stopwatch, countdown presets, focus timer (235 L)
│   │   ├── ShelfPanel.qml            # File shelf list with xdg-open triggers + download progress (143 L)
│   │   └── WeatherPanel.qml          # Current weather and forecast display (77 L)
│   └── scripts/                      # External Backend Daemons & Shell Scripts (4 files, 1,040 L)
│       ├── level-meter.py            # Python PipeWire monitor tap writing 4-bin RMS levels to tmpfs (213 L)
│       ├── notes-helper.py           # Python CLI managing ~/Notes/Quick directory and pins (139 L)
│       ├── shell-actions.sh          # Bash router: brightness, night-light, cliphist, grim, wf-recorder, power (258 L)
│       └── theme-system.sh           # Bash router: theme generator for Hyprland, GTK, Fish, Alacritty, awww (430 L)
│
├── core/                             # Compositor Intelligence & Mutation Layer (pranc-shell, 10 files, 2,374 L)
│   ├── WorkspaceManager.qml          # Read-only authoritative wrapper around Hyprland.workspaces (91 L)
│   ├── SurfaceManager.qml            # Read-only authoritative wrapper around Hyprland.toplevels (97 L)
│   ├── WorkspaceModel.qml            # Spatial ordering, occupancy, special workspace separation (201 L)
│   ├── SurfaceModel.qml              # Normalized surface records, application grouping, urgent flags (317 L)
│   ├── DesktopModel.qml              # Unified desktop composition graph (workspaces + surfaces + monitors) (377 L)
│   ├── DesktopState.qml              # Presentation state, sidebar flags, spatial transition progress (116 L)
│   ├── InteractionModel.qml          # Intent mediation, pre-flight target validation, security barrier (325 L)
│   ├── CompositorActionLayer.qml     # Mutation actuator executing Hyprland Lua dispatcher APIs (361 L)
│   ├── IdleManager.qml               # Native ext_idle_notification_v1 wrapper via IdleMonitor (102 L)
│   └── EdgeManager.qml               # [DEAD] Empty 15-byte placeholder file (1 L)
│
├── components/                       # Tactical Surface HUD Components (pranc-shell, 6 files, 3,288 L)
│   ├── ControlCenter.qml             # Left sidebar content: modes, telemetry, topology (550 L)
│   ├── ApplicationOverview.qml       # Right sidebar content: app cards, window lists, focus/close/move (1,004 L)
│   ├── WorkspaceNavigator.qml        # [ORPHANED] 773-line spatial workspace HUD (superseded by BottomBar)
│   ├── EdgeTrigger.qml               # Screen-edge hover sensor with anchors (48 L)
│   ├── PanelSurface.qml              # Translucent panel backdrop rectangle bound to theme/Theme.qml (20 L)
│   └── PanelContent.qml              # Standard padding and insets container (30 L)
│
├── panels/                           # Slide-out Window Containers (pranc-shell, 3 files, 838 L)
│   ├── LeftSidebar.qml               # Bottom-left triggered panel hosting ControlCenter (135 L)
│   ├── RightSidebar.qml              # Bottom-right triggered panel hosting ApplicationOverview (135 L)
│   └── BottomBar.qml                 # Bottom-center triggered panel hosting inlined Waybar replica (368 L)
│
├── desktop/                          # Ambient & Spatial Layers (5 files, 641 L)
│   ├── AmbientLayer.qml              # WlrLayer.Bottom idle overlay window (107 L)
│   ├── AmbientCornerBrackets.qml     # Screen-corner tactical crosshairs (143 L)
│   ├── AmbientReticle.qml            # Central orbital rings with continuous 120s drift (100 L)
│   ├── AmbientTelemetry.qml          # Monitor, workspace, power telemetry readout (122 L)
│   └── DesktopTransition.qml         # Ephemeral 280ms spatial transition reticle on WlrLayer.Top (295 L)
│
├── theme/
│   └── Theme.qml                     # Hardcoded cyber-tactical neon cyan/crimson token authority (221 L)
│
├── wallpaper/
│   ├── Wallpaper.qml                 # [ORPHANED] Procedural GLSL shader on WlrLayer.Background (106 L)
│   ├── README.md                     # Shader compilation guide (98 L)
│   └── shaders/                      # wallpaper.frag (77 L) and wallpaper.frag.qsb (compiled binary)
│
└── scripts/
    ├── media-picker.py               # [ORPHANED] Standalone background media selector script (418 L)
    └── screenshot-region.sh          # [ORPHANED] Standalone slurp/grim screenshot script (80 L)
```

---

## 3. ARCHITECTURE MAP

```text
                                     HYPRLAND / WAYLAND COMPOSITOR
                                                   │
                 ┌─────────────────────────────────┴─────────────────────────────────┐
                 ▼                                                                   ▼
     [Quickshell.Hyprland C++]                                         [Wayland ext_idle_notification_v1]
                 │                                                                   │
                 ├───────────────────────────────┐                                   ▼
                 ▼                               ▼                            core/IdleManager
        core/WorkspaceManager           core/SurfaceManager                          │
                 │                               │                                   ├────────────────┐
                 ▼                               ▼                                   │ (idle resume)  ▼
        core/WorkspaceModel             core/SurfaceModel                            ▼         desktop/AmbientLayer
                 │                               │                            island/IslandHub   (WlrLayer.Bottom)
                 └───────────────┬───────────────┘                                   │         (Brackets, Reticle,
                                 ▼                                                   │          Telemetry)
                         core/DesktopModel                                           │
                                 │                                                   ▼
                         core/DesktopState ──(change)──► desktop/DesktopTransition
                                 │                             (WlrLayer.Top 280ms)
                 ┌───────────────┴───────────────┐
                 ▼                               ▼
       panels/LeftSidebar              panels/RightSidebar                 panels/BottomBar
    (components/ControlCenter)     (components/AppOverview)            (Inlined Waybar Replica)
                 ▲                               ▲                                   ▲
                 └───────────────────────────────┼───────────────────────────────────┘
                                                 │
                                        components/EdgeTrigger
                                   (Bottom Overlay Window Mask)
                                   (Includes 4 Debug Squares)

─────────────────────────────────────────────────────────────────────────────────────────────────
                                     DYNAMIC ISLAND SUBSYSTEM
─────────────────────────────────────────────────────────────────────────────────────────────────

   SYSTEM BACKENDS & PROCESSES                                 STATE SINGLETONS
   • PipeWire Audio Sink/Source   ────────────────►           island/IslandHub
   • MPRIS Media Players          ────────────────►           island/ShellState
   • BlueZ Bluetooth Adapter      ────────────────►           island/TimerState
   • UPower Battery & Display     ────────────────►           island/PowerState
   • NotificationServer           ────────────────►           island/PrivacyState
   • island/Backend.qml           ────────────────►           island/BtState
   • level-meter.py (12Hz RMS)    ──(150ms cat)──►           island/ShelfState
   • shell-actions.sh (helper)    ────────────────►           island/WeatherState
   • theme-system.sh (awww, gtk)  ────────────────►           island/AppearanceState
                                                                      │
                                                                      ▼
                                                              island/Notch.qml
                                                          (WlrLayer.Overlay Window)
                                                                      │
                                ┌─────────────────────────────────────┴─────────────────────────────────────┐
                                ▼                                                                           ▼
                       Collapsed Status HUD                                                       Expanded Panel Host
                   (island/CollapsedStatus.qml)                                                    (1 of 14 Panels)
                 • Unread notification badge                                                    • ControlPanel (1,191 L)
                 • Recording pulse dot & timer                                                  • QuickNotesPanel (904 L)
                 • Morphing primary activity text                                               • TodoPanel (792 L)
                 • 4-bar PipeWire audio waveform                                                • CapturePanel (625 L)
                 • Mic (yellow) & Cam (purple) dots                                             • Launcher, Clipboard, Media,
                 • Bluetooth connect slide-in                                                   • Timer, Shelf, Theme,
                 • Exclusive 1000ms volume takeover                                             • Wallpaper, Weather, Power,
                                                                                                • NotifCenterPanel
```

---

## 4. STATE / EVENT FLOW

### Flow 1: IPC Invocation & Panel Expansion
1. **User Action / Keybind:** User presses Super key (`SUPER_L` release), bound in `~/.config/hypr/hyprland.lua` to:
   ```bash
   qs -c cool-shell ipc call notch toggle launcher
   ```
2. **IPC Handler Routing:** In [`shell.qml` line 1212](file:///home/pranc/.config/quickshell/cool-shell/shell.qml#L1212), `IpcHandler { target: "notch" }` receives `toggle("launcher")`, invoking [`ShellState.show("launcher")`](file:///home/pranc/.config/quickshell/cool-shell/island/ShellState.qml#L77).
3. **State Transition:** `ShellState.panel` flips from `"clock"` to `"launcher"`. `ShellState.expanded` becomes `true`. `ShellState.targetWidth` transitions to `panelWidths["launcher"]` (410px).
4. **Surface Reaction:** In [`island/Notch.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml#L128-L153):
   - `onPanelChanged` triggers.
   - `window.clockRevealed = false` immediately hides `CollapsedStatus` (fades in 90ms).
   - `snapPop.restart()` executes scale micro-overshoot on `notchSurface` (1.0 $\to$ 0.8 $\to$ 1.0 over 300ms).
   - Width and height Behaviors morph `notchSurface` to 434px $\times$ 304px (260ms `OutCubic`).
   - `stageTimer` (150ms delay) runs to allow pill expansion before staging content.
5. **Content Reveal & Focus Grab:**
   - `stageTimer` triggers $\to$ `window.contentStaged = true`.
   - `panelHost` opacity animates $0 \to 1$ (140ms `OutCubic`), `panelSlide` translates $y: 8 \to 0$ (180ms `OutCubic`).
   - `HyprlandFocusGrab` activates on `[window]`.
   - `focusTimer` (35ms delay) fires `window.focusInitialControl()` $\to$ `LauncherPanel.qml` `searchInput.forceActiveFocus(Qt.TabFocusReason)`.

### Flow 2: Volume Step Takeover & Dynamic Restoration
1. **Hardware / Keybind Input:** Multimedia volume key sends volume step via `wpctl`.
2. **Compositor / PipeWire Event:** PipeWire updates default sink volume. Native service `Quickshell.Services.Pipewire` emits `onVolumeChanged`.
3. **Takeover Assertion:** [`island/IslandHub.qml` lines 181–191](file:///home/pranc/.config/quickshell/cool-shell/island/IslandHub.qml#L181-L191) `Connections { target: root.sinkAudio }` catches the change and calls `root.showVolume()`.
4. **Pill Transformation:**
   - `IslandHub.volumeActive = true`, `volumePercent = Math.round(vol * 100)`.
   - `volumeTimer` (1,000ms) restarts.
   - In `Notch.qml`: `volumeFillClip` opacity fades to 1 (150ms). `volumeFill` width animates to `parent.width * volumePercent / 100` (180ms `OutCubic`).
   - In `CollapsedStatus.qml`: Standard collapsed row hides (`visible: !root.volumeActive`). Dark volume chip reveals (`visible: root.volumeActive`) and scales $0.85 \to 1.0$ (120ms `OutCubic`).
5. **Decay & Restoration:** When no further volume changes occur within 1,000ms, `volumeTimer` triggers `volumeActive = false`. `volumeFillClip` fades out in 150ms, the dark volume chip hides, and the underlying media/timer/clock activity smoothly resumes without state corruption.

### Flow 3: External Screenshot Detection & Surface Wave
1. **User Executes Screenshot:** User hits `Print` key $\to$ Hyprland runs `grim -g "$(slurp)" - | wl-copy`.
2. **Polling Daemon Detection:** In [`island/Backend.qml` lines 347–384](file:///home/pranc/.config/quickshell/cool-shell/island/Backend.qml#L347-L384), a recurring 2,000ms `Timer` fires `clipSigProcess`:
   ```bash
   wl-paste --type image/png | head -c 16384 | md5sum
   ```
3. **Fingerprint Qualification:** If MD5 differs from `lastClipImageSig` and is outside the internal capture suppression window (`Date.now() - ownCaptureAt > 4000`), `Backend.captureTick` increments.
4. **Hub Dispatch:** [`island/IslandHub.qml` lines 288–296](file:///home/pranc/.config/quickshell/cool-shell/island/IslandHub.qml#L288-L296) catches `onCaptureTickChanged`:
   - `showTransient("Screenshot captured", 1500)`
   - `flashBorder("white", 700)`
   - `burst()`
   - `sweep("white")`
5. **Multi-Layer Physical Reaction:**
   - `sweepAnim`: 30px white scanline with 52px trailing wash sweeps across the entire pill surface (450ms `OutCubic`).
   - `burstAnim`: 4 micro-particles explode downward from the pill base (350ms `OutCubic`).
   - `noticeFlash`: Border pulses white twice ($160\text{ms Out} + 380\text{ms In}$).
   - `CollapsedStatus.qml`: `primaryLabel` shrinks and fades out (110ms `OutCubic`), swaps text to `"Screenshot captured"`, and expands in (140ms `OutCubic`). After 1,500ms, it morphs back to the previous activity.

---

## 5. DYNAMIC ISLAND REVIEW

### Geometry, Anchoring, and Boundary Masking
- **Top Bézier Curves (Disabled Defect):** Lines 658–738 of [`island/Notch.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml#L658-L738) contain two `Shape` items (`leftShoulderPath` and `rightShoulderPath`) using `PathCubic` Bézier curves designed to flare the top corners of the pill smoothly into the monitor's top bezel. **Both items have `visible: false` hardcoded (lines 662 and 703)!** The pill floats with standard rounded corners rather than continuous organic Bézier shoulders.
- **Top Anchoring & Transform Origin:** Set to `Item.TopCenter` on `notchSurface`. All scale pops (`snapPop`, `arrivalPop`) and vertical height expansions grow downwards into the screen without altering the 10px bezel margin (`topGap: 10`).
- **Input Pass-Through Mask:** Handled cleanly via `mask: Region { item: notchBody; topLeftRadius: notchBody.radius; ... }` on the `PanelWindow`. All clicks outside the rounded rectangle pass through directly to underlying Hyprland toplevels.
- **Collapsed Dimensions:** Width 145px (plus 24px wings = 169px total), Height 24px.
- **Expanded Dimensions:** Width ranges from 365px (`clipboard`, `notifications`) to 520px (`control`, `media`). Height is dynamically evaluated via `Math.max(ShellState.panelHeights[panel], requestedPanel.implicitHeight) + padding`, ranging from 56px (`power`) to 430px (`notes`).

### State Arbitration & Actual Routing
The collapsed status priority ladder in [`island/IslandHub.qml` lines 138–161](file:///home/pranc/.config/quickshell/cool-shell/island/IslandHub.qml#L138-L161) resolves competing background tasks cleanly:
$$\text{Volume Takeover (P0)} \to \text{Transients (P1)} \to \text{Recording (P2)} \to \text{Timer Completion Hold (P3)} \to \text{Timer Active (P4)} \to \text{Media Playing (P5)} \to \text{Unread Notifications (P6)} \to \text{Downloads (P7)} \to \text{Paused Media (P8)} \to \text{Idle / Weather (P9)}$$

**The Click Routing Disconnect:**  
The shell defines `function primaryPanel()` in `IslandHub.qml`, which correctly maps the highest-priority activity to its panel (`recordingActive` $\to$ `capture`, `hasActive` $\to$ `timer`, `mediaPlaying` $\to$ `media`, `unreadCount > 0` $\to$ `notifications`, etc.). However, in [`island/Notch.qml` line 789](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml#L789), **the click handler never calls `IslandHub.primaryPanel()`:**
```qml
// Notch.qml lines 788-790
// Plain click always opens control center (hub for everything).
ShellState.show("control");
```
Clicking the island while music is playing, while a recording is running, or while unread notifications are waiting will ALWAYS open `ControlPanel.qml` instead of routing to `media`, `capture`, or `notifications`!

### Evaluation: "Full Surface Reaction" vs "Black Pill + Widget"
- **High-Polish Surface Reactions:**
  - **Volume:** The entire surface becomes an animated progress gauge from left to right.
  - **Recording:** The entire pill breathes a translucent red wash on a 500ms cadence (`recWash`).
  - **Timers:** A 2px bottom progress bar sweeps across the entire lower edge, flashing urgently when $\le 5$s.
  - **File Absorption:** Dragging a file stretches the notch (`scale: 1.08`). Dropping causes the proxy item to physically fly into the pill center, shrink, emit 4 burst particles, and rebound the notch (`scale: 1.12 $\to$ 1.0`).
- **"Black Pill + Widget" Fallbacks:**
  - **Expanded Panels:** When opened, the island behaves merely as a generic black rectangular box holding standard vertical desktop controls. It does not morph organically into specialized activity shapes.
  - **Privacy Indicators:** Mic and Cam indicators are simply 8px colored circles placed inside the collapsed Row.
  - **Multi-Monitor:** The island opens on ALL connected screens simultaneously upon Super-tap, but only screen 0 responds to file drops and notification bounces.

---

## 6. COMPLETE ANIMATION INVENTORY

Exhaustive inventory of all 42 primary animations across the shell:

| # | File / Component | Animation Target | Trigger / Condition | Property | Duration & Easing | Visual Role / Character | Conflict Risk |
|---|---|---|---|---|---|---|---|
| 1 | `island/Notch.qml` | `notchSurface` width Behavior | `ShellState.panel` change | `width` | 260ms `OutCubic` | Horizontal expansion / collapse | None |
| 2 | `island/Notch.qml` | `notchSurface` height Behavior | `ShellState.panel` change | `height` | 260ms `OutCubic` | Vertical expansion / collapse | Disabled during clipboard preview |
| 3 | `island/Notch.qml` | `snapPop` | Panel open / close / switch | `scale` | 150ms + 150ms `OutCubic` (1.0 $\to$ 0.8 $\to$ 1.0) | Micro-overshoot on state transitions | **High:** Jarring 100px jump on large 520px panels |
| 4 | `island/Notch.qml` | `arrivalPop` | `unreadCount` increments | `scale` | 140ms + 120ms `OutCubic` (1.0 $\to$ 1.04 $\to$ 1.0) | Tactile bounce on notification arrival | Can fight `snapPop` |
| 5 | `island/Notch.qml` | `recWash` Behavior | `recordingActive` & `recBlinkOn` | `opacity` | 500ms `OutCubic` (0.10 $\leftrightarrow$ 0.22) | Breathing red surface wash during recording | None |
| 6 | `island/Notch.qml` | `timerLine` Behavior | `TimerState.progressFraction` | `width` | 260ms `OutCubic` | Bottom edge progress line | None |
| 7 | `island/Notch.qml` | `urgentPulse` | `urgentRemaining` $\le 5$s | `opacity` | 500ms + 500ms `OutCubic` (1.0 $\leftrightarrow$ 0.35) | Flashing progress line on timer expiration | Loops infinitely until 0s |
| 8 | `island/Notch.qml` | `timerFillClip` Behavior | `TimerState.progressFraction` | `width` | 260ms `OutCubic` | Translucent interior fill wash | None |
| 9 | `island/Notch.qml` | `mediaFillClip` Behavior | `islandPlayer.position` | `width` | 250ms `OutCubic` | Translucent track progress fill | None |
| 10 | `island/Notch.qml` | `volumeFillClip` Behavior | `IslandHub.volumeActive` | `opacity` | 150ms `OutCubic` ($0 \to 1$) | Reveals volume takeover layer | None |
| 11 | `island/Notch.qml` | `volumeFill` Behavior | `IslandHub.volumePercent` | `width` | 180ms `OutCubic` | Volume fill gauge advancement | None |
| 12 | `island/Notch.qml` | `sweepAnim` | `IslandHub.sweep()` | `x` | 450ms `OutCubic` (-30 $\to$ width) | Colored scanline sweep across pill | Coalesces via restart |
| 13 | `island/Notch.qml` | `ripplePop` | `unreadCount` increments | `scale`, `opacity` | 400ms `OutCubic` (0.7 $\to$ 1.15, 1 $\to$ 0) | Expanding accent ripple on notification | None |
| 14 | `island/Notch.qml` | `burstAnim` | `IslandHub.burst()` | `burstT` | 350ms `OutCubic` ($0 \to 1$) | 4-dot particle scatter on capture/drop | Coalesces via restart |
| 15 | `island/Notch.qml` | `borderGlow` opacity Behavior | `flashActive` or `recordingActive`| `opacity` | 150ms `OutCubic` | Fades border glow in/out | None |
| 16 | `island/Notch.qml` | `borderGlow` color Behavior | `flashColor` change | `border.color` | 150ms `OutCubic` | Morphing border color (white, blue, red)| None |
| 17 | `island/Notch.qml` | `doneBlink` | `TimerState.completionHold` | `opacity` | 500ms + 500ms `OutCubic` (1.0 $\leftrightarrow$ 0.25)| Continuous breathing border on timer DONE | Clears on island click |
| 18 | `island/Notch.qml` | `mediaRingClip` Behavior | `window.mediaFraction` | `width` | 250ms `OutCubic` | Perimeter progress ring width | None |
| 19 | `island/Notch.qml` | `ringDip` | Track finishes ($>95\%$ + stop) | `opacity` | 150ms + 200ms `OutCubic` (1 $\to$ 0 $\to$ 1) | Dips media ring before next track starts | None |
| 20 | `island/Notch.qml` | `shelfStretch` | File dragged over DropArea | `scale` | 140ms `OutCubic` (1.0 $\to$ 1.08) | Stretches island toward incoming file | Chained into `shelfRelease` |
| 21 | `island/Notch.qml` | `shelfRelease` | File dragged out of DropArea | `scale` | 180ms `OutCubic` (1.08 $\to$ 1.0) | Relaxes island back to rest | Can fight `absorbPop` |
| 22 | `island/Notch.qml` | `absorbFly` | File dropped on DropArea | `x`, `y`, `scale`, `op` | 300ms `OutCubic` (scale 1 $\to$ 0.4, op 1 $\to$ 0.15) | File proxy flies into pill center | Triggers burst + absorbPop |
| 23 | `island/Notch.qml` | `absorbPop` | `absorbFly.onFinished` | `scale` | 100ms + 140ms `OutCubic` (0.96 $\to$ 1.12 $\to$ 1.0)| Bounce rebound as file absorbs | Clears `shelfRelease` |
| 24 | `island/Notch.qml` | `panelHost` opacity Behavior | `contentStaged` | `opacity` | 140ms `OutCubic` ($0 \leftrightarrow 1$) | Delays panel reveal until pill expands | None |
| 25 | `island/Notch.qml` | `panelSlide` Behavior | `contentStaged` | `y` | 180ms `OutCubic` ($8 \leftrightarrow 0$) | Upward glide for panel contents | None |
| 26 | `island/Notch.qml` | `panelSwitch` | Switch panel while expanded | `switchDim` | 120ms + 160ms `OutCubic` (1 $\to$ 0 $\to$ 1) | Cross-fade dip when switching active panel | Swaps `displayedPanel` |
| 27 | `island/Notch.qml` | `noticeFlash` | `ShellState.noticeTick` / timer | `opacity` | 160ms Out + 380ms In (loops: 2) | Attention double-flash on notification | None |
| 28 | `island/CollapsedStatus.qml` | `bubblePop` | `unread` count changes | `scale` | 150ms + 150ms `OutCubic` (0.7 $\to$ 1.08 $\to$ 1.0)| Unread badge bounce on increment | None |
| 29 | `island/CollapsedStatus.qml` | `recPulse` | `recActive == true` | `scale`, `opacity` | 500ms + 500ms `OutCubic` (1 $\leftrightarrow$ 1.3, 1 $\leftrightarrow$ 0.5)| Rhythmic heartbeat on red recording dot | Runs while recording |
| 30 | `island/CollapsedStatus.qml` | `recStop` | `recActive` becomes false | `scale`, `opacity` | 150ms `OutCubic` (1 $\to$ 0.6, 1 $\to$ 0) | Shrinks recording dot on stop | None |
| 31 | `island/CollapsedStatus.qml` | `morphOut` | `primaryLabel.text` change | `scale`, `opacity` | 110ms `OutCubic` (1 $\to$ 0.6, 1 $\to$ 0) | Old text shrinks and fades away | Chained into `morphIn` |
| 32 | `island/CollapsedStatus.qml` | `morphIn` | `morphOut.onFinished` | `scale`, `opacity` | 140ms `OutCubic` (0.6 $\to$ 1.0, 0 $\to$ 1) | New text pops in with scale growth | None |
| 33 | `island/CollapsedStatus.qml` | `wavePop` | `mediaPlaying` becomes true | `scale`, `opacity` | 140ms `OutCubic` (0.6 $\to$ 1.0, 0 $\to$ 1) | Equalizer visualizer pop on music play | None |
| 34 | `island/CollapsedStatus.qml` | wave bars Behavior | `IslandHub.levels[i]` change | `height` | 120ms `OutCubic` (2px $\to$ 12px) | Real-time audio waveform equalizer bars | Driven by level polling |
| 35 | `island/CollapsedStatus.qml` | `micPop` / `camPop` | `micActive` / `camActive` | `scale`, `opacity` | 180ms `OutCubic` (0 $\to$ 1.0, 0 $\to$ 1) | Organic pop-in when mic or cam starts | None |
| 36 | `island/CollapsedStatus.qml` | `btSlideAnim` | `btConnected` changes | `x`, `opacity` | 300ms `OutCubic` (x 14 $\to$ 0, op 0 $\to$ 1) | Bluetooth icon glides in from right | None |
| 37 | `island/CollapsedStatus.qml` | `btFadeOut` | Bluetooth disconnected | `opacity` | Pause 400ms + 300ms `OutCubic` (1 $\to$ 0) | Icon lingers briefly then fades out | None |
| 38 | `island/CollapsedStatus.qml` | `volPop` | Volume text or mute changes | `scale`, `opacity` | 120ms `OutCubic` (0.85 $\to$ 1.0, 0.4 $\to$ 1) | Tactile micro-bounce on volume change | None |
| 39 | `core/DesktopState.qml` | `transitionAnim` | `currentWorkspaceId` change | `_progress` | 280ms `OutCubic` (0.0 $\to$ 1.0) | Normalized spatial progress driver | Drives DesktopTransition |
| 40 | `desktop/DesktopTransition.qml`| `enterExitAnim` | `workspaceTransitioning` | `opacity`, `x` | 280ms composite (50ms in, 130ms hold, 100ms out)| Directional sliding HUD during workspace switch | Runs on WlrLayer.Top |
| 41 | `desktop/AmbientLayer.qml` | `fadeInAnim` / `fadeOutAnim` | `idleManager.idle` change | `opacity` | In: 1000ms `OutCubic` / Out: 180ms `OutQuad` | Slow ambient HUD emergence / instant mouse dismiss | Driven by native ext-idle |
| 42 | `panels/LeftSidebar.qml` (and RightSidebar/BottomBar) | `openAnim` / `closeAnim` | `open` state change | `x` / `y`, `opacity` | Open: 200ms `OutCubic` / Close: 160ms `InCubic` | Slide-out drawer entry and exit | Unmaps window when closed |

---

## 7. BACKEND / INTEGRATION REVIEW

### 1. Hyprland 0.47+ Lua Dispatch Integration
- Direct native C++ bindings via `Quickshell.Hyprland` singletons:
  - `Hyprland.workspaces` and `Hyprland.toplevels` are tracked reactively by `WorkspaceManager.qml` and `SurfaceManager.qml`.
  - Window mutations in [`core/CompositorActionLayer.qml`](file:///home/pranc/.config/quickshell/cool-shell/core/CompositorActionLayer.qml#L290-L330) and [`island/scripts/shell-actions.sh`](file:///home/pranc/.config/quickshell/cool-shell/island/scripts/shell-actions.sh#L183) execute Hyprland 0.47+ Lua dispatch commands:
    ```lua
    hl.dsp.window.move({ workspace = <id>, window = "address:<addr>" })
    hl.dsp.window.fullscreen({ window = "address:<addr>" })
    hl.dsp.send_shortcut({ mods = "CTRL", key = "V", window = "address:<addr>" })
    ```
- Window candidate enumeration in `shell-actions.sh` executes `hyprctl -j monitors` and `hyprctl -j clients | jq` to compute window geometry candidates for `CaptureSelector.qml`.

### 2. Audio & PipeWire Polling Inefficiency
- While volume and mute are handled reactively via `Quickshell.Services.Pipewire`, the audio waveform visualizer is severely inefficient:
  - [`island/scripts/level-meter.py`](file:///home/pranc/.config/quickshell/cool-shell/island/scripts/level-meter.py) captures audio from default sink monitor ports via `pw-record` and writes 4 RMS values to `$XDG_RUNTIME_DIR/cool-shell-levels` at 12Hz.
  - In [`island/IslandHub.qml` lines 244–271](file:///home/pranc/.config/quickshell/cool-shell/island/IslandHub.qml#L244-L271), Quickshell spawns `/bin/cat` via `Process` every **150ms** (~6.7 forks/sec) while music is playing.
  - In [`panels/BottomBar.qml` lines 79–106](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L79-L106), `BottomBar` spawns `wpctl get-volume @DEFAULT_AUDIO_SINK@` every **2,000ms**, completely ignoring the native `Pipewire` singleton already linked in the process.

### 3. MPRIS & Media Seeker
- `Quickshell.Services.Mpris` provides reactive player models, album art URLs, and metadata.
- Because MPRIS specification does not emit position-change signals, `Notch.qml` (line 1320) and `MediaPanel.qml` run a 1,000ms timer calling `player.positionChanged()`.

### 4. BlueZ & Bluetooth
- `Quickshell.Bluetooth` provides reactive adapter and device objects.
- In [`island/BtState.qml` lines 51–72](file:///home/pranc/.config/quickshell/cool-shell/island/BtState.qml#L51-L72), a 3,000ms `Timer` diffs `connectedNames` against `prevConnected` to detect connect/disconnect events and trigger island sweeps.

### 5. UPower & Battery Alert Loopback
- `Quickshell.Services.UPower` tracks battery percentage and charging state.
- In [`island/PowerState.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/PowerState.qml#L25), a 2,000ms `Timer` polls `charging` and `onBattery` transitions rather than using Qt signal connections.
- In [`island/LowBatteryMonitor.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/LowBatteryMonitor.qml#L21), when battery is $< 10\%$, Quickshell executes `gdbus call --session --dest org.freedesktop.Notifications ...` via `Process` to send a notification over D-Bus, which then loops back into Quickshell's own `NotificationServer`.

### 6. Screenshots & Screen Recording
- Grim + wl-copy: `island/scripts/shell-actions.sh` captures fullscreen or geometry to `~/Pictures/Screenshots/`.
- Screen recording: `wf-recorder` is spawned in the background, writing to `~/Videos/Recordings/`. Its PID is tracked in `$XDG_RUNTIME_DIR/quickshell-wf-recorder.pid`. Toggling sends `kill -INT $pid`.
- Interactive Capture Overlay: [`island/CaptureSelector.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/CaptureSelector.qml) creates an overlay surface on `WlrLayer.Overlay`. In region mode, it handles drag selection with dimensions tooltip. In window mode, it highlights window bounding boxes.

### 7. File Shelf & Download Watcher
- File Shelf: Files dragged onto `Notch.qml` are appended to [`island/shelf.json`](file:///home/pranc/.config/quickshell/cool-shell/island/shelf.json) via `FileView`. Clicking an item executes `xdg-open` via `Quickshell.execDetached`.
- Download Watcher: In [`island/ShelfState.qml` lines 181–192](file:///home/pranc/.config/quickshell/cool-shell/island/ShelfState.qml#L181-L192), a 5,000ms `Timer` spawns `find ~/Downloads -maxdepth 1 \( -name '*.part' -o -name '*.crdownload' -o -name '*.aria2' \) -printf '%s\t%f\n'` to track active browser downloads.

---

## 8. STRENGTHS

1. **Native Wayland Layer-Shell Architecture:** Clean layering (`WlrLayer.Overlay` for Island and CaptureSelector, `WlrLayer.Top` for Sidebars and Transition, `WlrLayer.Bottom` for Ambient HUD). Zero XWayland dependencies.
2. **True Compositor Intelligence (Pranc-Shell):** `WorkspaceManager.qml`, `SurfaceManager.qml`, and `CompositorActionLayer.qml` form an exceptionally robust, declarative layer around Hyprland C++ APIs, incorporating null-safe fallback handling and pre-flight validation.
3. **Flawless Input Masking:** Both `Notch.qml` and `CaptureSelector.qml` utilize `Region` masks on their `PanelWindow` instances, ensuring that transparent canvas areas never intercept mouse clicks or block underlying windows.
4. **Organic Pill Surface Feedback:** Physical drag-and-drop absorption (`shelfStretch` $\to$ `absorbFly` $\to$ `burstAnim` $\to$ `absorbPop`), volume fill bar, and scanline sweeps achieve genuine "entire surface transformation" rather than static widget boxes.
5. **Headless IPC Coverage:** 16 comprehensive IPC handlers allow full scriptability and testing of workspaces, surfaces, desktop models, compositor actions, idle states, and island panels via `qs -c cool-shell ipc call <target> <method>`.

---

## 9. WEAKNESSES / RISKS

1. **Click Routing Defect:** `Notch.qml` line 789 calls `ShellState.show("control")` unconditionally. The pill never routes clicks to the active activity (`IslandHub.primaryPanel()`), defeating the core purpose of a Live Activities pill.
2. **Disabled Bézier Curves:** `leftShoulderPath` and `rightShoulderPath` in `Notch.qml` are hardcoded to `visible: false`, disabling the organic flare into the top screen bezel.
3. **Severe Polling Overhead:** Over 15 active timers and subshell processes continuously poll external binaries:
   - Spawning `/bin/cat` every 150ms for audio levels.
   - Spawning `wpctl` every 2,000ms in `BottomBar.qml`.
   - Spawning `wl-paste | md5sum` every 2,000ms for clipboard screenshots.
   - Spawning `fuser /dev/video*` every 2,000ms for webcam probing.
   - Spawning `find ~/Downloads` every 5,000ms for downloads.
   - Spawning `nmcli` every 10,000ms in `BottomBar.qml`.
4. **Multi-Monitor Island Collision:** `Notch.qml` instances on secondary monitors expand simultaneously when the primary island opens, while `HyprlandFocusGrab` runs concurrently on all instances. Furthermore, notification bounces and file drops are hardcoded to `screen === Quickshell.screens[0]`.
5. **Tri-Theme Schism:** Three conflicting styling authorities exist: `theme/Theme.qml` (cyber-tactical), `island/Theme.qml` (dynamic Everforest), and `panels/BottomBar.qml` (hardcoded Waybar CSS). Changing the theme in the island does not update the rest of the shell.
6. **Substantial Dead & Orphaned Code:**
   - `components/WorkspaceNavigator.qml` (773 lines): completely orphaned.
   - `wallpaper/Wallpaper.qml` (106 lines) and GLSL shaders: completely superseded by `awww`.
   - `island/CallState.qml` (41 lines) and `island/AiState.qml` (26 lines): unreferenced dead stubs.
   - `core/EdgeManager.qml` (1 line): empty placeholder.
   - `scripts/media-picker.py` (418 lines) and `scripts/screenshot-region.sh` (80 lines): dead standalone scripts.
7. **Leftover On-Screen Debug Artifacts:** Four 8x8 colored rectangles (`#80ffffff`, `#00ff88`, `#00bfff`, `#ff0088`) are permanently rendered in the top-left of the overlay window (`shell.qml` lines 1407–1440).
8. **State Domain Pollution in `ShellState.qml`:** `ShellState.qml` mixes panel switching and layout dimensions with full Todo list persistence and CRUD parsing (`todos`, `loadTodos()`, `saveTodos()`). Furthermore, the collapsed pill state is named `"clock"`, even though no clock exists.
9. **`snapPop` Scale Distortion:** `snapPop` scales the island to 0.8 during panel switching. On wide panels (520px), this causes a 104px horizontal contraction and bounce that feels jarring.

---

## 10. DESIGN-SYSTEM REVIEW

### Evaluation of Visual Language
The shell exhibits an identity conflict between two well-executed but incompatible aesthetic paradigms:
1. **Cyber-Tactical Monospace (`theme/Theme.qml`, `components/`, `desktop/`):**
   - Palette: Deep charcoal (`#e0181825`), neon cyan (`#00bfff`), warning crimson (`#ff3366`), amber (`#ffb700`).
   - Geometry: 12px radii, 1px hairline borders (`#30ffffff`), crosshair reticles, corner brackets.
   - Typography: Monospace, all-caps headers with slash prefixes (`"// CONTROL CENTER"`), wide letter-spacing (1.5).
2. **Organic Soft Rounded (`island/Theme.qml`, `island/`, `island/panels/`):**
   - Palette: Everforest pastel tones (sage green `#a7c080`, cream `#d3c6aa`, coral `#e67e80`).
   - Geometry: Pill radii (up to 24px), soft translucent washes, micro particle bursts, scanline sweeps.
   - Typography: Geist Sans (`fontFamily: "Geist"`), mixed case, subdued weights.
3. **Waybar Industrial (`panels/BottomBar.qml`):**
   - Palette: Jet black translucency (`rgba(0,0,0,0.62)`), muted gray text (`#d7d7d7`), border (`#454446`).
   - Typography: `JetBrainsMono Nerd Font Propo`.

### Animation & Motion Consistency
- **Timing & Easing:** Highly disciplined. The vast majority of transitions use `Easing.OutCubic` over 140ms (`animationFast`) or 260ms (`animationNormal`).
- **Surface Washes:** The Dynamic Island executes volume washes, recording pulses, and timer sweeps with exceptional fluidness. However, expanded panels remain static rectangles that do not adapt their contours to their contents.

---

## 11. HIGH-VALUE IMPROVEMENTS

### 1. Fix Dynamic Island Click Routing
- **Change:** In [`island/Notch.qml` lines 788–790](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml#L788-L790), replace `ShellState.show("control")` with `ShellState.show(IslandHub.primaryPanel())`.
- **Rationale:** Restores the core Live Activities functionality: clicking the island during media playback opens `media`, during recording opens `capture`, with unread notifications opens `notifications`, and during timers opens `timer`.
- **Involved Files:** `island/Notch.qml`, `island/IslandHub.qml`.
- **Preserved Functionality:** Plain idle click still falls back to `"control"`. `completionHold` logic remains untouched.
- **Risk:** Minimal.

### 2. Replace Level-Meter `cat` Process Polling with Stream / IPC
- **Change:** Eliminate the 150ms `cat` polling loop in `IslandHub.qml`. Modify `level-meter.py` to write levels directly to `stdout`, and have `levelProc` in `IslandHub.qml` consume lines via `StdioCollector` or a streaming socket.
- **Rationale:** Eliminates ~6.7 process forks per second, saving significant CPU cycles and reducing battery drain during music playback.
- **Involved Files:** `island/scripts/level-meter.py`, `island/IslandHub.qml`.
- **Preserved Functionality:** Real-time 4-bar equalizer behavior in `CollapsedStatus.qml`.
- **Risk:** Low.

### 3. Re-enable & Tune Bézier Shoulder Curves
- **Change:** In [`island/Notch.qml` lines 662 and 703](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml#L662), change `visible: false` to `visible: !ShellState.expanded` and verify alignment against the top screen bezel.
- **Rationale:** Re-establishes the organic physical flare curving the collapsed pill into the top monitor bezel.
- **Involved Files:** `island/Notch.qml`.
- **Preserved Functionality:** Smooth expansion and collapse.
- **Risk:** Low; must verify that shoulder shapes do not clip expanded panel contents.

### 4. Remove Permanent On-Screen Debug Rectangles
- **Change:** Delete the test/debug indicator `Row` in [`shell.qml` lines 1407–1440](file:///home/pranc/.config/quickshell/cool-shell/shell.qml#L1407-L1440).
- **Rationale:** Removes four 8x8 colored debug rectangles permanently visible in the top-left of the display.
- **Involved Files:** `shell.qml`.
- **Preserved Functionality:** Edge triggers remain fully functional.
- **Risk:** None.

---

## 12. MEDIUM-VALUE IMPROVEMENTS

### 1. Unify the Theme Authorities
- **Change:** Refactor `theme/Theme.qml` and `panels/BottomBar.qml` to consume color tokens dynamically from `island/Theme.qml`.
- **Rationale:** Allows changing the theme via `ThemePanel` to update the sidebars, bottom bar, and ambient HUD in lockstep with the Dynamic Island.
- **Involved Files:** `theme/Theme.qml`, `panels/BottomBar.qml`, `components/*`, `desktop/*`.
- **Risk:** Medium; requires mapping tactical color tokens (cyan/crimson) to theme palette roles.

### 2. Purge Dead & Orphaned Files
- **Change:** Clean up `components/WorkspaceNavigator.qml`, `wallpaper/`, `core/EdgeManager.qml`, `island/CallState.qml`, `island/AiState.qml`, and `scripts/`.
- **Rationale:** Removes ~1,600 lines of dead code that confuse developers and language servers.
- **Involved Files:** Multiple files across the repository.
- **Risk:** None.

### 3. Replace BottomBar `wpctl` & `nmcli` Polling with Native Services
- **Change:** In `panels/BottomBar.qml`, replace the 2,000ms `wpctl` polling loop with `Quickshell.Services.Pipewire` bindings, and network polling with NetworkManager DBus properties.
- **Rationale:** Eliminates repeated process spawns and makes the bottom bar fully reactive.
- **Involved Files:** `panels/BottomBar.qml`.
- **Risk:** Low.

### 4. Extract `TodoState.qml` from `ShellState.qml`
- **Change:** Move `todos`, `loadTodos()`, `saveTodos()`, and `parseTodoInput()` from `ShellState.qml` into a dedicated `island/TodoState.qml` singleton. Rename default panel `"clock"` to `"collapsed"`.
- **Rationale:** Enforces clean separation of concerns and eliminates misleading legacy nomenclature.
- **Involved Files:** `island/ShellState.qml`, `island/TodoPanel.qml`, `island/Notch.qml`.
- **Risk:** Low.

---

## 13. OPTIONAL EXPERIMENTS

1. **Spring Dynamics for Island Scale & Geometry:** Replace standard `OutCubic` number animations on width/height with dampening spring physics (`SpringAnimation`), giving the island a fluid, gelatinous response during panel resizing.
2. **Context-Adaptive Panel Silhouettes:** Instead of expanding into uniform rectangular bounding boxes, allow panel backgrounds to curve organically around specific widgets (e.g. pill-shaped media player, compact circular timer).
3. **Multi-Monitor Island Scoping:** Update `shell.qml` and `Notch.qml` so that the Dynamic Island only expands on the monitor currently containing the active mouse pointer or keyboard focus.

---

## 14. FUTURE ARCHITECTURE

If `cool-shell` evolves into an enterprise-grade "Live Activities Hub", it should follow an incremental 4-layer model:

```text
┌────────────────────────────────────────────────────────┐
│               LAYER 4: PRESENTATION SURFACES           │
│   Dynamic Island (Notch), Sidebars, Ambient HUD, Bar   │
└───────────────────────────▲────────────────────────────┘
                            │
┌────────────────────────────────────────────────────────┐
│            LAYER 3: ACTIVITY ARBITRATION (HUB)         │
│   Priority Matrix, Dynamic Click Router, Transitions   │
└───────────────────────────▲────────────────────────────┘
                            │
┌────────────────────────────────────────────────────────┐
│             LAYER 2: STATE DOMAIN SINGLETONS           │
│   Media, Timers, Shelf, Privacy, Power, Themes, Todos  │
└───────────────────────────▲────────────────────────────┘
                            │
┌────────────────────────────────────────────────────────┐
│           LAYER 1: REACTIVE BACKENDS & COMPOSITOR      │
│   PipeWire, Mpris, UPower, BlueZ, Hyprland C++ Bindings│
└───────────────────────────┘────────────────────────────┘
```

- **Event Coalescing:** All external events (screenshots, Bluetooth, plug events) raise a monotonically increasing `tick` counter on their state singleton. Downstream visual components connect to `onTickChanged`, ensuring duplicate events within the same second are never lost.
- **Zero-Process Principle:** Migrate all polling daemons to persistent background stream connections or native Quickshell C++ plugins, ensuring idle CPU usage remains at 0.0%.

---

## 15. PRACTICAL VERIFICATION MATRIX

| Subsystem / Feature | Verification Method | Command / Test Procedure | Success Criteria |
|---|---|---|---|
| **Workspace Intelligence** | Static / Headless IPC | `qs -c cool-shell ipc call workspace listJson` | Returns valid JSON array of workspaces with occupancy |
| **Surface Intelligence** | Static / Headless IPC | `qs -c cool-shell ipc call surface activeJson` | Returns valid JSON with active window address & title |
| **Compositor Action Layer** | Live Hyprland Session | `qs -c cool-shell ipc call action switchWorkspace 2` | Hyprland switches to workspace 2 via Lua dispatch |
| **Dynamic Island Expansion** | Live Session / Keybind | `qs -c cool-shell ipc call notch toggle launcher` | Notch expands to 434px $\times$ 304px, search receives focus |
| **Volume Takeover** | PipeWire Interaction | `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+` | Full-width volume bar fills pill for 1,000ms, then restores |
| **External Screenshot** | Real System Event | `grim - \| wl-copy` | White sweep line traverses island, 4 burst particles fire |
| **Timer Completion** | Timed Real Event | `qs -c cool-shell ipc call island countdownAdd 1` | Border breathes on 0s, label displays "DONE" until clicked |
| **Audio Level Waveform** | Audio Playback | Play track in Spotify/mpv | 4-bar equalizer animates at 12Hz in collapsed pill |
| **File Shelf Drop** | Pointer Interaction | Drag image onto collapsed island | Notch scales 1.08, proxy flies into center, file added to shelf |
| **Ambient Layer Emergence** | Idle Daemon | `qs -c cool-shell ipc call idle setSimulatedIdle true` | Reticle & brackets fade in over 1,000ms; dismiss on mouse move |

---

## 16. RECOMMENDED NEXT STEPS

1. **Apply High-Value Bugfixes (Priority 1):**
   - In [`island/Notch.qml` line 789](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml#L789), replace `ShellState.show("control")` with `ShellState.show(IslandHub.primaryPanel())`.
   - Remove the four debug indicator rectangles in [`shell.qml` lines 1407–1440](file:///home/pranc/.config/quickshell/cool-shell/shell.qml#L1407-L1440).
   - Re-enable shoulder Bézier shapes in [`island/Notch.qml` lines 662 and 703](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml#L662).
2. **Optimize Audio Level Pipeline (Priority 2):**
   - Refactor `level-meter.py` to pipe levels directly to stdout, eliminating the 150ms `cat` execution.
3. **Codebase Cleanup (Priority 3):**
   - Delete orphaned `components/WorkspaceNavigator.qml`, `wallpaper/`, and stub files (`CallState.qml`, `AiState.qml`).
4. **Theme Harmonization (Priority 4):**
   - Bind `theme/Theme.qml` and `panels/BottomBar.qml` tokens to `island/Theme.qml`.
