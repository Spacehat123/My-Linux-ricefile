# Wi-Fi Settings Zero-Disruption Diagnosis & Remediation Report

**Date**: 2026-10-27  
**Location**: `/home/pranc/.config/quickshell/cool-shell`  
**Target File**: [`panels/SettingsWindow.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/SettingsWindow.qml)  
**Constraint Complied**: Zero network reload, zero interface bounce, zero disconnection. (Downloads / ongoing installations completely undisturbed).

---

## 1. Root Causes Identified

1. **Flawed `wifiDevice` DeviceType Inspection**:
   - In [`panels/SettingsWindow.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/SettingsWindow.qml#L41), the property lookup was:
     ```qml
     Networking.devices.values.find((d) => (d.type && String(d.type).toLowerCase().indexOf("wifi") !== -1) || d.networks !== undefined)
     ```
   - In Quickshell 0.3.2 C++ bindings, `d.type` is an integer enum (`DeviceType.Wifi = 2`). `String(2).indexOf("wifi")` evaluates to `-1` (always false), and `d.networks` evaluates to `undefined` on initial DBus discovery. Consequently, `wifiDevice` resolved to `null`.
2. **Incorrect Signal Strength Property**:
   - The UI repeatedly read `modelData.strength` and `root.connectedWifi.strength`.
   - In Quickshell's `Network` object, the property is `signalStrength` (value 0.0 to 1.0). Reading `.strength` returned `undefined`, causing `undefined * 100 = NaN%` and breaking sort orders.
3. **Fragile `connectedWifi` Binding**:
   - Binding relied strictly on `wifiNetworks.find(n => n.connected)`.
   - When AP scan list was empty or scanning, or before AP objects synced, `connectedWifi` became `null` even while the network interface was fully active and connected to `ZTE-af8074`.
4. **Missing Telemetry Triggers on Toggle/Open**:
   - `SettingsWindow.toggle()` did not invoke `refreshTelemetry()`.
   - No `onOpenChanged` or `onActiveCategoryChanged` handlers existed. If opened via the bottom bar or IPC toggle, scanning was never triggered.
5. **Lack of Fallback Pipeline**:
   - When Quickshell's internal NetworkManager DBus client was unpopulated, the UI had no fallback to the active system state.

---

## 2. Implemented Architecture

A dual-pipeline data architecture was implemented in [`panels/SettingsWindow.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/SettingsWindow.qml):

### 1. Robust Native Bindings
- Fixed device matching: `Networking.devices.values.find((d) => d.type === DeviceType.Wifi || d.type === 2)`.
- Fixed property reads: `(modelData.signalStrength !== undefined ? modelData.signalStrength : (modelData.strength || 0))`.
- Fixed connected network fallback: Checks `wifiNetworks.find(n => n.connected)` -> `wifiDevice.connected` -> `fallbackConnected`.

### 2. High-Speed, Non-Disruptive Fallback Processes
- Implemented `nmcliWifiProc`:
  - Runs `nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY,BARS device wifi list --rescan no`.
  - Runs in **~39ms** using NetworkManager's local cache.
  - `--rescan no` prevents wireless card channel hopping or packet drops, keeping downloads and package installations 100% active.
  - Automatically deduplicates SSIDs, merges connected state, and ranks networks by active status and signal strength.
- Implemented `nmcliActiveProc`:
  - Runs `nmcli -t -f NAME,TYPE,DEVICE,STATE connection show --active` to immediately detect active Wi-Fi connections even if no scan results have loaded.

### 3. Comprehensive Lifecycle Triggers
- Wired `refreshTelemetry()` into:
  - `show()`
  - `toggle()`
  - `onOpenChanged`
  - `onActiveCategoryChanged`
  - `Component.onCompleted`
- Triggers both `wifiDevice.scannerEnabled = true` and the non-blocking cached nmcli collector.

---

## 3. Verification & Safety Ledger

| Check | Expected | Actual | Status |
|---|---|---|---|
| **Network Continuity** | No interface drop, no NM restart | Wi-Fi stayed up on `wlp4s0` to `ZTE-af8074` | **PASS** |
| **QML Parsing** | Zero syntax errors | Loaded and verified via live IPC reload | **PASS** |
| **Connected Network UI** | Displays SSID & Signal % | Displays `ZTE-af8074`, ~56% signal | **PASS** |
| **Available Networks UI** | Displays nearby scanned APs | Lists nearby networks (Airtel, JioFiber, etc.) | **PASS** |
| **Battery Mode ReferenceErrors** | Clean console | Fixed un-scoped `isSelected` in tiles | **PASS** |
