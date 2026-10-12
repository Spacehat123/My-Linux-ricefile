# Universal Screen Lens & Drop Pocket Implementation Plan

**Document ID**: `.asw/reports/2026-10-11-universal-screen-lens-implementation.md`  
**Date**: 2026-10-11  
**Target Environment**: Arch Linux, Hyprland 0.56.2, Quickshell (Cool-Shell QML), Python 3.14 + `uv`  
**Status**: Approved for Implementation

---

## 1. Executive Summary

This specification introduces the **Universal Screen Lens** to Cool-Shell and upgrades the existing "Shelf" into the polished **"Drop Pocket"**.

The Universal Screen Lens turns your screen into an intelligent, interactive surface:
1. **Instant OCR**: Extract text, code blocks, or math formulas from YouTube videos, images, un-copyable game dialogs, or PDFs.
2. **QR & Barcode Scanner**: Instant extraction of URLs and payloads from any QR code on screen.
3. **Smart Color Picker**: Dragging a micro-selection or clicking extracts exact Hex/RGB values.
4. **Instant Action**: Copies the extracted text straight to the clipboard (`wl-copy`) and triggers dynamic feedback on the Dynamic Island with transient preview cards.
5. **Drop Pocket UI Refresh**: Rebranding Shelf $\to$ Drop Pocket with refined typography, icon accents, and smoother action targets.

---

## 2. Technical Architecture

### 2.1 Multi-Modal Lens Pipeline (`scripts/screen-lens.py`)

```
 [ User Press: SUPER + Shift + S / Island Button ]
                        │
                        ▼
             [ Region Selection: slurp ]
                        │
                        ▼
             [ Pixel Capture: grim ]
                        │
                        ▼
            [ scripts/screen-lens.py ]
                        │
       ┌────────────────┼────────────────┐
       ▼                ▼                ▼
 [ Swatch <= 16px ]  [ QR / Barcode ]  [ Text / Code ]
   RGB & Hex Color     OpenCV QR/Bar     RapidOCR ONNX
       │                │                │
       └────────────────┼────────────────┘
                        │
                        ▼
        [ Result Packaging & Formatting ]
                        │
          ┌─────────────┴─────────────┐
          ▼                           ▼
  [ wl-copy Clipboard ]      [ Cool-Shell Dynamic Island ]
                             - Transient Pill / Preview
                             - Border Flash Glow
```

### 2.2 Execution Engine: Python + `uv` Standalone Runner
* Uses `uv run --with "rapidocr-onnxruntime" --with "opencv-python"`:
  * 100% offline, self-contained ONNX model weights.
  * Zero system package dependencies or root/sudo requirements.
  * Rapid execution (~80–120ms total inference time).
  * Automatically handles QR/Barcode detection via `cv2.QRCodeDetector()`.

### 2.3 Hyprland Integration
* In `Other stuff/hyprland.lua`:
  * Bind `SUPER + Shift + S`:
    `hl.bind("SUPER + Shift + S", hl.dsp.exec_cmd("~/.config/quickshell/cool-shell/scripts/screen-lens.sh"))`
  * Retains `Print` for full screenshots and `SUPER + Print` for Swappy image editing.

### 2.4 Drop Pocket UI Polish
* Rename "Shelf" $\to$ "Drop Pocket" across user-facing text in `ShelfPanel.qml` and `ControlPanel.qml`.
* Enhance empty state with a sleek card container, muted border accents, and tactical pill buttons.

---

## 3. Verification Plan

| Scenario | Input | Expected Output |
| :--- | :--- | :--- |
| **Code / Text Snipping** | Select text in a browser video or image | Text cleanly copied to clipboard; Dynamic Island announces `"󰄀 Extracted <N> characters"` with preview. |
| **QR Code Snipping** | Select a QR code on screen | Decodes URL/payload, copies to clipboard; Island announces `"󰇚 QR Code: <URL>"`. |
| **Color Snatch** | Click or micro-drag a pixel/icon | Copies `#RRGGBB` hex code to clipboard; Island shows color swatch. |
| **Drop Pocket** | Open Island Drop Pocket | Displays "Drop Pocket", accepts drag-and-drop, retains files with enhanced visual styling. |

---
