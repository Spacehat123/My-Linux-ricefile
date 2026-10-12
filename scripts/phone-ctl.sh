#!/usr/bin/env bash
# ==============================================================================
# phone-ctl.sh - Master CLI controller for CoolPhone Screen Mirroring & Bridge
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIRROR_SCRIPT="${SCRIPT_DIR}/phone-mirror.sh"
DAEMON_SCRIPT="${SCRIPT_DIR}/phone-bridge-daemon.py"
FILTER_SCRIPT="${SCRIPT_DIR}/scrcpy-adb-filter.sh"
PID_FILE="/tmp/phone-bridge-daemon.pid"

ensure_daemon() {
    if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
        return 0
    fi
    echo "[phone-ctl] Starting background bridge daemon..."
    python3 "${DAEMON_SCRIPT}" >/tmp/phone-bridge-daemon.log 2>&1 &
    echo $! > "${PID_FILE}"
}

stop_daemon() {
    if [[ -f "${PID_FILE}" ]]; then
        local pid
        pid="$(cat "${PID_FILE}")"
        if kill -0 "${pid}" 2>/dev/null; then
            echo "[phone-ctl] Stopping bridge daemon (PID ${pid})..."
            kill "${pid}" 2>/dev/null || true
        fi
        rm -f "${PID_FILE}"
    fi
}

is_mirror_running() {
    pgrep -f "scrcpy.*--window-title=CoolPhone" >/dev/null 2>&1
}

case "${1:-status}" in
    start)
        ensure_daemon
        if is_mirror_running; then
            echo "[phone-ctl] CoolPhone mirror is already running."
            exit 0
        fi
        echo "[phone-ctl] Launching CoolPhone mirror..."
        "${MIRROR_SCRIPT}" &
        ;;

    stop)
        if is_mirror_running; then
            echo "[phone-ctl] Stopping CoolPhone mirror..."
            pkill -f "scrcpy.*--window-title=CoolPhone" || true
        else
            echo "[phone-ctl] CoolPhone mirror is not running."
        fi
        ;;

    toggle)
        if is_mirror_running; then
            echo "[phone-ctl] Stopping CoolPhone mirror..."
            pkill -f "scrcpy.*--window-title=CoolPhone" || true
        else
            ensure_daemon
            echo "[phone-ctl] Starting CoolPhone mirror..."
            "${MIRROR_SCRIPT}" &
        fi
        ;;

    daemon)
        ensure_daemon
        ;;

    stop-daemon)
        stop_daemon
        ;;

    pair)
        IP="${2:-}"
        PORT="${3:-5555}"
        CONFIG_DIR="$HOME/.config/cool-shell"
        mkdir -p "$CONFIG_DIR"

        if [[ -z "${IP}" ]]; then
            # Attempt automatic discovery via USB connection
            echo "[phone-ctl] No IP provided. Checking for USB-connected phone..."
            if adb devices | grep -E "\bdevice\b" >/dev/null 2>&1; then
                echo "[phone-ctl] Found USB device. Enabling TCP/IP mode on port 5555..."
                adb tcpip 5555 || true
                sleep 1
                echo "[phone-ctl] Querying phone Wi-Fi IP address..."
                IP=$(adb shell "ip -f inet addr show wlan0 | grep inet | awk '{print \$2}' | cut -d/ -f1" 2>/dev/null | tr -d '\r\n' || true)
                if [[ -z "${IP}" ]]; then
                    IP=$(adb shell "ip route" 2>/dev/null | awk '{print $9}' | head -n 1 | tr -d '\r\n' || true)
                fi
            fi
        fi

        if [[ -z "${IP}" ]]; then
            if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]] && command -v zenity >/dev/null 2>&1; then
                local form_res
                form_res=$(zenity --forms \
                    --title="CoolPhone Wireless Pairing" \
                    --text="Open 'Wireless Debugging' on your phone and tap 'Pair device with pairing code':" \
                    --add-entry="Phone IP (e.g. 192.168.1.17)" \
                    --add-entry="Pairing Port" \
                    --add-entry="6-digit Pairing Code" \
                    --separator="|" 2>/dev/null || true)
                if [[ -n "$form_res" ]]; then
                    IP=$(echo "$form_res" | cut -d'|' -f1 | tr -d ' ')
                    local p_port p_code
                    p_port=$(echo "$form_res" | cut -d'|' -f2 | tr -d ' ')
                    p_code=$(echo "$form_res" | cut -d'|' -f3 | tr -d ' ')
                    if [[ -n "$p_port" && -n "$p_code" ]]; then
                        echo "[phone-ctl] Pairing with ${IP}:${p_port} using code..."
                        adb pair "${IP}:${p_port}" "${p_code}" || true
                        PORT="${p_port}"
                    fi
                fi
            fi
        fi

        if [[ -z "${IP}" ]]; then
            echo "[-] Error: Could not detect phone IP or pairing was cancelled."
            echo "Usage: phone-ctl pair <PHONE_IP_ADDRESS> [PORT]"
            echo "Example: phone-ctl pair 192.168.1.50"
            exit 1
        fi

        echo "[phone-ctl] Connecting to wireless ADB device at ${IP}:${PORT}..."
        adb tcpip "${PORT}" >/dev/null 2>&1 || true
        adb connect "${IP}:${PORT}"
        echo "WIRELESS_IP=\"${IP}\"" > "${CONFIG_DIR}/phone.conf"
        echo "[+] Wireless pairing complete! Saved ${IP} to ~/.config/cool-shell/phone.conf"
        echo "[+] You can now unplug the USB cable and use CoolPhone wirelessly."
        ;;

    disconnect)
        IP="${2:-}"
        if [[ -n "${IP}" ]]; then
            adb disconnect "${IP}"
        else
            adb disconnect
        fi
        ;;

    push)
        FILE="${2:-}"
        if [[ -z "${FILE}" || ! -f "${FILE}" ]]; then
            echo "Usage: phone-ctl push <file-path>"
            exit 1
        fi
        echo "[phone-ctl] Filtering and pushing file ${FILE} to phone..."
        "${FILTER_SCRIPT}" push "${FILE}" "/sdcard/Download/"
        ;;

    status)
        echo "=== CoolPhone Status ==="
        if is_mirror_running; then
            echo "Mirror Window: RUNNING"
        else
            echo "Mirror Window: STOPPED"
        fi

        if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
            echo "Bridge Daemon: RUNNING (PID $(cat "${PID_FILE}"))"
        else
            echo "Bridge Daemon: STOPPED"
        fi

        echo ""
        echo "Connected ADB Devices:"
        if command -v adb >/dev/null 2>&1; then
            adb devices -l
        else
            echo "adb not found in PATH"
        fi
        ;;

    *)
        echo "Usage: phone-ctl {start|stop|toggle|daemon|stop-daemon|pair <ip> [port]|disconnect|push <file>|status}"
        exit 1
        ;;
esac
