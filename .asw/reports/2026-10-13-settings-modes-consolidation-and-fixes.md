# Settings Window Fixes & Unified System Modes Architecture Report

**Date**: 2026-10-13  
**Status**: Completed & Verified  
**Scope**: `panels/SettingsWindow.qml`, `shell.qml`  

---

## 1. Executive Summary

Resolved lifecycle bugs and syntax errors preventing Settings from opening cleanly, and consolidated all tactical operating modes (**Game Mode**, **The Feather**, **Study Mode**, and **God's Eye View Mode**) into a unified, high-performance **System Modes** category in [`panels/SettingsWindow.qml`](file://$HOME/.config/quickshell/cool-shell/panels/SettingsWindow.qml).

---

## 2. Problem Statement & Issues Fixed

1. **Game Mode Blocked Settings from Opening**:
   - In [`shell.qml`](file://$HOME/.config/quickshell/cool-shell/shell.qml), `onOpenSettingsRequested` checked `if (!ShellState.gameMode)`. When Game Mode was active, clicking the settings button in Control Center or requesting exceptions management completely failed to open Settings.
   - **Fix**: Removed the blocking check so settings can always be opened on-demand, allowing users to configure whitelist exceptions or turn off modes.
2. **`ReferenceError: NetworkDeviceType is not defined`**:
   - In [`panels/SettingsWindow.qml`](file://$HOME/.config/quickshell/cool-shell/panels/SettingsWindow.qml#L41), Wi-Fi device detection relied on an unexported global enum `NetworkDeviceType.Wifi`.
   - **Fix**: Replaced with safe string/property introspection `(d.type && String(d.type).toLowerCase().indexOf("wifi") !== -1) || d.networks !== undefined`.
3. **Scattered / Incomplete Mode Controls**:
   - Game Mode was isolated in category `gamemode` without an input field to add new whitelisted applications.
   - The Feather Mode was buried under Power & Battery.
   - Study Mode and God's Eye Mode were missing from Settings altogether.

---

## 3. Implementation Details

### A. New "System Modes" Tab in `panels/SettingsWindow.qml`
- Placed **System Modes** (`id: "modes"`) as the first category in the sidebar navigation with icon `󰓅`.
- Aliased legacy requests (`gamemode` -> `modes`) so existing IPC calls and UI triggers route directly to the new page.

### B. Consolidating All Modes
1. **Extreme Game Mode (Performance)**:
   - Live status banner with pruned process count (`ShellState.gameModeKilledCount`).
   - Interactive toggle switch (`ShellState.toggleGameMode()`).
   - Whitelist exceptions chip flow with remove buttons (`root.removeException()`).
   - **New App Input Row**: Direct `TextInput` + `+ Add App` button to add custom process names to the protected whitelist (`root.addException()`).
2. **The Feather Mode (Battery Preservation)**:
   - Live status banner with active power governor cap and Hz reduction (30Hz vs 60Hz).
   - Interactive toggle switch (`ShellState.toggleFeatherMode()`).
   - Preset selector pills: **20% Extreme (30Hz)**, **35% Balanced (60Hz)**, and **50% Minimal**.
3. **Study Lockdown Mode**:
   - Focus state banner showing active session countdown or standby indicator.
   - Duration selector pills (**15m**, **30m**, **45m**, **60m**, **90m**) updating `ShellState.studyTargetDuration`.
   - "Lock In 󰌾" action button triggering ceremony / prompt (`scripts/study-mode.py prompt-and-start`).
4. **God's Eye View Mode**:
   - Panoramic system matrix & window overview status.
   - Interactive toggle switch (`ShellState.toggleGodsEye()`).
   - "Open in Browser 󰖟" action button (`ShellState.openGodsEyeBrowser()`).

---

## 4. Verification Matrix

| Test Scenario | Action | Expected Result | Status |
|---|---|---|---|
| Open Modes via IPC | `qs -c cool-shell ipc call settings open "modes"` | Opens Settings directly on System Modes tab | PASS |
| Legacy "gamemode" Alias | `qs -c cool-shell ipc call settings open "gamemode"` | Redirects to System Modes tab | PASS |
| Settings Toggle & Close | `qs -c cool-shell ipc call settings toggle` / `close` | Closes and cleans up overlay | PASS |
| NetworkDeviceType Warning | Inspect scene log upon opening | Zero ReferenceError thrown | PASS |
| Whitelist Exception Addition | Add app via UI input | Appends to JSON exceptions via `game-mode.py` | PASS |
| Study Mode Protection | Verify study mode scripts | Untouched & locked | PASS |
