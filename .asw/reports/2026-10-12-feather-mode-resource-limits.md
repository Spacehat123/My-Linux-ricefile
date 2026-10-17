# Feather Mode Resource Limits Architecture & Verification Report

**Date**: 2026-10-12  
**Author**: Antigravity Pair-Programming Agent  
**Host**: Acer Aspire A715-42G (AMD Ryzen 5 5500U, Lucienne iGPU, NVIDIA GeForce GTX 1650 Mobile)  
**Status**: Implemented & Verified  

---

## 1. Executive Summary

Feather Mode ("The Feather" absolute battery optimization system) previously handled bloat pruning, compositor wallpaper termination, and display dimming. However, it lacked active kernel-enforced compute bandwidth caps and dynamic compositor GPU throttling.

This implementation introduces selectable **Resource Limits** (specifically **20% Maximum Battery** and **35% Balanced Eco** caps), enforcing:
1. **Linux CFS Cgroup Bandwidth Quota** on systemd user slice `app.slice` without requiring root permissions.
2. **Hyprland Compositor GPU Load Throttling** via native Lua configuration calls (`hl.config`) to disable all animations, Kawase/Gaussian blur shaders, and drop-shadow render passes.
3. **Display Refresh Rate Throttling**: Switching external/primary displays to **30Hz** (in 20% Extreme Cap mode) cutting display pipeline VBlank interrupts and frame presentations by 50%, while keeping **60Hz** in 35% mode.
4. **Dedicated NVIDIA GPU (GTX 1650) Sleep Enforcement**: Pruning non-essential GPU clients (such as stale `swaync` contexts) so the dGPU drops into deep P8 idle / RTD3 power down (~0-3W instead of active power draw).
5. **Interactive UI in Control Center & Settings**: Adding selectable preset pills (`20% Cap (30Hz)` and `35% Cap (60Hz)`), dynamic responsive card heights, and real-time IPC synchronization.

---

## 2. Technical Architecture & Implementation

### 2.1 CFS Bandwidth Quota Allocation (Kernel Cgroups v2)
On this host, the CPU is an AMD Ryzen 5 5500U featuring 6 cores and 12 hardware threads (total potential quota = 1200%).
User `pranc` owns delegation over `/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/`.

- **Formula**: $\text{CPUQuota} = \text{threads} \times \text{limit\_percent}$
  - **20% Limit**: $12 \times 20\% = 240\%$ quota (`cpu.max` = `240000 100000`). All user applications in `app.slice` are throttled to a maximum aggregate consumption of 20% of system CPU.
  - **35% Limit**: $12 \times 35\% = 420\%$ quota (`cpu.max` = `420000 100000`).
  - **Restoration**: `CPUQuota=""` restores unconstrained execution (`cpu.max` = `max 100000`).

Command used:
```bash
systemctl --user set-property app.slice CPUQuota=<val>%
```

### 2.2 Hyprland Compositor & GPU Optimization
Hyprland v0.56.2 uses a Lua configuration engine (`hl.config`). Legacy `hyprctl keyword` calls do not work.

- **Compositor Shaders & Animations**:
  - Disable:
    ```lua
    hl.config({ animations = { enabled = false } })
    hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } } })
    ```
  - Restore:
    ```lua
    hl.config({ animations = { enabled = true } })
    hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true } } })
    ```
- **Display Refresh Throttling (30Hz / 60Hz)**:
  - In 20% limit mode: Active monitors supporting 30Hz (e.g. `HDMI-A-1`) are switched to `1920x1080@30.0` via:
    ```lua
    hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@30.0", position = "0x0", scale = 1, disabled = false, vrr = 0 })
    ```
  - In 35% mode and on disable: Restored to native mode (`1920x1080@60.0`).

### 2.3 NVIDIA dGPU Power Optimization
The secondary GPU (NVIDIA GTX 1650 Mobile) was found to be held awake by `swaync` (3W draw).
Feather Mode stops `swaync.service` and queries `nvidia-smi` to ensure no processes attach to card0. This allows the GTX 1650 to remain in `P8` 0% utilization idle or power down into PCIe runtime D3 cold.

### 2.4 Control Center & Settings UI Integration
- **`components/ControlCenter.qml`**: Section 2C ("The Feather") features an expandable card (64px -> 102px when active), an active badge showing `20% CAP` / `35% CAP`, subtitle details with refresh rate and pruned count, and two selectable preset pills (`20% Cap (30Hz)` and `35% Cap (60Hz)`).
- **`panels/SettingsWindow.qml`**: Matches the responsive pill layout for unified desktop configuration.
- **`island/ShellState.qml`**: Handles process lifecycle, exposes `featherLimit`, and coordinates `setFeatherLimit()`.
- **`shell.qml`**: Exposes `feather.setLimit(limit)` and `feather.limit` via Quickshell IPC.

---

## 3. Verification Matrix

| Test Case | Command / Action | Expected Result | Observed Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Python Syntax Check** | `python3 -m py_compile island/scripts/feather-mode.py` | Exit code 0, no errors | Exit code 0 | **PASS** |
| **CLI Status** | `python3 island/scripts/feather-mode.py status` | Returns JSON with mode state and limit | Valid JSON output | **PASS** |
| **Enable 20% Limit** | `python3 island/scripts/feather-mode.py enable 20` | `cpu.max` = `240000 100000`, 30Hz display | `240000 100000`, 30.00Hz on HDMI-A-1 | **PASS** |
| **Switch Limit to 35%**| `python3 island/scripts/feather-mode.py set-limit 35` | `cpu.max` = `420000 100000`, 60Hz display | `420000 100000`, 60.00Hz on HDMI-A-1 | **PASS** |
| **Disable Feather Mode**| `python3 island/scripts/feather-mode.py disable` | `cpu.max` = `max 100000`, animations true, blur true, 60Hz | `max 100000`, blur=true, anim=true, 60Hz | **PASS** |
| **Quickshell IPC Integration** | `quickshell -c cool-shell ipc call feather status` | IPC returns JSON with `limit` | `{"success":true,"enabled":false,"limit":35}` | **PASS** |
| **IPC setLimit Toggle** | `quickshell -c cool-shell ipc call feather setLimit 20` | Updates active state | `{"success":true,"enabled":false,"limit":20}` | **PASS** |

---

## 4. Modified Files

- [`island/scripts/feather-mode.py`](file://$HOME/.config/quickshell/cool-shell/island/scripts/feather-mode.py): Core backend script implementing CPU quota calculations, Hyprland Lua configuration calls, monitor refresh throttling, and dGPU optimization.
- [`island/ShellState.qml`](file://$HOME/.config/quickshell/cool-shell/island/ShellState.qml): Added `featherLimit` property, `setFeatherLimit()` method, and process output parsing.
- [`components/ControlCenter.qml`](file://$HOME/.config/quickshell/cool-shell/components/ControlCenter.qml): Updated Section 2C with limit badges, 20% / 35% toggle pills, and animated card height.
- [`panels/SettingsWindow.qml`](file://$HOME/.config/quickshell/cool-shell/panels/SettingsWindow.qml): Added preset selector pills to The Feather settings card.
- [`shell.qml`](file://$HOME/.config/quickshell/cool-shell/shell.qml): Extended `feather` IpcHandler with `limit` property and `setLimit()` dispatcher.
