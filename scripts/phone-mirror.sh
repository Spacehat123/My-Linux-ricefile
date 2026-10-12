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

prompt_pairing() {
    local default_ip="192.168.1.17"
    if [ -f "$CONFIG_FILE" ]; then
        local saved_ip
        saved_ip=$(grep "^WIRELESS_IP=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '" ' || true)
        [ -n "$saved_ip" ] && default_ip="$saved_ip"
    fi

    local detected_port=""
    local mdns_pair
    mdns_pair=$(adb mdns services 2>/dev/null | grep "_adb-tls-pairing" | head -n 1 || true)
    if [ -n "$mdns_pair" ]; then
        local pair_endpoint
        pair_endpoint=$(echo "$mdns_pair" | awk '{print $3}')
        default_ip="${pair_endpoint%:*}"
        detected_port="${pair_endpoint##*:}"
    fi

    local form_res
    form_res=$(zenity --forms \
        --title="CoolPhone Wireless Pairing" \
        --text="Open 'Wireless Debugging' on your phone and tap 'Pair device with pairing code':" \
        --add-entry="Phone IP ($default_ip)" \
        --add-entry="Pairing Port ($detected_port)" \
        --add-entry="6-digit Pairing Code" \
        --separator="|" 2>/dev/null || true)

    if [ -z "$form_res" ]; then
        return 1
    fi

    local p_ip p_port p_code
    p_ip=$(echo "$form_res" | cut -d'|' -f1 | tr -d ' ')
    p_port=$(echo "$form_res" | cut -d'|' -f2 | tr -d ' ')
    p_code=$(echo "$form_res" | cut -d'|' -f3 | tr -d ' ')

    [ -z "$p_ip" ] && p_ip="$default_ip"
    [ -z "$p_port" ] && p_port="$detected_port"

    if [ -z "$p_port" ] || [ -z "$p_code" ]; then
        notify_island "⚠️ Port and 6-digit Code are required" 3500
        return 1
    fi

    notify_island "🔄 Pairing with ${p_ip}:${p_port}..." 3000
    local pair_out
    pair_out=$(adb pair "${p_ip}:${p_port}" "${p_code}" 2>&1 || true)

    if echo "$pair_out" | grep -iq "successfully paired"; then
        echo "WIRELESS_IP=\"${p_ip}\"" > "$CONFIG_FILE"
        notify_island "✅ Paired successfully!" 2500
        sleep 1
        local connect_service
        connect_service=$(adb mdns services 2>/dev/null | grep "_adb-tls-connect" | head -n 1 || true)
        if [ -n "$connect_service" ]; then
            local endpoint
            endpoint=$(echo "$connect_service" | awk '{print $3}')
            adb connect "$endpoint" >/dev/null 2>&1 || true
        else
            adb connect "${p_ip}:5555" >/dev/null 2>&1 || true
        fi
        return 0
    else
        notify_island "❌ Pairing failed. Check code & port." 4000
        echo "[-] Pairing failed: ${pair_out}" >&2
        return 1
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
        hyprctl dispatch focuswindow "title:^CoolPhone$" >/dev/null 2>&1 || true
        return 0
    fi

    # Check for connected ADB devices
    local devices
    devices=$(adb devices 2>/dev/null | grep -E "\b(device|offline|unauthorized)\b" | grep -v "devices" || true)

    # If no device connected, try auto-connecting via mDNS or saved wireless IP
    if [ -z "$devices" ]; then
        local connect_service
        connect_service=$(adb mdns services 2>/dev/null | grep "_adb-tls-connect" | head -n 1 || true)
        if [ -n "$connect_service" ]; then
            local endpoint
            endpoint=$(echo "$connect_service" | awk '{print $3}')
            echo "[*] Auto-connecting to discovered mDNS endpoint: $endpoint..."
            adb connect "$endpoint" >/dev/null 2>&1 || true
            sleep 0.5
            devices=$(adb devices 2>/dev/null | grep -E "\b(device|offline|unauthorized)\b" | grep -v "devices" || true)
        fi
    fi

    if [ -z "$devices" ] && [ -f "$CONFIG_FILE" ]; then
        local wireless_ip
        wireless_ip=$(grep "^WIRELESS_IP=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '" ' || true)
        if [ -n "$wireless_ip" ]; then
            echo "[*] Attempting wireless ADB connection to $wireless_ip..."
            adb connect "$wireless_ip" >/dev/null 2>&1 || true
            sleep 0.5
            devices=$(adb devices 2>/dev/null | grep -E "\b(device|offline|unauthorized)\b" | grep -v "devices" || true)
        fi
    fi

    local authorized
    authorized=$(echo "$devices" | grep -E "\bdevice\b" || true)

    # If still not connected/authorized, prompt the user for pairing code and port!
    if [ -z "$authorized" ]; then
        prompt_pairing
        devices=$(adb devices 2>/dev/null | grep -E "\b(device|offline|unauthorized)\b" | grep -v "devices" || true)
        authorized=$(echo "$devices" | grep -E "\bdevice\b" || true)
    fi

    if [ -z "$authorized" ]; then
        notify_island "📱 No Phone Connected (Pairing cancelled)" 3500
        echo "[-] No authorized Android device connected." >&2
        return 1
    fi

    notify_island "📱 Launching Phone Mirror..." 2500

    # Launch scrcpy with the surgical filtered ADB hook and rock-solid parameters
    export ADB="$FILTER_ADB"
    if [ -f "$HOME/.local/share/scrcpy/scrcpy-server" ]; then
        export SCRCPY_SERVER_PATH="$HOME/.local/share/scrcpy/scrcpy-server"
    fi
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

    setsid scrcpy \
        --window-title="CoolPhone" \
        --window-borderless \
        -m 1280 \
        --max-fps=60 \
        --stay-awake \
        --video-bit-rate=12M \
        >/tmp/coolphone-scrcpy.log 2>&1 &

    local s_pid=$!
    echo "$s_pid" > "$PID_FILE"

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
