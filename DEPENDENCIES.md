# Cool-Shell Dependency Specification & Architecture Manifest

> **Authoritative, production-grade reference for all system packages, Qt 6 runtimes, Quickshell C++ plugins, CLI tools, system daemons, Python machine learning libraries, and typography required to run `cool-shell`.**

`cool-shell` is an advanced, high-performance cyber-tactical desktop cockpit and dynamic shell built for **Hyprland** on **Wayland** using **Quickshell 0.3.x** and **Qt 6**. This document provides an exhaustive inventory of all prerequisites, their architectural roles, and copy-paste installation commands for Arch Linux and AUR package managers.

---

## Table of Contents
1. [Core Architecture Prerequisites](#1-core-architecture-prerequisites)
   - [Operating System & Compositor](#operating-system--compositor)
   - [Qt 6 Runtime & Essential QML Modules](#qt-6-runtime--essential-qml-modules)
   - [Quickshell Framework & C++ Engine Plugins](#quickshell-framework--c-engine-plugins)
2. [CLI Tools & System Daemons Matrix](#2-cli-tools--system-daemons-matrix)
3. [Python Machine Learning & AI Runtime (`requirements.txt`)](#3-python-machine-learning--ai-runtime-requirementstxt)
4. [Typography & Iconography](#4-typography--iconography)
5. [One-Line Installation Commands](#5-one-line-installation-commands)
   - [Official Repositories (Pacman)](#option-a-official-arch-repositories-pacman)
   - [AUR Packages (Paru / Yay)](#option-b-aur-packages-paru--yay)
   - [Unified All-In-One Command](#option-c-unified-all-in-one-command)
   - [Python AI Virtual Environment Setup](#option-d-python-ai-virtual-environment-setup)
6. [System Verification & Self-Test](#6-system-verification--self-test)

---

## 1. Core Architecture Prerequisites

### Operating System & Compositor
- **Platform**: Arch Linux (or Arch derivatives: EndeavourOS, CachyOS, Manjaro).
- **Display Server**: Wayland.
- **Compositor**: `hyprland` (version `>= 0.40.0`, verified with `0.45.0+`).
  - Required for Hyprland IPC sockets (`HYPRLAND_INSTANCE_SIGNATURE`), client management, workspace navigation dispatchers, and monitor management.
- **Screen Locker**: `hyprlock` (default lock surface invoked upon idle timeout or Super+L). Optional alternative: `veila-git`.
- **Night Light**: `hyprsunset` (official `extra` repo package for gamma temperature and blue-light adjustment).

### Qt 6 Runtime & Essential QML Modules
`cool-shell` relies on the modular Qt 6 framework. Missing any of these packages will cause QML import errors or disable specific features (such as blur effects or video wallpapers):

| Arch Package | Version | QML Import URI | Purpose in `cool-shell` |
|---|---|---|---|
| `qt6-base` | `>= 6.7` | `QtCore` | Core Qt runtime, D-Bus communication, event loops. |
| `qt6-declarative` | `>= 6.7` | `QtQuick`, `QtQuick.Layouts`, `QtQuick.Shapes`, `QtQuick.Effects` | QML declarative engine, canvas rendering, vector shapes, layout trees. |
| `qt6-5compat` | `>= 6.7` | `Qt5Compat.GraphicalEffects` | GPU shader effects: `FastBlur`, `DropShadow`, `OpacityMask`, and soft washes across cards and panels. |
| `qt6-multimedia` | `>= 6.7` | `QtMultimedia` | High-performance hardware-accelerated media playback for animated video wallpapers (`Wallpaper.qml`). |
| `qt6-multimedia-ffmpeg` | `>= 6.7` | Backend plugin | FFmpeg video decoding plugin for Qt 6 Multimedia. |
| `qt6-wayland` | `>= 6.7` | Wayland client plugin | Wayland platform abstraction and layer-shell client protocol bindings. |
| `qt6-shadertools` | `>= 6.7` | Shader compiler (`qsb`) | Qt Shader Baker toolchain for fragment shaders and procedural graphics. |
| `qt6-svg` | `>= 6.7` | SVG renderer | Vector icon rendering for Minflair SVG icon sets (`MinflairSvgIcon.qml`). |

### Quickshell Framework & C++ Engine Plugins
- **Engine Package**: `quickshell-git` (AUR) or `quickshell` (version `>= 0.3.0`, verified on `0.3.2`).
- **Required C++ Subsystem Plugins**:
  - `Quickshell.Wayland`: Provides `WlrLayershell`, `PanelWindow`, edge margins, and pointer hit-test non-interception masking.
  - `Quickshell.Hyprland`: Native Hyprland C++ event socket bridge providing active workspaces, focused clients, and monitor geometry.
  - `Quickshell.Io`: Native async process execution (`Process { command: [...] }`), detached execution, file streams, and UNIX socket IPC.
  - `Quickshell.Widgets`: Specialized UI primitives (`ClippingRectangle`, `Icon`).
  - `Quickshell.Bluetooth`: Real-time BlueZ D-Bus integration for adapter states, discovered devices, and pairing management.
  - `Quickshell.Networking`: NetworkManager D-Bus integration for Wi-Fi SSID scanning, signal strength bars, and active VPN connection tracking.
  - `Quickshell.Services.Mpris`: MPRIS2 media controller protocol (Spotify, browser audio, playerctl sync, track position, album art).
  - `Quickshell.Services.Pipewire`: Low-latency audio stream tracking, audio node graph introspection, and hardware volume manipulation.
  - `Quickshell.Services.SystemTray`: StatusNotifierItem (SNI) host protocol for system tray applets.
  - `Quickshell.Services.UPower`: System battery health, charge percentages, and discharge rate telemetry.
  - `Quickshell.Services.Notifications`: Desktop notification server protocol, priority queuing, and Dynamic Island notification cards.

---

## 2. CLI Tools & System Daemons Matrix

The shell scripts in `island/scripts/` and `scripts/` automate desktop state, media handling, and hardware control. Below is the complete manifest of command-line tools and daemons:

| Domain | CLI Command / Daemon | Arch Package | Repo / Origin | Purpose in `cool-shell` |
|---|---|---|---|---|
| **Compositor** | `hyprctl` | `hyprland` | Official | Dispatches compositor actions, query window hierarchy, reload decorations. |
| **Compositor** | `hyprlock` | `hyprlock` | Official | Lockscreen surface invoked by idle timeout or manual trigger. |
| **Compositor** | `hyprsunset` | `hyprsunset` | Official | Gamma temperature controller for night-light mode (`shell-actions.sh`). |
| **Audio** | `pipewire` | `pipewire` | Official | Core Wayland multimedia and low-latency audio server. |
| **Audio** | `wireplumber` | `wireplumber` | Official | Session manager for PipeWire; provides `wpctl` default sink/volume actuator. |
| **Audio** | `pw-record` | `pipewire` | Official | Raw PCM audio capture for Level Meter (`level-meter.py`) and Voice Notes (`voice-note.sh`). |
| **Audio** | `pw-play` | `pipewire` | Official | Raw audio playback for Kokoro TTS (`voice-engine.py`) and timer alarms. |
| **Audio** | `pw-link` | `pipewire` | Official | Direct audio node port patcher for monitor tap capture. |
| **Audio** | `pactl` | `pipewire-pulse` | Official | PulseAudio compatibility layer for legacy audio clients. |
| **Audio** | `playerctl` | `playerctl` | Official | Controls MPRIS media players (play, pause, next, metadata query). |
| **Audio** | `cava` | `cava` | Official | Console audio visualizer backend for real-time waveform meters (`FloatingMediaCompanion.qml`). |
| **Audio** | `sptlrx` | `sptlrx-bin` | AUR | Synchronized terminal and socket lyrics fetching daemon (`lyrics-daemon.sh`). |
| **Audio** | `mpv` | `mpv` | Official | Headless background audio player for Study Mode lo-fi streams (`study-mode.py`). |
| **Vision & Capture** | `grim` | `grim` | Official | Screen capture tool for window thumbnails, screen lens, and region snips. |
| **Vision & Capture** | `slurp` | `slurp` | Official | Interactive on-screen geometric region selector for Screen Lens and recording. |
| **Vision & Capture** | `wf-recorder` | `wf-recorder` | Official | Hardware-accelerated screen video and audio recorder (`shell-actions.sh`). |
| **Vision & Capture** | `tesseract` | `tesseract` | Official | Fast native C++ OCR engine for instant text extraction from snips (`screen-lens.sh`). |
| **Vision & Capture** | `tessdata_fast` | `tesseract-data-eng`| Official | Fast English OCR language training data. |
| **Vision & Capture** | `leptonica` | `leptonica` | Official | Advanced image processing and image analysis library used by Tesseract. |
| **Vision & Capture** | `zbarimg` | `zbar` | Official | Instant C-native QR code and barcode scanner (~10ms decode time). |
| **Vision & Capture** | `magick` | `imagemagick` | Official | Sub-millisecond 1×1 hex color sampler for Screen Lens color picker mode. |
| **Vision & Capture** | `swappy` | `swappy` | Official | Instant interactive Wayland image annotator and editor. |
| **Media Processing** | `ffmpeg` / `ffprobe` | `ffmpeg` | Official | Video thumbnail generation for live wallpapers, audio extraction, and subtitle muxing (`caption.py`). |
| **Clipboard** | `wl-copy` / `wl-paste` | `wl-clipboard` | Official | System Wayland clipboard integration for OCR text, colors, and screenshots. |
| **Clipboard** | `cliphist` | `cliphist` | Official | Clipboard history daemon and wipe utility (`SettingsWindow.qml`). |
| **Hardware** | `brightnessctl` | `brightnessctl` | Official | Backlight brightness controller for laptops and supported external monitors. |
| **Hardware** | `upower` | `upower` | Official | D-Bus power daemon for battery telemetry, charging status, and battery health. |
| **Hardware** | `sensors` | `lm_sensors` | Official | Hardware temperature sensors and fan speed telemetry. |
| **Network** | `nmcli` | `networkmanager` | Official | NetworkManager CLI for Wi-Fi scanning, connection switching, and VPN status. |
| **Bluetooth** | `bluetoothctl` | `bluez-utils` | Official | Bluetooth daemon utilities for device pairing and discovery. |
| **Wallpaper** | `awww` / `awww-daemon` | `awww` | Official | High-performance Wayland wallpaper animation and display daemon (in `extra`). |
| **Wallpaper** | `swww` | `swww` | AUR | Alternative Wayland wallpaper daemon supported by `install.sh`. |
| **Theming** | `matugen` | `matugen-bin` | AUR | Material You dynamic color palette generator from wallpaper images (`generate-palette.sh`). |
| **Speech** | `espeak-ng` | `espeak-ng` | Official | Phoneme translation dictionary for Kokoro ONNX speech synthesis. |
| **Phone Bridge** | `adb` | `android-tools` | Official | Android Debug Bridge for wireless phone file transfer and battery tracking. |
| **Phone Bridge** | `scrcpy` | `scrcpy` | Official | Ultra-low-latency Android screen mirroring and remote input control. |
| **System & Dialogs** | `zenity` | `zenity` | Official | Native GUI dialogs for file pickers, pairing prompts, and battery alerts. |
| **System & IPC** | `jq` | `jq` | Official | JSON processor for Hyprland client data and state serialization. |
| **System & IPC** | `curl` | `curl` | Official | HTTP retrieval tool for live weather data (`WeatherState.qml`) and models. |
| **System & IPC** | `socat` | `socat` | Official | UNIX domain socket relay for local AI image daemon communication. |
| **System & IPC** | `fd` | `fd` | Official | High-speed filesystem crawler for application launcher indexing (`LauncherPanel.qml`). |
| **Process Control** | `killall`, `fuser` | `psmisc` | Official | Process killing and socket port inspection utilities. |
| **Process Control** | `pgrep`, `pkill`, `ps` | `procps-ng` | Official | Process management and background daemon supervision. |
| **POSIX Base** | `cat`, `cut`, `awk`, `sed`, `tr`, `head`, `mkdir`, `date`, `chmod` | `coreutils`, `gawk`, `sed` | Official | Standard POSIX text processing and file management toolset. |
| **Security** | `ufw` | `ufw` | Official | Host firewall management. |
| **Security** | `bw` | `bitwarden-cli` / `bitwarden` | Official / AUR | Bitwarden credential management integration. |
| **Runtimes** | `python` (>= 3.10) | `python` | Official | Core scripting runtime for background daemons and models. |
| **Runtimes** | `uv` | `uv` | Official | High-performance Astral Python package manager and virtualenv runner. |
| **Runtimes** | `node`, `npm` | `nodejs`, `npm` | Official | JavaScript runtime for God's Eye View 3D OSINT Satellite Globe. |

---

## 3. Python Machine Learning & AI Runtime (`requirements.txt`)

`cool-shell` includes native local AI capabilities running 100% offline via local models:
- **TTS Engine**: Kokoro ONNX (`scripts/voice-engine.py`)
- **Multimodal Screen Lens**: RapidOCR & OpenCV (`scripts/screen-lens.py`)
- **Video & Audio Captioning**: NVIDIA FastConformer-CTC (`scripts/caption.py`)
- **Local AI Image Studio**: Realistic Vision v5.1 + LCM-LoRA (`scripts/image-daemon.py`)
- **AI Studio Chat UI**: Gradio Web Interface (`scripts/chat-ui.py`)

### Python Package Specifications

| Package | Minimum Version | Subsystem | Calling Scripts | Purpose |
|---|---|---|---|---|
| `kokoro-onnx` | `>= 0.6.0` | Kokoro Voice Engine | `scripts/voice-engine.py` | Realtime streaming text-to-speech synthesis. |
| `onnxruntime` | `>= 1.19.0` | AI Runtimes | `scripts/voice-engine.py`, `scripts/screen-lens.py` | ONNX model execution engine for CPU/GPU. |
| `soundfile` | `>= 0.12.1` | Audio Subsystem | `scripts/voice-engine.py`, `scripts/caption.py` | High-fidelity WAV export and raw audio buffer conversion. |
| `numpy` | `>= 1.26.0` | Math & Arrays | `scripts/voice-engine.py`, `scripts/screen-lens.py` | Numerical tensor and waveform manipulation. |
| `rapidocr-onnxruntime` | `>= 1.3.0` | Universal Screen Lens | `scripts/screen-lens.py` | High-accuracy local OCR engine for snips and text recognition. |
| `pyzbar` | `>= 0.1.9` | Universal Screen Lens | `scripts/screen-lens.py` | Python binding for zbar QR code and barcode extraction. |
| `opencv-python-headless` | `>= 4.10.0` | Universal Screen Lens | `scripts/screen-lens.py` | Computer vision, QR detection, barcode detection, color analysis. |
| `Pillow` | `>= 10.4.0` | Image Studio & Lens | `scripts/image-daemon.py`, `scripts/chat-ui.py` | Image manipulation, resizing, and format conversions. |
| `sherpa-onnx` | `>= 1.10.0` | Fast-Caption Engine | `scripts/caption.py` | High-speed offline ASR with NVIDIA FastConformer-CTC. |
| `huggingface-hub` | `>= 0.24.0` | Model Management | `scripts/caption.py`, `scripts/image-daemon.py` | Automatic model weights caching and download verification. |
| `torch` | `>= 2.4.0` | AI Image Studio | `scripts/image-daemon.py` | Deep learning tensor engine with CUDA support. |
| `torchvision` | `>= 0.19.0` | AI Image Studio | `scripts/image-daemon.py` | Image transforms and vision model utilities. |
| `diffusers` | `>= 0.30.0` | AI Image Studio | `scripts/image-daemon.py` | Latent Diffusion and LCM-LoRA generation pipelines. |
| `transformers` | `>= 4.44.0` | AI Image Studio | `scripts/image-daemon.py` | CLIP text encoders and tokenizers for Stable Diffusion. |
| `accelerate` | `>= 0.33.0` | AI Image Studio | `scripts/image-daemon.py` | Fast VRAM offloading and multi-device acceleration. |
| `gradio` | `>= 4.40.0` | Conversational Chat UI | `scripts/chat-ui.py` | Local web-based interactive interface for AI image creation. |

> [!TIP]
> Both `scripts/voice-engine.py` and `scripts/screen-lens.py` declare PEP 723 inline script metadata. If `uv` is installed, they can also run directly without activating a virtual environment via `uv run --script <script_name>`.

---

## 4. Typography & Iconography

`cool-shell` implements a structured typography hierarchy designed for modern cyber-tactical and glassmorphic user interfaces:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        cool-shell Typography Map                       │
├─────────────────────────┬────────────────────────┬─────────────────────┤
│ UI Surface              │ Primary Font Family    │ Arch Package / Path │
├─────────────────────────┼────────────────────────┼─────────────────────┤
│ Master UI & Panels      │ Geist (or Inter)       │ ttf-geist (AUR)     │
│ Iconography & Badges    │ JetBrainsMonoNL Nerd   │ ttf-jetbrains-mono  │
│ Lyrics Companion Card   │ Fredoka (Variable)     │ ~/.local/share/fonts│
│ Telemetry & Coordinates │ Geom (SemiBold)        │ ~/.local/share/fonts│
│ Monospace & Reticles    │ monospace (Fallback)   │ system monospace    │
└─────────────────────────┴────────────────────────┴─────────────────────┘
```

1. **Primary Interface Font**:
   - **Font**: `Geist` (`Island.Theme.fontFamily: "Geist"`).
   - **Role**: Clean modernist geometric sans designed by Vercel for user interfaces and convex status bars.
   - **Arch Package**: `ttf-geist` (AUR) or `otf-geist-mono-nerd` (Official).
   - **Alternative / Fallback**: `inter-font` (`Inter` from Arch `extra`).
2. **Icon & Symbolic Font**:
   - **Font**: `JetBrainsMonoNL Nerd Font` (`Island.Theme.iconFontFamily: "JetBrainsMonoNL Nerd Font"`).
   - **Role**: Monospace alignment and comprehensive Nerd Font symbol glyphs (`󰂯`, `󰍬`, `󰄀`, `󰇚`, `󰌌`, etc.).
   - **Arch Package**: `ttf-jetbrains-mono-nerd` (Official `extra`).
3. **Accent Display Fonts**:
   - **Fredoka Variable**: Used in `FloatingMediaCompanion.qml` for rounded lyrics typography.
     - **Location**: `~/.local/share/fonts/Fredoka-VariableFont_wdth,wght.ttf` (or AUR `ttf-fredoka`).
   - **Geom SemiBold**: Used in `DesktopAmbientSlate.qml` for cyber-tactical coordinate grids.
     - **Location**: `~/.local/share/fonts/Geom-SemiBold.ttf`.
4. **Unicode & Emoji Fallback**:
   - **Packages**: `noto-fonts`, `noto-fonts-emoji` (Official `extra`).

---

## 5. One-Line Installation Commands

### Option A: Official Arch Repositories (Pacman)

Run this one-liner to install all official system packages, Qt 6 dependencies, CLI utilities, audio infrastructure, and official fonts:

```bash
sudo pacman -S --needed --noconfirm \
  hyprland hyprlock hyprsunset \
  qt6-base qt6-declarative qt6-5compat qt6-multimedia qt6-multimedia-ffmpeg qt6-wayland qt6-shadertools qt6-svg \
  pipewire wireplumber pipewire-pulse pipewire-alsa playerctl cava mpv \
  grim slurp wf-recorder tesseract tesseract-data-eng leptonica zbar imagemagick swappy ffmpeg \
  wl-clipboard cliphist brightnessctl awww upower networkmanager bluez bluez-utils lm_sensors \
  espeak-ng android-tools scrcpy zenity jq curl socat fd psmisc procps-ng coreutils findutils git ufw bitwarden \
  python uv nodejs npm \
  ttf-jetbrains-mono-nerd inter-font noto-fonts noto-fonts-emoji
```

### Option B: AUR Packages (Paru / Yay)

Install the Quickshell engine, AUR daemons, dynamic theming tools, and Geist font:

```bash
# Using yay:
yay -S --needed --noconfirm quickshell-git sptlrx-bin matugen-bin ttf-geist

# Or using paru:
paru -S --needed --noconfirm quickshell-git sptlrx-bin matugen-bin ttf-geist
```

### Option C: Unified All-In-One Command

For users with `yay` or `paru` installed, install all official and AUR dependencies in a single step:

```bash
yay -S --needed --noconfirm \
  hyprland hyprlock hyprsunset quickshell-git \
  qt6-base qt6-declarative qt6-5compat qt6-multimedia qt6-multimedia-ffmpeg qt6-wayland qt6-shadertools qt6-svg \
  pipewire wireplumber pipewire-pulse pipewire-alsa playerctl cava mpv sptlrx-bin \
  grim slurp wf-recorder tesseract tesseract-data-eng leptonica zbar imagemagick swappy ffmpeg \
  wl-clipboard cliphist brightnessctl awww matugen-bin upower networkmanager bluez bluez-utils lm_sensors \
  espeak-ng android-tools scrcpy zenity jq curl socat fd psmisc procps-ng coreutils findutils git ufw bitwarden \
  python uv nodejs npm \
  ttf-jetbrains-mono-nerd ttf-geist inter-font noto-fonts noto-fonts-emoji
```

### Option D: Python AI Virtual Environment Setup

Set up the isolated Python virtual environment using `uv` (recommended) or standard `venv`:

```bash
# 1. Create virtual environment
uv venv ~/.local/share/cool-shell/venv --python 3.12

# 2. Install all core Python dependencies
uv pip --python ~/.local/share/cool-shell/venv/bin/python install -r ~/.config/quickshell/cool-shell/requirements.txt

# 3. (Optional) Install NVIDIA CUDA acceleration for PyTorch
uv pip --python ~/.local/share/cool-shell/venv/bin/python install --upgrade torch torchvision --index-url https://download.pytorch.org/whl/cu124
```

---

## 6. System Verification & Self-Test

Run these diagnostic commands to verify that your environment is 100% prepared:

### 1. Check CLI Tools Availability
```bash
for bin in hyprctl hyprlock quickshell pw-record pw-play playerctl cava grim slurp wf-recorder tesseract zbarimg magick swappy awww matugen brightnessctl nmcli bluetoothctl upower sensors zenity jq curl socat fd uv; do
  if command -v "$bin" >/dev/null 2>&1; then
    echo "  [OK] $bin"
  else
    echo "  [MISSING] $bin"
  fi
done
```

### 2. Verify Quickshell C++ & Qt 6 Plugins
```bash
quickshell --version
```
*Expected output*: `Quickshell 0.3.x`

### 3. Verify Python Dependencies Resolution
```bash
~/.local/share/cool-shell/venv/bin/python3 -c "
import kokoro_onnx, onnxruntime, soundfile, numpy, cv2, rapidocr_onnxruntime, PIL
print('✅ Core Python AI & Vision dependencies verified!')
"
```

### 4. Verify Fonts Availability
```bash
fc-list : family | grep -E '^(Geist|JetBrainsMonoNL Nerd Font|Inter|Fredoka|Geom)' | sort -u
```
