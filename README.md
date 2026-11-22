# cool-shell

> **A high-performance, cyber-tactical desktop environment and unified operating cockpit built natively for Hyprland on Wayland using Quickshell 0.3.x and Qt 6.**

`cool-shell` unifies tactile hardware control, intelligent system modes, local machine intelligence, ambient astronomical rendering, and mobile device bridging into a single, cohesive Wayland desktop surface with zero latency, spring physics, and real-time hardware telemetry.

---

## 🏛️ System Architecture

`cool-shell` enforces a strict **unidirectional reactive architecture** that separates compositor observation from compositor mutation, preventing race conditions and stale UI states:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      Observation Pipeline (Read-Only)                  │
│                                                                        │
│   Hyprland / Wayland C++ Singletons                                    │
│          ↓                                                             │
│   WorkspaceManager / SurfaceManager (Authoritative Wrappers)           │
│          ↓                                                             │
│   WorkspaceModel / SurfaceModel (Normalized Projections)               │
│          ↓                                                             │
│   DesktopModel (Multi-Level Composition Graph)                         │
│          ↓                                                             │
│   DesktopState (Presentation State & Transition Driver)                │
│          ↓                                                             │
│   Shell Surfaces: TopConvexBar, Sidebars, BottomBar, Ambient Slate     │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      Mutation Pipeline (Actuation Barrier)             │
│                                                                        │
│   User Interaction (Tactile UI HUD / Gestures / IPC)                   │
│          ↓                                                             │
│   InteractionModel (Pre-flight Target Validation)                      │
│          ↓                                                             │
│   CompositorActionLayer (Strict Allowlist Barrier)                     │
│          ↓                                                             │
│   Native Quickshell C++ APIs (Hyprland.dispatch, Toplevel.activate)    │
│          ↓                                                             │
│   Hyprland Wayland Compositor                                          │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```text
~/.config/quickshell/cool-shell/
├── shell.qml                     # Root entry point, singletons, and IPC registration
├── theme/
│   └── Theme.qml                 # Single semantic token authority (metrics, colors, durations)
├── core/                         # Authoritative compositor wrappers and data models
├── island/                       # Drop-down feature panels and subsystem state machines
│   ├── ShellState.qml            # Panel geometry, dimensions, and active monitor routing
│   ├── WeatherState.qml          # Localized weather caching and telemetry state
│   ├── AppearanceState.qml       # Wallpapers and dynamic color palettes
│   └── panels/                   # 16 Interactive drop-down island panels
├── components/                   # Left and Right sidebar tactical HUD components
│   ├── ControlCenter.qml         # visionOS-style modular control center
│   └── TodayCenter.qml           # Right sidebar scratchpad, calendar, and system overview
├── panels/                       # Surface containers (TopConvexBar, LeftSidebar, RightSidebar, ShortcutsWindow)
├── desktop/                      # Ambient astronomical layer, customizable clock slate, and motes
│   ├── AmbientConfig.qml         # Persistent layout, template, and celestial toggle authority
│   ├── AmbientLayer.qml          # Wayland fullscreen ambient surface
│   ├── DesktopAmbientSlate.qml   # Customizable clock (Pranc / Default / Minimal) & radial telemetry dial
│   ├── SolarLunarArc.qml         # Bangalore astronomical solar/lunar orbit engine
│   └── AtmosphericMotes.qml      # Autonomous interactive fireflies & living air particles
├── wallpaper/                    # Video wallpaper playback and GPU shaders
├── requirements.txt              # Authoritative Python dependencies (uv / pip compatible)
├── DEPENDENCIES.md               # Complete dependencies matrix, package origins, and setup guide
└── scripts/                      # Autonomous daemons, hardware controls, and intelligence tools
```

---

## ⌨️ System Keybindings & Hotkeys (`SUPER + .`)

Press **`SUPER + .`** anytime to summon the built-in, searchable **Shortcuts Cheatsheet Window**:

| Shortcut | Action | Details / Scope |
| :--- | :--- | :--- |
| **`SUPER + .`** | **Shortcuts Cheatsheet** | Toggle interactive shortcuts cheatsheet window |
| **`SUPER + L`** | **Lock Screen** | Secure Wayland session lock via Veila |
| **`SUPER + SHIFT + L`** | **Lockscreen Theme Switcher** | Switch Veila themes (`.local/share/veila/wallpapers`) |
| **`SUPER`** *(release)* | **App Launcher & Calc** | Instant app search, calculator, unit & currency conversion |
| **`SUPER + Space`** | **Contextual Action Hub** | Floating radial hub for recent files, tools, and actions |
| **`SUPER + A`** | **Wallpapers & Live Video** | Browse static categories and dynamic animated `.mp4` video loops |
| **`SUPER + C`** | **Color & Material Themes** | Real-time Material You palette generator |
| **`SUPER + M`** | **Now Playing & Lyrics** | Synced karaoke lyrics, playback controls, and volume wheel |
| **`SUPER + N`** | **Notification Center** | View notification stream, priority alerts, and history |
| **`SUPER + G`** | **AI Image Studio Bar** | Fast prompt bar with Latent Consistency Model (LCM) |
| **`SUPER + X`** | **Power & Session Menu** | Lock, sleep, restart, or shutdown |
| **`SUPER + I`** | **System Settings** | Quickshell hardware and desktop settings center |
| **`SUPER + TAB`** | **Window Overview Matrix** | Visual birds-eye overview across active workspaces |
| **`SUPER + R`** | **Bird's-Eye Overview** | Bird's-eye overview and window stash pocket |
| **`SUPER + P`** | **Cycle Display Layout** | Cycle multi-monitor layout presets |
| **`SUPER + SHIFT + P`** | **Confirm Display Layout** | Confirm and save active multi-monitor configuration |
| **`SUPER + T`** | **Terminal Emulator** | Launch Kitty GPU-accelerated terminal |
| **`SUPER + E`** | **File Manager** | Launch Dolphin graphical file manager |
| **`SUPER + W`** | **Web Browser** | Launch Brave web browser |
| **`SUPER + Q`** | **Close Window** | Gracefully terminate focused window |
| **`SUPER + V`** | **Clipboard Manager** | Cliphist fuzzy history picker with preview |
| **`SUPER + D`** / **`SUPER + V`** | **Toggle Window Floating** | Switch active window between tiling and floating |
| **`SUPER + J`** | **Toggle Split Direction** | Swap horizontal / vertical tiling split |
| **`SUPER + Y`** | **Pin Window** | Pin floating window across all workspaces |
| **`SUPER + H`** / **`SUPER + K`** | **Focus Window Left / Right** | Shift keyboard focus between tiling columns |
| **`SUPER + Arrows`** | **Directional Window Focus** | Move focus Left, Right, Up, or Down |
| **`SUPER + 1 .. 9, 0`** | **Jump to Workspace 1 - 10** | Instant switch to numbered workspace |
| **`SUPER + SHIFT + 1 .. 0`** | **Move Window to Workspace** | Send focused window to workspace 1 through 10 |
| **`SUPER + S`** | **Toggle Stash Pocket** | Slide down special scratchpad workspace |
| **`SUPER + ALT + S`** | **Send Window to Stash** | Move active window into stash pocket |
| **`SUPER + Scroll Wheel`** | **Scroll Workspaces** | Cycle workspaces smoothly via mouse wheel |
| **`SUPER + Left Drag`** | **Move Window** | Interactive floating window movement |
| **`SUPER + Right Drag`** | **Resize Window** | Interactive window boundary scaling |
| **`Print`** | **Quick Area Snip** | Interactive rectangular crop directly copied to clipboard |
| **`SUPER + Print`** | **Annotate Screenshot** | Capture screen region and open in Swappy editor |
| **`SUPER + SHIFT + S`** | **Universal Screen Lens** | Optical OCR text extract, QR code decoder & color sampler |
| **`SUPER + F1`** | **Extreme Game Mode** | Suspend desktop shell; switch to ~50MB RAM gaming profile |
| **`SUPER + SHIFT + N`** | **Night Light Toggle** | Toggle Hyprsunset warm blue light filter |
| **`SUPER + ALT + A`** | **Switch Audio Sink** | Quick-toggle audio output (Headphones / Speakers / HDMI) |
| **`SUPER + ALT + P`** | **CoolPhone Mirroring** | Toggle Android screen mirror via Scrcpy |
| **`SUPER + SHIFT + ESC`** | **Force Kill Application** | Interactive cursor crosshair to terminate frozen apps |
| **`Fn + Media Keys`** | **Audio & Brightness** | Hardware volume, mic mute, brightness, and playback transport |

---

## 🌌 Ambient Desktop HUD & Celestial Engine

When on an empty workspace or during idle periods, `cool-shell` transitions into an architectural ambient slate ([`desktop/AmbientLayer.qml`](file://$HOME/.config/quickshell/cool-shell/desktop/AmbientLayer.qml)):

### 1. Customizable Templates & Placements
Configured via [`desktop/AmbientConfig.qml`](file://$HOME/.config/quickshell/cool-shell/desktop/AmbientConfig.qml) and persistent `desktop/ambient_config.json`:
- **`"pranc"` (Custom Setup)**: Horizontal clock `HH | MM` with 0.5-alpha vertical divider, 4-line segmented radial vitals ring (GPU in crimson red, CPU in cyan, Battery in emerald, RAM in purple) with center BT/Wi-Fi hub and hover tooltip, plus top-right localized weather.
- **`"default"`**: Classic vertical stacked clock (`HH` on top of `MM` in Geom font), date, modern frosted glass telemetry chips row, and weather.
- **`"minimal"`**: Ultra-clean single-line `HH:MM` clock, date, and compact inline weather/battery telemetry.
- **Dynamic Placements**: Move the clock slate to `"top-left"`, `"center"`, `"bottom-left"`, or `"top-right"` with smooth animated transitions.

### 2. Celestial Orbit (Sun & Moon)
- Renders an astronomical 24-hour circular orbit ([`desktop/SolarLunarArc.qml`](file://$HOME/.config/quickshell/cool-shell/desktop/SolarLunarArc.qml)) mapping Bangalore astronomical solar noon, dusk, dawn, and nadir with continuous optical diffraction rays.
- Can be toggled on/off instantly via IPC or Control Center.

### 3. Atmospheric Living Air (Motes & Fireflies)
- 14 autonomous celestial stars and twilight fireflies ([`desktop/AtmosphericMotes.qml`](file://$HOME/.config/quickshell/cool-shell/desktop/AtmosphericMotes.qml)) with cursor repulsion and obstacle collision physics.
- **Performance Optimization**: When toggled off, the 50 FPS physics loop completely halts, reducing background CPU/GPU load to zero.

---

## 🏝️ Liquid Glass Top Convex Bar & Dynamic Panels

At the apex of the screen sits the **Top Convex Bar** ([`panels/TopConvexBar.qml`](file://$HOME/.config/quickshell/cool-shell/panels/TopConvexBar.qml)), an Apple Liquid Glass and Minflair-inspired tactile bar with spring physics:
- **Instant Keyboard Focus**: Opens search and calculator instantaneously with exclusive Wayland layer-shell focus and zero mouse motion lag.
- **Continuous Enter-to-Calculate**: Pressing Enter on mathematical calculations (e.g. `25 * 4`) copies the answer to the clipboard and populates the search bar for further chained arithmetic.
- **16 Drop-Down Modals**: Wallpaper picker, theme engine, power menu, clipboard history, quick notes, todo checklist, timer/stopwatch, weather HUD, and AI studio.

---

## 🎛️ Bottom-Anchored Control Center (Left Sidebar)

Positioned cleanly at the bottom-left of the display ([`panels/LeftSidebar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/LeftSidebar.qml)):
- **Hardware Toggles**: Wi-Fi, Bluetooth, VPN, Airplane mode, Night Light, Performance/Eco mode, and Dynamic Island toggles.
- **Dual Capsule Sliders**: Low-latency Pipewire audio volume and backlight brightness controls.
- **Study Mode**: Cryptographically locked focus ceremony preventing app distractions.
- **CoolPhone Bridge**: macOS Sequoia-style wireless Android mirroring with hardware screen-off and clipboard sync.
- **Screen Tools**: 1-click Area Snip, Fullscreen Screenshot, and Region Screen Recording (`wf-recorder`).

---

## 🚀 Installation & Requirements

Full dependency matrices, package origins, and setup diagnostics are documented in **[`DEPENDENCIES.md`](file://$HOME/.config/quickshell/cool-shell/DEPENDENCIES.md)** and **[`requirements.txt`](file://$HOME/.config/quickshell/cool-shell/requirements.txt)**.

### Arch Linux / Pacman & AUR Setup

```bash
# 1. Install official repository prerequisites
sudo pacman -S --needed \
    hyprland hyprlock pipewire wireplumber pipewire-pulse pipewire-alsa playerctl \
    grim slurp wf-recorder tesseract tesseract-data-eng leptonica zbar imagemagick \
    swappy wl-clipboard cliphist brightnessctl awww espeak-ng python uv nodejs npm \
    jq curl socat psmisc procps-ng coreutils findutils fd ufw bitwarden scrcpy \
    android-tools cava mpv ffmpeg zenity networkmanager bluez bluez-utils upower \
    lm_sensors qt6-5compat qt6-multimedia qt6-multimedia-ffmpeg qt6-declarative \
    qt6-svg ttf-jetbrains-mono-nerd inter-font noto-fonts noto-fonts-emoji

# 2. Install AUR packages
paru -S --needed quickshell-git hyprsunset sptlrx-bin matugen-bin ttf-geist
```

### Python Machine Learning Virtual Environment

```bash
uv venv ~/.config/quickshell/cool-shell/.venv
source ~/.config/quickshell/cool-shell/.venv/bin/activate
uv pip install -r ~/.config/quickshell/cool-shell/requirements.txt
```

---

## 📡 Quickshell IPC Protocol

`cool-shell` provides extensive IPC control via the `qs` command-line tool:

```bash
# Ambient HUD Controls
qs -c cool-shell ipc call ambient setTemplate "pranc"     # "pranc" | "default" | "minimal"
qs -c cool-shell ipc call ambient setClockPosition "center" # "top-left" | "center" | "bottom-left" | "top-right"
qs -c cool-shell ipc call ambient toggleSunMoon             # Toggle solar & lunar orbit
qs -c cool-shell ipc call ambient toggleParticles           # Toggle living air fireflies
qs -c cool-shell ipc call ambient getSummary                # Query ambient status JSON

# Cheatsheet & Windows
qs -c cool-shell ipc call shortcuts toggle                  # Toggle Shortcuts Cheatsheet (Super + .)
qs -c cool-shell ipc call settings toggle                   # Toggle Settings Window (Super + I)
qs -c cool-shell ipc call control setLeftSidebarOpen true   # Open Left Sidebar / Control Center

# Dynamic Island Panels
qs -c cool-shell ipc call notch toggle launcher             # Toggle App Launcher
qs -c cool-shell ipc call notch toggle wallpaper            # Toggle Wallpaper Panel
qs -c cool-shell ipc call notch toggle media                # Toggle Media Player & Lyrics
```
