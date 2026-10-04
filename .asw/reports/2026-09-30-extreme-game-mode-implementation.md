# Extreme Game Mode & Total Resource Optimization Report

**Date:** 2026-09-30  
**Status:** ✅ **OPERATIONAL & VERIFIED**  
**Workspace:** `/home/pranc/.config/quickshell/cool-shell`  
**Author:** Antigravity Autonomous Pair Programming Agent  

---

## 1. Requirement & Directive

The user requested an aggressive, zero-compromise **Extreme Game Mode**:
1. **Kill all user processes and applications**, including open workspace windows (e.g. Brave, Dolphin, Mission Center, Discord, Steam, background electron apps), to reclaim all available system memory.
2. **Preserve system integrity**: Hyprland, Xwayland, PipeWire/WirePlumber (sound for games), systemd, D-Bus, polkit, portals, and the active terminal/AGY pair-programming session must remain running.
3. **Limit Quickshell surfaces**: Hide and unmap all sidebars (Left and Right), floating bottom dock, ambient layer, desktop transitions, edge triggers, and settings windows.
4. **Isolate Dynamic Island**: The Dynamic Island becomes the sole active UI element, showing only `󰊴 GAME MODE` when collapsed, with a single action when clicked: **"Turn Game Mode Off"**.
5. **Compositor Tuning**: Disable compositor blur and animations to reduce input latency to near-zero.
6. **Reclaim RAM**: Maximize free memory (observed jump from 671 MiB free to **2.1 GiB free**, with 4.0 GiB available).

---

## 2. Architecture & Implementation

### A. Process Termination Engine (`island/scripts/game-mode.py`)
- **Location:** [`island/scripts/game-mode.py`](file:///home/pranc/.config/quickshell/cool-shell/island/scripts/game-mode.py)
- **Whitelisted Essential Infrastructure:**
  - `Hyprland`, `hyprlock`, `hypridle`, `Xwayland`
  - `quickshell` (PID of host shell)
  - `pipewire`, `wireplumber`, `pipewire-pulse`
  - `systemd`, `dbus-broker`, `dbus-daemon`, `polkitd`, `rtkit-daemon`
  - `upowerd`, `NetworkManager`, `bluetoothd`
  - `xdg-desktop-portal*`
  - Active AGY / Antigravity CLI process and its hosting terminal tree (`kitty`, `bash`, `fish`) so the pair programming session remains alive.
- **Candidate Elimination:**
  - Evaluates all processes owned by `$UID` via `/proc`.
  - Sends `SIGTERM` followed by `SIGKILL` to all non-whitelisted user processes (including open workspace browsers, renderers, file managers, GPU utility processes, background electron apps).
  - Optimizes Hyprland: `hyprctl keyword animations:enabled 0` and `hyprctl keyword decoration:blur:enabled 0`.
- **Restoration:**
  - When disabled, restores `animations:enabled 1`, `decoration:blur:enabled 1`, and restarts `awww-daemon`.

### B. Dynamic Island Game Mode Panel (`island/panels/GameModePanel.qml`)
- **Location:** [`island/panels/GameModePanel.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/panels/GameModePanel.qml)
- **Silhouette:** 300×84 floating glass card with `Theme.radiusCard`.
- **Single Option Layout:**
  - Header: `󰊴 Game Mode Active` with a `Max FPS` badge.
  - Prominent button: **`[ 󰈆 Turn Game Mode Off ]`** with crimson hover highlight and tactile click scaling.
  - Clicking this button immediately triggers `ShellState.toggleGameMode()`.

### C. Dynamic Island Integration (`island/Notch.qml`)
- **Location:** [`island/Notch.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml)
- When `ShellState.gameMode` is `true`:
  - `notchBody` border glows with `Theme.red`.
  - `CollapsedStatus` (time, battery, volume, unread badges) is completely hidden.
  - Replaced by a minimal Game Mode status: `󰊴 GAME MODE`.
  - Clicking the collapsed pill directly routes to `ShellState.show("gamemode")`.
  - All other panel requests (control, launcher, notes, todo, media, weather, etc.) are locked out.

### D. Global Surface Suspension (`shell.qml`)
- **Location:** [`shell.qml`](file:///home/pranc/.config/quickshell/cool-shell/shell.qml)
- When `ShellState.gameMode` is `true`:
  - `leftSidebar.open` is forced to `false` and unmapped.
  - `rightSidebar.open` is forced to `false` and unmapped.
  - `bottomBar.open` is forced to `false` and unmapped.
  - `triggerWindow.visible` is set to `false`.
  - `ambientLayer.enabled` is set to `false`.
  - `settingsWindow` is automatically hidden via `onGameModeToggled`.
  - Forces Qt Quick garbage collection (`gc()`).

---

## 3. Live Verification Results

1. **Process Termination & RAM Drop:**
   - Pre-activation: 4.4 GiB used, 671 MiB free.
   - Post-activation: 3.1 GiB used, **2.1 GiB free** (4.0 GiB available memory).
   - 24 non-essential background processes and open application instances terminated (including all Brave browser renderers, Dolphin, MissionCenter, and awww-daemon).
2. **System Stability:**
   - Hyprland, Quickshell, PipeWire audio, and AGY session remained fully responsive.
3. **Dynamic Island Isolation:**
   - Collapsed island displayed `󰊴 GAME MODE` with crimson border glow.
   - Expanding the island revealed solely the `GameModePanel` with the "Turn Game Mode Off" button.
4. **Compositor Restoration:**
   - Disabling Game Mode successfully restored `animations:enabled` (true), `decoration:blur:enabled` (true), restarted `awww-daemon`, and brought back all sidebars and dock triggers.
