# Acer Aspire A715-42G Battery Charge Limit & Health Mode Report

**Date**: 2026-10-13  
**Target Hardware**: Acer Aspire A715-42G (`ECS_AN515_46`)  
**Kernel**: `7.2.9-arch1-1`  
**Subsystem**: ACPI Embedded Controller (EC) / Quickshell Settings  

---

## 1. Executive Summary & Root Cause Analysis

When setting the battery limit to **70%** at **67%** capacity, the laptop continued charging uninterrupted past 70% and past 80% to **84%**.

Two specific factors caused this behavior:

### Factor A: Firmware Limitation (Fixed 80% Threshold)
Unlike laptops from Asus or Lenovo (which support variable thresholds like 60%, 70%, or 85% via `sysfs`), the Acer firmware architecture for Aspire and Nitro models does **not** support arbitrary percentages.
- As confirmed by reverse-engineering in `$HOME/Desktop/Acer nitrosene/Linux-NitroSense/core/device_regs.py`, Acer Embedded Controller register `0x03` (`BATTERYCHARGELIMIT`) operates as a **binary toggle**:
  - `0x51` (81 dec): **80% Battery Health Mode** (Acer Care Center / NitroSense Care Mode).
  - `0x11` (17 dec): **100% Full Charge** (Charge Limit Disabled).
- The hardware EC physically ignores or rejects values other than the factory health-mode flags.

### Factor B: Permission Denied during Unprivileged Execution
- Writing to the Acer Embedded Controller requires writing directly to `/sys/kernel/debug/ec/ec0/io` after loading `modprobe ec_sys write_support=y`.
- Because debugfs (`/sys/kernel/debug/`) is restricted (`drwx------ root:root`), Quickshell running as standard user `pranc` encountered `PermissionError: [Errno 13] Permission denied`.
- In the initial implementation, the exception was caught silently with `pass` and exited without escalating privileges. As a result, the hardware EC was **never** instructed to cap charging, leaving the machine in full 100% charging mode.

---

## 2. Implemented Fixes

### 1. Actuator Refactoring ([`scripts/battery-limit.sh`](file://$HOME/.config/quickshell/cool-shell/scripts/battery-limit.sh))
- **Direct Acer EC Access**: Interacts directly with register `0x03` via `/sys/kernel/debug/ec/ec0/io` (and `/dev/ec` fallback).
- **Graceful Privilege Elevation**:
  1. Checks non-interactive `sudo -n "$0" "$@"`. If a sudoers rule exists, it executes instantly without delay or password prompts.
  2. If unprivileged and non-interactive sudo is unavailable, invokes a graphical Zenity password prompt (`zenity --password`) within the Wayland desktop session.
  3. Falls back to `pkexec`.
- **User-Safe IPC Notifications**: Resolves root vs unprivileged Quickshell socket boundaries by routing Dynamic Island notifications through the active desktop user session (`sudo -u "$SUDO_USER" qs -c cool-shell ...`).

### 2. Settings UI Refactoring ([`panels/SettingsWindow.qml`](file://$HOME/.config/quickshell/cool-shell/panels/SettingsWindow.qml))
- **Removed Misleading Presets**: Removed arbitrary percentage sliders and preset buttons (60%, 70%, 85%, 90%) that the Acer EC cannot physically fulfill.
- **Hardware-Aligned Mode Selector**:
  - **80% Health Mode**: Caps charging at 80% to preserve lithium chemistry when operating on AC power.
  - **100% Full Charge**: Unlocks full battery capacity for maximum unplugged mobile usage.
- **Hardware Architecture Disclosure**: Added an in-UI explanation detailing that the Acer Aspire / Nitro hardware Embedded Controller enforces the fixed 80% cutoff at firmware level.

---

## 3. Recommended Privilege Escalation Setup

To enable instant, passwordless toggling directly from Settings or keyboard shortcuts without graphical password dialogs, execute the following one-line sudoers rule:

```bash
echo "$USER ALL=(ALL) NOPASSWD: $HOME/.config/quickshell/cool-shell/scripts/battery-limit.sh" | sudo tee /etc/sudoers.d/cool-shell-battery
```

---

## 4. Verification & Testing Matrix

| Component | Target Action | Verification Result |
| :--- | :--- | :--- |
| `scripts/battery-limit.sh status` | Query live status & capacity | Outputs valid JSON with `acer_fixed_threshold: 80` |
| `panels/SettingsWindow.qml` | UI rendering | Two-state mode cards with visual active states |
| `Linux-NitroSense` mapping | Model compatibility | Aspire A715-42G confirmed mapped to `ECS_AN515_46` register `0x03` |
| AC Discharging above 80% | AC connected when >80% | Verified behavior: AC powers system; battery naturally settles to 80% |

---

## 5. Hardware Safety & Battery Health Analysis

### Why Limiting to 80% Protects (Not Damages) the Battery
1. **Electrochemical Stress Reduction**:
   - Lithium-ion cells suffer maximum stress when held at $>4.15\text{V}/\text{cell}$ (100% state of charge), which accelerates cathode degradation and solid-electrolyte interphase (SEI) growth.
   - Operating at 80% (~$3.90\text{V}/\text{cell}$) reduces degradation rates by **$3\times\text{ to }4\times$**, drastically reducing battery wear and swelling (pillowing) when plugged in for long sessions.
2. **AC Power Pass-Through (Zero Micro-Cycling)**:
   - Modern laptop motherboard PMICs (Power Management ICs) use automatic power multiplexing.
   - When the 80% limit is active, the charger IC stops supplying charge current to the battery. Motherboard rails (CPU, GPU, fans, display) draw power **directly from the AC adapter**. The battery remains idle in standby and is **not** repeatedly drained and recharged.
3. **Hardware Guardrails**:
   - The script strictly restricts writes to register address `0x03` with assertion `val in (0x51, 0x11)`. It is physically impossible for the script to touch fan curves, thermal trip points, voltages, or any other register.
   - Immediate read-back verification ensures data integrity on every write.
   - This uses the exact same firmware call that Acer's official Windows software (Acer Care Center / NitroSense) uses.
