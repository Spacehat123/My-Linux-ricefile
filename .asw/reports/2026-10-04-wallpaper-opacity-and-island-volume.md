# Wallpaper Transparency Intelligence & Dynamic Island Volume Scroll Report

**Date**: 2026-10-04  
**Scope**: Dynamic background state switching (static when opaque vs live when see-through) and wheel scroll volume control on the Dynamic Island in `cool-shell`.  
**Status**: Verified & Operational  

---

## 1. Executive Summary

Two key user experience enhancements have been implemented and verified:

1. **Wallpaper Dynamic Lifecycle (Static when Opaque vs Live when See-Through)**:
   - When an opaque application window (e.g. Brave Browser, VS Code, Nautilus) is on the active workspace, the live video wallpaper automatically pauses, freezing on the current frame as a static background. This eliminates visual distraction behind window gaps and drops GPU/CPU video decoding overhead to 0.
   - When windows on the active workspace are see-through/translucent (e.g. `kitty` terminal with `background_opacity 0.4`, `alacritty`, `foot`, `wezterm`, or transparent visualizers like `cava`), or when the desktop is completely clear (empty workspace), the wallpaper runs in **live** mode (continuous 60 FPS playback).
2. **Dynamic Island Scroll-to-Volume**:
   - Scrolling the mouse wheel or touchpad over the collapsed Dynamic Island pill at the top of the screen now increases or decreases system volume in real time.
   - Integrates directly with native `Pipewire.defaultAudioSink.audio` (with `wpctl` fallback).
   - Smooth trackpad and mouse-wheel delta step accumulation prevents jerky jumps.
   - Immediately brings up the Dynamic Island volume HUD and renders the horizontal fill bar and volume percentage.

---

## 2. Architecture & Implementation

### 2.1 Dynamic Wallpaper Intelligence (`Wallpaper.qml` & `shell.qml`)
- **`wallpaper/Wallpaper.qml`**:
  - Added `property bool live: true`.
  - Added `_syncPlayback()` managing `MediaPlayer` states:
    - If `live === true`: starts/resumes playback (`mediaPlayer.play()`).
    - If `live === false`: cleanly pauses on the current frame (`mediaPlayer.pause()`).
    - The frame remains statically rendered by `VideoOutput` on Wayland `WlrLayer.Background`.
- **`shell.qml`**:
  - `seeThroughPatterns`: Catalog of recognized translucent window classes, app IDs, and terminals (`kitty`, `alacritty`, `foot`, `wezterm`, `ghostty`, `urxvt`, `st`, `xterm`, `cava`, `glava`, etc.).
  - `isSurfaceSeeThrough(surface)`: Inspects `windowClass`, `appId`, `initialClass`, and `title`.
  - `shouldWallpaperBeLiveForMonitor(screen)`:
    - Matches the monitor to its active/focused workspace.
    - If the workspace has 0 windows: returns `true` (bare desktop -> live).
    - If any window on the workspace is opaque: returns `false` (opaque window -> static).
    - If all windows on the workspace are see-through: returns `true` (see-through -> live).
  - `_wallpaperLiveTick`: Reactive tick tracking workspace focus, surface count, and active address to re-evaluate instantly upon workspace switches or window events.
  - Dedicated IPC methods and properties on `wallpaper`:
    - `qs -c cool-shell ipc call wallpaper isLive`
    - `qs -c cool-shell ipc prop get wallpaper live`
    - `qs -c cool-shell ipc call wallpaper setAutoPause <true|false>`

### 2.2 Dynamic Island Wheel Volume Control (`IslandHub.qml` & `Notch.qml`)
- **`island/IslandHub.qml`**:
  - Added `adjustVolume(deltaPercent)`:
    - Computes current volume percentage from `sinkAudio.volume` (or defaults).
    - Sets `sinkAudio.volume = target / 100.0`.
    - Automatically unmutes if muted and volume is increased.
    - Re-arms `volumeTimer` and triggers `showVolume()` to render the volume takeover HUD.
    - Includes `wpctl` fallback if `sinkAudio` is momentarily unbound.
- **`island/Notch.qml`**:
  - Added `onWheel` event handler on `collapsedMouseArea` covering the entire island pill.
  - Uses `_wheelDeltaAccum` with a step threshold of 40 units (smooth scaling for trackpads, crisp 5-6% steps for 120-unit mouse notches).
  - Scoped to `!window.isExpanded` so that scrolling inside expanded panel lists (notifications, launcher, clipboard) is never interrupted.
- **`shell.qml`**:
  - Exposed `adjustVolume(delta)` in `IpcHandler { target: "island" }`.
  - Added `volumePercent`, `volumeActive`, and `volumeMuted` to `island.getSummary()`.

---

## 3. Verification Matrix

| Test Scenario | Action | Expected Output | Actual Output | Status |
|---|---|---|---|---|
| **Opaque Window (Brave)** | Focus Workspace 1 with Brave | Wallpaper pauses, `live: false` | `{"success":true,"live":false,"focusedWorkspace":1}` | **PASS** |
| **See-Through Window (Kitty)** | Switch to Workspace 2 with Kitty | Wallpaper resumes, `live: true` | `{"success":true,"live":true,"focusedWorkspace":2}` | **PASS** |
| **Bare Desktop** | Switch to Workspace 4 (empty) | Wallpaper runs live, `live: true` | `{"success":true,"live":true,"focusedWorkspace":4}` | **PASS** |
| **Volume Up via Island** | Scroll up / IPC `adjustVolume 5` | Volume increases, HUD activates | `{"success":true,"volumePercent":23}` | **PASS** |
| **Volume Down via Island** | Scroll down / IPC `adjustVolume -5` | Volume decreases, HUD activates | `{"success":true,"volumePercent":18}` | **PASS** |
| **Game Mode Invariance** | Verify Game Mode status | Game Mode must remain disabled | Game Mode strictly OFF (`false`) | **PASS** |
