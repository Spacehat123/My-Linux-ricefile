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

At the apex of the screen sits the **Dynamic Island** ([`island/Notch.qml`](file://$HOME/.config/quickshell/cool-shell/island/Notch.qml)), a tactile, hardware-accelerated floating pill powered by spring physics (`SpringAnimation`, damping=0.3) and elastic morphing.

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

An uncompromising deep-work and discipline enforcement system designed for exam prep (CA / ICAI) and intensive study blocks ([`scripts/study-mode.py`](file://$HOME/.config/quickshell/cool-shell/scripts/study-mode.py)).

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
- **Desktop Contribution Heatmap**: Renders an interactive 52-week activity grid on the desktop wallpaper layer ([`desktop/StudyContributionHeatmap.qml`](file://$HOME/.config/quickshell/cool-shell/desktop/StudyContributionHeatmap.qml)), tracking sessions, consistency streaks, and deep-work volume.

---

## 🪶 Feather Mode & Hardware Resource Throttling

A precision power-capping profile engineered for maximum battery longevity, silent fan operation, and thermal management ([`island/scripts/feather-mode.py`](file://$HOME/.config/quickshell/cool-shell/island/scripts/feather-mode.py)).

### Architecture & Throttling Limits
- **Hardware-Level CPU & GPU Capping**: Enforces strict operational ceilings via Linux kernel cpufreq governor, energy-performance preferences (`power`), and GPU frequency limiters:
  - **20% Limit (`Feather 20%`)**: Absolute power minimization. Caps CPU clock ceiling to baseline, limits GPU compute, ideal for reading, note-taking, and battery emergency.
  - **35% Limit (`Feather 35%`)**: Balanced whisper-quiet profile. Ample headroom for smooth 60fps desktop rendering while cutting package power draw by over 60%.
- **Tactile Island & Control Center HUD**: Interactive pills (`20%` / `35%`) inside the Control Center allow instant 1-tap switching without root password prompts.
- **Process Freeze & Scheduler Renicing**: Automatically freezes intensive background indexers and sets desktop interactive tasks to higher priority (`nice -n -5`), maintaining snappy UI response even under aggressive power caps.

---

## 🔋 Hardware Battery Health Care Mode (Acer EC 80%)

A direct hardware-level battery preservation system tailored for Acer laptops and Embedded Controller (EC) architectures ([`scripts/battery-limit.sh`](file://$HOME/.config/quickshell/cool-shell/scripts/battery-limit.sh)).

### Electrical & Hardware Operation
- **Acer EC Register Control**: Directly interacts with the Embedded Controller firmware (`ec_sys` / `/dev/port`) to activate native Acer Battery Care Mode (`0x01`).
- **Physical 80% Cutoff**: The hardware EC microcontroller physically disconnects battery charging circuitry at 80% capacity, switching the laptop directly to wall AC bypass power.
- **Settling Behavior**: If enabled while battery charge is above 80% (e.g. 85%), charging halts instantly. The system draws exclusively from the battery until 80% is reached, then locks indefinitely at 80% on AC power.
- **Chemistry Protection**: Prevents high-voltage anode degradation and thermal saturation caused by prolonged 100% float charging (4.2V/cell).
- **Hardened Safety Guardrails**:
  - Validates EC register address boundaries before every read/write.
  - Implements Polkit privilege delegation with zero desktop hang.
  - Interactive toggle located in the Settings Window under **System Modes**.

---

## 👁️ Screen Lens OCR & AI Multimodal Studio

Integrated local perception and machine intelligence surfaces accessible right from the desktop and Dynamic Island.

### 🔍 Screen Lens (OCR & Read-Aloud)
- **Regional Capture**: Shortcut activates a tactile crosshair selector (`slurp` + `grim`) to drag a frame over any text, code, or document on screen.
- **Local OCR Extraction**: Uses `tesseract` to parse textual content directly into the clipboard within milliseconds.
- **Dynamic Island Read-Aloud**: Immediately morphs the Notch into an audio reader HUD (`🔊 Reading aloud...`), streaming localized speech synthesis (`speech-dispatcher` / `piper-tts`) with 1-click stop.

### 🎨 AI Image Studio (Local LCM Generation)
- **Dedicated Prompt Modal**: Press shortcut or click the AI icon on the notch to expand the **AI Prompt Panel** ([`island/panels/AiPromptPanel.qml`](file://$HOME/.config/quickshell/cool-shell/island/panels/AiPromptPanel.qml)).
- **Sub-Second Daemon Preload**: Daemon keeps model weights hot in VRAM (`image-daemon.py`) for rapid generation without load penalty.
- **Realistic Vision v5.1 + LCM**: Generates native 512×512 photo-realistic outputs locally on NVIDIA GPU in ~3 seconds.
- **Instant Shelf Stash**: Completed renders fly into the Dynamic Island with transient preview and auto-stash into Drop Pocket.

---

## 🎛️ Tactical Desktop Surfaces & Spatial Navigation

Beyond the Dynamic Island, `cool-shell` provides a complete multi-layered cyber-tactical desktop cockpit:

### 1. Slide-Out Sidebars
- **Left Sidebar ([`panels/LeftSidebar.qml`](file://$HOME/.config/quickshell/cool-shell/panels/LeftSidebar.qml))**: Hosts the full Control Center, system mode switches (Feather Mode, Study Mode, Battery Care, Game Mode), audio sink selectors, and performance graphs.
- **Right Sidebar ([`panels/RightSidebar.qml`](file://$HOME/.config/quickshell/cool-shell/panels/RightSidebar.qml))**: Application Overview with searchable running surfaces, window thumbnail previews, and window management controls.

### 2. Workspace Navigator & Directional HUD
- **Bottom Bar ([`panels/BottomBar.qml`](file://$HOME/.config/quickshell/cool-shell/panels/BottomBar.qml))**: Floating workspace pills with occupancy pips, urgency alerts, and active window counters.
- **Spatial Transition Overlay ([`desktop/DesktopTransition.qml`](file://$HOME/.config/quickshell/cool-shell/desktop/DesktopTransition.qml))**: Ephemeral HUD overlay indicating workspace switch direction (`← / →`) with spring physics.

### 3. Idle-Triggered Ambient Layer
- Activates automatically upon user inactivity via `ext_idle_notification_v1` ([`desktop/AmbientLayer.qml`](file://$HOME/.config/quickshell/cool-shell/desktop/AmbientLayer.qml)).
- Features linear orbital telemetry rings, tactical corner brackets, and floating battery/workspace coordinates.

### 4. GPU Procedural Shader Wallpaper
- Live harmonic interference fragment shader ([`wallpaper/shaders/wallpaper.frag`](file://$HOME/.config/quickshell/cool-shell/wallpaper/shaders/wallpaper.frag)) compiled via Qt 6 Shader Baker (`qsb`).
- Renders directly on `WlrLayer.Background` with zero CPU overhead.

---

## 🚀 Installation & Setup

### Automated Modular Installers
Run the interactive master installer menu:

```bash
./install.sh
```

Or run modular numbered installers directly:
- `installers/01-quickshell.sh` — Builds/installs Quickshell with Hyprland & PipeWire support.
- `installers/02-hyprland.sh` — Hyprland dependencies, Wayland tools, and portal backends.
- `installers/03-audio.sh` — Pipewire, Wireplumber, playerctl, and SPTLRX lyrics daemon.
- `installers/04-phone.sh` — Scrcpy, Android tools, ADB, and bridge requirements.
- `installers/05-caption.sh` — NVIDIA FastConformer-CTC ONNX model, sherpa-onnx, and ffmpeg.
- `installers/06-ai.sh` — Latent Consistency Models and diffusers runtime.

### Launching
Run `cool-shell` via Quickshell:

```bash
quickshell -c cool-shell
```

---

## 📡 Quickshell IPC Protocol

`cool-shell` exposes native IPC endpoints for automation, scripts, and keybindings:

```bash
# Query Dynamic Island state summary
qs -c cool-shell ipc call island getSummary

# Trigger media captioning modal on a video
qs -c cool-shell ipc call island captionMedia "/path/to/video.mp4"

# Add a file directly to Drop Pocket
qs -c cool-shell ipc call island shelfAdd "/path/to/document.pdf"

# Show custom transient notification with glow
qs -c cool-shell ipc call island showTransient "🚀 Mission Accomplished" 3500

# Toggle active system modes
python3 scripts/study-mode.py start --duration 1800
python3 island/scripts/feather-mode.py toggle 35
```








