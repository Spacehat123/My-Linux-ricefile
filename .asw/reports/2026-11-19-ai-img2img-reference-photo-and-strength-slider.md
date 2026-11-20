# AI Studio: Image-to-Image (img2img) Reference Photo & Strength Slider Implementation

- **Date**: 2026-11-19
- **Target Subsystem**: AI Image Studio & Dynamic Island Modal
- **Files Modified**:
  - UI Panel: [`island/panels/AiPromptPanel.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/panels/AiPromptPanel.qml)
  - Island Host & State: [`island/IslandHub.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/IslandHub.qml), [`island/Notch.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml), [`island/ai-settings.json`](file:///home/pranc/.config/quickshell/cool-shell/island/ai-settings.json)
  - Inference Daemon: [`scripts/image-daemon.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-daemon.py)
  - CLI Runner: [`scripts/image-engine.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-engine.py)

---

## 1. Executive Summary
Extended the on-device AI Studio (Realistic Vision v5.1 + LCM-LoRA) with **Image-to-Image (img2img)** capabilities. The user can drag and drop any image file onto the prompt modal or pick a file via native Zenity dialog, adjust a continuous reference strength slider (10% to 95%) or tap quick preset chips (`30% Subtle`, `65% Balanced`, `85% Restyle`), and generate restyled variations without any extra model downloads or memory overhead.

---

## 2. Technical Architecture & Memory Sharing

### 2.1 Zero-Download In-Memory Pipeline Sharing
Hugging Face `diffusers` allows reusing existing loaded model weights through pipeline inheritance:
```python
def get_img2img_pipeline():
    global pipe, pipe_img2img
    if pipe_img2img is not None:
        return pipe_img2img
    if pipe is None:
        load_pipeline()
    from diffusers import AutoPipelineForImage2Image
    pipe_img2img = AutoPipelineForImage2Image.from_pipe(pipe)
    return pipe_img2img
```
- **Weights Reused**: `unet`, `vae`, `text_encoder`, `tokenizer`, `scheduler` are shared directly by reference.
- **Additional Disk Download**: **0 MB**.
- **Additional Idle RAM/VRAM**: **0 MB**.

### 2.2 Inference Execution Workflow
1. When `image_path` is passed, the daemon opens the reference image with PIL and resizes it to the target resolution (`512x512` or `768x432`) using `Image.Resampling.LANCZOS`.
2. `pipe_img2img` transfers to CUDA, slices attention, and denoises over `num_inference_steps` scaled by `strength`.
3. Latents are decoded through VAE on GPU, post-processed, and the pipeline immediately offloads back to CPU RAM.

---

## 3. UI/UX Interaction Design

### 3.1 Drop Zone & Native File Picker
- **`DropArea`**: Covers the entire prompt panel. Dragging an image from Dolphin, Nautilus, or browser drops the path directly into `IslandHub.setAiReferenceImage()`.
- **`+ Photo` Button**: Located left of the prompt input. Clicking launches `zenity --file-selection` via a background `Process`.
- **Thumbnail Preview & Clear**: Once an image is loaded, a 38x38 thumbnail preview appears with a hover `✕` button to instantly clear and return to pure text-to-image mode.

### 3.2 Dynamic Island Height Expansion
- In [`island/Notch.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml), `panelContentHeight` now tracks `requestedPanel.implicitHeight`.
- When an image is added, `implicitHeight` expands from `110px` to `154px` via eased animation, revealing the strength row.

### 3.3 Interactive Strength Slider
- Continuous draggable track mapping from `10%` to `95%` (`0.10` to `0.95`).
- Live percentage readout with visual indicator.
- 3 Instant preset chips:
  - `30%` (Subtle variation / preserve facial & object geometry)
  - `65%` (Balanced restyle)
  - `85%` (Heavy creative reinterpret)
- Dynamic contextual hint explaining the active strength range.

---

## 4. Verification & Status
- Daemon & CLI argument parsing verified and compiled without syntax errors.
- QML property bindings and file picker process verified.
- Graphify index updated.
