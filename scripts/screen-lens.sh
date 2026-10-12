#!/usr/bin/env bash
set -euo pipefail

# Ensure ~/.local/bin and ~/.local/lib are available
export PATH="$HOME/.local/bin:$PATH:/usr/local/bin:/usr/bin"
export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
export TESSDATA_PREFIX="$HOME/.local/share/tessdata"
export OMP_THREAD_LIMIT=1

notify_island() {
    local text="$1"
    local duration="${2:-3500}"
    qs -c cool-shell ipc call island showTransient "$text" "$duration" >/dev/null 2>&1 || true
}

# Visual slurp box styled to match Cool-Shell theme (semi-transparent dark with emerald accent)
geom=$(slurp -d -b "#1a1a1a99" -c "#00ffccbb" -B "#00ffcc22" -w 2 2>/dev/null || true)
if [[ -z "$geom" ]]; then
    exit 0
fi

# Extract width and height from geometry ("X,Y WxH")
dim=$(echo "$geom" | awk '{print $2}')
w=${dim%x*}
h=${dim#*x}

tmp_img="/tmp/screen-lens-$$.png"
trap 'rm -f "$tmp_img"' EXIT

# Capture selected geometry
grim -g "$geom" "$tmp_img"

# 1. Ultra-fast Color Picker (Region <= 16x16)
if [[ "$w" -le 16 && "$h" -le 16 ]]; then
    if command -v magick >/dev/null 2>&1; then
        hex=$(magick "$tmp_img" -resize 1x1! -format "#%[hex:u.p{0,0}]" info: 2>/dev/null || true)
        if [[ -n "$hex" ]]; then
            echo -n "$hex" | wl-copy
            notify_island "🎨 Color copied: $hex" 3500
            exit 0
        fi
    fi
fi

# 2. Instant QR Code / Barcode Decoder via native zbar (Pure C, ~10ms)
if command -v zbarimg >/dev/null 2>&1; then
    qr_data=$(zbarimg -q --raw "$tmp_img" 2>/dev/null || true)
    if [[ -n "$qr_data" ]]; then
        qr_trimmed=$(echo "$qr_data" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [[ -n "$qr_trimmed" ]]; then
            echo -n "$qr_trimmed" | wl-copy
            preview="${qr_trimmed:0:36}"
            if [[ ${#qr_trimmed} -gt 36 ]]; then
                preview="${preview}..."
            fi
            notify_island "󰇚 QR: $preview" 4000
            exit 0
        fi
    fi
fi

# 3. High-Speed, Low-CPU Native Tesseract OCR (Single-threaded C++, ~250ms, <1% CPU)
if command -v tesseract >/dev/null 2>&1; then
    raw_text=$(tesseract "$tmp_img" stdout -l eng --oem 1 2>/dev/null || true)
    clean_text=$(echo "$raw_text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    if [[ -n "$clean_text" ]]; then
        echo "$clean_text" > /tmp/screen-lens-last.txt
        echo -n "$clean_text" | wl-copy
        word_count=$(echo "$clean_text" | wc -w)
        first_line=$(echo "$clean_text" | head -n 1 | cut -c 1-28)
        if [[ ${#first_line} -ge 28 ]]; then
            first_line="${first_line}..."
        fi
        # Offer Read Aloud in Island without running any TTS until user clicks
        qs -c cool-shell ipc call island showLensAction "$first_line" "$word_count" >/dev/null 2>&1 || true
        exit 0
    fi
fi

# Fallback: No content detected
notify_island "No text detected" 2000
