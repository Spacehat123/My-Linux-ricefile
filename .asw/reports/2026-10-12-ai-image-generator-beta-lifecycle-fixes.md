# AI Image Generator Lifecycle & Wiring Fixes (Beta Baseline)

**Date**: 2026-10-12  
**Status**: Completed (Beta Stored)  
**Author**: Antigravity  

---

## 1. Executive Summary

This report documents the resolution of race conditions, desktop viewer integration issues, and IPC state retention bugs in the AI Image Studio component of Cool-Shell. As directed, the 512×512 Realistic Vision v5.1 + LCM-LoRA pipeline has been cleanly wired, hardened against concurrent instances, verified against Quickshell IPC, and parked at a solid **Beta** baseline without running heavy GPU inference passes.

---

## 2. Root Cause Analysis

### 2.1 Island Stuck on "Generating Image..."
1. **Missing Client-Side Notification**: [`scripts/image-engine.py`](file://$HOME/.config/quickshell/cool-shell/scripts/image-engine.py) (the client process spawned by Quickshell via `execDetached`) was exiting without issuing IPC notifications to reset `IslandHub.aiGenerating` to `false`. If the daemon hit a socket timeout (>120s) or encountered an error, the Dynamic Island was left permanently in the generating state.
2. **Daemon Timeout Drop under System Load**: In [`scripts/image-daemon.py`](file://$HOME/.config/quickshell/cool-shell/scripts/image-daemon.py), `notify_island_ai` had a strict `timeout=1` second. Under 100% CPU/GPU inference load, IPC subprocess calls taking slightly longer were timed out and silently caught by `except Exception: pass`, dropping the completion signal.

### 2.2 Swappy Viewer Not Opening
1. **Missing Client Viewer Call**: [`scripts/image-engine.py`](file://$HOME/.config/quickshell/cool-shell/scripts/image-engine.py) received the completed file path from the daemon but exited after printing to stdout, without launching any image viewer.
2. **Daemon Environment Isolation**: The background daemon, running as a detached session (`start_new_session=True`), attempted to launch `swappy` in its own environment context where desktop display variables may not match user session requirements, and discarded all output.

### 2.3 Daemon Startup Race Conditions
1. **Premature Socket Check**: When <kbd>SUPER + G</kbd> triggered `--preload` while the user was typing a prompt, the daemon began loading model weights (15–20s). Because the UNIX socket `/tmp/cool-shell-image.sock` was previously bound *after* `load_pipeline()`, subsequent requests (e.g. hitting Enter to generate) perceived the socket as absent and spawned a *second* daemon process.
2. Two 2GB model pipelines were loaded into CPU memory simultaneously, creating severe memory contention and race conditions on the socket and PID file.

---

## 3. Implemented Fixes

### 3.1 Single-Instance File Locking & Immediate Socket Binding
In [`scripts/image-daemon.py`](file://$HOME/.config/quickshell/cool-shell/scripts/image-daemon.py):
- Added exclusive file locking via `fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)` on `/tmp/cool-shell-image.lock`. If another daemon process is starting or active, any new daemon invocation terminates immediately.
- The UNIX socket is bound and listening immediately in `start_server()` before model weights are loaded, allowing the kernel socket queue to buffer requests while weights are read into memory.
- Added automatic fallback to `xdg-open` if `swappy` is unavailable.
- Increased IPC notification timeout to 4 seconds with dual fallback to `qs` and `quickshell`.

### 3.2 Client-Side Viewer Launch & Guaranteed Island Reset
In [`scripts/image-engine.py`](file://$HOME/.config/quickshell/cool-shell/scripts/image-engine.py):
- Added `is_daemon_process_alive()` using PID checks to ensure client never spawns redundant daemon processes while one is initializing.
- Increased communication socket timeout to 180s (3 minutes) to accommodate pipeline operations safely.
- Added `open_viewer(path)` directly in the client to spawn `swappy -f <path>` (with `xdg-open` fallback) using the user's active desktop environment (`WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`).
- Wrapped generation execution in a `finally: notify_island_done()` block, guaranteeing that `IslandHub.setAiGenerating(false, "")` is executed on completion, timeout, or failure.

### 3.3 Dynamic Island State & Safety Watchdog
1. In [`island/IslandHub.qml`](file://$HOME/.config/quickshell/cool-shell/island/IslandHub.qml):
   - Added an automated 3-minute safety watchdog timer (`aiSafetyTimer`) that clears `aiGenerating` if no termination message arrives.
   - Cleared `aiStatusMsg` upon completion so the collapsed island pill displays current system metrics cleanly.
   - Renamed collapsed status label from `"󱨊 Generating 1080p..."` to `"󱨊 Generating Image..."`.
2. In [`island/ShellState.qml`](file://$HOME/.config/quickshell/cool-shell/island/ShellState.qml):
   - In `toggleAiDaemon()`, added an active panel check (`if (panel === "ai") return;`) to ensure the daemon is not unloaded while the user is actively typing in the AI prompt box.
3. In [`island/panels/AiPromptPanel.qml`](file://$HOME/.config/quickshell/cool-shell/island/panels/AiPromptPanel.qml):
   - Updated placeholder text to `"Describe the image you want to generate..."` and button label to `"Generate"` to match native 512×512 mode.

---

## 4. Verification Matrix

| Test Scenario | Action / Command | Expected Behavior | Observed Result | Pass/Fail |
|---|---|---|---|---|
| **IPC State Toggle** | `qs -c cool-shell ipc call island setAiGenerating true "Test"` | Island sets `aiGenerating: true` | `{"success":true,"aiGenerating":true}` | **PASS** |
| **IPC State Reset** | `qs -c cool-shell ipc call island setAiGenerating false ""` | Island clears `aiGenerating: false` | `{"success":true,"aiGenerating":false}` | **PASS** |
| **Daemon Status Query** | `./scripts/image-engine.sh --status` | Reports daemon load status | `{"loaded": false}` | **PASS** |
| **Quickshell IPC Introspection** | `qs -c cool-shell ipc show` | All target handlers registered | Targets `notch`, `island`, `control` healthy | **PASS** |

---

## 5. Status & Next Steps

The AI Image Studio lifecycle is parked at **Beta**:
- Model: Realistic Vision v5.1 + LCM-LoRA (Resident in CPU memory when loaded, transferred to CUDA only during diffusion, 0 MB idle VRAM).
- Resolution: Native 512×512.
- Ready for future work on higher resolutions (e.g. 2-stage latent upscaling or tiled super-resolution) whenever desired.
