# Cool-Shell (Pranc Rice) — Features & Capabilities Manual

> **Comprehensive reference manual detailing every major feature, subsystem, daemon, mode, security layer, IPC interface, and workflow in Cool-Shell.**

---

## 1. System Overview & Core Stack

**Cool-Shell** is an ultra-low-latency, modular desktop environment built on:
- **Wayland Compositor**: **Hyprland** (dynamic tiling, fluid animations, custom Lua configuration).
- **Desktop Shell**: **Quickshell** (declarative Qt/QML shell environment running natively on Wayland layershell).
- **Audio Architecture**: **PipeWire** & **WirePlumber** (native stream routing, volume control, and audio level tapping).
- **Local AI & Compute**: **PyTorch / CUDA**, **ONNX Runtime**, **Diffusers**, and **Kokoro TTS**.

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
│                   SECURITY & PRIVACY INFRASTRUCTURE                    │
│   UFW Stealth Wall  │  MAC Randomizer  │  Bitwarden  │  LUKS / Vault   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Dynamic Island Subsystem (`island/`)

Located at the top center of the primary display, morphing between compact ambient indicators and operational workspace cards with spring physics.

### Notch Morphing & Ambient Ticker (`island/Notch.qml`, `island/CollapsedStatus.qml`)
- **Collapsed Notch (145×36px)**: Minimalist status bar displaying clock, battery telemetry, and real-time activity pills:
  - **Live Synchronized Lyrics**: Real-time karaoke lyrics streamed from Spotify/media players via `sptlrx` and IPC.
  - **Audio Waveform Visualizer**: Live multi-bar audio equalizer reacting to master PipeWire output (`level-meter.py`).
  - **AI Generation Pulse**: Glowing violet pulse indicating background image generation activity.
  - **Screen Lens Action Pill**: One-click toast to synthesize captured OCR text with Kokoro TTS.
  - **Battery & Power Alerts**: Adaptive charging and low-power notifications.

### Interactive Island Panels (`island/panels/`)
- **AI Prompt Panel (`Super+G`)**: Centered floating input bar to generate 512×512 photorealistic images on-device without switching windows.
- **Media Controller (`MediaPanel.qml`)**: Full album art presentation, interactive track scrub bar, volume, playback buttons, and complete synchronized lyrics scroll.
- **Screen Capture Panel (`CapturePanel.qml`)**: Quick triggers for Region, Window, or Fullscreen captures and video recordings with audio toggle.
- **Stash Pocket / Shelf (`ShelfPanel.qml`)**: Drag-and-drop persistent shelf for holding files, images, and text snippets across virtual workspaces.
- **Clipboard History (`ClipboardPanel.qml`)**: Instant clipboard recall backed by `cliphist` with keyboard search and paste.
- **Application Launcher (`LauncherPanel.qml`)**: Desktop entry search with fuzzy matching and category filters.
- **Todo & Task Tracker (`TodoPanel.qml`)**: Interactive checklist with timestamps, completion stats, and JSON persistence (`todos.json`).
- **Quick Notes (`QuickNotesPanel.qml`)**: Markdown-enabled scratchpad with live preview and persistent storage.
- **Theme Studio (`ThemePanel.qml`)**: Real-time palette switcher (Cherry, Gruvbox, Nord, Catppuccin, Tokyo Night, Cyberpunk).
- **Wallpaper Selector (`WallpaperPanel.qml`)**: Visual browser for animated `.mp4` video loops and static desktop wallpapers.
- **Pomodoro & Timers (`TimerPanel.qml`)**: Countdown timers and stopwatches.
- **Weather Station (`WeatherPanel.qml`)**: Live localized meteorological conditions, temperature, humidity, and forecast.
- **Session & Power Hub (`PowerPanel.qml`)**: One-touch triggers for Lock, Suspend, Reboot, and Power Off.

---

## 3. Left Sidebar: Control Center & Specialized Operating Modes

A floating smoked-glass control center accessible by bumping the left screen edge or clicking the bottom-left trigger.

### Quick Controls
- **Dynamic Wallpaper**: Toggle between live `.mp4` video loops and static wallpapers.
- **Ambient HUD**: Cycle through Dynamic, Always-On, or Disabled workspace HUD overlays.
- **Do Not Disturb (DND)**: Instantly silence notifications and audio chimes.
- **Night Light**: Toggle warm 4200K / standard 6500K color temperature via `hyprsunset`.

### Specialized Operating Modes
1. **Performance Mode (Bloat Killer)**:
   - Activated via `island/scripts/game-mode.py`.
   - Freezes heavy background apps, kills non-essential bloat, minimizes rendering latency, and provides zero-frame-drop gaming performance.
2. **The Feather (Absolute Battery Mode)**:
   - Activated via `island/scripts/feather-mode.py`.
   - Strips non-essential daemons, disables blur and heavy animations, and enforces bare-minimum Hyprland power consumption.
   - Includes **20% and 35% CPU/GPU hardware resource limit pills** to maximize battery life under heavy workloads.
3. **Study Mode (Lockout & Focus Harness)**:
   - Dedicated focus mode designed for deep work (`scripts/study-mode.py`, `scripts/study-mode.sh`).
   - Enforces a **30-minute lockdown duration (1800s)** with a floating password authentication dialog to unlock.
   - Features a window & tab killer with an active whitelist (e.g. Brave research tabs) and GitHub reward heatmap telemetry.
4. **AI Image Studio Controller**:
   - Preloads or unloads the local Stable Diffusion daemon (`scripts/image-engine.sh`).
   - Displays real-time memory state: `"WARM"` in RAM (0 VRAM idle) or `"Unloaded • 0 MB RAM"`.
5. **God's Eye (3D OSINT Intelligence Globe)**:
   - Starts the real-time Cesium 3D geospatial intelligence globe on `http://localhost:4173` (`scripts/gods-eye.sh`).
   - **Smart Browser Session Routing**: Automatically routes to an active Brave browser session (new tab) and focuses the window via Hyprland IPC. If no browser is running, starts a new session.
   - Clean shutdown upon toggle off, freeing all server resources.

### Sound, Workspace & Display Telemetry
- **PipeWire Master Volume**: Slider, mute button, live synchronized lyrics toggle, and live audio waveform toggle.
- **Display & Workspace Telemetry**: Current workspace number, active surface counts, display resolution, and refresh rate.
- **Quick Action Buttons**: Direct shortcuts for Region Screenshot, Screen Recording, and Shell Settings.

---

## 4. Right Sidebar: VALENCE Cyber-Minimalist Command Deck

Hardware monitoring and device control deck accessible from the right screen edge (`panels/RightSidebar.qml`).

- **Hardware Telemetry Gauges**: Real-time CPU usage %, GPU load %, VRAM allocation, RAM usage, and disk space.
- **Temperature Sensors**: Live CPU and GPU thermal gauges with warning thresholds.
- **Network Deck**: Connected Wi-Fi SSID, signal strength, download/upload bandwidth meters.
- **Bluetooth Hub**: Paired devices, battery percentages, and connection controls.
- **Audio Stream Routing**: Interactive PipeWire input/output device selector and stream manager.
- **Calendar & Notifications**: Persistent notification history and monthly calendar matrix.

---

## 5. Navigation & Workspace Spatial Overview

- **BirdsEye Overview (`components/BirdsEyeOverview.qml` — `Super+R`)**:
  - Interactive spatial workspace switcher showing live window placements across all virtual monitors.
- **Bottom Bar Dock (`panels/BottomBar.qml`)**:
  - Minimal floating Wayland dock with pinned app launchers, running tasks, and workspace dots.
- **Stash Pocket (`components/StashPocket.qml`)**:
  - Quick slide-out drawer for dropping and organizing temporary files.

---

## 6. Micro-Daemons & Local AI Subsystems

### A. Universal Screen Lens (`scripts/screen-lens.sh` & `scripts/screen-lens.py`)
- **Keybinding**: `Super+Shift+S`
- **Region Capture**: Interactive `slurp` rectangle with emerald accent.
- **Micro-Color Extraction**: Selections ≤ 16×16 px calculate average hex color code and copy directly to clipboard.
- **Instant QR / Barcode Scanner**: Decodes QR codes and barcodes in ~10ms via native C `zbarimg`.
- **High-Speed C++ Tesseract OCR**: Single-threaded C++ engine runs in ~250ms with <1% CPU footprint, automatically copies text to clipboard, and triggers an Island toast with a one-click **Read Aloud** button.

### B. Kokoro Realtime TTS Voice Engine (`scripts/voice-engine.sh` & `scripts/voice-engine.py`)
- **Streaming Synthesis**: Clause-streaming sub-second text-to-speech using `kokoro-onnx` and ONNX Runtime.
- **Audio Output**: Streams directly into `pw-play` with media ducking (lowering music volume while speaking).
- **Instant Cancel**: Cleanly stops playback via IPC (`qs -c cool-shell ipc call island stopVoice`).

### C. Local AI Image Studio Engine (`scripts/image-engine.sh` & `scripts/image-daemon.py`)
- **Keybinding**: `Super+G`
- **Model Architecture**: Realistic Vision v5.1 + LCM-LoRA text-to-image pipeline.
- **Native 512×512 Resolution**: Fast 4–8 step inference matching the model's native resolution.
- **Zero-Idle VRAM**: Resides in CPU RAM when idle (0 MB VRAM), transfers to GPU only during generation, and offloads immediately.
- **3-Minute Auto-Shutdown**: Automatically exits and releases 100% of RAM after 3 minutes of inactivity.
- **Prompt Distillation**: Strips conversational fluff, extracts negative cues, and caps prompt strictly within CLIP's 75 tokens.
- **Viewer Integration**: Automatically launches generated images in `swappy` for instant inspection.

### D. God's Eye View 3D Globe (`scripts/gods-eye.sh`)
- Real-time 3D geospatial intelligence globe running from `~/Desktop/gods-eye-view`.
- Features keyless satellite imagery, terrain elevation, live aircraft ADS-B transponders, active satellite orbits, earthquakes, wildfires, and tactical military HUD/FLIR shaders.

---

## 7. Security, Privacy & Credential Management Layer

- **Bitwarden Password Manager (`extra/bitwarden`)**:
  - Secure, open-source password manager desktop client and CLI (`bitwarden-cli`).
  - Generates and stores 20+ character unique passwords and TOTP two-factor authentication codes.
- **Stealth Inbound Firewall (`ufw`)**:
  - `Default Incoming: DENY`, `Default Outgoing: ALLOW`.
  - Drops all unsolicited inbound connection attempts, port scans, and pings without responding.
- **Wi-Fi Hardware Identity Masking (MAC Randomization)**:
  - NetworkManager automatically presents randomized hardware addresses on every connection and scan.
- **Encrypted DNS Lookups**:
  - Secure DNS over HTTPS (Quad9 / Cloudflare) to prevent domain snooping by local networks and ISPs.
- **SSH Key Protection**:
  - Ed25519 private key protected with a strong passphrase and strict `0600` permissions.
- **Physical Auto-Lock**:
  - `hypridle` locks the screen with `hyprlock` after 2 minutes of idle and shuts off displays after 60 seconds.

---

## 8. Quickshell IPC API Reference (`shell.qml`)

Trigger or query any shell action from scripts or terminal using `qs -c cool-shell ipc call <target> <function> [args...]`:

| Target | Function / Property | Parameters | Description |
|---|---|---|---|
| `island` | `showTransient` | `text: string, ms: int` | Display temporary toast in Dynamic Island |
| `island` | `showLensAction` | `snippet: string, words: int` | Display OCR text with "Read Aloud" action |
| `island` | `triggerReadAloud` | *none* | Synthesize and speak last captured OCR text |
| `island` | `stopVoice` | *none* | Immediately stop voice synthesis |
| `island` | `setAiGenerating` | `generating: bool, msg: string` | Toggle Island AI glowing pulse |
| `island` | `toggleLyrics` | *none* | Toggle synchronized lyrics display |
| `island` | `toggleVisualizer` | *none* | Toggle live audio visualizer meter |
| `control` | `setLeftSidebarOpen` | `val: bool` | Open or close Left Sidebar Control Center |
| `control` | `toggleWallpaper` | *none* | Toggle between video and static wallpaper |
| `control` | `toggleAmbient` | *none* | Cycle ambient HUD overlay modes |
| `overview` | `toggle` | *none* | Toggle BirdsEye spatial workspace switcher |
| `notch` | `toggle` | `panel: string` | Toggle specific Island panel |
| `notch` | `close` | *none* | Collapse Island back to default pill |
| `theme` | `reload` | *none* | Reload dynamic theme colors from disk |
| `phone` | `status` | *none* | Returns JSON with connection, battery, charging, and mirror state |
| `phone` | `toggleMirror` | *none* | Toggle CoolPhone scrcpy screen mirroring |
| `phone` | `openPanel` | *none* | Open PhonePanel in Dynamic Island |
| `phone` | `setBattery` | `battery, charging, connected` | Authoritative battery telemetry synchronization |

---

## 9. Global Keybindings Cheatsheet

| Shortcut | Action | Subsystem |
|---|---|---|
| `Super + Shift + S` | Universal Screen Lens (OCR, QR, Color Picker) | `scripts/screen-lens.sh` |
| `Super + Alt + P` | CoolPhone Android Screen Mirror Toggle | `scripts/phone-ctl.sh toggle` |
| `Super + G` | AI Image Prompt Bar | Dynamic Island (`AiPromptPanel.qml`) |
| `Super + R` | BirdsEye Spatial Workspace Overview | `components/BirdsEyeOverview.qml` |
| `Left Edge Bump` | Open Left Sidebar (Control Center & Modes) | `panels/LeftSidebar.qml` |
| `Right Edge Bump` | Open Right Sidebar (VALENCE Command Deck) | `panels/RightSidebar.qml` |
| `Bottom-Left Click` | Open Control Center Drawer | `components/EdgeTrigger.qml` |

---

## 10. CoolPhone: macOS Sequoia-Style Android Screen Mirroring & Filtered File Bridge

Seamless Android integration modeled after Apple's macOS Sequoia iPhone Mirroring:
- **Floating Hardware Frame**: Borderless, 26px rounded floating frame (`380x824`) with `keepaspectratio = true` in Hyprland.
- **Physical USB HID Input Emulation**: Uses `--keyboard=uhid` and `--mouse=uhid` so PC mouse and keyboard control the phone seamlessly without triggering on-screen touch keyboards.
- **Strict MIME Type Filtered Bridge**: Dragging files onto the mirror window executes an ADB interceptor (`scrcpy-adb-filter.sh`) that inspects MIME types (`file -b --mime-type`) against a strict whitelist (Images, Audio, Video, PDF/Office Docs, APKs), rejecting executable scripts/binaries and alerting through the Dynamic Island.
- **Two-Way Reverse File Ingestion**: Drop files on your phone into `/sdcard/SendToPC/` and the background bridge daemon pulls them into `~/Downloads/Phone/`, adds them directly to the Cool-Shell Stash Shelf, and fires an Island toast.
- **Dynamic Island & Control Center Integration**: Shows real-time phone connection pill (`📱 [85% ⚡]`), interactive `PhonePanel.qml`, and quick tile in Control Center.
- **Connection Flexibility**: Connect via standard USB-C cable or pair wirelessly across local Wi-Fi with `./scripts/phone-ctl.sh pair <phone-ip>`.

