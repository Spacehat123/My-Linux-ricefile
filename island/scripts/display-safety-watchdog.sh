#!/usr/bin/env bash
# ==============================================================================
# Fail-Safe Display Safety Watchdog for Hyprland
# Guarantees that the system NEVER gets locked out or left with 0 active displays.
# ==============================================================================
set -u

LOCK_FILE="/tmp/hypr_display_safety_watchdog.pid"
BACKUP_CONFIG="/tmp/hypr_display_last_working.lua"
DEADLINE_FILE="/tmp/hypr_display_rollback.deadline"
PERSISTENT_MONITORS="$HOME/.config/hypr/monitors.lua"

# Prevent duplicate watchdogs
if [[ -f "$LOCK_FILE" ]]; then
  old_pid=$(cat "$LOCK_FILE" 2>/dev/null || true)
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    exit 0
  fi
fi
echo "$$" > "$LOCK_FILE"

trap 'rm -f "$LOCK_FILE"; exit 0' EXIT INT TERM

emergency_recover() {
  echo "[WATCHDOG $(date)] ZERO ACTIVE DISPLAYS DETECTED! INITIATING EMERGENCY RESTORE..." >&2

  # 1. Immediate dynamic eval recovery for both HDMI and eDP
  hyprctl eval "
    if hl and hl.monitor then
      hl.monitor({ output = 'HDMI-A-1', mode = '1920x1080@60.0', position = '0x0', scale = 1, disabled = false })
      hl.monitor({ output = 'eDP-1', mode = 'preferred', position = '0x0', scale = 1, disabled = false })
    end
  " >/dev/null 2>&1

  # 2. If a working backup exists, restore it to ~/.config/hypr/monitors.lua
  if [[ -f "$BACKUP_CONFIG" ]]; then
    cp -f "$BACKUP_CONFIG" "$PERSISTENT_MONITORS"
    hyprctl reload >/dev/null 2>&1 || true
  fi

  rm -f "$DEADLINE_FILE"
}

rollback_previous() {
  echo "[WATCHDOG $(date)] ROLLBACK DEADLINE EXPIRED! RESTORING LAST WORKING CONFIG..." >&2
  if [[ -f "$BACKUP_CONFIG" ]]; then
    cp -f "$BACKUP_CONFIG" "$PERSISTENT_MONITORS"
    # Re-apply via lua eval
    lua_code=$(cat "$BACKUP_CONFIG")
    hyprctl eval "$lua_code" >/dev/null 2>&1 || true
    hyprctl reload >/dev/null 2>&1 || true
  else
    # Emergency fallback: ensure both monitors enabled
    emergency_recover
  fi
  rm -f "$DEADLINE_FILE"
  command -v notify-send >/dev/null 2>&1 && notify-send -u critical "Display Switcher" "Display reverted automatically to safe configuration."
}

while true; do
  sleep 2

  # Check active monitors count
  active_count=$(hyprctl monitors -j 2>/dev/null | /home/pranc/.local/bin/jq 'length' 2>/dev/null || echo "1")

  if [[ "$active_count" -eq 0 ]]; then
    emergency_recover
    sleep 3
    continue
  fi

  # Check timeout rollback deadline
  if [[ -f "$DEADLINE_FILE" ]]; then
    deadline=$(cat "$DEADLINE_FILE" 2>/dev/null || echo "0")
    current_time=$(date +%s)
    if [[ "$current_time" -ge "$deadline" && "$deadline" -gt 0 ]]; then
      rollback_previous
    fi
  fi
done
