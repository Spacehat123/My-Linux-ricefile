# Region & Window Screen Recording Verification Report

**Date**: 2026-10-10  
**Topic**: Draggable Area & Window Selection for Screen Recording  
**Target Systems**: `island/panels/CapturePanel.qml`, `island/CaptureSelector.qml`, `island/Backend.qml`, `island/scripts/shell-actions.sh`, `shell.qml`

---

## 1. Executive Summary

Previously, the screen recording option in the Capture subsystem was constrained exclusively to recording the entire display without an interactive region or window picker. Users requested the ability to select what part of the screen to record by dragging a selection rectangle—mirroring the behavior of still screenshot region selection.

The subsystem has been enhanced to provide complete parity between Still screenshot capture and Screen recording:
- **Display**, **Window**, and **Area** (region) selection modes are now fully supported in both Still and Record modes.
- Dragging to select a custom bounding box in Record mode displays a themed red selection rectangle with a `󰑊 W × H` dimensions badge and passes normalized geometry to `wf-recorder -g`.
- Picking a window in Record mode highlights the target window with a red outline and records the window's exact coordinates.
- Encoder dimension safety is enforced: odd width/height dimensions are automatically rounded to even multiples of 2, preventing YUV420p video encoder crashes.
- Audio capture (microphone/system audio) is fully toggleable via a dedicated interactive pill within the panel viewfinder and passes `-a` to `wf-recorder` when enabled.
- Recording stop signals cleanly send `SIGINT` to `wf-recorder`, finalizing MP4 container headers without corruption.

---

## 2. Key Architecture & File Modifications

### 2.1 Backend Script (`island/scripts/shell-actions.sh`)
- **`record-start-geometry`**:
  - Validates and parses `$x`, `$y`, `$width`, `$height`, and `$audio_flag`.
  - Enforces codec safety: `width=$(( (width / 2) * 2 ))` and `height=$(( (height / 2) * 2 ))`.
  - Spawns `wf-recorder -g "$x,$y ${width}x${height}" -f "$output"` with optional `-a`.
  - Records PID to `$recording_pid_file` and output path to `${recording_pid_file}.target`.
  - Emits desktop notification (`notify-send`) and stdout token `recording-started`.
- **`record-start`**:
  - Supports full-screen recording with optional audio flag.
- **`record-stop`**:
  - Gracefully stops `wf-recorder` with `kill -INT "$pid"`, cleans up PID/target state files, notifies user with the destination path, and outputs `recording-stopped`.
- **`record-toggle`**:
  - Accepts audio flag and toggles recording state.

### 2.2 Core Logic (`island/Backend.qml`)
- Added `property string captureAction: "still"` (`"still"` vs `"record"`).
- Added `property bool recordAudio: true` for microphone state persistence.
- Added `startRecording(mode, withAudio)`: dispatches window candidates query for `"window"`, enables selector overlay for `"region"`, or dispatches `record-start full` for `"full"`.
- Added `stopRecording()`: triggers `record-stop` helper.
- Updated `toggleRecording(mode, withAudio)`: checks `recording` boolean and toggles appropriately.
- Updated `geometryCaptureDelay`: checks `root.captureAction === "record"` and dispatches `record-start-geometry` with audio flag or `capture-geometry` (grim).

### 2.3 Interactive Visual Overlay (`island/CaptureSelector.qml`)
- Binds border colors and badges to `Backend.captureAction`:
  - When `captureAction === "record"`, selection border glows `Theme.red`, and the dimensions badge shows `󰑊 W × H` in red.
  - Candidate windows glow red when hovered during window recording.
  - When `captureAction === "still"`, selection border glows `Theme.primary`.

### 2.4 Panel Interface (`island/panels/CapturePanel.qml`)
- Unified the left target selection column across both Still and Record modes:
  - Users can select **Display** (`full`), **Window** (`window`), and **Area** (`region`) in both modes.
  - Highlight and accent colors adapt dynamically (`Theme.primary` for Still, `Theme.red` for Record).
- Integrated an interactive Microphone pill in the viewfinder header:
  - Displays current mic state (`[ 󰍬 Mic On ]` vs `[ 󰍭 Mic Off ]`).
  - Supports click and keyboard activation (`Return`/`Space`).
  - Unmutes Pipewire audio source automatically when turning Mic On.
- Updated viewfinder frame preview:
  - Dynamically resizes for `"region"` (111x38 with glowing corner brackets) and `"window"` (126x48 with title dots) in both Still and Record modes.
  - Shows centered red recording dot/square when in Record mode.
- Action button adapts label, subtitle, and action:
  - If recording is active: "Stop recording" (`Backend.stopRecording()`).
  - If recording is inactive: "Record area/window/display" (`Backend.startRecording()`).
  - Delay timer (`recordDelay`) closes the Island before launching overlay/recording.

### 2.5 IPC & Shortcuts (`shell.qml`)
- Updated `recordingShortcutDelay` to call `Backend.toggleRecording("region", Backend.recordAudio)`.
- Added `cancel()` to `IpcHandler { target: "capture" }` allowing programmatic dismissal of active selectors.

---

## 3. Verification Matrix

| Test Scenario | Action / Input | Expected Result | Result |
| :--- | :--- | :--- | :--- |
| **Bash Syntax** | `bash -n island/scripts/shell-actions.sh` | Clean exit code 0 | **PASS** |
| **Geometry Recording CLI** | `shell-actions.sh record-start-geometry 100 100 200 200 audio` | `wf-recorder` launched with `-g "100,100 200x200" -a`, outputs `recording-started` | **PASS** |
| **Record Status CLI** | `shell-actions.sh record-status` | Outputs `recording-active` | **PASS** |
| **Record Stop CLI** | `shell-actions.sh record-stop` | `wf-recorder` receives `SIGINT`, outputs `recording-stopped`, MP4 created | **PASS** |
| **Codec Dimension Safety** | Arbitrary dimensions (odd numbers) | Auto-rounded to even values, prevents encoder crash | **PASS** |
| **Quickshell QML Load** | `quickshell kill -c cool-shell && quickshell -c cool-shell -d` | Reloads daemon, "Configuration Loaded" with 0 errors | **PASS** |
| **Panel Toggle IPC** | `quickshell ipc -c cool-shell call notch toggle capture` | Capture panel displays with Display, Window, Area | **PASS** |
| **Capture Cancel IPC** | `quickshell ipc -c cool-shell call capture cancel` | Cleanly resets active selection state without side effects | **PASS** |

---

## 4. Conclusion & Next Steps

The user request to record specific parts of the screen via draggable region selection has been implemented end-to-end, tested, and verified.
No further code changes are required for this capability.
