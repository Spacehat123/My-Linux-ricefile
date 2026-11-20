# AI Image Studio: Conversational Chat Interface & Parameter Studio Integration

**Date**: 2026-11-19  
**Target Subsystems**:
- [`scripts/chat-ui.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/chat-ui.py)
- [`scripts/launch-chat.sh`](file:///home/pranc/.config/quickshell/cool-shell/scripts/launch-chat.sh)
- [`scripts/image-daemon.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-daemon.py)
- [`scripts/image-engine.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-engine.py)
- [`components/ControlCenter.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/ControlCenter.qml)
- [`island/panels/AiPromptPanel.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/panels/AiPromptPanel.qml)

---

## 1. Executive Summary

A full-featured, lightweight conversational web interface for the local image model (`Realistic Vision v5.1` + `LCM-LoRA`) has been integrated. It is powered by Gradio 6, runs 100% offline, fits strictly within the 4 GB GTX 1650 VRAM boundary, and operates **100% independently of the existing QuickShell `Super + G` island prompt panel**.

Both the QuickShell island panel (`Super + G`) and the Chat WebUI share the background engine daemon ([`scripts/image-daemon.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-daemon.py)) via a local UNIX socket. This eliminates duplicate memory consumption (0 MB extra weight download, zero VRAM duplication) and ensures zero GPU collisions.

---

## 2. Key Architecture & Features

### 2.1 Independent Shared-Daemon Architecture
- **Daemon-Brokered Execution**:
  - `Super + G` dispatches fast one-off prompts to `/tmp/cool-shell-image.sock` with strict single-output persistence (`~/Pictures/generated/ai_output.png`).
  - The Chat WebUI (`localhost:7860`) dispatches prompts to the same socket with `purge_previous=False`, storing conversation outputs in `~/Pictures/generated/chat/`.
  - When either surface triggers a generation, the daemon locks, slices attention/VAE, moves weights to CUDA, executes diffusion, offloads to CPU RAM, and releases CUDA memory.
  - Idle state remains **0 MB VRAM**.

### 2.2 Multimodal Conversational UI
- **Chat Stream**:
  - Generates responses in conversation bubbles with full text prompt history and inline rendered image previews.
  - Multimodal input: Users can type a prompt or drag-and-drop / attach a reference photo directly in the chat bar.
  - If a photo is attached, it automatically engages `img2img` styling at the chosen strength; otherwise, standard `txt2img` is executed.
  - Rich metadata caption: `Generated in 11.2s | 768×432 | 8 steps | CFG 1.8 | Seed 42109`.

### 2.3 Extended Parameter Studio (Sidebar Drawer)
The Chat WebUI exposes an extensive parameter drawer:
1. **Style Presets**: Photorealistic Studio, Cinematic Cyberpunk, Anime & Digital Art, Dark Fantasy, Analog 35mm Film, Architectural, or None (Raw Prompt).
2. **Aspect Ratios & Resolutions**:
   - `1:1 Square (512×512)`
   - `16:9 Landscape (768×432)`
   - `9:16 Portrait (432×768)`
   - `4:3 Standard (640×480)`
   - `3:4 Portrait (480×640)`
3. **Inference Steps**: Slider (4 to 20 steps, default 8).
4. **CFG Scale**: Slider (1.0 to 4.0, default 1.8).
5. **Img2Img Denoising Strength**: Slider (0.10 to 0.95, default 0.65).
6. **Custom Negative Prompt**: Text area for custom negative cues or preset combinations.
7. **Seed Control**: Integer input (`-1` for randomized, or exact integer for deterministic reproduction).
8. **Studio Illumination Boost**: Checkbox toggle to automatically distill prompts with professional softbox lighting.

### 2.4 Session Gallery Tab
- Dedicated `🖼️ Session Gallery` tab displaying all generated images in the session in a responsive thumbnail grid with click-to-preview and download options.
- "Clear Chat" button purges the chat history and memory.

### 2.5 Quick Shell Launchers
- **Left Sidebar Control Center**: Added a dedicated `󰭹` Chat launcher button right next to the model `ON / OFF` toggle in [`components/ControlCenter.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/ControlCenter.qml).
- **Super + G Panel Header**: Added a `󰭹 Chat` chip button in [`island/panels/AiPromptPanel.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/panels/AiPromptPanel.qml) for 1-click transition between quick generation and the full parameter studio.
- **Standalone CLI Launcher**: [`scripts/launch-chat.sh`](file:///home/pranc/.config/quickshell/cool-shell/scripts/launch-chat.sh) safely spawns the background server and opens `http://127.0.0.1:7860` in the user's browser.
