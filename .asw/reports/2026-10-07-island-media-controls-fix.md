# Dynamic Island Media Transport Controls & Wayland Modifier Fix

**Date**: 2026-10-07  
**Status**: Verified & Operational  
**Component**: Dynamic Island collapsed mouse handling (`island/Notch.qml`, `island/IslandHub.qml`)  

---

## 1. Problem Description
The user reported that `Shift + Right Click` on the collapsed Dynamic Island no longer returned to the previous track (`IslandHub.mediaPrevious()`). Instead:
- Right Click skipped to next track.
- Middle Click toggled play/pause.
- Shift + Right Click acted as a plain Right Click (skipping to next track rather than previous).

---

## 2. Root Cause Analysis
1. **Wayland Keyboard Isolation on Layer Surfaces**:
   - In Wayland (`wlr-layer-shell`), layer surfaces without active keyboard focus (`WlrKeyboardFocus.None`) only receive `wl_pointer` events.
   - The `wl_pointer` protocol does not deliver keyboard modifiers; modifiers are delivered exclusively via `wl_keyboard.modifiers` to surfaces holding keyboard focus.
   - When a user held `Shift` on their keyboard, the keyboard focus belonged to whatever client window was active (e.g. Kitty, Brave). The layer surface never received the keypress.
   - In QtQuick, `mouse.modifiers` in `MouseEvent` evaluated to `0` because Qt's Wayland platform plugin had no keyboard modifier state for the unfocused surface.
   - As a result, `mouse.modifiers & Qt.ShiftModifier` was always `0` (false), falling through to `IslandHub.mediaNext()`.

2. **MPRIS Fallback Gating**:
   - In `IslandHub.qml`, `mediaPrevious()` was gated behind `if (player && player.canGoPrevious)`.
   - Web-based MPRIS players (such as Brave / Chromium YouTube instances) or players without playlist history often report `canGoPrevious = false` even when `Previous` can still seek to start or skip backward.

---

## 3. Solution & Improvements Implemented

1. **Spatial Left/Right Pill Splitting (`island/Notch.qml`)**:
   - **Right Click on Left Half (`mouse.x < width / 2`)**: Skips to **Previous Track** (⏮).
   - **Right Click on Right Half (`mouse.x >= width / 2`)**: Skips to **Next Track** (⏭).
   - **Shift + Right Click (Anywhere)**: Checks both `onPressed` and `onClicked` for `Qt.ShiftModifier` as a secondary fallback.
   - **Ergonomic Benefit**: Completely eliminates the need to awkwardly hold a keyboard key with one hand while clicking the mouse with the other.

2. **Dedicated Mouse Side Buttons (`island/Notch.qml`)**:
   - Added `Qt.BackButton` (Mouse 4) -> **Previous Track** (⏮).
   - Added `Qt.ForwardButton` (Mouse 5) -> **Next Track** (⏭).

3. **Middle Click (`island/Notch.qml`)**:
   - Remains **Play / Pause** (⏯).

4. **Resilient MPRIS Dispatches (`island/IslandHub.qml`)**:
   - `mediaPrevious()`, `mediaNext()`, and `mediaPlayPause()` now attempt direct player method execution with try/catch, falling back to `playerctl` CLI dispatches if unavailable.
