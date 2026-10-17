#!/usr/bin/env bash
# ==============================================================================
# Robust Display Switcher for Hyprland (Lua Configuration)
# Seamlessly switches between output modes:
#   1. laptop   - PC Screen Only (eDP-1 only, HDMI-A-1 disabled)
#   2. mirror   - Duplicate Displays (eDP-1 mirrors HDMI-A-1)
#   3. extend   - Extend Displays (HDMI-A-1 at 0x0, eDP-1 at 1920x0)
#   4. external - Second Screen Only (HDMI-A-1 only, eDP-1 disabled)
#
# Migrates workspaces automatically to prevent black screens and lost windows.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_CONFIG="/tmp/hypr_display_last_working.lua"
MODE_FILE="/tmp/hypr_display_current_mode.txt"
PERSISTENT_MONITORS_LUA="$HOME/.config/hypr/monitors.lua"
PERSISTENT_MONITORS_CONF="$HOME/.config/hypr/monitors.conf"
WATCHDOG_SCRIPT="$SCRIPT_DIR/display-safety-watchdog.sh"
export PATH="$HOME/.local/bin:$PATH"
JQ_BIN="$(command -v jq || echo jq)"
if ! command -v "$JQ_BIN" >/dev/null 2>&1; then
  JQ_BIN="jq"
fi

# Ensure safety watchdog is active in background
ensure_watchdog() {
  if ! pgrep -f "display-safety-watchdog.sh" >/dev/null 2>&1; then
    python3 -c "import subprocess; subprocess.Popen(['bash', '$WATCHDOG_SCRIPT'], start_new_session=True)" >/dev/null 2>&1 || true
  fi
}

notify_user() {
  local title="$1"
  local msg="$2"
  # Dynamic Island Notch HUD
  quickshell ipc -c cool-shell call island showTransient "$title" 3500 >/dev/null 2>&1 || true
  # Desktop notification
  command -v notify-send >/dev/null 2>&1 && notify-send -u normal "Display Switcher" "$title\n$msg" || true
}

get_connected_monitors() {
  hyprctl monitors all -j | "$JQ_BIN" -r '.[].name'
}

# Migrate all active workspaces to the target monitor so windows never get lost
migrate_workspaces_to() {
  local target_mon="$1"
  local ws_ids
  ws_ids=$(hyprctl workspaces -j 2>/dev/null | "$JQ_BIN" -r '.[].id' 2>/dev/null || true)

  local cur_ws
  cur_ws=$(hyprctl activeworkspace -j 2>/dev/null | "$JQ_BIN" -r '.id' 2>/dev/null || echo "1")

  local lua_mig="
    if hl and hl.dsp and hl.dsp.workspace then
  "
  for id in $ws_ids; do
    if [[ -n "$id" && "$id" != "null" ]]; then
      lua_mig+="      hl.dispatch(hl.dsp.workspace.move({ workspace = $id, monitor = '$target_mon' }))
"
    fi
  done
  lua_mig+="      if hl.dsp.focus then hl.dispatch(hl.dsp.focus({ workspace = $cur_ws })) end
    end
  "

  hyprctl eval "$lua_mig" >/dev/null 2>&1 || true
}

detect_current_mode() {
  local edp_dis
  edp_dis=$(hyprctl monitors all -j 2>/dev/null | "$JQ_BIN" -r '.[] | select(.name=="eDP-1") | .disabled' 2>/dev/null || echo "false")
  local hdmi_dis
  hdmi_dis=$(hyprctl monitors all -j 2>/dev/null | "$JQ_BIN" -r '.[] | select(.name=="HDMI-A-1") | .disabled' 2>/dev/null || echo "false")
  local edp_mirror
  edp_mirror=$(hyprctl monitors all -j 2>/dev/null | "$JQ_BIN" -r '.[] | select(.name=="eDP-1") | .mirrorOf' 2>/dev/null || echo "none")

  if [[ "$edp_dis" == "true" && "$hdmi_dis" == "false" ]]; then
    echo "external"
  elif [[ "$edp_dis" == "false" && "$hdmi_dis" == "true" ]]; then
    echo "laptop"
  elif [[ "$edp_dis" == "false" && "$hdmi_dis" == "false" ]]; then
    if [[ "$edp_mirror" != "none" && "$edp_mirror" != "" && "$edp_mirror" != "null" ]]; then
      echo "mirror"
    else
      echo "extend"
    fi
  else
    cat "$MODE_FILE" 2>/dev/null || echo "external"
  fi
}

apply_mode() {
  local target_mode="$1"
  local mode_title=""
  local mode_desc=""
  local lua_content=""
  local conf_content=""

  case "$target_mode" in
    laptop|pc)
      target_mode="laptop"
      mode_title="PC Screen Only (eDP-1)"
      mode_desc="Laptop display active. External monitor disabled."
      lua_content=$(cat <<'EOF'
-- Output Mode: PC Screen Only (Laptop eDP-1)
hl.monitor({
    output = "HDMI-A-1",
    disabled = true
})
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60.05",
    position = "0x0",
    scale = 1,
    disabled = false,
    vrr = 0
})
EOF
)
      conf_content=$(cat <<'EOF'
# Output Mode: PC Screen Only (Laptop eDP-1)
monitor=HDMI-A-1,disable
monitor=eDP-1,1920x1080@60.05,0x0,1,vrr,0
EOF
)
      ;;

    mirror|duplicate)
      target_mode="mirror"
      mode_title="Duplicate Displays (Mirror)"
      mode_desc="Both displays show identical synchronized desktop."
      lua_content=$(cat <<'EOF'
-- Output Mode: Duplicate Displays (Mirror)
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@60.0",
    position = "0x0",
    scale = 1,
    disabled = false,
    vrr = 0
})
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60.05",
    position = "0x0",
    scale = 1,
    disabled = false,
    mirror = "HDMI-A-1",
    vrr = 0
})
EOF
)
      conf_content=$(cat <<'EOF'
# Output Mode: Duplicate Displays (Mirror)
monitor=HDMI-A-1,1920x1080@60.0,0x0,1,vrr,0
monitor=eDP-1,1920x1080@60.05,0x0,1,mirror,HDMI-A-1,vrr,0
EOF
)
      ;;

    extend|dual)
      target_mode="extend"
      mode_title="Extend Displays (Dual Screen)"
      mode_desc="Extended desktop: HDMI-A-1 (left) + eDP-1 (right)."
      lua_content=$(cat <<'EOF'
-- Output Mode: Extend / Dual Screen
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@60.0",
    position = "0x0",
    scale = 1,
    disabled = false,
    vrr = 0
})
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60.05",
    position = "1920x0",
    scale = 1,
    disabled = false,
    vrr = 0
})
EOF
)
      conf_content=$(cat <<'EOF'
# Output Mode: Extend / Dual Screen
monitor=HDMI-A-1,1920x1080@60.0,0x0,1,vrr,0
monitor=eDP-1,1920x1080@60.05,1920x0,1,vrr,0
EOF
)
      ;;

    external|second|*)
      target_mode="external"
      mode_title="Second Screen Only (HDMI-A-1)"
      mode_desc="External monitor active. Laptop display disabled."
      lua_content=$(cat <<'EOF'
-- Output Mode: Second Screen Only (External HDMI-A-1)
hl.monitor({
    output = "eDP-1",
    disabled = true
})
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@60.0",
    position = "0x0",
    scale = 1,
    disabled = false,
    vrr = 0
})
EOF
)
      conf_content=$(cat <<'EOF'
# Output Mode: Second Screen Only (External HDMI-A-1)
monitor=eDP-1,disable
monitor=HDMI-A-1,1920x1080@60.0,0x0,1,vrr,0
EOF
)
      ;;
  esac

  # Backup previous working lua
  if [[ -f "$PERSISTENT_MONITORS_LUA" ]]; then
    cp -f "$PERSISTENT_MONITORS_LUA" "$BACKUP_CONFIG"
  fi

  # 1. Apply monitor layout via Hyprland Lua eval
  hyprctl eval "$lua_content" >/dev/null 2>&1 || true

  # 2. Persist to disk for reboot & config reloads
  echo "$lua_content" > "$PERSISTENT_MONITORS_LUA"
  echo "$conf_content" > "$PERSISTENT_MONITORS_CONF"
  echo "$target_mode" > "$MODE_FILE"

  # 3. Migrate workspaces so windows never end up on disabled/black displays
  if [[ "$target_mode" == "laptop" ]]; then
    migrate_workspaces_to "eDP-1"
  elif [[ "$target_mode" == "external" || "$target_mode" == "mirror" ]]; then
    migrate_workspaces_to "HDMI-A-1"
  fi

  # 4. Notify user cleanly via Island Notch HUD & desktop notification
  notify_user "$mode_title" "$mode_desc"
  echo "Display switched to: $mode_title ($target_mode)"
}

cycle_mode() {
  ensure_watchdog

  # Check connected outputs
  local mon_list
  mon_list=$(get_connected_monitors)
  local mon_count
  mon_count=$(echo "$mon_list" | grep -c . || echo "0")

  if [[ "$mon_count" -le 1 ]]; then
    notify_user "Display Switcher" "Only 1 display detected ($mon_list). No external output."
    return 0
  fi

  local cur_mode
  cur_mode=$(detect_current_mode)

  # Cycle order:
  # external -> laptop (PC screen only) -> mirror (Duplicate) -> extend (Dual screen) -> external
  local next_mode="laptop"
  case "$cur_mode" in
    external)
      next_mode="laptop"
      ;;
    laptop)
      next_mode="mirror"
      ;;
    mirror)
      next_mode="extend"
      ;;
    extend|*)
      next_mode="external"
      ;;
  esac

  apply_mode "$next_mode"
}

confirm_mode() {
  notify_user "Display Confirmed" "Current display configuration locked."
  echo "Display settings confirmed."
}

revert_mode() {
  if [[ -f "$BACKUP_CONFIG" ]]; then
    local lua_code
    lua_code=$(cat "$BACKUP_CONFIG")
    hyprctl eval "$lua_code" >/dev/null 2>&1 || true
    cp -f "$BACKUP_CONFIG" "$PERSISTENT_MONITORS_LUA"
    notify_user "Display Reverted" "Restored previous display configuration."
  else
    apply_mode "external"
  fi
}

case "${1:-cycle}" in
  cycle)
    cycle_mode
    ;;
  laptop|pc)
    apply_mode "laptop"
    ;;
  mirror|duplicate)
    apply_mode "mirror"
    ;;
  extend|dual)
    apply_mode "extend"
    ;;
  external|second)
    apply_mode "external"
    ;;
  confirm)
    confirm_mode
    ;;
  revert)
    revert_mode
    ;;
  *)
    echo "Usage: $0 {cycle|laptop|mirror|extend|external|confirm|revert}"
    exit 1
    ;;
esac
