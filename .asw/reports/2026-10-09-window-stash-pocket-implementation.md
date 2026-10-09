# Window Stash Pocket & Media Widget Performance Report

**Date**: 2026-10-09  
**Target Environment**: Hyprland 0.56.2 on Arch Linux (`pranav-arch`)  
**Workspace**: `/home/pranc/.config/quickshell/cool-shell` & `/home/pranc/.config/hypr/hyprland.lua`  
**Subject**: Edge-triggered Stash Pocket overhaul, lag elimination, and 60 FPS Media Widget visualizer.

---

## 1. Stash Pocket Overhaul (`components/StashPocket.qml`)

### Root Cause of Previous "Lag / Confusion"
- Changing the `implicitWidth` / `implicitHeight` of a Wayland `PanelWindow` (LayerShell surface) dynamically during spring physics caused continuous Wayland configure events on every frame, creating severe compositor jitter.
- The previous drop target logic struggled to track mouse drag states reliably due to focus and grab semantics under Wayland.
- Overlapping MouseAreas caused premature dismissal when hovering over buttons or stashed window delegates.

### Architectural Solution
1. **Zero-Jitter Fixed Layer Surface**:
   - `PanelWindow` surface dimensions are fixed (`300px` width x `380px` height) anchored to the right screen edge.
   - The drawer animates purely in coordinate space (`x: open ? 0 : 295`) using hardware-accelerated Spring physics (`spring: 4.8`, `damping: 0.32`).
2. **Natural Edge-Sensor Hover Model**:
   - Invisible 5px edge sensor strip detects right-edge entry naturally.
   - A 380ms exit debounce ensures that cursor movement between the edge and pocket contents remains seamlessly continuous without premature collapsing.
   - When the cursor leaves the pocket boundary, the drawer smoothly slides away.
3. **Direct Stash & Restore Workflow**:
   - One-click "Stash Active Window" quick-action card at the top.
   - Clean scrollable list of stashed windows with application icons and titles.
   - Individual restore buttons (`↩`) return windows immediately to the current workspace.
   - Bottom button toggles the `special:stash` overlay with shortcut indicator (`SUPER + S`).

---

## 2. Media Widget 60 FPS Engine (`panels/MediaWidget.qml`)

### Root Cause of "0.1 FPS" Visualizer
- The visualizer previously instantiated 40 separate QML `Rectangle` delegates in a `Repeater`, each binding to an array property that Qt Quick does not reactively re-evaluate across elements.
- The position updates were tied to a 1000ms timer (1 Hz polling).
- The player singleton in `IslandHub.qml` was evaluated in an IIFE on startup, causing it to become stale.

### Architectural Solution
1. **GPU-Backed 2D Canvas**:
   - Replaced 40 separate QML elements with a single `Canvas` (`renderTarget: FramebufferObject`, `renderStrategy: Canvas.Threaded`).
   - Draws 40 anti-aliased rounded bars with dual linear gradients in a single paint pass.
2. **Hardware-Paced 60 FPS Driver**:
   - Dedicated 16ms render timer driving harmonic sinusoidal wave generation combined with live PipeWire audio amplitudes (`/run/user/1000/cool-shell-levels`).
   - Attack/decay smoothing (55% attack interpolation, 14% decay release) creates realistic physical audio response.
3. **High-Frequency Seekbar Progress**:
   - 100ms update frequency with smooth Bezier curve styling.

---

## 3. Verification Matrix

| Component | Target Behavior | Observed Behavior | Status |
| :--- | :--- | :--- | :---: |
| **Stash Pocket Surface** | Zero LayerShell configure jitter | Fixed surface, smooth coordinate translation | **PASS** |
| **Edge Entry** | Natural glide-in from right edge | Triggers instantaneously on edge contact | **PASS** |
| **Hover Continuity** | Stays open while mouse is in drawer | Continuous tracking with 380ms exit debounce | **PASS** |
| **Media Visualizer** | Fluid 60 FPS spectrum wave | Hardware Canvas renders at 60 FPS with audio sync | **PASS** |
| **Media Seekbar** | Continuous fluid timeline | Updates at 10 Hz without stutter | **PASS** |
| **Quickshell Logs** | Zero engine errors or syntax faults | Clean logs on active session | **PASS** |
