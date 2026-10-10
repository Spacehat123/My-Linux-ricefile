# Verification Report: Hyprland Display Switcher, Lua Config Fix, and Workspace Migration

**Date:** 2026-10-10  
**Environment:** Arch Linux, Hyprland 0.56.2 (Lua Configuration Engine), Quickshell 0.3.1  
**Target Subsystems:**
- `island/scripts/display-switcher.sh`: Mode cycle logic, Lua evaluations, workspace migration, and multi-display output management.
- `island/scripts/display-safety-watchdog.sh`: Non-interfering fail-safe display recovery daemon (emergency recovery only on zero active displays).
- `shell.qml`: `displays` IPC target with `setMode` and `cycle` dispatchers.
- `/home/pranc/.config/hypr/hyprland.lua`: `package.loaded["monitors"] = nil` dynamic reload cache invalidation.

---

## 1. Root Cause Analysis

The user reported severe issues with display switching:
> *"display switcher has too many bugs, it's like one workspace goes to the other screen and this one is black. Can't switch workspace, it's more like extend rather than only pc screen."*

Detailed investigation into Hyprland's runtime state and scripts identified four separate cascading failure mechanisms:

### 1.1 Unwanted 15-Second Watchdog Rollback
- **Problem**: `island/scripts/display-safety-watchdog.sh` was running a 15-second timeout on `/tmp/hypr_display_rollback.deadline`.
- **Impact**: When the user pressed `SUPER + P` to switch to PC Screen Only (`eDP-1`), unless they pressed `SUPER + SHIFT + P` within 15 seconds, the watchdog automatically ran `emergency_recover`. That recovery function enabled *both* displays at `position = '0x0'` with no mirror, immediately forcing the compositor into an unintended overlapping dual-display state.

### 1.2 Fatal Lua Syntax Error in Mirror Mode (`mirrorOf`)
- **Problem**: `display-switcher.sh` generated Lua code specifying `mirrorOf = "HDMI-A-1"`.
- **Impact**: Hyprland's Lua C API rejected this field with `hl.monitor: unknown field 'mirrorOf'`, causing Lua evaluation to crash and fail. The correct field in Hyprland Lua is `mirror = "HDMI-A-1"`. Because of this bug, Duplicate/Mirror mode never functioned.

### 1.3 Missing `disabled = false` Flag on Re-enabled Outputs
- **Problem**: When an output was previously set to `disabled = true`, Hyprland maintained its disabled state unless explicitly overridden with `disabled = false`.
- **Impact**: Attempts to re-enable `eDP-1` or `HDMI-A-1` were silently ignored, leaving monitors disabled and black.

### 1.4 Lua Module Caching on `hyprctl reload`
- **Problem**: In `/home/pranc/.config/hypr/hyprland.lua`, line 14 executed `require("monitors")`. In Lua, modules loaded via `require` are permanently cached in `package.loaded["monitors"]`.
- **Impact**: Modifying `~/.config/hypr/monitors.lua` on disk had zero effect when `hyprctl reload` was called, because Lua simply returned the cached in-memory module.

### 1.5 Missing Workspace Migration Across Displays
- **Problem**: In Hyprland, workspaces are bound to monitor IDs. When an output was disabled (or when entering extend mode), workspaces were not explicitly re-homed to the primary screen.
- **Impact**: Workspaces with active windows (e.g. Brave, terminals) were left assigned to the other monitor. When attempting to switch to those workspaces, Hyprland focused the inactive or disabled monitor, giving the illusion of a frozen/black screen where workspaces could not be selected.

---

## 2. Implemented Architecture & Solutions

### 2.1 Re-architected `display-switcher.sh`
- **Intuitive Cycle Sequence**:
  - `external` (HDMI-A-1 only) → `laptop` (PC Screen Only, eDP-1) → `mirror` (Duplicate Displays) → `extend` (Dual Displays) → `external` (Second Screen Only).
- **Workspace Migration Function (`migrate_workspaces_to`)**:
  - Automatically queries active workspace IDs from `hyprctl workspaces -j`.
  - Dispatches `hl.dsp.workspace.move({ workspace = id, monitor = target_mon })` in Lua for every workspace.
  - Automatically focuses the primary workspace on the target monitor.
- **Correct Lua Fields**:
  - Employs `disabled = false` on active monitors.
  - Employs `mirror = "HDMI-A-1"` on `eDP-1` during Duplicate mode.
- **Dual Persistence**:
  - Writes to both `~/.config/hypr/monitors.lua` (for Lua configuration) and `~/.config/hypr/monitors.conf` (for legacy/nwg-displays compatibility).

### 2.2 Rebuilt `display-safety-watchdog.sh`
- **Zero Involuntary Reversions**: Removed all 15-second deadline countdowns.
- **True Fail-Safe Protection**: Only activates `emergency_recover` if `active_count == 0` (complete signal loss across all displays).
- When emergency recovery triggers, it enables both displays with `mirror = 'HDMI-A-1'` so the user can immediately see their screen without broken workspace boundaries.

### 2.3 Cache Invalidation in `hyprland.lua`
- Inserted `package.loaded["monitors"] = nil` before `require("monitors")` in `/home/pranc/.config/hypr/hyprland.lua`. Every reload now guarantees that `monitors.lua` is re-read from disk.

### 2.4 Quickshell IPC Extension
- Extended the `displays` IPC target in [`shell.qml`](file:///home/pranc/.config/quickshell/cool-shell/shell.qml#L1762-L1775) with `setMode(mode: string)` supporting direct transitions (`laptop`, `pc`, `mirror`, `duplicate`, `extend`, `dual`, `external`, `second`).

---

## 3. Verification Matrix

| Test Case | Command / Action | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **PC Screen Only** | `./display-switcher.sh laptop` | `eDP-1` active, `HDMI-A-1` disabled; all workspaces on `eDP-1` | Confirmed via `hyprctl monitors` and `workspaces` | **PASS** |
| **Duplicate / Mirror** | `./display-switcher.sh mirror` | Both displays active; `eDP-1.mirrorOf = "2"` | Confirmed in `hyprctl monitors all -j` | **PASS** |
| **Extend Displays** | `./display-switcher.sh extend` | `HDMI-A-1` at `0x0`, `eDP-1` at `1920x0` | Confirmed side-by-side coordinates | **PASS** |
| **Second Screen Only** | `./display-switcher.sh external` | `HDMI-A-1` active, `eDP-1` disabled; all workspaces on HDMI | Confirmed via `hyprctl monitors` and `workspaces` | **PASS** |
| **Cycle Sequence** | `./display-switcher.sh cycle` | Moves sequentially: external → laptop → mirror → extend → external | Verified full loop across 4 cycles | **PASS** |
| **Workspace Migration** | Check `hyprctl workspaces -j` | All open workspaces migrate to the active screen | Workspaces 1, 2, 3 moved smoothly without loss | **PASS** |
| **No 15s Rollback** | Wait >30 seconds in mode | Mode stays permanently without reverting | Configuration retained indefinitely | **PASS** |
| **Watchdog Integrity** | `pgrep -fa display-safety-watchdog` | Daemon running in background | Active (PID 84624) | **PASS** |
| **IPC Connectivity** | `qs -c cool-shell ipc call displays cycle` | Calls Quickshell IPC dispatcher cleanly | Returned `{"success":true,"action":"cycle"}` | **PASS** |
