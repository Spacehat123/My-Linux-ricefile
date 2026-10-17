# Cool-Shell (Pranc Rice) — System & Functional Architecture Reference

> **Comprehensive reference manual detailing every major subsystem, daemon, UI surface, operating mode, IPC interface, and script in Cool-Shell.**

---

## 1. System Overview & Architecture

**Cool-Shell** is an ultra-low-latency, modular desktop environment built on **Quickshell** (Wayland QML shell) and **Hyprland** (dynamic tiling Wayland compositor).

### High-Level Architectural Layers

```
┌────────────────────────────────────────────────────────────────────────┐
│                        QUICKSHELL WAYLAND SHELL                        │
├───────────────────┬───────────────────┬────────────────────────────────┤
│   Dynamic Island  │   Left Sidebar    │         Right Sidebar          │
│   (Notch/Panels)  │  (Control Center) │      (VALENCE Command Deck)    │
├───────────────────┴───────────────────┴────────────────────────────────┤
│                    STATE & COMMUNICATION BUS                           │
│     ShellState.qml  •  IslandHub.qml  •  Theme.qml  •  IPC Handlers    │
├────────────────────────────────────────────────────────────────────────┤
│                       MICRO-DAEMONS & ENGINES                          │
│  AI Image Engine  │  Screen Lens OCR  │ Kokoro Voice │  God's Eye 3D   │
│  (Zero-VRAM LCM)  │ (Tesseract/zbar)  │ (Stream TTS) │  (OSINT Globe)  │
├───────────────────┴───────────────────┴──────────────┴─────────────────┤
│                   LINUX PLATFORM & HARDWARE LAYER                      │
│   Hyprland Compositor  •  PipeWire Audio  •  CUDA GPU  •  V4L2/grim    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Dynamic Island Subsystem (`island/`)

The Dynamic Island sits at the top of the primary monitor, morphing smoothly between compact status indications and full-blown operational panels.

### A. The Notch (`island/Notch.qml`)
- **Physics-Driven Geometry**: Morphs dynamically based on the active panel or system event using smooth spring animations.
- **Hover & Interaction**: Hovering or clicking expands contextual quick actions or switches panels.
- **Visual Pill States**:
  - `collapsed` (145px × 36px) — Minimalist clock, battery, and live ticker.
  - `media` (460–540px × 220px) — Music controls with synchronized scrolling lyrics.
  - `ai` (540px × 110px) — Super+G prompt bar with pulse glow.
  - `lens` (395px × 80px) — OCR toast with instant "Read Aloud" action.
  - `timer` (380px × 220px) — Countdown timer and stopwatch display.

### B. Collapsed Status Ticker (`island/CollapsedStatus.qml`)
Displays real-time ambient telemetry in the collapsed notch:
1. **Live Synchronized Lyrics**: Real-time karaoke lyrics streamed from `sptlrx` via Quickshell IPC.
2. **Audio Visualizer**: Live multi-bar audio wave meter powered by PipeWire audio taps (`island/scripts/level-meter.py`).
3. **AI Generation Pulse**: Glowing violet pulse while local AI image models generate in the background.
4. **Lens OCR Actions**: Instant clickable badge offering one-tap Kokoro TTS speech synthesis of newly captured text.
5. **Battery Alerts**: Low battery warnings and charging status via `LowBatteryMonitor.qml`.

### C. Island Panels (`island/panels/`)
- **`AiPromptPanel.qml` (`Super+G`)**: Floating prompt bar for generating 512×512 images using the on-device AI Image Engine.
- **`MediaPanel.qml`**: Media controller with album cover art, play/pause/skip, interactive scrub bar, volume, and full synchronized lyrics view.
- **`CapturePanel.qml`**: Screenshot (Screen, Window, Region) and screen recording (with audio toggle) triggers.
- **`ShelfPanel.qml`**: Persistent drag-and-drop pocket for temporarily holding files, images, and code snippets across workspaces.
- **`ClipboardPanel.qml`**: Searchable clipboard history backed by `cliphist` with one-click paste.
- **`LauncherPanel.qml`**: Rapid application launcher with desktop entry search and category filters.
- **`TodoPanel.qml`**: Interactive task manager with completion status, timestamps, and JSON persistence (`island/todos.json`).
- **`QuickNotesPanel.qml`**: Markdown scratchpad with live preview and persistent storage (`island/NotesState.qml`).
- **`ThemePanel.qml`**: Real-time theme picker (Cherry, Gruvbox, Nord, Catppuccin, Cyberpunk, etc.).
- **`WallpaperPanel.qml`**: Video and static wallpaper browser with live desktop preview.
- **`TimerPanel.qml`**: Pomodoro, countdown timers, and stopwatches.
- **`WeatherPanel.qml`**: Current temperature, weather conditions, humidity, and forecast telemetry.
- **`PowerPanel.qml`**: Quick actions for lock, logout, suspend, reboot, and power off.

---

## 3. Left Sidebar: Control Center (`panels/LeftSidebar.qml` & `components/ControlCenter.qml`)

A floating smoked glass drawer accessible by bumping the left screen edge or via bottom-left trigger.

### Section Breakdown
1. **Section 1: Greeting & Header**: Live system clock, formatted date, and Settings gear icon.
2. **Section 2: Quick Control Tiles**:
   - **Wallpaper Engine**: Toggle dynamic MP4 video wallpapers or static backdrops.
   - **Ambient HUD**: Cycles between Dynamic, Always-On, and Disabled HUD overlays.
   - **Do Not Disturb (DND)**: Silences desktop notifications and audio chimes.
   - **Night Light**: Toggles Hyprsunset blue light filter (Warm 4200K / Standard 6500K).
3. **Section 2B: Performance Mode (Bloat Killer)**:
   - High-performance gaming switch backed by `island/scripts/game-mode.py`.
   - Freezes/kills heavy background tasks, optimizes Hyprland rendering, and shows the count of pruned processes.
4. **Section 2C: The Feather (Absolute Battery Mode)**:
   - Aggressive power-saving mode backed by `island/scripts/feather-mode.py`.
   - Strips non-essential daemons, disables blur/animations, and keeps Hyprland at bare-minimum CPU/battery draw.
5. **Section 2D: AI Image Engine Controller**:
   - Preloads or stops the local Stable Diffusion daemon (`scripts/image-engine.sh`).
   - Displays real-time status: `"WARM"` in RAM or `"Unloaded • 0 MB RAM"`.
6. **Section 2E: God's Eye (3D OSINT Intelligence Globe)**:
   - Starts the real-time Cesium 3D geospatial intelligence globe on `http://localhost:4173`.
   - **Smart Browser Routing**: Automatically routes to an active Brave browser session (new tab) and focuses the window via Hyprland IPC. If no browser is running, starts a new session.
   - Clean shutdown upon toggle off, freeing all server resources.
7. **Section 3: Sound & Volume Card**:
   - PipeWire native volume slider and mute toggle.
   - Live Lyrics toggle (activates/deactivates `sptlrx` daemon).
   - Audio Waveform Meter toggle.
8. **Section 4: Display & Workspace Telemetry**:
   - Active workspace number, open surface/window count.
   - Connected display model, native resolution, and refresh rate.
9. **Section 5: Action Shortcuts**:
   - Direct triggers for Region Screenshot, Screen Recording, and Shell Settings.

---

## 4. Right Sidebar: VALENCE Command Deck (`panels/RightSidebar.qml`)

Cyber-minimalist system monitoring deck accessible from the right screen edge.

### Telemetry Modules
- **Hardware Gauges**: Live CPU usage %, GPU utilization %, VRAM allocation, RAM usage, and disk space.
- **Temperature Sensors**: Real-time CPU and GPU thermals with safety thresholds.
- **Network Deck**: Current Wi-Fi SSID, signal strength, upload/download bandwidth gauges.
- **Bluetooth Hub**: Connected Bluetooth devices, battery percentages, and pairing controls.
- **Audio Routing**: Interactive source/sink device switcher and PipeWire stream mixer.
- **Calendar & Notifications**: Persistent notification history and monthly calendar matrix.

---

## 5. Navigation & Spatial Workspace Map

- **BirdsEye Overview (`components/BirdsEyeOverview.qml` — `Super+R`)**:
  - Interactive spatial workspace switcher showing live window placements across all virtual monitors.
- **Bottom Bar Dock (`panels/BottomBar.qml`)**:
  - Minimal floating Wayland dock with pinned app launchers, running tasks, and workspace dots.
- **Stash Pocket (`components/StashPocket.qml`)**:
  - Quick slide-out drawer for dropping and organizing temporary files.

---

## 6. Micro-Daemons & Engine Subsystems

### A. Universal Screen Lens (`scripts/screen-lens.sh` & `scripts/screen-lens.py`)
- **Keybinding**: `Super+Shift+S`
- **Region Capture**: Interactive `slurp` rectangle styled in semi-transparent dark with emerald accent.
- **Color Extraction**: Micro-selections (≤ 16×16 px) immediately compute average hex color code, copy to clipboard, and show an Island toast.
- **Instant QR / Barcode Scanner**: Scans QR codes and barcodes in ~10ms via native C `zbarimg` and copies the decoded text/URL.
- **Zero-Compilation C++ Tesseract OCR**:
  - Single-threaded C++ engine runs in ~250ms with <1% CPU footprint.
  - Automatically copies captured text to the Wayland clipboard (`wl-copy`).
  - Sends a notification to Dynamic Island with a one-click **Read Aloud** button.

### B. Kokoro Realtime TTS Voice Engine (`scripts/voice-engine.sh` & `scripts/voice-engine.py`)
- **Engine**: `kokoro-onnx` utilizing ONNX Runtime (CPU / CUDA).
- **Streaming Pipeline**: Splits long text into clauses and sentences, streaming audio buffers directly into `pw-play` for sub-second first-audio latency.
- **Media Ducking**: Automatically ducks Spotify/media volume while speaking and restores volume upon completion.
- **Instant Cancel**: Cleanly stops playback on user dismissal via IPC (`qs -c cool-shell ipc call island stopVoice`).

### C. Local AI Image Studio Daemon (`scripts/image-engine.sh` & `scripts/image-daemon.py`)
- **Keybinding**: `Super+G`
- **Model**: Realistic Vision v5.1 + LCM-LoRA (Latent Consistency Model).
- **Native 512×512 Resolution**: Fast inference (4–8 steps) matching the exact training resolution.
- **Zero-Idle VRAM Architecture**:
  - Pipeline remains resident in CPU system RAM when warm (0 MB VRAM).
  - Transferred to CUDA GPU only during generation, and immediately offloaded back to CPU RAM.
- **Auto-Shutdown Timer**: Automatically exits and releases 100% of RAM after 3 minutes of inactivity.
- **Prompt Distillation**: Automatically strips conversational filler, parses negative cues, prevents text/watermarks, and caps prompt strictly within CLIP's 75 tokens.
- **Viewer Integration**: Automatically launches the image in `swappy` for instant viewing and annotation.

### D. God's Eye View 3D Globe (`scripts/gods-eye.sh`)
- **Location**: `$HOME/Desktop/gods-eye-view`
- **Port**: `http://localhost:4173`
- **Features**:
  - Keyless Esri World Imagery 3D globe with global elevation.
  - Live ADS-B aircraft tracking with 3D models and chase camera view.
  - Real-time satellite orbits and ground footprint telemetry.
  - Seismic earthquake monitoring and hurricane weather layers.
  - Tactical military HUD, FLIR thermal, and NVG night-vision shaders.
- **Browser Lifecycle**: Managed entirely through the Left Sidebar toggle with auto-focus under Hyprland.

---

## 7. Dynamic Theming Engine (`island/scripts/theme-system.sh`)

- **Material You / Matugen**: Automatically samples colors from the active desktop wallpaper or image and generates harmonic palettes.
- **Theme Presets**: Cherry (Default), Gruvbox, Nord, Tokyo Night, Catppuccin Mocha, Cyberpunk.
- **Live Broadcast**: Updates all QML surfaces, Wayland borders, and terminal color schemes dynamically without restarting the shell.

---

## 8. Quickshell IPC Endpoints Reference (`shell.qml`)

You can query or trigger any shell action from bash scripts, keybindings, or daemons using `qs -c cool-shell ipc call <target> <function> [args...]`:

| Target | Function / Property | Parameters | Description |
|---|---|---|---|
| `island` | `showTransient` | `text: string, ms: int` | Displays a temporary toast notification in Dynamic Island |
| `island` | `showLensAction` | `snippet: string, words: int` | Displays OCR text result with "Read Aloud" action |
| `island` | `triggerReadAloud` | *none* | Triggers Kokoro TTS synthesis of last OCR text |
| `island` | `stopVoice` | *none* | Immediately cancels active voice synthesis |
| `island` | `setAiGenerating` | `generating: bool, msg: string` | Toggles the Island AI generation glowing pulse |
| `island` | `toggleLyrics` | *none* | Toggles synchronized lyrics streaming in the Island |
| `island` | `toggleVisualizer` | *none* | Toggles live PipeWire audio wave meter in the Island |
| `island` | `mediaPlayPause` | *none* | Toggles play/pause on the active media player |
| `island` | `mediaNext` / `mediaPrevious` | *none* | Skips to next or previous media track |
| `control` | `setLeftSidebarOpen` | `val: bool` | Opens or closes the Left Sidebar Control Center |
| `control` | `toggleWallpaper` | *none* | Toggles between animated video and static wallpaper |
| `control` | `toggleAmbient` | *none* | Cycles ambient HUD display modes |
| `action` | `focusSurface` | `address: string` | Focuses the specified Wayland window address |
| `action` | `moveSurfaceToWorkspace` | `address: string, id: int` | Moves window to specified workspace |
| `action` | `toggleFloating` | `address: string` | Toggles floating mode on active window |
| `overview` | `toggle` | *none* | Toggles BirdsEye workspace spatial overview |
| `notch` | `toggle` | `panel: string` | Toggles specific Island panel (`media`, `ai`, `timer`, etc.) |
| `notch` | `close` | *none* | Closes any expanded Island panel back to collapsed |
| `theme` | `reload` | *none* | Reloads dynamic theme colors from disk |

---

## 9. Global Keybindings Cheatsheet

| Shortcut | Action | Subsystem |
|---|---|---|
| `Super + Shift + S` | Universal Screen Lens (OCR, QR, Color Picker) | `scripts/screen-lens.sh` |
| `Super + G` | AI Image Generation Prompt Bar | Dynamic Island (`AiPromptPanel.qml`) |
| `Super + R` | BirdsEye Spatial Workspace Overview | `components/BirdsEyeOverview.qml` |
| `Left Edge Bump` | Open Left Sidebar (Control Center & Modes) | `panels/LeftSidebar.qml` |
| `Right Edge Bump` | Open Right Sidebar (VALENCE Command Deck) | `panels/RightSidebar.qml` |
| `Bottom-Left Click` | Open Control Center Drawer | `components/EdgeTrigger.qml` |

---

## 10. Study Mode & Focus Lock Subsystem

| Feature | Details | Architecture & Path |
|---|---|---|
| **Activation Ceremony** | 2-Warning prompt sequence + Cryptographic password check (`Studyudsob`) | `components/ControlCenter.qml` |
| **Password Storage** | Salted SHA-256 hash with `0600` permissions (zero plaintext in repo) | `~/.local/share/cool-shell/study/auth.hash` |
| **Hard Anti-Cheat Lockout** | Un-skippable timer block surviving reboots; early exit strictly blocked | `scripts/study-mode.py` (`cmd_stop`) |
| **Whitelisted Applications** | Dolphin, Brave, PDF/Image readers (Okular, Evince, Zathura, Loupe, Gwenview, Imv, Swappy), Kate/KWrite, terminal, MPV | `scripts/study-mode.py` (`ALLOWED_CLASSES`) |
| **Brave Tab Whitelist** | ICAI BoS Live, Google NotebookLM, WhatsApp Web, and local browser pages | Hyprland IPC keystroke injection (`sendshortcut CTRL,W`) |
| **Lo-Fi Study Audio** | Auto-pauses Spotify; plays local lo-fi MP3s from `~/Music/study/` via `mpv` | `scripts/study-mode.py` (`start_lofi_player`) |
| **Dynamic Island Focus Pill** | Dynamic Island morphs into a focused pill (`󰑴 CA / ICAI Study 00:10`) | `island/Notch.qml` (`studyPillRow`) |
| **Ambient Reward Heatmap** | GitHub-style 7-row contribution grid (Mon–Sun) starting today with green shading | `desktop/StudyContributionHeatmap.qml` |
| **Overtime Flow State** | Timer counts up after milestone with penalty-free exit; credits sessions every 30m | `scripts/study-mode.py` (`run_daemon`) |
| **CLI Management** | Direct terminal control: `scripts/study-mode.sh {start\|stop\|status\|history\|verify}` | `scripts/study-mode.sh` |

