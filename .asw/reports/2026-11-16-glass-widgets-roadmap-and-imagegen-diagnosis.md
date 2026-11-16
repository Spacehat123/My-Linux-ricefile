# System Architecture Report: Liquid Glass Widget Roadmap & AI Image Generation Bug Diagnosis

- **Date**: 2026-11-16
- **Author**: Antigravity Chief of Staff
- **Target Subsystems**: Quickshell Desktop (`cool-shell`), AI Image Studio Daemon, Control Center
- **Status**: Diagnostic Complete & Architectural Roadmap Logged

---

## Part 1: The 6 Liquid Glass Widget Specifications (Permanent Record)

Per user directive, here is the permanent record and design specification for the 6 liquid glass desktop widgets:

### 1. Modular Control Center Pods (Primary Priority)
- **Reference**: iOS 18 / visionOS Control Center (User Reference Image 1).
- **Architecture**: Decoupled, modular glass tiles instead of a flat vertical list.
  - **Connectivity Pod (2×2 Squircle)**: Wi-Fi, Bluetooth, Mobile/Network, and Hotspot/Airplane mode with active illuminated round badges.
  - **Now Playing Tile**: Album artwork, track/artist label, and tactile transport controls.
  - **Vertical Liquid Slider Capsules**: Master Volume and Screen Brightness vertical tubes with interactive fluid-level fills and specular sheen.
  - **Quick Mode Tiles**: Feather Battery Mode, Game Mode, Do Not Disturb, and Night Light.
- **Surface Material**: Squircle curvature (radius 20–24px), 1px directional key-light specular border, subtle ambient occlusion drop shadow.

### 2. Floating Media Player Capsule
- **Reference**: Floating Dynamic Island / Lockscreen Player (User Reference Images 0 & 2).
- **Architecture**: Standalone pill capsule floating over desktop or docked above bottom bar.
  - Mini album artwork thumbnail with curved corners.
  - Track & artist typography with high-contrast protection.
  - Interactive scrub bar with liquid progress fill.
  - Dynamic audio spectrum equalizer waves.

### 3. Glass Volume & Brightness OSD Popups (On-Screen Displays)
- **Reference**: Transient HUD popups triggered by hardware Fn keys (`XF86Audio*`, `XF86MonBrightness*`).
- **Architecture**: 1.5-second ephemeral glass pill centered on screen.
  - Thick optical meniscus bevel and refractive rim.
  - Zero desktop clutter (only visible during adjustment).

### 4. Contextual Action Hub
- **Reference**: Floating context menu (User Reference Image 3).
- **Architecture**: Compact popup card summoned near cursor on hotkey (`Super + Space`).
  - Screen Lens (Instant OCR text capture, QR scanner, color picker).
  - Dictation / Voice Note Recorder.
  - AI Image Prompt launcher.
  - Clipboard history drawer.

### 5. Floating Bottom Navigation / Dock Capsule
- **Reference**: Navigation pill (User Reference Image 0).
- **Architecture**: Bottom dock capsule (`dockBody` in `panels/BottomBar.qml`) rendered as an elevated optical glass pill over the wallpaper.
  - Active workspace indicators and system status popovers.
  - 315° key-light specular rim highlight.

### 6. Desktop Ambient Weather & Clock Slate
- **Reference**: Clean architectural lockscreen / empty workspace HUD.
- **Architecture**: Minimalist frosted glass slate pinned to a corner of the desktop or lockscreen (`hyprlock`).
  - Large architectural clock and date.
  - Weather icon, current temperature, and precipitation badge.
  - Battery health and hardware telemetry summary.

---

## Part 2: Diagnosis of the AI Image Generation Issue (`Super + G`)

### Symptom
Pressing `Super + G` opens the AI Prompt modal on the Dynamic Island. When a prompt is entered, the UI status updates to `"Generating Image..."` but generation never starts and the modal remains stuck indefinitely.

### Empirical Root Cause Analysis

1. **Trigger Chain**:
   - `Super + G` triggers `qs_ipc("notch toggle ai")` in `~/.config/hypr/hyprland.lua`.
   - In `island/panels/AiPromptPanel.qml`: User clicks or presses Enter $\to$ calls `IslandHub.triggerAiGeneration(text)`.
   - In `island/IslandHub.qml`:
     ```qml
     function triggerAiGeneration(prompt) {
         if (!prompt || !prompt.trim()) return;
         root.setAiGenerating(true, "Generating Image...");
         Quickshell.execDetached([Quickshell.shellPath("scripts/image-engine.sh"), prompt.trim()]);
     }
     ```
   - `IslandHub` sets `aiGenerating = true`.

2. **The Execution Failure in `image-engine.sh`**:
   - `scripts/image-engine.sh` searches for Python:
     ```bash
     if [ -x "$HOME/.unsloth/studio/unsloth_studio/bin/python3" ]; then
         PYTHON_BIN="$HOME/.unsloth/studio/unsloth_studio/bin/python3"
     elif [ -x "$HOME/.local/share/cool-shell/venv/bin/python3" ]; then
         PYTHON_BIN="$HOME/.local/share/cool-shell/venv/bin/python3"
     else
         PYTHON_BIN="python3"
     fi
     ```
   - Neither `~/.unsloth/` nor `~/.local/share/cool-shell/venv/` exists on the filesystem.
   - `image-engine.sh` falls back to system Python `/usr/bin/python3` (Python 3.14 on Arch Linux).

3. **Fatal Python Crash in `image-daemon.py`**:
   - System Python attempts to launch the background daemon:
     ```
     Traceback (most recent call last):
       File ".../scripts/image-daemon.py", line 146, in load_pipeline
         import torch
     ModuleNotFoundError: No module named 'torch'
     ```
   - The daemon immediately crashes. The Unix domain socket `/tmp/cool-shell-image.sock` is never created.
   - `image-engine.py` polls for 45 seconds waiting for the socket, logs `[-] Daemon did not respond in time`, and exits with code 1.

4. **UI Deadlock**:
   - Because `Quickshell.execDetached` runs detached in the background without a process exit listener, and the daemon died before sending an IPC failure signal, `IslandHub.aiGenerating` was never set back to `false`.
   - The Dynamic Island remains permanently locked in the `"Generating Image..."` state until Quickshell is restarted.

### Model Weights Status
- The model weights are **already downloaded and present** in `~/.local/share/cool-shell/models/image/`:
  - `SG161222/Realistic_Vision_V5.1_noVAE` (~2.1 GB)
  - `latent-consistency/lcm-lora-sdv1-5` (~135 MB)
- Hardware: NVIDIA GeForce GTX 1650 (4 GB VRAM) is detected and idle.

### Remediation Plan
1. **Create Python 3.12/3.11 virtual environment** at `~/.local/share/cool-shell/venv/` using `uv`.
2. **Install PyTorch with CUDA support** (`torch`, `torchvision`, `diffusers`, `transformers`, `accelerate`).
3. **Add Error-Recovery to `IslandHub.qml` & `image-engine.py`**:
   - Ensure that if `image-engine.py` fails or times out, it issues an IPC call resetting `setAiGenerating(false, "Generation Failed")` so the UI never deadlocks.
