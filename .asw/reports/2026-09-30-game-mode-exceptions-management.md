# Game Mode Exceptions Management & UI Deep-Link Verification

**Date:** 2026-09-30  
**Status:** Complete & Verified  
**Scope:** Process Whitelisting, UI Management, Left Sidebar Deep-Link, Zero-Overhead Lifecycle  

---

## 1. Overview

Extreme Game Mode terminates non-essential applications and background bloat to achieve near-zero idle latency and free up maximum RAM. To give users total control over what remains running during gameplay, a complete **Exceptions Management System** has been integrated into `cool-shell`.

Exceptions can be managed through:
1. **Interactive Settings Window UI** ([`panels/SettingsWindow.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/SettingsWindow.qml))
2. **Left Sidebar Direct Deep-Link Button** ([`components/ControlCenter.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/ControlCenter.qml))
3. **IPC CLI Commands** (`qs -c cool-shell ipc call settings open gamemode`)
4. **Standalone Python CLI** (`python3 island/scripts/game-mode.py add-exception <app>`)
5. **JSON State File** (`~/.local/state/cool-shell/game-mode-exceptions.json`)

---

## 2. Architecture & Components

```
Left Sidebar (ControlCenter.qml)
   └── [ 󰒓 Exceptions ] Button
            │
            ▼
ShellState.qml (openSettingsRequested("gamemode"))
            │
            ▼
SettingsWindow.qml (Category: "gamemode")
   ├── Popular App Checkboxes (Steam, Discord, Spotify, OBS, Heroic, Lutris, Brave, MPV)
   ├── Custom Process Text Input ("Type executable name... [Enter]")
   └── Active Whitelist Tags (removable pill badges with '✕')
            │
            ▼
island/scripts/game-mode.py (add-exception / remove-exception / list-exceptions)
            │
            ▼
~/.local/state/cool-shell/game-mode-exceptions.json
```

### Whitelist Preservation Rules
When Game Mode is engaged, `island/scripts/game-mode.py`:
1. Checks the executable name, cmdline, and process comm against the user's exception list.
2. Protects **all descendant processes** of any whitelisted app (e.g., launching a game from Steam or Heroic protects the game engine, proton, wine, and helper sub-processes).
3. Protects **ancestor trees** so parent launchers are not severed.
4. Preserves desktop infrastructure (Hyprland, Quickshell, PipeWire, systemd, D-Bus, portals, polkit, AGY session).

---

## 3. UI Improvements & Fixes

1. **Dedicated Exceptions Button on Game Mode Card:**
   - In [`components/ControlCenter.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/ControlCenter.qml), added an independent `󰒓` settings button right next to the toggle switch.
   - Clicking the button directly opens the Settings Window to the "Game Mode & Rules" tab.
   - Decoupled `TapHandler`s so clicking the gear icon never accidentally triggers Game Mode.

2. **JavaScript String Compatibility Fix:**
   - In [`panels/SettingsWindow.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/SettingsWindow.qml), replaced Python-style `.lower()` calls with JavaScript `.toLowerCase()`.

3. **Row Layout Fix:**
   - Fixed QML warning where checkbox pills inside `Row` had `anchors.right: parent.right`. Now anchored directly to the parent card.

4. **IPC Deep-Linking:**
   - Added typed IPC method `function open(category: string): void` to `shell.qml` under `target settings`.

---

## 4. Hyprland Session Protection Fix (Critical)

### Root Cause
When launching Hyprland from a TTY (e.g. `login` -> `-fish` -> `hyprland`), the login shell `-fish` acts as the systemd-logind session leader for PAM Session 2. 
Originally, `game-mode.py` protected the `hyprland` PID itself, but did not walk up the parent hierarchy. Consequently, `-fish` was flagged as a background process and terminated with SIGTERM. When the session leader shell died, `systemd-logind` terminated the entire user session, causing Hyprland and all desktop processes to exit back to the login prompt.

### Resolution
1. **Universal Ancestor Walk:** For every protected process (Hyprland, Quickshell, PipeWire, AGY, user exceptions), `game-mode.py` now recursively traverses parent process IDs (`ppid`) all the way up to PID 1, immunizing all parent login shells (`-fish`, `-bash`, `-zsh`), session runners, and display managers.
2. **Explicit Login Shell Protection:** Added `name.startswith("-")` and exact matches for `login`, `agetty`, `greetd`, etc., to `ESSENTIAL_EXACT_NAMES`.
3. **Cross-UID Tree Resolution:** `get_all_processes()` reads the entire system `/proc` hierarchy so parent chains that cross UID boundaries (e.g. root `login` -> user `fish`) are never broken.
4. **Verified via Dry-Run:** Confirmed that `hyprland`, `-fish`, `login`, `Xwayland`, `quickshell`, `pipewire`, and terminal sessions are 100% immune from termination.

---

## 5. Verification Matrix

| Test Case | Trigger | Expected Outcome | Status |
|---|---|---|---|
| Exceptions Tab Direct Link | Tap `󰒓` on Left Sidebar Game Mode Card | Opens Settings Window directly to "Game Mode & Rules" | PASSED |
| IPC Deep-Link | `qs -c cool-shell ipc call settings open gamemode` | Settings window opens to `gamemode` tab | PASSED |
| Preset Toggle | Click checkbox for Brave/Steam | Adds/removes app from exceptions file immediately | PASSED |
| Custom Input | Enter custom name in input field | Appends name to JSON exceptions list and renders tag | PASSED |
| Tag Removal | Click `✕` on active tag | Removes process from whitelist | PASSED |
| Zero Overhead | Run `qs -c cool-shell log` | Zero QML binding or anchor warnings | PASSED |
