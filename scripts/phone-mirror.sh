#!/usr/bin/env bash
# ==============================================================================
# Cool-Shell — macOS Sequoia-Style Android Phone Mirror Launcher
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILTER_ADB="$SCRIPT_DIR/scrcpy-adb-filter.sh"
CONFIG_FILE="$HOME/.config/cool-shell/phone.conf"
PID_FILE="/tmp/coolphone-mirror.pid"

mkdir -p "$HOME/.config/cool-shell"

notify_island() {
    local msg="$1"
    local ms="${2:-3500}"
    qs -c cool-shell ipc call island showTransient "$msg" "$ms" >/dev/null 2>&1 || \
    quickshell -c cool-shell ipc call island showTransient "$msg" "$ms" >/dev/null 2>&1 || true
}

is_mirror_running() {
    pgrep -f "scrcpy.*CoolPhone" >/dev/null 2>&1
}

stop_mirror() {
    if is_mirror_running; then
        echo "[*] Stopping CoolPhone mirror..."
        pkill -f "scrcpy.*CoolPhone" 2>/dev/null || true
        rm -f "$PID_FILE"
        notify_island "📱 Phone Mirror Closed" 2000
    fi
}

start_mirror() {
    if ! command -v scrcpy >/dev/null 2>&1 || ! command -v adb >/dev/null 2>&1; then
        notify_island "⚠️ scrcpy or adb not installed" 4000
        echo "[-] Error: scrcpy and android-tools (adb) must be installed." >&2
        echo "    Run: sudo pacman -S scrcpy android-tools" >&2
        exit 1
    fi

    if is_mirror_running; then
        echo "[*] Mirror already running."
        # Focus the existing window under Hyprland
        hyprctl dispatch focuswindow "title:^CoolPhone$" >/dev/null 2>&1 || true
        return 0
    fi

    # Check for connected ADB devices
    local devices
    devices=$(adb devices 2>/dev/null | grep -E "\b(device|offline|unauthorized)\b" | grep -v "devices" || true)

    # If no USB device connected, check if a wireless IP is configured
    if [ -z "$devices" ] && [ -f "$CONFIG_FILE" ]; then
        local wireless_ip
        wireless_ip=$(grep "^WIRELESS_IP=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '" ' || true)
        if [ -n "$wireless_ip" ]; then
            echo "[*] Attempting wireless ADB connection to $wireless_ip:5555..."
            adb connect "$wireless_ip:5555" >/dev/null 2>&1 || true
            sleep 0.5
            devices=$(adb devices 2>/dev/null | grep -E "\b(device)\b" | grep -v "devices" || true)
        fi
    fi

    if [ -z "$devices" ]; then
        notify_island "📱 No Phone Detected (Connect USB or Pair Wi-Fi)" 4000
        echo "[-] No Android device detected via USB or Wireless ADB." >&2
        return 1
    fi

    if echo "$devices" | grep -q "unauthorized"; then
        notify_island "⚠️ Unlock Phone & Accept USB Debugging prompt" 5000
        echo "[-] Device unauthorized. Please unlock your phone and tap 'Allow USB debugging'." >&2
        return 1
    fi

    notify_island "📱 Launching Phone Mirror..." 2500

    # Launch scrcpy with the surgical filtered ADB hook and Apple-style parameters
    export ADB="$FILTER_ADB"
    if [ -f "$HOME/.local/share/scrcpy/scrcpy-server" ]; then
        export SCRCPY_SERVER_PATH="$HOME/.local/share/scrcpy/scrcpy-server"
    fi
    setsid scrcpy \
        --window-title="CoolPhone" \
        --window-borderless \
        --turn-screen-off \
        --stay-awake \
        --keyboard=uhid \
        --mouse=uhid \
        --video-bit-rate=16M \
        --max-fps=60 \
        --audio-buffer=40 \
        >/tmp/coolphone-scrcpy.log 2>&1 &

    local s_pid=$!
    echo "$s_pid" > "$PID_FILE"

    # Give Hyprland a moment to apply window rules and focus
    sleep 0.5
    hyprctl dispatch focuswindow "title:^CoolPhone$" >/dev/null 2>&1 || true
}

toggle_mirror() {
    if is_mirror_running; then
        stop_mirror
    else
        start_mirror
    fi
}

case "${1:-toggle}" in
    start)
        start_mirror
        ;;
    stop)
        stop_mirror
        ;;
    toggle)
        toggle_mirror
        ;;
    status)
        if is_mirror_running; then
            echo '{"running": true}'
        else
            echo '{"running": false}'
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|toggle|status}"
        exit 1
        ;;
esac
