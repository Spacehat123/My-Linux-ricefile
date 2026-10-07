# Audio Subsystem Restoration & Output Sinks Integration

**Date**: 2026-10-07  
**Status**: Verified & Operational  
**Component**: PipeWire / WirePlumber / `cool-shell` Audio Management  

---

## 1. Problem Overview
The user reported that the desktop audio output was displaying "Dummy Output" despite having 3 physical audio output endpoints:
1. **Bluetooth Headset**: Boat Rockerz 550 (`FC:58:FA:F3:F3:05`)
2. **Laptop Internal Speakers**: Realtek ALC255 / AMD Ryzen HD Audio Controller
3. **External Display Audio**: Renoir/Cezanne HDMI/DP Digital Stereo (Samsung Display)

---

## 2. Root Cause Analysis
Diagnostic commands (`wpctl status`, `pactl list cards`) revealed:
1. **ALSA Sound Card Profiles Set to Off**:
   - Card `alsa_card.pci-0000_05_00.1` (HDMI/DP Audio) had `Active Profile: off`.
   - Card `alsa_card.pci-0000_05_00.6` (Realtek Analog Audio) had `Active Profile: off` following an earlier driver/ALSA device acquisition error (`spa.alsa: Error opening low-level control device 'hw:1'`).
2. **PipeWire Fallback Mechanism**:
   - When all physical hardware sinks are disabled, PipeWire automatically initializes a fallback null-sink (`auto_null` / "Dummy Output") to keep audio applications from crashing.
3. **Bluetooth Headset Unlinked from WirePlumber**:
   - The device was paired and connected in `bluez`, but WirePlumber had not attached the bluez5 A2DP/HFP profile to a PipeWire sink.

---

## 3. Corrective Actions Taken
1. **Re-enabled Physical ALSA Card Profiles**:
   - `pactl set-card-profile alsa_card.pci-0000_05_00.6 output:analog-stereo+input:analog-stereo`
   - `pactl set-card-profile alsa_card.pci-0000_05_00.1 output:hdmi-stereo`
2. **WirePlumber Session Restart**:
   - `systemctl --user restart wireplumber`
   - Cleanly re-initialized ALSA endpoints and bluez5 transport bindings without requiring a system reboot.
3. **Bluetooth Headset Sink Activation**:
   - Reconnected `FC:58:FA:F3:F3:05` via `bluetoothctl`, activating the `bluez_output.FC_58_FA_F3_F3_05.1` sink (`Rockerz 550`) and configuring it as default.

---

## 4. UI Integration & Enhancements in `cool-shell`
1. **Settings Window (`panels/SettingsWindow.qml`)**:
   - Added a dedicated **OUTPUT DEVICES** section to the "Sound & Audio" category.
   - Dynamically lists all active hardware sinks from `Pipewire.nodes`.
   - Displays device type icons (󰋋 Bluetooth, 󰍹 HDMI/External Monitor, 󰕾 Speaker).
   - Provides per-device volume slider, active badge, and one-click default sink selection with atomic `wpctl set-default` synchronization.
2. **Control Panel (`island/panels/ControlPanel.qml`)**:
   - Audio output section populated with all 3 available sinks under the `output` tab.
3. **Bottom Bar & Left Sidebar**:
   - Retained reactive bindings to `Pipewire.defaultAudioSink.audio` with zero polling.

---

## 5. Verification Matrix

| Verification Item | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- |
| `wpctl status` Sinks | 3 physical sinks (Ryzen Analog, HDMI Samsung, Rockerz 550) | 3 sinks present; Dummy Output gone | PASS |
| Default Sink | Set to active output (Rockerz 550) | `* 96. Rockerz 550` default | PASS |
| Audio Playback | Audible sound on chosen device | Confirmed working by user | PASS |
| Dynamic Island Output Tab | Lists all 3 sinks for 1-click switching | Present & functional | PASS |
| Settings Window Audio Tab | Lists physical devices + app streams | Implemented & verified | PASS |
