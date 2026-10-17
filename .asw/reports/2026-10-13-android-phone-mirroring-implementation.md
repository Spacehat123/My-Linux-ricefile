# Android Phone Mirroring & Filtered File Bridge Implementation Report

**Date**: 2026-10-13  
**Author**: Antigravity  
**Target**: Cool-Shell (Hyprland + Quickshell)  
**Status**: Completed & Verified  

---

## 1. Executive Summary

This engineering implementation delivers an Apple macOS Sequoia-style Android Screen Mirroring and Filtered File Bridge system directly integrated into Cool-Shell. The feature enables floating screen mirroring with native PC mouse and physical keyboard input, a bi-directional MIME-filtered file bridge, and real-time telemetry (battery/charging status) in the Dynamic Island and Control Center.

**Absolute Safeguard Adherence**:
- The Study Mode subsystem (`scripts/study-mode.py`, `scripts/study-mode.sh`, and all related QML locks/ceremonies) remains 100% untouched and preserved.

---

## 2. Architecture & Components

```
+-----------------------------------------------------------------------------------+
|                                  Cool-Shell UI                                    |
|   +-----------------------+     +----------------------+     +----------------+   |
|   | Dynamic Island Notch  |     | Left Sidebar Control |     | Collapsed Pill |   |
|   |   (PhonePanel.qml)    |     |    (ControlCenter)   |     |    (Status)    |   |
|   +-----------+-----------+     +----------+-----------+     +-------+--------+   |
|               |                            |                         |            |
|               +----------------------------+-------------------------+            |
|                                            |                                      |
|                                     ShellState.qml                                |
|                                (IPC Handler: "phone")                             |
+--------------------------------------------+--------------------------------------+
                                             |
                   +-------------------------+-------------------------+
                   |                                                   |
                   v                                                   v
         scripts/phone-ctl.sh                               scripts/phone-mirror.sh
      (CLI & Lifecycle Manager)                           (Hardware-Framed Scrcpy)
                   |                                                   |
                   +---------------+                                   |
                                   |                                   v
                                   v                      scripts/scrcpy-adb-filter.sh
                     scripts/phone-bridge-daemon.py          (MIME Whitelist Proxy)
                      (Battery sync & Auto-Pull)                       |
                                   |                                   v
                                   +--------------+                    |
                                                  |                    |
                                                  v                    v
                                          Android Device (USB / Wi-Fi ADB)
```

### Component Breakdown

1. **`scripts/scrcpy-adb-filter.sh`**:
   - Acts as an ADB interceptor proxy provided to scrcpy via `$ADB`.
   - Passes all normal ADB commands with 0ms latency.
   - For `adb push`, inspects the source file's real MIME type via `file -b --mime-type`.
   - Whitelist allowed: Images (`image/*`), Audio (`audio/*`), Video (`video/*`), Documents (`pdf`, `txt`, `docx`, `xlsx`, `pptx`, etc.), and Android Application Packages (`apk`).
   - Automatically blocks shell scripts (`text/x-shellscript`), ELF binaries (`application/x-pie-executable`, `application/x-executable`), and unknown binaries, immediately dispatching warning notifications to Quickshell Dynamic Island.

2. **`scripts/phone-mirror.sh`**:
   - Launches `scrcpy` with borderless Apple-style window parameters:
     - `--window-title="CoolPhone"`
     - `--window-borderless`
     - `--turn-screen-off` (keeps phone screen dark to conserve battery)
     - `--stay-awake` (prevents device sleep while mirrored)
     - `--keyboard=uhid` and `--mouse=uhid` (kernel-level USB HID emulation, preventing the software touch keyboard from appearing on the phone screen)
     - High fidelity video stream at 60 FPS, 16 Mbps bitrate, 40ms low-latency audio buffer.

3. **`scripts/phone-bridge-daemon.py`**:
   - Polls battery percentage and charging state via ADB `dumpsys battery` and publishes telemetry to Quickshell via IPC.
   - Watches `/sdcard/SendToPC/` on Android. Any photo or document dropped into this folder from the phone is automatically pulled to `~/Downloads/Phone/`, registered into Cool-Shell Stash Shelf, and announced via Dynamic Island toast.

4. **`scripts/phone-ctl.sh`**:
   - Unified command-line interface: `start`, `stop`, `toggle`, `daemon`, `pair <ip> [port]`, `push <file>`, `status`.

5. **Hyprland Window Rules & Shortcuts (`Other-stuff/hyprland.lua` & `~/.config/hypr/hyprland.lua`)**:
   - Window title `^CoolPhone$`: `float = true`, `size = 380 824`, `keepaspectratio = true`, `rounding = 26`, `opaque = true`, `nodim = true`.
   - Shortcut: `SUPER + ALT + P` triggers `scripts/phone-ctl.sh toggle`.

6. **Quickshell Integration**:
   - `island/ShellState.qml`: Properties `phoneConnected`, `phoneBattery`, `phoneCharging`, `phoneMirrorActive`, and `togglePhoneMirror()`. Added to panel dimensions and cycle ring.
   - `island/panels/PhonePanel.qml`: Native Dynamic Island card with device state, mirror toggle, phone screen off switch, screenshot to shelf, and bridge status.
   - `island/CollapsedStatus.qml`: Displays `📱 [XX% ⚡]` pill when device is connected.
   - `components/ControlCenter.qml`: Quick tile with live connection badge and mirror toggle.
   - `shell.qml`: `IpcHandler { target: "phone" }` exposing `setBattery`, `toggleMirror`, `openPanel`, and `status`.

---

## 3. Verification Matrix

| Test Case | Method | Result | Status |
|---|---|---|---|
| Binary Tool Presence | `which scrcpy adb` | `$HOME/.local/bin/scrcpy`, `$HOME/.local/bin/adb` | PASS |
| MIME Whitelist Enforcement | Push test text file vs shell script | Allowed `.txt` forwarded; Blocked `.sh` rejected with exit 1 & logged | PASS |
| Quickshell Syntax & Load | `quickshell -c cool-shell -d` | Clean load, zero QML type errors | PASS |
| IPC Handler `phone` | `qs -c cool-shell ipc call phone status` | Returns valid status JSON | PASS |
| IPC Battery Sync | `qs -c cool-shell ipc call phone setBattery 85 false true` | Updates ShellState telemetry | PASS |
| Dynamic Island Panel | `qs -c cool-shell ipc call phone openPanel` | Opens `PhonePanel.qml` with no regressions | PASS |
| Study Mode Safeguard | `git diff scripts/study-mode.* components/ControlCenter.qml` | 0 modifications to Study Mode logic | PASS |
