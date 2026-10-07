# Dynamic Island Media Transport Controls Report

**Date**: 2026-10-04  
**Scope**: Dynamic Island click-based media controls (right click next, middle click play/pause, shift+right click previous) in `cool-shell`.  
**Status**: Verified & Operational  

---

## 1. Executive Summary

Mouse interaction on the collapsed Dynamic Island pill at the top of the desktop has been extended to provide seamless, direct media transport control:

- **Right Click**: Skips to the **Next** track (`IslandHub.mediaNext()`).
- **Middle Click (Wheel Click)**: Toggles **Play / Pause** (`IslandHub.mediaPlayPause()`).
- **Shift + Right Click**: Returns to the **Previous** track (`IslandHub.mediaPrevious()`).
- **Visual Feedback**: The island pill border emits a subtle 300ms flash (`Theme.primary`) upon triggering, and track title / artist label updates dynamically.

---

## 2. Architecture & Implementation

### 2.1 Native MPRIS & Shell Integration (`island/IslandHub.qml`)
- Added centralized media helper methods in `IslandHub.qml`:
  - `mediaNext()`: Dispatches `.next()` on the currently active `Quickshell.Services.Mpris` player (with fallback to `playerctl next`).
  - `mediaPrevious()`: Dispatches `.previous()` on the active MPRIS player (with fallback to `playerctl previous`).
  - `mediaPlayPause()`: Dispatches `.togglePlaying()` on the active MPRIS player (with fallback to `playerctl play-pause`).
  - Each action triggers `flashBorder(Theme.primary, 300)` for immediate visual confirmation.

### 2.2 Collapsed Island Mouse Area (`island/Notch.qml`)
- Configured `collapsedMouseArea`:
  - `acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton`
  - In `onClicked: (mouse)`:
    - `mouse.button === Qt.RightButton`: Checks `mouse.modifiers & Qt.ShiftModifier` (executes `mediaPrevious` if Shift held, else `mediaNext`).
    - `mouse.button === Qt.MiddleButton`: Executes `mediaPlayPause`.
    - `mouse.button === Qt.LeftButton`: Retains existing intelligent activity and panel routing (Control center, Timer acknowledge, Game mode).

### 2.3 IPC Integration (`shell.qml`)
- Added headless testing endpoints under `IpcHandler { target: "island" }`:
  - `quickshell ipc -c cool-shell call island mediaNext`
  - `quickshell ipc -c cool-shell call island mediaPrevious`
  - `quickshell ipc -c cool-shell call island mediaPlayPause`

---

## 3. Verification Matrix

| Action / Test | Trigger | Result | Status |
|---|---|---|---|
| **Right Click / Next Track** | IPC `call island mediaNext` / Right Click | Advanced from *"Paint The Town Blue"* to *"Wasteland"*, border flashed | **PASS** |
| **Middle Click / Play-Pause** | IPC `call island mediaPlayPause` / Middle Click | Paused playback (`playerctl status` -> Paused); second invocation resumed (`Playing`) | **PASS** |
| **Left Click / Panel Open** | Left Click on Island | Preserved normal panel opening behavior | **PASS** |
| **Scroll Volume** | Wheel scroll on Island | Preserved volume adjust (+/- 5%) with HUD bar | **PASS** |
| **Game Mode Invariance** | Verification | Game Mode strictly OFF (`false`) | **PASS** |
