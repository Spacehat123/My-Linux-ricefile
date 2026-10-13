# cool-shell

> **A high-performance, cyber-tactical desktop environment and unified operating cockpit built natively for Hyprland on Wayland using Quickshell 0.3.1 and Qt 6.**

`cool-shell` unifies tactile hardware control, intelligent system modes, local machine intelligence, and mobile device bridging into a single, cohesive Wayland desktop surface with zero latency, spring physics, and hardware telemetry.

---

## 🏛️ System Architecture

`cool-shell` enforces a strict **unidirectional reactive architecture** that separates compositor observation from compositor mutation, preventing race conditions and stale UI states:

```
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
│   Shell Surfaces: Notch, Sidebars, BottomBar, Ambient, Transitions     │
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
├── island/                       # Dynamic Island notch, state machines, and modal panels
│   ├── Notch.qml                 # Floating tactile notch with spring physics
│   ├── IslandHub.qml             # Central priority arbitration and transient notifications
│   ├── ShellState.qml            # Panel geometry, dimensions, and active monitor routing
│   └── panels/                   # Interactive drop-down island panels
├── components/                   # Left and Right sidebar tactical HUD components
├── panels/                       # Slide-out sidebar containers and Settings window
├── desktop/                      # Ambient idle layer, telemetry reticles, and contribution heatmap
├── wallpaper/                    # Procedural GLSL harmonic interference GPU wallpaper
└── scripts/                      # Autonomous daemons, hardware controls, and intelligence tools
```

---

## 🏝️ Apple-Style Dynamic Island (The Notch)

At the apex of the screen sits the **Dynamic Island** ([`island/Notch.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml)), a tactile, hardware-accelerated floating pill powered by spring physics (`SpringAnimation`, damping=0.3) and elastic morphing.

### Collapsed Ambient Pill
When idle, the notch remains a compact, unobtrusive capsule displaying real-time situational awareness:
- **🎵 Synced Live Lyrics**: Integrates with `sptlrx` daemon to stream synchronized karaoke lyrics directly across the pill surface.
- **📊 4-Bar Audio Visualizer**: Real-time FFT audio levels (`level-meter.py`) pulse to music playback.
- **⚡ Battery & Charging**: Glows primary accent with charging wattage and percentage when plugged in.
- **🔴 Screen Recording**: Displays active recording duration with pulsing red safety beacon.
- **📬 Unread Counter**: Discreet notification badge indicating unseen system events.

### Modal Panel Ecosystem
Clicking or triggering shortcuts on the notch smoothly morphs it into 16 full-featured tactile tools:

| Panel | Identifier | Description |
| :--- | :--- | :--- |
| **Control Center** | `control` | Quick toggles (Night Light, DND, Bluetooth, Mic, Cam), brightness/volume sliders, power profiles. |
| **App Launcher** | `launcher` | Fast keyboard-driven fuzzy desktop application launcher. |
| **Clipboard** | `clipboard` | Persistent history of copied text and media with 1-tap copy/delete. |
| **Drop Pocket** | `shelf` | Drag-and-drop workspace shelf storing file references for later retrieval. |
| **Quick Notes** | `notes` | Persistent scratchpad with instant autosave and markdown formatting. |
| **Todo List** | `todo` | Interactive checklist with priority markers and completion tracking. |
| **Theme & Accents**| `theme` | Real-time accent palette switcher and semantic color tuning. |
| **Wallpaper** | `wallpaper` | Live procedural GPU shader and desktop wallpaper selector. |
| **Media Player** | `media` | Extended MPRIS player with track scrubber, volume wheel, and full lyrics display. |
| **Notifications** | `notifications` | Notification history center with dismiss-all and actionable cards. |
| **Timer / Stopwatch**| `timer` | Pomodoro focus intervals, multi-duration countdowns, and precision stopwatch. |
| **Weather HUD** | `weather` | Real-time localized weather reports, temperature, and forecasts via `wttr.in`. |
| **Game Mode** | `gamemode` | High-priority compositor mode disabling animations and background noise. |
| **AI Studio** | `ai` | Text-to-image prompt interface powered by local Realistic Vision / LCM. |
| **Phone Hub** | `phone` | Android device mirroring, wireless ADB status, and mobile controls. |
| **Media Caption** | `caption` | Frictionless drag-and-drop subtitle generator prompt. |

---

## ⚡ Zero-Terminal Drag-and-Drop Captioning Engine

A frictionless subtitle generator and extractor powered by **NVIDIA FastConformer-CTC (NeMo 244M)** via `sherpa-onnx` and `ffmpeg`.

```
Drag Video/Audio onto Island ──► Intercepted by Notch ──► Tactile Island Choices:
                                                             ├─► 🎬 Embed in Video (Lossless soft-subs + archive)
                                                             ├─► 📝 Caption File Only (.srt + archive)
                                                             └─► 󰏫 Stash in Pocket (Regular shelf)
```

### Features & Capabilities
- **Direct Notch Drop**: Drag any media file (`.mp4`, `.mkv`, `.webm`, `.mov`, `.avi`, `.mp3`, `.wav`, `.m4a`, `.flac`) directly onto the collapsed Dynamic Island notch.
- **Zero Terminal Overhead**: Everything executes asynchronously in the background via Quickshell native `Process`. No terminal window ever opens.
- **Ultra-Fast Local GPU Inference**: Transcribes speech at **~40× real-time** on GPU (transcribes a 1-hour recording in under 90 seconds).
- **Instant Extraction Bypass**: If a dropped video file already possesses an embedded subtitle track, it rips the stream to `.srt` instantly in **~0.06 seconds**, bypassing GPU transcription.
- **Dual-Destination Output Architecture**:
  1. `<media_dir>/<name>.srt` (Editable caption file alongside the original media).
  2. `~/Music/caption_extracts/<name>.srt` (Centralized knowledge archive).
  3. `<media_dir>/<name>_subtitled.mp4` (Lossless copy-stream container with toggleable soft subtitle track).
- **Tactile Island Telemetry**: Collapsed pill displays `⚡ Embedding captions...` or `⚡ Transcribing...`, popping a green border flash (`#22c55e`) and confetti burst upon completion.

---

## 📱 macOS Sequoia-Style Android Mirroring & Bridge (`cool-phone`)

Seamless mobile continuity bringing native Android control to the Wayland desktop, inspired by macOS Sequoia's iPhone Mirroring.

### Key Capabilities
- **Wireless ADB Auto-Discovery**: Discovers wireless debugging endpoints over local Wi-Fi using mDNS service browsing (`_adb-tls-pairing._tcp`).
- **1-Click Auto-Pairing Modal**: Interactive GUI dialog automatically triggers when pairing is required, allowing 6-digit pairing code entry without opening a terminal.
- **High-Framerate Low-Latency Stream**: Powered by hardware-accelerated `scrcpy` wrapped in a custom floating Wayland frame (`title: CoolPhone`) conforming to Hyprland layout rules.
- **Dedicated Dynamic Island Phone Hub**:
  - 📱 **Screen Toggle**: Power on/off remote phone screen without waking physical display.
  - 🔊 **Volume Control**: Hardware volume steps sent via ADB keyevents.
  - 🧭 **Navigation Bar**: Quick Home (`KEYCODE_HOME`), Back (`KEYCODE_BACK`), and App Switcher actions.
  - 📸 **Instant Phone Screenshot**: Grabs direct frame buffer capture (`adb exec-out screencap -p`), saves to `~/Pictures/Screenshots/`, and automatically absorbs it into the Dynamic Island Drop Pocket.
- **Zero-Load Architecture**: When the Phone switch is toggled off in the Sidebar or Control Center, all daemons and ADB pollers terminate immediately, guaranteeing 0.0% background CPU consumption.

---

## 🎓 Study Mode Lockdown & Daily Contribution Heatmap

An uncompromising deep-work and discipline enforcement system designed for exam prep (CA / ICAI) and intensive study blocks ([`scripts/study-mode.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/study-mode.py)).

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Study Mode Hard Lockdown                        │
│                                                                        │
│   🔒 Cryptographic Salted Password Verification (Prevents Quit)        │
│   🚫 Hyprland Window & Tab Guardian (Kills YouTube, Reddit, Discord)  │
│   📄 Full Educational Whitelist (ICAI, BOS, NotebookLM, All PDFs)     │
│   📂 All File Explorers & Choosers Permitted (Dolphin, Portals, etc.)  │
│   🎧 Autonomous Background Lo-Fi Music (~/Music/study/)                │
│   📈 Overtime Flow State (Counts UP After Milestone with Zero Penalty) │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│             Desktop GitHub-Style Contribution Heatmap                  │
│                                                                        │
│   🟩 52-Week Deep Work Matrix  │  🔥 Streak Counters  │  🎯 Milestones │
└────────────────────────────────────────────────────────────────────────┘
```

### Key Capabilities
- **Hard Lockdown Architecture**: Once initiated (e.g. 30-minute block), early termination is impossible without cryptographic password verification (`Studyudsob` hashed with unique 16-byte random salt). Survives compositor reloads and system reboots.
- **Autonomous Window Guardian**: Daemon queries Hyprland clients every 300ms. Instantly terminates distracting windows (Steam, Discord, Spotify) and dispatches Lua-based tab closure (`Ctrl+W`) for distracting web domains (YouTube, Reddit, Twitter/X, Instagram, Twitch, Netflix).
- **Educational Whitelist**: Fully permits ICAI Board of Studies resources (`resource.cdn.icai.org`, `bos`), Google NotebookLM, WhatsApp Web, and **all standalone or browser-viewed PDF study materials**.
- **Complete File Manager & Portal Protection**: All Linux file explorers (`dolphin`, `nautilus`, `nemo`, `thunar`, `pcmanfm`, `caja`, `ranger`, `yazi`) and desktop portals (`xdg-desktop-portal-gtk`, `kdialog`, `zenity`) are whitelisted, allowing seamless document downloading and organization.
- **Autonomous Lo-Fi Accompaniment**: Silently mounts and shuffles study tracks from `~/Music/study/` in background `mpv` loop without UI clutter.
- **Desktop Contribution Heatmap**: Renders an interactive 52-week activity grid on the desktop wallpaper layer ([`desktop/StudyContributionHeatmap.qml`](file:///home/pranc/.config/quickshell/cool-shell/desktop/StudyContributionHeatmap.qml)), tracking sessions, consistency streaks, and deep-work volume.




