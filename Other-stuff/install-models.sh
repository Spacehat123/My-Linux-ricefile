#!/usr/bin/env bash
# ==============================================================================
# Cool-Shell / Pranc Rice - Automated Model & Asset Fetcher
# ==============================================================================
set -euo pipefail

echo "=========================================================="
echo "  🚀 Installing Models & Assets for Cool-Shell"
echo "=========================================================="

KOKORO_DIR="$HOME/.local/share/cool-shell/models/kokoro"
IMAGE_DIR="$HOME/.local/share/cool-shell/models/image"
TESSDATA_DIR="$HOME/.local/share/tessdata"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
GENERATED_DIR="$HOME/Pictures/generated"

# 1. Directory Structure
echo "[*] Creating directory structures..."
mkdir -p "$KOKORO_DIR" "$IMAGE_DIR" "$TESSDATA_DIR" "$GENERATED_DIR"
mkdir -p "$WALLPAPER_DIR"/{cherry,darth,live,nature,sea,space}

# 2. Kokoro Realtime TTS Models
echo "[*] Checking Kokoro TTS ONNX model..."
if [ ! -f "$KOKORO_DIR/kokoro-v1.0.int8.onnx" ]; then
    echo "    -> Downloading kokoro-v1.0.int8.onnx (88MB)..."
    curl -L --progress-bar -o "$KOKORO_DIR/kokoro-v1.0.int8.onnx" \
        "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.int8.onnx"
else
    echo "    -> kokoro-v1.0.int8.onnx already exists."
fi

if [ ! -f "$KOKORO_DIR/voices-v1.0.bin" ]; then
    echo "    -> Downloading voices-v1.0.bin (27MB)..."
    curl -L --progress-bar -o "$KOKORO_DIR/voices-v1.0.bin" \
        "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"
else
    echo "    -> voices-v1.0.bin already exists."
fi

# 3. Tesseract OCR Fast English Data
echo "[*] Checking Tesseract OCR data..."
if [ ! -f "$TESSDATA_DIR/eng.traineddata" ]; then
    echo "    -> Downloading eng.traineddata (23MB)..."
    curl -L --progress-bar -o "$TESSDATA_DIR/eng.traineddata" \
        "https://github.com/tesseract-ocr/tessdata_fast/raw/main/eng.traineddata"
else
    echo "    -> eng.traineddata already exists."
fi

# 4. Espeak-NG Data Symlink
echo "[*] Checking Espeak-NG phoneme dictionaries..."
if [ -d "/usr/share/espeak-ng-data" ] && [ ! -d "$HOME/.local/share/espeak-ng-data" ]; then
    echo "    -> Symlinking /usr/share/espeak-ng-data to ~/.local/share/espeak-ng-data"
    ln -sfn /usr/share/espeak-ng-data "$HOME/.local/share/espeak-ng-data"
fi

echo "=========================================================="
echo "  ✅ All models and asset folders are verified and ready!"
echo "=========================================================="
