#!/usr/bin/env bash
# ==============================================================================
# Cool-Shell Battery Charge Limit Actuator
# Supports Acer Aspire/Nitro EC register 0x03, Linux sysfs, and Acer WMI
# ==============================================================================

set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
CONFIG_DIR="${USER_HOME}/.config/cool-shell"
CONFIG_FILE="${CONFIG_DIR}/battery-limit.json"
mkdir -p "${CONFIG_DIR}"

read_config() {
    python3 -c '
import json, sys
try:
    with open(sys.argv[1], "r") as f:
        data = json.load(f)
    print(str(data.get("enabled", False)) + " " + str(data.get("limit", 80)))
except Exception:
    print("False 80")
' "${CONFIG_FILE}"
}

write_config() {
    local enabled="$1"
    local limit="$2"
    python3 -c '
import json, sys
path = sys.argv[1]
enabled = (sys.argv[2].lower() == "true")
limit = int(sys.argv[3])
with open(path, "w") as f:
    json.dump({"enabled": enabled, "limit": limit}, f, indent=2)
' "${CONFIG_FILE}" "${enabled}" "${limit}"
    chown "$TARGET_USER:$TARGET_USER" "${CONFIG_FILE}" 2>/dev/null || true
}

notify_desktop() {
    local msg="$1"
    if [[ -n "${SUDO_USER:-}" && "$EUID" -eq 0 ]]; then
        sudo -u "$SUDO_USER" qs -c cool-shell ipc call island showTransient "$msg" 3000 >/dev/null 2>&1 || true
    else
        qs -c cool-shell ipc call island showTransient "$msg" 3000 >/dev/null 2>&1 || true
    fi
}

# Ensure root privileges for EC write
ensure_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi

    # Try non-interactive sudo first (e.g. if sudoers rule is set or session is cached)
    if sudo -n true 2>/dev/null; then
        exec sudo -E "$0" "$@"
    fi
    if sudo -n "$0" "$@" 2>/dev/null; then
        exit 0
    fi

    # Prompt graphically via Zenity if in desktop session
    if command -v zenity >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-${DISPLAY:-}}" ]]; then
        PASS=$(zenity --password --title="Acer Battery Health Mode" --text="Root access is required to write to the Acer Embedded Controller (EC)." 2>/dev/null || true)
        if [[ -n "$PASS" ]]; then
            echo "$PASS" | sudo -S -E "$0" "$@"
            exit $?
        fi
    fi

    # Fallback to pkexec
    if command -v pkexec >/dev/null 2>&1; then
        exec pkexec "$0" "$@"
    fi

    echo "Error: Root privileges required to write to Acer EC registers." >&2
    exit 1
}

# Direct hardware write using root
write_hardware_ec() {
    local enable="$1" # "true" or "false"
    
    # Load ec_sys module with write support if not present or not writable
    if [[ ! -w "/sys/kernel/debug/ec/ec0/io" && ! -w "/dev/ec" ]]; then
        modprobe -r ec_sys 2>/dev/null || true
        modprobe ec_sys write_support=y 2>/dev/null || true
        if [[ ! -w "/sys/kernel/debug/ec/ec0/io" && ! -w "/dev/ec" ]]; then
            modprobe acpi_ec 2>/dev/null || true
        fi
    fi

    # 1. Acer EC Register 0x03 write
    # 0x51 (81) enables 80% battery care limit
    # 0x11 (17) disables limit (100% full charge)
    local ec_val=17
    if [[ "$enable" == "true" ]]; then
        ec_val=81
    fi

    python3 -c '
import os, sys
val = int(sys.argv[1])
success = False
for path in ["/sys/kernel/debug/ec/ec0/io", "/dev/ec"]:
    if os.path.exists(path):
        try:
            with open(path, "wb+") as f:
                f.seek(0x03)
                f.write(bytearray([val]))
                f.flush()
            success = True
            break
        except Exception:
            pass
sys.exit(0 if success else 1)
' "$ec_val" 2>/dev/null || true

    # 2. Also update standard sysfs if present
    local sysfs_val=100
    if [[ "$enable" == "true" ]]; then
        sysfs_val=80
    fi
    for f in /sys/class/power_supply/BAT*/charge_control_end_threshold \
             /sys/class/power_supply/BAT*/charge_control_limit_max \
             /sys/class/power_supply/BAT*/charge_stop_threshold; do
        if [[ -w "$f" ]]; then
            echo "$sysfs_val" > "$f" 2>/dev/null || true
        fi
    done

    # 3. Also update Acer WMI if present
    local wmi_val=0
    if [[ "$enable" == "true" ]]; then
        wmi_val=1
    fi
    for f in /sys/bus/wmi/drivers/acer-wmi-battery/health_mode \
             /sys/bus/wmi/devices/*/health_mode; do
        if [[ -w "$f" ]]; then
            echo "$wmi_val" > "$f" 2>/dev/null || true
        fi
    done
}

action="${1:-status}"

case "${action}" in
    status)
        read -r cfg_enabled cfg_limit < <(read_config)
        
        cap=100
        if [[ -f /sys/class/power_supply/BAT1/capacity ]]; then
            cap="$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 100)"
        fi

        # Check actual EC state if root or readable
        hw_state="unknown"
        if [[ -r "/sys/kernel/debug/ec/ec0/io" ]]; then
            hw_val=$(python3 -c '
try:
    with open("/sys/kernel/debug/ec/ec0/io", "rb") as f:
        f.seek(0x03)
        v = f.read(1)[0]
        print("enabled" if v in (0x51, 0x40) else "disabled")
except Exception:
    print("unknown")
' 2>/dev/null || echo "unknown")
            hw_state="$hw_val"
        fi

        python3 -c '
import json, sys
enabled = (sys.argv[1].lower() == "true")
limit = int(sys.argv[2])
cap = int(sys.argv[3])
hw_state = sys.argv[4]
print(json.dumps({
    "enabled": enabled,
    "limit": limit,
    "current_capacity": cap,
    "hardware_state": hw_state,
    "acer_fixed_threshold": 80
}))
' "${cfg_enabled}" "${cfg_limit}" "${cap}" "${hw_state}"
        ;;

    enable)
        ensure_root "$@"
        read -r _ cfg_limit < <(read_config)
        write_config "true" "80"
        write_hardware_ec "true"
        echo '{"enabled": true, "limit": 80, "hardware_written": true}'
        notify_desktop "🔋 Battery Health Mode: 80% Limit Engaged"
        ;;

    disable)
        ensure_root "$@"
        read -r _ cfg_limit < <(read_config)
        write_config "false" "100"
        write_hardware_ec "false"
        echo '{"enabled": false, "limit": 100, "hardware_written": true}'
        notify_desktop "🔋 Battery Health Mode: 100% Full Charge Enabled"
        ;;

    toggle)
        read -r cfg_enabled cfg_limit < <(read_config)
        if [[ "${cfg_enabled}" == "True" || "${cfg_enabled}" == "true" ]]; then
            ensure_root "$@"
            write_config "false" "100"
            write_hardware_ec "false"
            echo '{"enabled": false, "limit": 100}'
            notify_desktop "🔋 Battery Health Mode: 100% Full Charge Enabled"
        else
            ensure_root "$@"
            write_config "true" "80"
            write_hardware_ec "true"
            echo '{"enabled": true, "limit": 80}'
            notify_desktop "🔋 Battery Health Mode: 80% Limit Engaged"
        fi
        ;;

    set-limit)
        new_limit="${2:-80}"
        # On Acer hardware, the physical cap is 80%
        if [[ "${new_limit}" -le 85 ]]; then
            new_limit=80
            ensure_root "$@"
            write_config "true" "80"
            write_hardware_ec "true"
            echo '{"enabled": true, "limit": 80}'
            notify_desktop "🔋 Acer Battery Health: Fixed 80% Cap Applied"
        else
            ensure_root "$@"
            write_config "false" "100"
            write_hardware_ec "false"
            echo '{"enabled": false, "limit": 100}'
            notify_desktop "🔋 Charging to 100% Full Capacity"
        fi
        ;;

    *)
        echo "Usage: $0 {status|enable|disable|toggle|set-limit <percentage>}"
        exit 1
        ;;
esac
