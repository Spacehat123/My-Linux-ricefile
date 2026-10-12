#!/usr/bin/env bash
# ==============================================================================
# Step 3: Lightweight Models Installer (~139 MB Total)
# Includes: Kokoro Realtime TTS Engine + Tesseract Fast OCR
# Fast, low-bandwidth download (~15-30 seconds)
# ==============================================================================
set -euo pipefail

echo "=========================================================="
echo "  🗣️  [3/5] Installing Lightweight Models (~139 MB)"
echo "  Includes: Kokoro TTS Voice Engine + Tesseract OCR"
echo "=========================================================="

KOKORO_DIR="$HOME/.local/share/cool-shell/models/kokoro"
TESSDATA_DIR="$HOME/.local/share/tessdata"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

mkdir -p "$KOKORO_DIR" "$TESSDATA_DIR"
mkdir -p "$WALLPAPER_DIR"/{cherry,darth,live,nature,sea,space}
mkdir -p "$HOME/Pictures/generated"

# 1. Kokoro ONNX Model (~89 MB)
echo "[*] Checking Kokoro TTS ONNX model (~89 MB)..."
if [ ! -f "$KOKORO_DIR/kokoro-v1.0.int8.onnx" ]; then
    echo "    -> Downloading kokoro-v1.0.int8.onnx..."
    curl -L --progress-bar -o "$KOKORO_DIR/kokoro-v1.0.int8.onnx" \
        "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.int8.onnx"
else
    echo "    -> kokoro-v1.0.int8.onnx already installed."
fi

# 2. Kokoro Voice Embeddings (~27 MB)
echo "[*] Checking Kokoro Voice Embeddings (~27 MB)..."
if [ ! -f "$KOKORO_DIR/voices-v1.0.bin" ]; then
    echo "    -> Downloading voices-v1.0.bin..."
    curl -L --progress-bar -o "$KOKORO_DIR/voices-v1.0.bin" \
        "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"
else
    echo "    -> voices-v1.0.bin already installed."
fi

# 3. Tesseract OCR Fast English Data (~23 MB)
echo "[*] Checking Tesseract Fast English OCR Data (~23 MB)..."
if [ ! -f "$TESSDATA_DIR/eng.traineddata" ]; then
    echo "    -> Downloading eng.traineddata..."
    curl -L --progress-bar -o "$TESSDATA_DIR/eng.traineddata" \
        "https://github.com/tesseract-ocr/tessdata_fast/raw/main/eng.traineddata"
else
    echo "    -> eng.traineddata already installed."
fi

# 4. Espeak-NG Symlink
if [ -d "/usr/share/espeak-ng-data" ] && [ ! -d "$HOME/.local/share/espeak-ng-data" ]; then
    ln -sfn /usr/share/espeak-ng-data "$HOME/.local/share/espeak-ng-data"
fi

echo "=========================================================="
echo "  ✅ Step 3 Complete: Lightweight TTS & OCR models ready!"
echo "=========================================================="
