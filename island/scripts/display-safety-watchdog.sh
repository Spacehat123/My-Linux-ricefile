#!/usr/bin/env bash
# ==============================================================================
# Fail-Safe Display Safety Watchdog for Hyprland
# Guarantees that the system NEVER gets locked out with 0 active displays.
# Only intervenes if ALL screens are completely disabled/blackout.
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

  # 1. Immediate dynamic eval recovery for both HDMI and eDP (mirroring for instant visibility)
  hyprctl eval "
    if hl and hl.monitor then
      hl.monitor({ output = 'HDMI-A-1', mode = '1920x1080@60.0', position = '0x0', scale = 1, disabled = false })
      hl.monitor({ output = 'eDP-1', mode = '1920x1080@60.05', position = '0x0', scale = 1, disabled = false, mirror = 'HDMI-A-1' })
    end
  " >/dev/null 2>&1 || true

  # 2. If a working backup exists, restore it to ~/.config/hypr/monitors.lua
  if [[ -f "$BACKUP_CONFIG" ]]; then
    cp -f "$BACKUP_CONFIG" "$PERSISTENT_MONITORS"
    hyprctl reload >/dev/null 2>&1 || true
  fi

  rm -f "$DEADLINE_FILE"
  command -v notify-send >/dev/null 2>&1 && notify-send -u critical "Display Safety Watchdog" "Zero displays detected. Emergency recovery activated." || true
}

while true; do
  sleep 2

  # Check active monitors count
  active_count=$(hyprctl monitors -j 2>/dev/null | /home/pranc/.local/bin/jq 'length' 2>/dev/null || echo "1")

  # Only intervene if ALL displays are lost (0 active displays)
  if [[ "$active_count" -eq 0 ]]; then
    emergency_recover
    sleep 3
    continue
  fi
done
