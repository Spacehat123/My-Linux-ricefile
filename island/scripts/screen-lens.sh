#!/usr/bin/env bash
# Screen Lens: OCR text capture & QR reader helper for cool-shell
set -e

killall -q slurp 2>/dev/null || true
CAPTURE_FILE="/tmp/screen_lens_capture.png"
rm -f "$CAPTURE_FILE"

# Prompt user for rectangular screen selection using slurp
if ! REGION=$(slurp -b "#00000088" -c "#0a84ffff" -w 2); then
    exit 0
fi

grim -g "$REGION" "$CAPTURE_FILE"

if [ ! -s "$CAPTURE_FILE" ]; then
    exit 0
fi

export LD_LIBRARY_PATH="/home/pranc/.local/lib:${LD_LIBRARY_PATH:-}"
export TESSDATA_PREFIX="/home/pranc/.local/share/tessdata"

# 1. Try QR Code Reader first
QR_TEXT=$(/home/pranc/.local/bin/zbarimg -q --raw "$CAPTURE_FILE" 2>/dev/null || true)
if [ -n "$QR_TEXT" ]; then
    printf "%s" "$QR_TEXT" | wl-copy
    quickshell -c cool-shell ipc call island showTransient "󰄀 QR Code Copied" 3000 2>/dev/null || true
    exit 0
fi

# 2. Fall back to OCR Text Capture
OCR_TEXT=$(/home/pranc/.local/bin/tesseract "$CAPTURE_FILE" stdout -l eng 2>/dev/null || true)
CLEAN_TEXT=$(printf "%s" "$OCR_TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if [ -n "$CLEAN_TEXT" ]; then
    printf "%s" "$CLEAN_TEXT" | wl-copy
    SNIPPET=$(printf "%s" "$CLEAN_TEXT" | tr '\n' ' ' | cut -c 1-40)
    quickshell -c cool-shell ipc call island showTransient "󰄀 Text Copied: \"$SNIPPET...\"" 3500 2>/dev/null || true
else
    quickshell -c cool-shell ipc call island showTransient "󰄀 No text or QR detected in selection" 3000 2>/dev/null || true
fi
