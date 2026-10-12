# Complete System Setup, Model Manifest & Filesystem Placement Guide

> **This document explains every single prerequisite, model weight, Python environment, external repository, and filesystem path required to replicate this exact setup on any Arch Linux machine from scratch.**

---

## 1. Master Filesystem Placement Matrix

Here is the exact layout of where every component, configuration, model, and runtime must reside on your system:

| Component | Repository Source / Origin | Target Filesystem Destination | Purpose |
|---|---|---|---|
| **Cool-Shell (Quickshell)** | `Spacehat123/My-Linux-ricefile.git` | `~/.config/quickshell/cool-shell/` | Core Wayland shell, Dynamic Island, Sidebars |
| **Hyprland Configuration** | `Other-stuff/hyprland.lua` | `~/.config/hypr/hyprland.lua` | Compositor config, window rules & keybindings |
| **Kokoro Voice Models** | HuggingFace / GitHub Releases | `~/.local/share/cool-shell/models/kokoro/` | Realtime streaming text-to-speech engine |
| **Tesseract OCR Data** | Tesseract GitHub fast tessdata | `~/.local/share/tessdata/` | Native C++ OCR language data |
| **Espeak-NG Phonemes** | Arch `espeak-ng` package | `~/.local/share/espeak-ng-data/` | Phoneme dictionaries for Kokoro synthesis |
| **AI Image Model (Base)** | HuggingFace: Realistic Vision v5.1 | `~/.local/share/cool-shell/models/image/` | 512×512 photorealistic image checkpoint |
| **AI Image Model (LoRA)** | HuggingFace: LCM-LoRA SDv1.5 | `~/.local/share/cool-shell/models/image/` | 4–8 step Latent Consistency acceleration |
| **Python CUDA Environment** | Unsloth Studio or custom uv venv | `~/.unsloth/studio/unsloth_studio/` | PyTorch + CUDA/cuDNN environment for AI models |
| **God's Eye View Server** | `bilawalsidhu/gods-eye-view.git` | `~/Desktop/gods-eye-view/` | Real-time 3D OSINT Satellite & Intelligence Globe |
| **Wallpaper Library** | Categorized wallpapers & MP4s | `~/Pictures/Wallpapers/` | Dynamic and static wallpaper selector pool |
| **Generated AI Artwork** | Runtime output | `~/Pictures/generated/` | Output directory for `Super+G` image generations |

---

## 2. Model Downloads & Exact Locations

### A. Kokoro Realtime TTS Models
Kokoro requires two files located in `~/.local/share/cool-shell/models/kokoro/`:
1. **Model Weights**: `kokoro-v1.0.int8.onnx` (~88 MB)
   - **URL**: `https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.int8.onnx`
2. **Voice Embeddings**: `voices-v1.0.bin` (~27 MB)
   - **URL**: `https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin`

**Commands to install**:
```bash
mkdir -p ~/.local/share/cool-shell/models/kokoro
curl -L -o ~/.local/share/cool-shell/models/kokoro/kokoro-v1.0.int8.onnx \
  https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.int8.onnx
curl -L -o ~/.local/share/cool-shell/models/kokoro/voices-v1.0.bin \
  https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin
```

### B. Tesseract OCR Language Data
Required by `scripts/screen-lens.sh` for instant screen OCR:
- **Location**: `~/.local/share/tessdata/eng.traineddata` (~23 MB)
- **URL**: `https://github.com/tesseract-ocr/tessdata_fast/raw/main/eng.traineddata`

**Commands to install**:
```bash
mkdir -p ~/.local/share/tessdata
curl -L -o ~/.local/share/tessdata/eng.traineddata \
  https://github.com/tesseract-ocr/tessdata_fast/raw/main/eng.traineddata
```

### C. Espeak-NG Phoneme Dictionaries
Required for Kokoro TTS text phonemization:
- **Location**: `~/.local/share/espeak-ng-data/`
- **Method**: Provided by the system package `espeak-ng` or symlinked:
```bash
sudo pacman -S --needed espeak-ng
mkdir -p ~/.local/share
ln -sfn /usr/share/espeak-ng-data ~/.local/share/espeak-ng-data
```

### D. Local AI Image Models (Realistic Vision v5.1 + LCM-LoRA)
- **Cache Location**: `~/.local/share/cool-shell/models/image/`
- **Base Checkpoint**: `SG161222/Realistic_Vision_V5.1_noVAE` (~2.1 GB, fp16)
- **LoRA Checkpoint**: `latent-consistency/lcm-lora-sdv1-5` (~135 MB)

These are automatically downloaded by Diffusers upon first launch, or you can pre-pull them using `huggingface-cli`:
```bash
mkdir -p ~/.local/share/cool-shell/models/image
python3 -c "
from diffusers import AutoPipelineForText2Image, LCMScheduler
import torch
cache = '$HOME/.local/share/cool-shell/models/image'
pipe = AutoPipelineForText2Image.from_pretrained(
    'SG161222/Realistic_Vision_V5.1_noVAE',
    torch_dtype=torch.float16,
    cache_dir=cache
)
pipe.load_lora_weights('latent-consistency/lcm-lora-sdv1-5', cache_dir=cache)
print('Done!')
"
```

---

## 3. Python & CUDA Runtime Environment

### Option 1: Unsloth Studio Environment (Current Machine Setup)
The user's setup links directly to the Unsloth Studio PyTorch runtime:
- **Binary Path**: `~/.unsloth/studio/unsloth_studio/bin/python3`
- **NVIDIA CUDA Libraries**: `~/.unsloth/studio/unsloth_studio/lib/python3.13/site-packages/nvidia/cu13/lib`
- **NVIDIA cuDNN Libraries**: `~/.unsloth/studio/unsloth_studio/lib/python3.13/site-packages/nvidia/cudnn/lib`

### Option 2: Clean Standalone `uv` Environment (Portable Replication)
If setting up on a clean machine without Unsloth:
```bash
# 1. Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# 2. Create standalone venv
mkdir -p ~/.local/share/cool-shell
uv venv ~/.local/share/cool-shell/venv --python 3.12

# 3. Install PyTorch with CUDA and Diffusers
uv pip --python ~/.local/share/cool-shell/venv/bin/python install \
  torch torchvision diffusers transformers accelerate \
  kokoro-onnx onnxruntime-gpu soundfile numpy rapidocr-onnxruntime pyzbar opencv-python-headless Pillow
```

---

## 4. God's Eye View Setup (`godseye`)

- **Repository**: `https://github.com/bilawalsidhu/gods-eye-view.git`
- **Target Location**: `/home/pranc/Desktop/gods-eye-view`
- **Prerequisites**: Node.js `v24` LTS (`fnm` or `pacman -S nodejs npm`)

**Installation Steps**:
```bash
cd ~/Desktop
git clone https://github.com/bilawalsidhu/gods-eye-view.git
cd gods-eye-view
npm ci
npm run doctor

# Create startup script start.sh
cat << 'EOF' > start.sh
#!/usr/bin/env bash
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:$PATH"
exec npm run dev
EOF
chmod +x start.sh

# Verify runs on http://localhost:4173
```
*Note*: The Left Sidebar "God's Eye" toggle automatically controls `~/Desktop/gods-eye-view` via [`scripts/gods-eye.sh`](file:///home/pranc/.config/quickshell/cool-shell/scripts/gods-eye.sh).

---

## 5. Hyprland Integration & Keybindings

Copy the provided config to Hyprland's config directory:
```bash
mkdir -p ~/.config/hypr
cp ~/.config/quickshell/cool-shell/Other-stuff/hyprland.lua ~/.config/hypr/hyprland.lua
```

### Essential Hyprland Lines for Cool-Shell
Ensure these commands and bindings are active in your Hyprland configuration:
```lua
-- Autostart Quickshell
hl.exec_cmd("quickshell -c cool-shell")

-- BirdsEye Workspace Overview
hl.bind("SUPER + R", hl.dsp.exec_cmd("quickshell ipc -c cool-shell call birdseye toggle"))

-- Universal Screen Lens (OCR, QR, Color Picker)
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("/home/pranc/.config/quickshell/cool-shell/scripts/screen-lens.sh"))

-- AI Image Prompt Bar
hl.bind("SUPER + G", hl.dsp.exec_cmd("quickshell ipc -c cool-shell call notch toggle ai"))
```

---

## 6. Wallpaper Directory Structure

Create the wallpaper categorization structure in `~/Pictures/Wallpapers/`:
```bash
mkdir -p ~/Pictures/Wallpapers/{cherry,darth,live,nature,sea,space}
mkdir -p ~/Pictures/generated
```
- Place `.mp4` video loops inside `~/Pictures/Wallpapers/live/` for dynamic animated backgrounds.
- Place `.png`/`.jpg` wallpapers in the respective category folders.
- The wallpaper panel and theme engine will automatically discover them.

---

## 7. Modular Setup Scripts & Unmissable Master Installer

All installer scripts are modular, unhidden, and explicitly numbered in `Other-stuff/` so you can install only what you need without downloading heavy assets:

| Script | Purpose | Download Size | Required / Optional |
|---|---|:---:|:---:|
| **`install.sh`** (repo root) | Master interactive terminal menu to run all or selected steps | — | Master Launcher |
| **`01-system-packages.sh`** | Installs all Arch Pacman and AUR system packages | ~300 MB | **Required** |
| **`02-python-environment.sh`** | Sets up Python virtualenv with PyTorch & CUDA | ~1.5 GB | **Required** |
| **`03-light-models-tts-ocr.sh`** | Downloads Kokoro TTS ONNX & Tesseract OCR | ~139 MB | **Recommended** |
| **`04-heavy-ai-image-models.sh`** | Downloads Realistic Vision v5.1 + LCM-LoRA from Hugging Face | ~2.2 GB | *Optional* (AI Art) |
| **`05-godseye-globe.sh`** | Clones & installs God's Eye 3D Cesium OSINT globe | ~350 MB | *Optional* (3D Globe) |

### Quick Start:
To launch the interactive menu, simply run from the repository root:
```bash
./install.sh
```
Or run any individual numbered script directly:
```bash
./Other-stuff/01-system-packages.sh
./Other-stuff/02-python-environment.sh
./Other-stuff/03-light-models-tts-ocr.sh
```
