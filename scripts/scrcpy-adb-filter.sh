#!/usr/bin/env bash
# ==============================================================================
# Cool-Shell — Surgical ADB Interceptor & Drag-and-Drop MIME Filter for scrcpy
# ==============================================================================
set -euo pipefail

REAL_ADB=""
for candidate in "$HOME/.local/bin/adb" "/usr/bin/adb" "/usr/local/bin/adb"; do
    if [ -x "$candidate" ]; then
        REAL_ADB="$candidate"
        break
    fi
done
if [ -z "$REAL_ADB" ]; then
    REAL_ADB="$(command -v adb 2>/dev/null || true)"
fi

notify_island() {
    local msg="$1"
    local ms="${2:-3500}"
    qs -c cool-shell ipc call island showTransient "$msg" "$ms" >/dev/null 2>&1 || \
    quickshell -c cool-shell ipc call island showTransient "$msg" "$ms" >/dev/null 2>&1 || true
}

# If the command is NOT "push", forward immediately to real adb with 0ms latency
if [ "${1:-}" != "push" ]; then
    exec "$REAL_ADB" "$@"
fi

# ==============================================================================
# Push Interception & Strict MIME Type Whitelisting
# Format: adb push <src_file> <dest>
# ==============================================================================
SRC_FILE="${2:-}"
if [ -z "$SRC_FILE" ] || [ ! -e "$SRC_FILE" ]; then
    exec "$REAL_ADB" "$@"
fi

FILENAME="$(basename "$SRC_FILE")"
MIME_TYPE="$(file -b --mime-type "$SRC_FILE" 2>/dev/null || true)"
EXT="${FILENAME##*.}"
EXT="$(echo "$EXT" | tr '[:upper:]' '[:lower:]')"

is_allowed=false

case "$MIME_TYPE" in
    image/*)
        is_allowed=true
        ;;
    audio/*)
        is_allowed=true
        ;;
    video/*)
        is_allowed=true
        ;;
    application/pdf|text/plain|text/markdown|application/epub+zip|text/csv)
        is_allowed=true
        ;;
    application/vnd.openxmlformats-officedocument.*|application/msword|application/vnd.ms-excel)
        is_allowed=true
        ;;
    application/vnd.android.package-archive)
        is_allowed=true
        ;;
    application/zip|application/x-zip-compressed)
        # Allow zip only if extension is apk, epub, or docx
        if [[ "$EXT" =~ ^(apk|epub|docx|xlsx|pptx)$ ]]; then
            is_allowed=true
        fi
        ;;
esac

# Fallback check by file extension for known formats
if [ "$is_allowed" = false ]; then
    case "$EXT" in
        jpg|jpeg|png|webp|gif|svg|avif|heic|heif)
            is_allowed=true
            ;;
        mp3|flac|ogg|wav|m4a|aac|opus)
            is_allowed=true
            ;;
        mp4|webm|mkv|mov|avi)
            is_allowed=true
            ;;
        pdf|txt|md|csv|epub|docx|xlsx|pptx)
            is_allowed=true
            ;;
        apk)
            is_allowed=true
            ;;
    esac
fi

if [ "$is_allowed" = true ]; then
    notify_island "📤 Sending ${FILENAME} to Phone..." 3000
    "$REAL_ADB" "$@"
    notify_island "✅ Sent ${FILENAME} to Phone" 3500
else
    notify_island "🚫 Blocked: ${FILENAME} is not an allowed file type (${MIME_TYPE})" 4500
    echo "[-] Blocked: File '$FILENAME' ($MIME_TYPE) is not in the allowed transfer whitelist." >&2
    exit 1
fi
