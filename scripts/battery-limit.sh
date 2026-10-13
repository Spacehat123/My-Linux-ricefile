#!/usr/bin/env bash
# ==============================================================================
# Cool-Shell Battery Charge Limit Actuator
# Supports Linux sysfs (charge_control_end_threshold), Acer WMI, and Acer EC registers
# ==============================================================================

set -euo pipefail

CONFIG_DIR="${HOME}/.config/cool-shell"
CONFIG_FILE="${CONFIG_DIR}/battery-limit.json"
mkdir -p "${CONFIG_DIR}"

# Initialize config if absent
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo '{"enabled": false, "limit": 80}' > "${CONFIG_FILE}"
fi

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
}

# Hardware detection and application
apply_hardware_limit() {
    local target_limit="$1"
    local is_enabled="$2"
    
    local val=100
    if [[ "${is_enabled}" == "true" ]]; then
        val="${target_limit}"
    fi

    # 1. Standard Linux kernel charge control sysfs
    for f in /sys/class/power_supply/BAT*/charge_control_end_threshold \
             /sys/class/power_supply/BAT*/charge_control_limit_max \
             /sys/class/power_supply/BAT*/charge_stop_threshold; do
        if [[ -w "$f" ]]; then
            echo "$val" > "$f" 2>/dev/null && return 0
        elif [[ -f "$f" ]]; then
            pkexec sh -c "echo '$val' > '$f'" 2>/dev/null && return 0
        fi
    done

    # 2. Acer WMI battery driver
    for f in /sys/bus/wmi/drivers/acer-wmi-battery/health_mode \
             /sys/bus/wmi/devices/*/health_mode; do
        local wmi_val=0
        if [[ "${is_enabled}" == "true" && "${val}" -le 80 ]]; then
            wmi_val=1
        fi
        if [[ -w "$f" ]]; then
            echo "$wmi_val" > "$f" 2>/dev/null && return 0
        elif [[ -f "$f" ]]; then
            pkexec sh -c "echo '$wmi_val' > '$f'" 2>/dev/null && return 0
        fi
    done

    # 3. Direct Acer Embedded Controller (EC) register 0x03 fallback
    if [[ -d "/sys/kernel/debug/ec/ec0" || -e "/dev/ec" ]]; then
        # 0x51 for limit on (80%), 0x11 for limit off (100%)
        local ec_val=17 # 0x11
        if [[ "${is_enabled}" == "true" ]]; then
            ec_val=81 # 0x51
        fi
        python3 -c '
import os, sys
val = int(sys.argv[1])
try:
    if os.path.exists("/sys/kernel/debug/ec/ec0/io"):
        with open("/sys/kernel/debug/ec/ec0/io", "wb+") as f:
            f.seek(0x03)
            f.write(bytearray([val]))
            sys.exit(0)
    elif os.path.exists("/dev/ec"):
        with open("/dev/ec", "wb+") as f:
            f.seek(0x03)
            f.write(bytearray([val]))
            sys.exit(0)
except Exception:
    pass
sys.exit(1)
' "$ec_val" 2>/dev/null && return 0
    fi

    return 0
}

action="${1:-status}"

case "${action}" in
    status)
        read -r cfg_enabled cfg_limit < <(read_config)
        
        # Check current capacity
        cap=100
        if [[ -f /sys/class/power_supply/BAT1/capacity ]]; then
            cap="$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 100)"
        fi
        
        python3 -c '
import json, sys
enabled = (sys.argv[1].lower() == "true")
limit = int(sys.argv[2])
cap = int(sys.argv[3])
print(json.dumps({
    "enabled": enabled,
    "limit": limit,
    "current_capacity": cap
}))
' "${cfg_enabled}" "${cfg_limit}" "${cap}"
        ;;

    enable)
        read -r _ cfg_limit < <(read_config)
        write_config "true" "${cfg_limit}"
        apply_hardware_limit "${cfg_limit}" "true"
        echo "{\"enabled\": true, \"limit\": ${cfg_limit}}"
        ;;

    disable)
        read -r _ cfg_limit < <(read_config)
        write_config "false" "${cfg_limit}"
        apply_hardware_limit "${cfg_limit}" "false"
        echo "{\"enabled\": false, \"limit\": ${cfg_limit}}"
        ;;

    toggle)
        read -r cfg_enabled cfg_limit < <(read_config)
        if [[ "${cfg_enabled}" == "True" || "${cfg_enabled}" == "true" ]]; then
            write_config "false" "${cfg_limit}"
            apply_hardware_limit "${cfg_limit}" "false"
            echo "{\"enabled\": false, \"limit\": ${cfg_limit}}"
        else
            write_config "true" "${cfg_limit}"
            apply_hardware_limit "${cfg_limit}" "true"
            echo "{\"enabled\": true, \"limit\": ${cfg_limit}}"
        fi
        ;;

    set-limit)
        new_limit="${2:-80}"
        if [[ "${new_limit}" -lt 50 ]]; then new_limit=50; fi
        if [[ "${new_limit}" -gt 100 ]]; then new_limit=100; fi
        
        read -r cfg_enabled _ < <(read_config)
        write_config "${cfg_enabled}" "${new_limit}"
        if [[ "${cfg_enabled}" == "True" || "${cfg_enabled}" == "true" ]]; then
            apply_hardware_limit "${new_limit}" "true"
        fi
        echo "{\"enabled\": ${cfg_enabled,,}, \"limit\": ${new_limit}}"
        ;;

    *)
        echo "Usage: $0 {status|enable|disable|toggle|set-limit <50-100>}"
        exit 1
        ;;
esac
