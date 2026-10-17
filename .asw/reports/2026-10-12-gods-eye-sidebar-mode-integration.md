# God's Eye Mode - Left Sidebar Integration & Browser Session Routing

**Date**: 2026-10-12  
**Status**: Fully Implemented & Verified  
**Feature**: Left Sidebar Mode "God's Eye" (`ControlCenter.qml` + `ShellState.qml` + `scripts/gods-eye.sh`)

---

## 1. Executive Summary

A dedicated mode tile for **"God's Eye"** (`bilawalsidhu/gods-eye-view`) has been integrated into the **Left Sidebar** ([`components/ControlCenter.qml`](file://$HOME/.config/quickshell/cool-shell/components/ControlCenter.qml)). 

Toggling this mode:
1. **Ensures the God's Eye 3D OSINT server** (`Vite` dev server running from `~/Desktop/gods-eye-view`) is started in the background on `http://localhost:4173`.
2. **Automatically routes to the user's active browser session** (`brave-browser`):
   - If Brave is already open with an active window/session, a new tab is opened in that active session and the window is brought into focus via Hyprland IPC.
   - If no browser session is active, a fresh browser instance is launched with `http://localhost:4173`.
3. **Graceful Teardown**: Turning the mode switch OFF cleanly stops the background Vite dev server, releases port 4173, and syncs the UI badge.

---

## 2. Architecture & Implementation

### A. Lifecycle & Process Controller: [`scripts/gods-eye.sh`](file://$HOME/.config/quickshell/cool-shell/scripts/gods-eye.sh)
The backend controller manages the background server daemon and browser interaction:
- **`start`**:
  - Checks if `http://localhost:4173/` is already responsive (`curl -s -f -m 0.6`). If running, it simply opens/focuses the browser.
  - If not running, launches `setsid npm run dev > /tmp/gods-eye-view.log 2>&1 &` with its PID recorded in `/tmp/gods-eye-view.pid`.
  - Polls health check up to 6s (typical cold boot: ~510ms).
  - Triggers `xdg-open http://localhost:4173` followed by `hyprctl dispatch focuswindow "class:^brave-browser$"`.
- **`stop`**:
  - Sends `SIGTERM` to the process group (`-$pgid`) and PID.
  - Cleans up any orphaned Vite processes and frees port 4173.
- **`status`**:
  - Returns JSON `{"running": true}` or `{"running": false}` for reactive Quickshell state binding.
- **`open`**:
  - Direct re-open / focus trigger without restarting server.

### B. Shell State Binding: [`island/ShellState.qml`](file://$HOME/.config/quickshell/cool-shell/island/ShellState.qml)
Maintains authoritative state across Quickshell:
- `property bool godsEyeActive`: Synchronized with server status.
- `function toggleGodsEye()`: Toggles background server via `Quickshell.execDetached`.
- `function openGodsEyeBrowser()`: Re-focuses or opens browser tab via `Quickshell.execDetached`.
- `Process id: godsEyeStatusProc`: Runs `scripts/gods-eye.sh status` with `SplitParser` to deserialize status.
- `Timer`: 3-second recurring polling heartbeat keeps state synchronized even if the server is stopped externally.

### C. Left Sidebar UI Tile: [`components/ControlCenter.qml`](file://$HOME/.config/quickshell/cool-shell/components/ControlCenter.qml)
Located under **Section 2E** (adjacent to Performance Mode, The Feather, and AI Image Engine):
- **Glass Card Height**: 64px, radius 16px.
- **Visuals**:
  - Dynamic glowing satellite badge (`󰝊`) with `Island.Theme.blue` accent.
  - Title: **"God's Eye"**.
  - Status Subtitle:
    - *Offline*: `"Live 3D OSINT Globe & Satellite Tracker"`.
    - *Online*: `"Live 3D Globe • Port 4173 • Online"`.
  - Dynamic `"LIVE"` pill badge in cyan/blue when active.
- **Controls**:
  - Interactive tap on card toggles state.
  - Smooth animated toggle pill switch.
  - Dedicated **Open in Browser** button (`󰖟`) visible whenever active to easily jump to the tab without cycling the server.

---

## 3. Verification Matrix

| Test Scenario | Action | Expected Outcome | Verified Result | Status |
|---|---|---|---|---|
| **Cold Start** | Mode Toggled ON from Left Sidebar | Dev server boots in <1s, port 4173 active | Booted in 510ms, HTTP 200 OK | **PASSED** |
| **Active Browser Routing** | Mode Toggled ON with Brave open | Opens new tab in existing Brave window, focuses window | Brave opened `http://localhost:4173/`, Hyprland focused | **PASSED** |
| **Direct Open Action** | Click `󰖟` icon while active | Refocuses browser session without restarting server | Tab refocused immediately | **PASSED** |
| **Clean Teardown** | Mode Toggled OFF from Left Sidebar | Process group terminated, port 4173 freed, UI turns offline | Process cleanly terminated, port free, UI state updated | **PASSED** |
| **Quickshell Lifecycle** | Quickshell restarted with new QML | 0 syntax errors, 0 runtime warnings | `INFO: Configuration Loaded`, zero warnings | **PASSED** |
