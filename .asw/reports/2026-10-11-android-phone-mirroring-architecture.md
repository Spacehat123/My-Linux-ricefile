# Architectural Plan & Specification: Android Phone Mirroring & Filtered File Bridge

**Document ID**: `.asw/reports/2026-10-11-android-phone-mirroring-architecture.md`  
**Date**: 2026-10-11  
**Target Environment**: Arch Linux, Hyprland 0.56.2 (Lua configuration), Quickshell (Cool-Shell QML), `scrcpy` 5.0, `android-tools`  
**Status**: Pending User Approval (Planning & Mapping Phase — Zero Project Code Edited)

---

## 1. Executive Summary

This plan details the implementation of an **Apple-style Android Phone Mirroring and Filtered File Bridge** in **Cool-Shell**.
The system gives you a dedicated, floating phone mirror window on your Linux display with full mouse navigation and mechanical PC keyboard typing into Android, while introducing strict, bidirectional drag-and-drop file filtering (whitelisting only specified file types) and deep Dynamic Island integration.

---

## 2. Architecture & Technical Mechanics

### 2.1 The Mirror Window (Apple-Style Device Frame)
* **Engine**: `scrcpy` launched with:
  * `--window-title="CoolPhone"`
  * `--window-borderless` (eliminates standard OS titlebars/borders)
  * `--turn-screen-off` (keeps physical phone screen completely black, preserving battery, thermals, and privacy while mirrored)
  * `--stay-awake` (prevents phone from locking mid-session)
  * `--keyboard=uhid` (emulates a physical hardware USB HID keyboard at the Linux/Android kernel level; avoids triggering the Android on-screen virtual keyboard)
  * `--mouse=uhid` (native cursor rendering, right-click = Back, middle-click = Home)
  * `--video-bit-rate=16M --max-fps=60 --audio-buffer=40`
* **Hyprland Window Styling**:
  In `Other stuff/hyprland.lua`:
  * `float = true`, `size = "380 824"` (19.5:9 aspect ratio)
  * `keepaspectratio = true` (prevents letterboxing/stretching when resizing)
  * `rounding = 26` (smooth smartphone hardware corner radius)
  * `opaque = true`, `nodim = true` (phone display remains vivid and fully opaque even when unfocused)
  * Can be pinned across workspaces or toggled with a single hotkey (`SUPER + ALT + P`).

---

### 2.2 Bidirectional File Transfer with Strict Whitelisting

#### A. PC $\to$ Phone (Drag-and-Drop with Whitelist Interception)
* **The Problem**: By default, `scrcpy` takes whatever file is dropped onto its window and sends it to Android via `adb push`, without verifying file types.
* **The Solution**: **Surgical ADB Proxy Hook (`scrcpy-adb-filter.sh`)**.
  * `scrcpy` checks the environment variable `$ADB` when invoking ADB commands.
  * We launch `scrcpy` with `ADB=".../scripts/scrcpy-adb-filter.sh"`.
  * For standard subcommands (`devices`, `forward`, `reverse`, `shell`), it calls the real `adb` immediately with 0ms overhead.
  * When a file is dropped, `scrcpy` invokes `adb push <local_file> <target>`.
  * Our filter intercepts this call and runs a MIME-type check:
    * `file --brief --mime-type "$local_file"` (prevents extension spoofing like `.exe` renamed to `.png`).
    * **Approved Categories (Whitelisted)**:
      * **Images**: `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.svg`, `.avif`, `.heic`
      * **Audio**: `.mp3`, `.flac`, `.ogg`, `.wav`, `.aac`, `.m4a`
      * **Video**: `.mp4`, `.webm`, `.mkv`, `.mov`
      * **Documents**: `.pdf`, `.txt`, `.md`, `.epub`, `.docx`, `.xlsx`
    * **If Disallowed** (e.g., binaries, archives, unwanted files):
      * Aborts transfer instantly before pushing to the device.
      * Sends an alert to Cool-Shell’s Dynamic Island:
        `"🚫 Blocked: <filename> is not an allowed file type"` with a red border flash.
    * **If Allowed**:
      * Emits a Dynamic Island notification: `"📤 Sending <filename> to Phone..."`
      * Executes the real `/usr/bin/adb push`.
      * Emits a completion alert on success: `"✅ Sent <filename> to Phone"`.
* **Bonus Cool-Shell DropZone**: Dropping files onto the **Dynamic Island** or **RightSidebar Phone Tile** also validates against this same whitelist before sending.

#### B. Phone $\to$ PC (Reverse Transfer to Linux)
* **The Problem**: In Wayland, you cannot drag a file out of an SDL video window directly onto your desktop because the Android guest OS doesn't negotiate Wayland data sources.
* **The Solution**: **ADB Outbox Watcher Daemon (`phone-bridge-daemon.py`)**.
  1. The daemon creates a designated folder on your phone: `/sdcard/SendToPC/`.
  2. The daemon monitors `/sdcard/SendToPC/` in real time over ADB using Android's native `inotifyd` (zero CPU overhead, event-driven, zero polling delay).
  3. **User Flow**: Inside the mirrored phone window (using your PC mouse), you open your phone's Gallery or Files app, select photos or documents, and share or move them to the `SendToPC` folder.
  4. The daemon immediately detects the file, pulls it to `~/Downloads/Phone/`, verifies the MIME type against the whitelist, and registers it with Cool-Shell’s `ShelfState` (`ShelfPanel.qml`).
  5. The Dynamic Island expands with a smooth ingestion animation: `"📥 Received <filename> from Phone"`.
  6. The file is automatically cleaned up from the phone's outbox staging area.

---

### 2.3 Cool-Shell UI & IPC Integration

1. **Dynamic Island (`island/Notch.qml` & `island/ShellState.qml`)**:
   * **Status Pill**: Shows a clean `📱 [Battery %]` pill in the collapsed bar whenever the phone is plugged in / paired.
   * **Expanded Phone Card**:
     * Battery percentage & charging state.
     * Quick toggle button: **"Mirror Phone"** (starts/stops the mirror window).
     * Quick action toggles: "Screen Off / On", "Take Phone Screenshot", "Send Clipboard".
     * Drop zone: Drag files onto the island to push them directly to phone.
2. **RightSidebar (`panels/RightSidebar.qml` & `components/ControlCenter.qml`)**:
   * A "Phone Mirror" tile in the Control Center deck alongside Ambient and Game Mode.
   * Device status card in Tab 1 (Surfaces/Devices).
3. **IPC Target (`shell.qml`)**:
   * `IpcHandler { target: "phone" }`:
     * `qs -c cool-shell ipc call phone toggleMirror`
     * `qs -c cool-shell ipc call phone pinMirror`
     * `qs -c cool-shell ipc call phone getStatus`

---

## 3. Implementation Plan & File Change Map

| File to Modify / Create | Nature of Change | Purpose |
| :--- | :--- | :--- |
| `scripts/scrcpy-adb-filter.sh` *(New)* | Shell Script | Intercepts `scrcpy`'s ADB calls, inspects MIME types, enforces whitelist, dispatches Island notifications. |
| `scripts/phone-bridge-daemon.py` *(New)* | Python Daemon | Tracks device connection, watches `/sdcard/SendToPC/`, pulls files to `~/Downloads/Phone/`, registers with Shelf. |
| `island/panels/PhonePanel.qml` *(New)* | QML Component | Dynamic Island expanded card for phone controls, battery status, and drop area. |
| `island/ShellState.qml` *(Edit)* | QML Registry | Register `"phone"` panel dimensions (`380x240`) and phone connection properties. |
| `island/CollapsedStatus.qml` *(Edit)* | QML UI | Add `📱 [Battery %]` pill when phone is connected. |
| `shell.qml` *(Edit)* | QML IPC | Add `IpcHandler { target: "phone" }` to expose CLI/keybind actuation. |
| `Other stuff/hyprland.lua` *(Edit)* | Hyprland Config | Add `coolphone-device-frame` window rule (`float`, `keepaspectratio`, `rounding = 26`, `opaque`, `nodim`) and `SUPER + ALT + P` toggle keybind. |

---

## 4. Verification & QA Matrix

| Verification Step | Test Scenario | Expected Outcome |
| :--- | :--- | :--- |
| **Mirror Launch & Input** | Run `scrcpy` with proxy wrapper and phone plugged in. | Window appears with 26px rounded corners, no titlebar. Mouse clicks/scrolls, keyboard types seamlessly. Phone screen stays black. |
| **PC $\to$ Phone Whitelisted File** | Drag `.png` or `.pdf` onto mirror window. | Island announces transfer; file successfully lands in `/sdcard/Download/`. |
| **PC $\to$ Phone Blocked File** | Drag disallowed file (e.g., `.sh`, `.exe`, `.tar.gz`) onto mirror window. | Filter halts transfer before ADB push; Island flashes red warning: `"Blocked: File type not permitted"`. |
| **Phone $\to$ PC Reverse Transfer** | In phone Gallery/Files, move photo to `SendToPC`. | Daemon detects via inotify, pulls file into `~/Downloads/Phone/`; Island shows ingestion animation; file appears in Cool-Shell Shelf. |
| **Workspace Transition & Pinning** | Press `SUPER + ALT + P` (or pin toggle). | Phone mirror window pins floating across workspaces or unpins cleanly. |

---
