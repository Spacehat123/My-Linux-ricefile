# Battery Charge Limit (80% Health Mode & Custom Thresholds) Report

**Date**: 2026-10-13  
**Status**: Implemented & Ready for User Verification  
**Scope**: [`panels/SettingsWindow.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/SettingsWindow.qml), [`scripts/battery-limit.sh`](file:///home/pranc/.config/quickshell/cool-shell/scripts/battery-limit.sh)  
**Safety Constraint**: Did NOT test hardware activation on live system at 100% battery (as requested by user).

---

## 1. Executive Summary

Implemented an 80% Battery Charge Limit (Health Mode) and custom threshold management in Cool-Shell's Settings under **Power & Battery**. The system provides an instant toggle to switch the limit on/off, pre-configured quick presets (60%, 70%, 80% Recommended, 85%, 90%, 100%), and a continuous slider for custom limits (50%–100%).

---

## 2. Hardware Architecture & Actuator Backend

The backend actuator is located at [`scripts/battery-limit.sh`](file:///home/pranc/.config/quickshell/cool-shell/scripts/battery-limit.sh):

1. **Multi-Backend Fallback Order**:
   - **Linux Sysfs**: Writes to `/sys/class/power_supply/BAT*/charge_control_end_threshold`, `charge_control_limit_max`, or `charge_stop_threshold`.
   - **Acer WMI Battery Driver**: Writes `1` (80% health mode) or `0` (100% full capacity) to `/sys/bus/wmi/drivers/acer-wmi-battery/health_mode`.
   - **Acer Embedded Controller (EC) Register**: Interacts with EC register `0x03` (matching the user's `Linux-NitroSense` reverse-engineered address: `0x51` for limit on, `0x11` for limit off) via `ec_sys` or `/dev/ec`.
2. **State & Persistence**:
   - Settings are stored in `~/.config/cool-shell/battery-limit.json`.
   - Read-only `status` action queries config and sysfs battery capacity without modifying hardware registers.

---

## 3. UI Implementation in Settings

In [`panels/SettingsWindow.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/SettingsWindow.qml) under **Power & Battery**:
- **Status Badge**: Displays `80% CAP ACTIVE` (or chosen limit) when on, and `OFF (100% FULL)` when off.
- **Toggle Switch**: Toggles between 100% unrestricted charging and the configured limit.
- **Quick Preset Pills**:
  - `60%` (Long-term storage)
  - `70%` (Stationary desk use)
  - `80% (Health)` (Recommended sweet spot for lithium cycle preservation)
  - `85%` (Extended endurance)
  - `90%` (Travel preparation)
  - `100%` (Full capacity)
- **Custom Limit Slider**: Smoothly selects any custom integer limit between 50% and 100%.

---

## 4. Verification Note

- The actuator script's read-only status check was verified: `{"enabled": false, "limit": 80, "current_capacity": 100}`.
- In strict adherence to user instructions, hardware actuation was **not executed** while the laptop is at 100% charge. The user will test and activate it on their own terms.
