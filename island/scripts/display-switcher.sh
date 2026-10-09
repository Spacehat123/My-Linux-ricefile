#!/usr/bin/env bash
# ==============================================================================
# Fail-Safe Display Switcher for Hyprland
# Switches between output modes: External -> Extend -> Laptop Only -> Mirror
# Includes an automatic 15-second rollback watchdog to prevent lockouts.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_CONFIG="/tmp/hypr_display_last_working.lua"
DEADLINE_FILE="/tmp/hypr_display_rollback.deadline"
MODE_FILE="/tmp/hypr_display_current_mode.txt"
PERSISTENT_MONITORS="$HOME/.config/hypr/monitors.lua"
WATCHDOG_SCRIPT="$SCRIPT_DIR/display-safety-watchdog.sh"

# Ensure watchdog is running
ensure_watchdog() {
  if ! pgrep -f "display-safety-watchdog.sh" >/dev/null 2>&1; then
    python3 -c "import subprocess; subprocess.Popen(['bash', '$WATCHDOG_SCRIPT'], start_new_session=True)" >/dev/null 2>&1 || true
  fi
}

notify_user() {
  local title="$1"
  local msg="$2"
  # Try Island Notch HUD
  quickshell ipc -c cool-shell call island showTransient "$title: $msg" 3500 >/dev/null 2>&1 || true
  # Fallback to desktop notification
  command -v notify-send >/dev/null 2>&1 && notify-send -u normal "$title" "$msg" || true
}

get_connected_monitors() {
  hyprctl monitors all -j | /home/pranc/.local/bin/jq -r '.[].name'
}

confirm_mode() {
  rm -f "$DEADLINE_FILE"
  notify_user "Display Confirmed" "Current display mode kept."
  echo "Display settings confirmed."
}

revert_mode() {
  rm -f "$DEADLINE_FILE"
  if [[ -f "$BACKUP_CONFIG" ]]; then
    cp -f "$BACKUP_CONFIG" "$PERSISTENT_MONITORS"
    lua_code=$(cat "$BACKUP_CONFIG")
    hyprctl eval "$lua_code" >/dev/null 2>&1 || true
    hyprctl reload >/dev/null 2>&1 || true
    notify_user "Display Reverted" "Restored previous working display configuration."
    echo "Reverted to previous configuration."
  else
    # Emergency fallback
    hyprctl eval "hl.monitor({ output = 'HDMI-A-1', mode = '1920x1080@60.0', position = '0x0', scale = 1, disabled = false }); hl.monitor({ output = 'eDP-1', mode = 'preferred', position = '0x0', scale = 1, disabled = false })" >/dev/null 2>&1 || true
    notify_user "Emergency Recovery" "Both displays activated."
  fi
}

cycle_mode() {
  ensure_watchdog

  # Check connected outputs
  local mon_list
  mon_list=$(get_connected_monitors)
  local mon_count
  mon_count=$(echo "$mon_list" | grep -c . || echo "0")

  if [[ "$mon_count" -le 1 ]]; then
    notify_user "Display Switcher" "Only 1 display detected ($mon_list). No external output to switch."
    return 0
  fi

  # Determine current mode
  local cur_mode="external"
  if [[ -f "$MODE_FILE" ]]; then
    cur_mode=$(cat "$MODE_FILE" 2>/dev/null || echo "external")
  else
    # Detect from hyprctl
    local edp_dis
    edp_dis=$(hyprctl monitors all -j | /home/pranc/.local/bin/jq -r '.[] | select(.name=="eDP-1") | .disabled')
    local hdmi_dis
    hdmi_dis=$(hyprctl monitors all -j | /home/pranc/.local/bin/jq -r '.[] | select(.name=="HDMI-A-1") | .disabled')

    if [[ "$edp_dis" == "true" && "$hdmi_dis" == "false" ]]; then
      cur_mode="external"
    elif [[ "$edp_dis" == "false" && "$hdmi_dis" == "true" ]]; then
      cur_mode="laptop"
    else
      cur_mode="extend"
    fi
  fi

  # Cycle to next mode
  local next_mode="extend"
  local mode_title="Extend Displays"
  case "$cur_mode" in
    external)
      next_mode="extend"
      mode_title="Extend Displays (Dual Screen)"
      ;;
    extend)
      next_mode="laptop"
      mode_title="Laptop Screen Only (eDP-1)"
      ;;
    laptop)
      next_mode="mirror"
      mode_title="Mirror Displays (Duplicate)"
      ;;
    mirror|*)
      next_mode="external"
      mode_title="External Screen Only (HDMI-A-1)"
      ;;
  esac

  # 1. First time in cycle sequence: save current working config as rollback target
  if [[ ! -f "$DEADLINE_FILE" ]]; then
    if [[ -f "$PERSISTENT_MONITORS" ]]; then
      cp -f "$PERSISTENT_MONITORS" "$BACKUP_CONFIG"
    fi
  fi

  # 2. Set 15s rollback deadline
  local deadline
  deadline=$(( $(date +%s) + 15 ))
  echo "$deadline" > "$DEADLINE_FILE"

  # 3. Generate new monitors.lua
  local lua_content=""
  case "$next_mode" in
    external)
      lua_content=$(cat <<'EOF'
-- Output Mode: External Screen Only
hl.monitor({
    output = "eDP-1",
    disabled = true
})
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@60.0",
    position = "0x0",
    scale = 1,
    vrr = 0
})
EOF
)
      ;;

    extend)
      lua_content=$(cat <<'EOF'
-- Output Mode: Extend / Dual Screen
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@60.0",
    position = "0x0",
    scale = 1,
    vrr = 0
})
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60.05",
    position = "1920x0",
    scale = 1,
    vrr = 0
})
EOF
)
      ;;

    laptop)
      lua_content=$(cat <<'EOF'
-- Output Mode: Laptop Screen Only
hl.monitor({
    output = "HDMI-A-1",
    disabled = true
})
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60.05",
    position = "0x0",
    scale = 1,
    vrr = 0
})
EOF
)
      ;;

    mirror)
      lua_content=$(cat <<'EOF'
-- Output Mode: Mirror Displays
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@60.0",
    position = "0x0",
    scale = 1,
    vrr = 0
})
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60.05",
    position = "0x0",
    scale = 1,
    mirrorOf = "HDMI-A-1",
    vrr = 0
})
EOF
)
      ;;
  esac

  # Write persistent configuration
  echo "$lua_content" > "$PERSISTENT_MONITORS"
  echo "$next_mode" > "$MODE_FILE"

  # Apply via Hyprland Lua eval
  hyprctl eval "$lua_content" >/dev/null 2>&1 || true
  hyprctl reload >/dev/null 2>&1 || true

  # Notify with countdown info
  notify_user "$mode_title" "Reverting in 15s (Super+Shift+P to keep)"
  echo "Switched to: $mode_title"
}

case "${1:-cycle}" in
  cycle)
    cycle_mode
    ;;
  confirm)
    confirm_mode
    ;;
  revert)
    revert_mode
    ;;
  *)
    echo "Usage: $0 {cycle|confirm|revert}"
    exit 1
    ;;
esac
