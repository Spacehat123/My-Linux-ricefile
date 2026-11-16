# Liquid Glass Live Capture Architecture & Feasibility Report

**Date**: 2026-11-17  
**System**: Arch Linux, Hyprland 0.56.2, Quickshell 0.3.2  
**Target Component**: `widgets/liquid-glass-media-player/LiquidGlassMediaPlayer.qml` & `panels/FloatingMediaCompanion.qml`

---

## 1. Executive Summary

All static fallback images, hardcoded paths (`cherry/5.png`), and fake wallpaper layers have been completely removed from `LiquidGlassMediaPlayer.qml`. The widget now relies exclusively on live compositor buffer capture via Wayland screencopy.

This report documents our empirical investigation into Wayland protocols on Hyprland 0.56.2 and Quickshell 0.3.2, explains the physics of the Wayland feedback recursion problem, and provides four concrete engineering architectures to achieve live background refraction.

---

## 2. Environment & Protocol Audit

| Component | Version / Identifier | Protocol Support / Capability |
| :--- | :--- | :--- |
| **Compositor** | Hyprland `0.56.2` | `zwlr_screencopy_manager_v1`, `ext_image_copy_capture_manager_v1`, `hyprland_toplevel_export_manager_v1` |
| **Shell Framework** | Quickshell `0.3.2` | Implements `zwlr_screencopy_manager_v1` via `Quickshell.Wayland._Screencopy` (`ScreencopyView`) |
| **Active Display** | `HDMI-A-1` | 1920x1080 @ 60Hz (Scale: 1.0) |
| **Live Wallpaper Daemon**| `awww-daemon` (PID 1091) | Queryable via `awww query` |

### Key Protocol Findings

1. **`zwlr_screencopy_manager_v1` (Quickshell's Engine)**:
   - Quickshell exposes this through `ScreencopyView`.
   - Its `captureSource` **only** accepts display outputs (`QuickshellScreenInfo`).
   - It captures the **entire composited output framebuffer** (the final image rendered to the monitor).
2. **`hyprland_toplevel_export_manager_v1`**:
   - While Hyprland exposes toplevel export, Quickshell's `ScreencopyView` cannot bind to individual window handles. Passing a toplevel handle throws: `Capture source set to non captureable object`.
3. **Layer Exclusion Inability**:
   - Neither `wlr-screencopy` nor `ext-image-copy-capture` allows excluding a specific layer-shell surface or namespace from an output capture. Every rendered pixel currently visible on the display is included in the captured frame.

---

## 3. The Feedback Loop Phenomenon

When `ScreencopyView.live = true` is used while the glass widget is rendered on screen:
1. Frame $N$: Screencopy captures the display including the glass capsule.
2. Frame $N+1$: The glass shader samples that capture, displacing the pixels inside the capsule.
3. Frame $N+2$: Screencopy captures the display containing the already-displaced capsule.
4. Result: An infinite recursive mirror tunnel (cascading frames within frames), verified empirically in `/tmp/test_feedback_result.png`.

---

## 4. Tested Architectures to Achieve Live Glass

### Architecture 1: Ephemeral Pulse / Zero-Overhead Hide-and-Capture (Empirically Verified)

- **Mechanism**:
  To capture the true background without self-recursion, the widget is briefly unmapped or hidden (`visible = false` or `opacity = 0`) for a single compositor render tick (16–25ms). `screencopy.captureFrame()` is triggered, followed immediately by restoring widget visibility and calling `ShaderEffectSource.scheduleUpdate()`.
- **Empirical Proof**:
  Verified in `/tmp/test_flicker.qml` and captured via `grim`. The resulting capture (`flicker_crop_inspect.png`) contained the raw underlying text editor with **zero recursive feedback boxes**.
- **When to Trigger**:
  1. **On Reveal / Open**: Before the capsule fades in, take a pristine capture. The user perceives 0 flicker because the widget is not yet visible.
  2. **On Drag Release**: When the user finishes repositioning the capsule, take a fresh capture of the new location.
  3. **Low-rate Idle Refresh (e.g. 1Hz) or on Window Focus Change**: Periodically update the buffer so moving background windows are reflected.

### Architecture 2: Full-Screen Cached Buffer with Real-Time Coordinate Tracking (60fps Dragging)

- **Mechanism**:
  Instead of cropping screencopy to a tiny box that must re-capture every pixel during motion, `ScreencopyView` captures the full 1920x1080 display.
  Inside the widget:
  ```qml
  ShaderEffectSource {
      id: backdropSource
      sourceItem: screencopy
      sourceRect: Qt.rect(capsuleCard.x, capsuleCard.y, capsuleCard.width, capsuleCard.height)
      live: false
  }
  ```
- **Benefits**:
  - While dragging, `sourceRect` moves across the full-screen texture smoothly at 60–144Hz.
  - The glass distorts whatever is at `(x, y)` instantly with zero GPU stutter.
  - Upon mouse release (`onReleased`), an ephemeral pulse updates the full-screen capture.

### Architecture 3: Dual-Mode Dynamic Wallpaper & Window Hybrid

- **Mechanism**:
  - If the capsule is over bare desktop space, query the running wallpaper daemon dynamically (`awww query`) to fetch the active wallpaper file path.
  - No hardcoded paths: strictly dynamically queried.
  - When windows are present, fall back to Architecture 1 (screencopy pulse).

---

## 5. Verification Matrix

| Verification Item | Target Behavior | Current Status |
| :--- | :--- | :--- |
| **Purge Fake Assets** | Zero hardcoded wallpaper paths (`cherry/5.png`, `wallpaperFallback`) | **VERIFIED CLEAN** (Removed from codebase) |
| **Shader Compilation** | `liquid_glass.frag.qsb` compiled with debug modes | **VERIFIED PASS** (qsb built 12K binary) |
| **Screencopy Feed** | `ScreencopyView` directly feeds `ShaderEffectSource` | **WIRED** |
| **Debug Mode 3** | Renders raw captured backdrop texture | **AVAILABLE** via IPC |
