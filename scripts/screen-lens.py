#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "opencv-python",
#   "rapidocr-onnxruntime",
# ]
# ///
"""
Universal Screen Lens - Multi-Modal Screen Intelligence Engine
Extracts OCR text, QR codes, barcodes, or color hex values from screen snips.
Copies result to clipboard (wl-copy) and broadcasts rich feedback to Cool-Shell Dynamic Island.
"""

import sys
import os
import subprocess
import json

def notify_island(text: str, duration_ms: int = 3500, border_color: str = "#00ffcc"):
    """Dispatches transient text and border flash to the Cool-Shell Island."""
    try:
        subprocess.run(
            ["qs", "-c", "cool-shell", "ipc", "call", "island", "showTransient", text, str(duration_ms)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1
        )
    except Exception:
        pass

def copy_to_clipboard(content: str):
    """Copies extracted content to the Wayland system clipboard."""
    try:
        subprocess.run(["wl-copy", content], check=True, timeout=2)
    except Exception as e:
        print(f"Error copying to clipboard: {e}", file=sys.stderr)

def main():
    if len(sys.argv) < 2:
        print("Usage: screen-lens.py <path_to_image>", file=sys.stderr)
        sys.exit(1)

    img_path = sys.argv[1]
    if not os.path.isfile(img_path):
        print(f"File not found: {img_path}", file=sys.stderr)
        sys.exit(1)

    import cv2
    import numpy as np

    img = cv2.imread(img_path)
    if img is None:
        print("Failed to read image", file=sys.stderr)
        sys.exit(1)

    h, w = img.shape[:2]

    # --- Mode 1: Color Picker (Small region <= 16x16) ---
    if w <= 16 and h <= 16:
        # Calculate mean color
        mean_bgr = img.mean(axis=(0, 1))
        b, g, r = int(round(mean_bgr[0])), int(round(mean_bgr[1])), int(round(mean_bgr[2]))
        hex_color = f"#{r:02X}{g:02X}{b:02X}"
        copy_to_clipboard(hex_color)
        notify_island(f"🎨 Color copied: {hex_color}", 3500, hex_color)
        print(f"COLOR: {hex_color}")
        return

    # --- Mode 2: QR Code Detection ---
    qr_detector = cv2.QRCodeDetector()
    decoded_qr, points, _ = qr_detector.detectAndDecode(img)
    if decoded_qr and decoded_qr.strip():
        qr_text = decoded_qr.strip()
        copy_to_clipboard(qr_text)
        preview = qr_text[:36] + "..." if len(qr_text) > 36 else qr_text
        notify_island(f"󰇚 QR: {preview}", 4000)
        print(f"QR: {qr_text}")
        return

    # --- Mode 3: Barcode Detection (if supported) ---
    try:
        barcode_detector = cv2.barcode.BarcodeDetector()
        ok, decoded_info, decoded_type, _ = barcode_detector.detectAndDecode(img)
        if ok and decoded_info:
            for item in decoded_info:
                if item and item.strip():
                    barcode_text = item.strip()
                    copy_to_clipboard(barcode_text)
                    notify_island(f"󰇚 Barcode: {barcode_text}", 4000)
                    print(f"BARCODE: {barcode_text}")
                    return
    except Exception:
        pass

    # --- Mode 4: High-Accuracy OCR via RapidOCR ---
    from rapidocr_onnxruntime import RapidOCR
    engine = RapidOCR()
    ocr_result, elapse = engine(img)

    if ocr_result:
        lines = []
        for item in ocr_result:
            if item and len(item) > 1 and item[1]:
                text_part = item[1].strip()
                if text_part:
                    lines.append(text_part)

        if lines:
            full_text = "\n".join(lines).strip()
            copy_to_clipboard(full_text)

            preview = full_text.replace("\n", " ").strip()
            if len(preview) > 35:
                preview = preview[:32] + "..."

            notify_island(f"󰄀 Extracted: {preview} ({len(full_text)} chars)", 4000)
            print(f"OCR ({len(full_text)} chars):\n{full_text}")
            return

    # Fallback: Nothing detected
    notify_island("󰄀 No text or code detected", 2500)
    print("NO_RESULT")

if __name__ == "__main__":
    main()
