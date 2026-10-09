# Settings System Fix & Comprehensive 12-Category Expansion Report

- **Date**: 2026-10-09
- **Workspace**: `/home/pranc/.config/quickshell/cool-shell`
- **Component**: [`panels/SettingsWindow.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/SettingsWindow.qml), [`island/ShellState.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/ShellState.qml), [`components/ControlCenter.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/ControlCenter.qml), [`island/panels/ControlPanel.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/panels/ControlPanel.qml), [`shell.qml`](file:///home/pranc/.config/quickshell/cool-shell/shell.qml)
- **Status**: Verified & Operational

---

## 1. Root Cause Analysis: Settings Icons Failure

### The Issue
- **Symptom**: Clicking the settings gear icon on the Dynamic Island ([`island/panels/ControlPanel.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/panels/ControlPanel.qml)) or on the sidebar ([`components/ControlCenter.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/ControlCenter.qml)) failed to open the Settings window. However, clicking the gear icon on the Game Mode card succeeded in opening Settings.
- **Root Cause**:
  1. In [`island/ShellState.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/ShellState.qml), the signal was declared with a typed parameter:
     ```qml
     signal openSettingsRequested(string category)
     ```
  2. In Qt 6 QML, calling any signal declared with parameters with zero arguments (e.g. `openSettingsRequested()`) throws an immediate JavaScript runtime exception:
     ```text
     Error: Insufficient arguments
     ```
     This caused the signal invocation to abort silently in the engine.
  3. The Game Mode card succeeded solely because its click handler provided the required parameter:
     ```qml
     openSettingsRequested("gamemode") // 1 argument provided -> Success
     ```
  4. In [`shell.qml`](file:///home/pranc/.config/quickshell/cool-shell/shell.qml), `onOpenSettingsRequested` called `settingsWindow.toggle()` when `category` was empty, which failed to guarantee that the modal became visible, and did not close the open sidebar drawers.

---

## 2. Implemented Fixes

### 2.1 Parameter Safety & Helper Method in `ShellState.qml`
In [`island/ShellState.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/ShellState.qml):
1. Added a robust helper function that always guarantees a string argument is passed to the signal:
   ```qml
   signal openSettingsRequested(string category)

   function openSettings(category) {
       close();
       openSettingsRequested(category !== undefined && category !== null ? category : "");
   }
   ```
2. Replaced `show("settings")` to use `openSettings("")`:
   ```qml
   if (name === "settings") {
       openSettings("");
       return;
   }
   ```

### 2.2 Caller Standardization in `ControlPanel.qml` and `ControlCenter.qml`
1. In [`island/panels/ControlPanel.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/panels/ControlPanel.qml):
   Updated the header `IconButton` to call `ShellState.openSettings("")`.
2. In [`components/ControlCenter.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/ControlCenter.qml):
   Updated both `gearTap` (top header gear) and `prefTap` (bottom quick preferences tile) to dismiss the sidebar and call `Island.ShellState.openSettings("")`:
   ```qml
   TapHandler {
       id: gearTap
       onTapped: {
           if (root.desktopState) root.desktopState.setLeftSidebarOpen(false);
           Island.ShellState.openSettings("");
       }
   }
   ```

### 2.3 Window Binding & Drawer Dismissal in `shell.qml`
In [`shell.qml`](file:///home/pranc/.config/quickshell/cool-shell/shell.qml):
1. Bound `SettingsWindow` explicitly to the active screen:
   ```qml
   SettingsWindow {
       id: settingsWindow
       screen: (ShellState.activeScreenName ? Quickshell.screens.find(s => s && s.name === ShellState.activeScreenName) : null) || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
   }
   ```
2. Enhanced `onOpenSettingsRequested` to dismiss any active sidebars and ensure the settings window is shown:
   ```qml
   function onOpenSettingsRequested(category) {
       if (!ShellState.gameMode) {
           if (desktopState) {
               desktopState.setLeftSidebarOpen(false);
               desktopState.setRightSidebarOpen(false);
               desktopState.setBottomBarOpen(false);
           }
           if (category && category !== "") {
               settingsWindow.openCategory(category);
           } else {
               settingsWindow.show();
           }
       }
   }
   ```

---

## 3. Comprehensive 12-Category Settings Redesign

[`panels/SettingsWindow.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/SettingsWindow.qml) was completely overhauled into a modern, Windows-Settings style layout—organized cleanly, privacy-first, and lightweight:

| Category ID | Display Name | Icon | Capabilities & Hardware Bindings |
| :--- | :--- | :--- | :--- |
| **`network`** | **Network & Wi-Fi** | `󰤨` | Master Wi-Fi toggle (`Networking.wifiEnabled`), active connection card (SSID, signal strength, security, IP, disconnect), available network scan list with connect actuators, wired interface status, zero-logging privacy guarantee. |
| **`bluetooth`**| **Bluetooth & Devices**| `󰂯` | Master Bluetooth adapter toggle (`Bluetooth.defaultAdapter.enabled`), adapter discoverability, paired devices list with connect/disconnect/forget actions, active scanning discovery mode. |
| **`display`** | **Display & Brightness**| `󰍹` | Connected monitor topology (`Quickshell.screens` & `Hyprland.monitors`), hardware screen brightness slider (`brightnessctl set <pct>%`), Night Light warm color slider (3000K–6500K) via `hyprsunset` and `shell-actions.sh`, wallpaper launcher. |
| **`audio`** | **Sound & Volume** | `󰕾` | Default output sink switcher (`wpctl set-default`), master volume slider & mute, default microphone selector & volume slider, individual application volume mixer streams. |
| **`mouse`** | **Mouse & Touchpad** | `󰍽` | Real-time pointer sensitivity slider (-1.0 to 1.0) via `hyprctl keyword input:sensitivity`, acceleration profile (Adaptive vs Flat), natural scrolling toggle, tap-to-click toggle, left-handed mode toggle. |
| **`keyboard`** | **Keyboard & Shortcuts**| `󰌌` | Key repeat delay slider (150ms–600ms via `input:repeat_delay`), key repeat rate slider (10–60 cps via `input:repeat_rate`), NumLock by default toggle, tactical shortcuts cheat sheet table. |
| **`appearance`**| **Appearance & Themes**| `󰏘` | Dynamic theme switcher (`Cherry`, `Cyberpunk`, `Nord`, `Catppuccin`, etc.), live color swatch previews, active checkmark indicator, instant desktop-wide restyling. |
| **`gamemode`** | **Game Mode & Rules** | `󰊴` | Extreme Game Mode status & RAM savings telemetry, whitelist exceptions management (Steam, Discord, Spotify, Heroic, OBS, etc.) with add/remove buttons. |
| **`power`** | **Power & Battery** | `󰁹` | Real-time battery charge & AC charging telemetry (`UPower.displayDevice`), inactivity sleep timeout slider (1m to 10m). |
| **`privacy`** | **Privacy & Security** | `󰌾` | Hardware sensor status dashboard (Microphone in use, Camera active, Screen capture active), one-click clipboard wipe (`cliphist wipe`), one-click thumbnail cache clear, 100% offline guarantee. |
| **`a11y`** | **Accessibility & Voice**| `󰐝` | Screen reader TTS toggle (`spd-say`), high contrast mode, animation reduce motion toggle. |
| **`about`** | **System & About** | `󰋽` | Cool-Shell version, Quickshell 0.3.1, Wayland/Hyprland runtime specs, onboarding tour reset button. |

---

## 4. Verification & Testing Matrix

| Test Case | Method | Result |
| :--- | :--- | :--- |
| **Island Header Settings Icon** | Trigger `ShellState.openSettings("")` | **PASS** — Settings opens immediately |
| **Island Navigation Grid Settings** | Trigger `ShellState.show("settings")` | **PASS** — Settings opens immediately |
| **Sidebar Header Gear Icon** | Trigger `gearTap` in Control Center | **PASS** — Sidebar dismisses and Settings opens |
| **Sidebar Preferences Tile** | Trigger `prefTap` in Control Center | **PASS** — Sidebar dismisses and Settings opens |
| **Game Mode Exceptions Gear** | Trigger `exceptTap` in Control Center | **PASS** — Opens directly to `gamemode` category |
| **Game Mode Integrity** | Verified state: `quickshell ipc prop get state gameMode` | **PASS** — `gameMode` remains `false` |
| **12-Category Navigation** | IPC automated loop across all 12 categories | **PASS** — All 12 categories load with zero errors |
| **Hardware Brightness Actuator** | `brightnessctl` probe & slider actuation | **PASS** — Values match and update hardware backlight |
| **Hyprland Input Keywords** | `hyprctl keyword input:...` actuation | **PASS** — Pointer sensitivity, scrolling, and repeat rates apply cleanly |
| **Scope Confinement** | Verified work strictly within `/cool-shell` | **PASS** — 100% isolated to workspace |
