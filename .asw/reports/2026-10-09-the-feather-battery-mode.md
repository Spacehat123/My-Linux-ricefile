# Architectural Report: "The Feather" Absolute Battery Mode (Bare-Minimum Hyprland)

**Date**: 2026-10-09  
**Target Subsystem**: `cool-shell` / `Hyprland` Compositor Power Optimization  
**Author**: Antigravity Assistant  

---

## 1. Executive Summary

Per user direction, "The Feather" mode preserves **Hyprland at absolute bare-minimum resource consumption**, ensuring Wayland/X11 display infrastructure remains alive so the user can launch applications on demand while eliminating all idle and background power drain.

When toggled on:
- **Hyprland is kept running at absolute bare minimum**:
  - `animations:enabled 0` (0 frame interpolation overhead)
  - `decoration:blur:enabled 0` (no GPU dual-cavity shader blurs)
  - `decoration:shadow:enabled 0` (no window shadow texture passes)
  - `misc:vfr 1` (Variable Frame Rate active: 0 FPS rendering when screen is static)
- **Wallpaper engine stopped**: `awww-daemon` is killed, halting video decoding and GPU texture streaming.
- **Display brightness**: Saved and scaled down to battery-preserving `15%`.
- **All non-essential user bloat is pruned**: Browsers (`brave`, `chrome`, `firefox`), Discord, Spotify, Electron apps, media players, and existing background windows are killed.
- **Shell state**: `quickshell` stays alive with live video wallpaper and ambient HUD disabled, preserving the left sidebar toggle so the user can easily switch the mode off.
- **When turned off**:
  - Restores Hyprland animations, blur, shadows, and VFR.
  - Restores original hardware brightness.
  - Relaunches `awww-daemon` and runs `theme-system.sh restore-wallpaper` to return to the full visual Hyprland desktop.

---

## 2. Process Protection & Pruning Ledger

### 2.1 Preserved Infrastructure (Distro Minimum, Hyprland & Shell)

| Category | Binaries / Identifiers | Rationale |
| :--- | :--- | :--- |
| **Compositor & Display** | `Hyprland`, `hyprland`, `start-hyprland`, `Xwayland`, `hypridle`, `hyprlock` | Preserved at bare-minimum (0 animations, VFR 1) so user can launch apps on demand. |
| **Desktop Shell** | `quickshell` | Left sidebar and Control Center remain available to toggle the mode off. |
| **Linux Kernel** | Root/Kernel threads (`kthreadd`, `kworker`, etc.) | Base hardware and driver infrastructure (UID 0 untouched). |
| **Distro Core Daemons** | `systemd`, `(sd-pam)`, `systemd-journald`, `systemd-logind`, `systemd-udevd`, `dbus-daemon`, `dbus-broker`, `polkitd`, `upowerd`, `NetworkManager` | Keeps base distro runtime, D-Bus messaging, power telemetry, and network link active. |
| **Audio Core** | `pipewire`, `wireplumber`, `pipewire-pulse` | Baseline distro audio stack. |
| **Agent / Session** | `antigravity`, `agy`, `python3` | Universal ancestor walk shields active development sessions. |

### 2.2 Pruned Applications (Killed on Enable)

Any non-essential user application is terminated via `SIGTERM` followed by `SIGKILL`:
- Web browsers (`brave`, `chrome`, `firefox`, `chromium`, `zen`, `opera`, `vivaldi`)
- Electron / messaging apps (`discord`, `slack`, `telegram`, `signal`, `element`)
- Media players (`spotify`, `vlc`, `mpv`, `cava`, `glava`)
- Wallpaper daemons (`awww-daemon`, `swww-daemon`)
- Game launchers & office apps (`steam`, `heroic`, `lutris`, `obsidian`)

---

## 3. Activation & Deactivation Lifecycle

### 3.1 On Activation (`feather-mode.py enable` / `feather on`)
1. **State Persistence**:
   Writes `featherMode = True` to `~/.local/state/cool-shell/feather-mode.json`.
2. **Display Brightness**:
   Caches current brightness via `brightnessctl g` and scales hardware brightness to `15%`.
3. **Application Pruning**:
   Sends `SIGTERM` (120ms grace period) followed by `SIGKILL` to all non-distro user applications.
4. **Compositor Minimization**:
   - `hyprctl keyword animations:enabled 0`
   - `hyprctl keyword decoration:blur:enabled 0`
   - `hyprctl keyword decoration:shadow:enabled 0`
   - `hyprctl keyword misc:vfr 1`
5. **Wallpaper Engine**:
   Halts `awww-daemon` via `pkill -TERM awww-daemon`.
6. **Quickshell Invariant**:
   `shell.qml` automatically pauses live video wallpaper playback and ambient HUD drawing via `!ShellState.featherMode`.

### 3.2 On Deactivation (`feather-mode.py disable` / `feather off`)
1. **Compositor Restoration**:
   - `hyprctl keyword animations:enabled 1`
   - `hyprctl keyword decoration:blur:enabled 1`
   - `hyprctl keyword decoration:shadow:enabled 1`
2. **Brightness Restoration**:
   Restores cached brightness level via `brightnessctl set <saved>`.
3. **Wallpaper & Theme Restoration**:
   - Launches `awww-daemon`.
   - Runs `island/scripts/theme-system.sh restore-wallpaper`.
4. **Shell Invariant**:
   `ShellState.featherMode = false` automatically re-engages live wallpapers, ambient HUD, and full desktop experience.

---

## 4. UI & Shell Components

1. **Backend Engine**: [`island/scripts/feather-mode.py`](file:///home/pranc/.config/quickshell/cool-shell/island/scripts/feather-mode.py)
   - Exposes: `status`, `enable` (`on`), `disable` (`off`), `toggle`, `dry-run`.
2. **CLI Shortcut**: [`island/scripts/feather`](file:///home/pranc/.config/quickshell/cool-shell/island/scripts/feather)
   - Usage: `island/scripts/feather off` or `on`.
3. **Left Sidebar Card**: [`components/ControlCenter.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/ControlCenter.qml)
   - **Inactive**: *"Absolute battery • Bare-minimum Hyprland"*.
   - **Active**: *"Active • <N> pruned • Bare Hyprland"*, emerald eco styling, animated pill switch.
4. **Settings Window**: [`panels/SettingsWindow.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/SettingsWindow.qml)
   - Power & Battery settings category reflects bare-minimum Hyprland mode.
5. **IPC Endpoint**: `shell.qml` -> `quickshell ipc -c cool-shell call feather status` / `toggle`.

---

## 5. Non-Destructive Verification Ledger

| Test Case | Execution Command | Result |
| :--- | :--- | :--- |
| **Python Compilation** | `python3 -m py_compile island/scripts/feather-mode.py` | Pass (Exit 0) |
| **Dry-Run Inspection** | `python3 island/scripts/feather-mode.py dry-run` | Pass (Exit 0). Shielded 41 essential processes (Hyprland, Xwayland, quickshell, systemd, dbus, polkit, upowerd, pipewire, agy). Identified 32 user bloat candidates to prune. |
| **Quickshell IPC Query** | `quickshell ipc -c cool-shell call feather status` | Pass (Exit 0). Returned `{"success": true, "enabled": false, "killedCount": 0}`. |
| **Live Killing Omission** | Invariant respected | Prevented active development session termination. |
