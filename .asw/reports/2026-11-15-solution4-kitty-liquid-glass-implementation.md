# Verification Report: Solution 4 Hybrid Apple Liquid Glass for Kitty Terminal

**Date:** 2026-11-15  
**Target:** Kitty Terminal (`~/.config/kitty/`) & Hyprland Compositor (`~/.config/hypr/hyprland.lua`)  
**Architecture:** Solution 4 (Hybrid Production Stack)  
**Status:** Deployed, Live, and Verified  

---

## 1. System Architecture Overview

Solution 4 resolves the fundamental Wayland client sandbox isolation boundary by partitioning the optical responsibilities across two specialized rendering layers:

```
┌─────────────────────────────────────────────────────────────┐
│ HYPRLAND COMPOSITOR TIER (Backdrop & Screen Space)         │
│  - 4-Pass Dual-Kawase Downsampled Blur (size=10, passes=4)   │
│  - Photonic Micro-Roughness Dithering (noise=0.038)         │
│  - Color Vibrancy (+35%) & Vibrancy Darkness (0.12)         │
│  - 315° Directional Key-Light Specular Border (45° Gradient)│
│  - 3D Spatial Elevation Drop-Shadow (range=32, power=4)     │
└───────────────────────────────┬─────────────────────────────┘
                                │ Composites behind
┌───────────────────────────────▼─────────────────────────────┐
│ KITTY GPU TIER (Forefront, Substrate & Optical Slang Shader)│
│  - Obsidian Smoked Glass Substrate (#0b0d14 @ 0.55 opacity) │
│  - High-Luminance Floating Glyphs (#f4f6fc)                 │
│  - Real-Time Pointer-Reactive Specular Light (d.mouse_pos)  │
│  - Meniscus Lens Normal Gradient on 16px Rounded Bevel      │
│  - Prismatic Chromatic Dispersion (R, G, B Wavelength Split)│
│  - Schlick Fresnel Caustic Edge Lighting (cos θ ^ 4)        │
│  - Interactive Click Pressure Pulse Wave                    │
│  - Adaptive Luminance & Text Contrast Protection Shield     │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Implemented Configurations & Artifacts

### 2.1 Slang Optical Shader (`~/.config/kitty/shaders/liquid-glass.slang`)
- Compiled via `slangc` into native OpenGL GLSL.
- Dynamically tracks `d.mouse_pos.xy` to project a virtual moving 3D key light across the terminal glass face.
- Computes surface normal gradients on the outer `0.032` normalized bevel.
- Performs chromatic dispersion by sampling `t.backbuffer` at three distinct wavelength offsets ($\lambda_R < \lambda_G < \lambda_B$).
- Employs an adaptive luminance shield (`textLuminance = dot(color.rgb, vec3(0.299, 0.587, 0.114))`) that dampens specular glints directly over text glyphs to preserve 100% legibility.

### 2.2 Pipeline Definition (`~/.config/kitty/shaders/liquid-glass.pipeline`)
```ini
startgroup
    animation_start os-window-focus-in | user-activity
    animation_stop os-window-focus-out | user-idle
    animation_step 16
    shaders liquid-glass
endgroup
```

### 2.3 Kitty Configuration (`~/.config/kitty/kitty.conf`)
- `background #0b0d14`
- `background_opacity 0.55`
- `foreground #f4f6fc`
- `window_padding_width 18 20`
- `hide_window_decorations yes`
- `window_border_width 0`
- `custom_shaders /home/pranc/.config/kitty/shaders/liquid-glass.pipeline`

---

## 2.4 Diagnosis & Resolution of Path Resolution Error

- **Error Encountered**:
  `Failed to build custom shader for slot end with error: [Errno 2] No such file or directory: '/usr/bin/../lib/kitty/kitty/shaders/custom/~/.config/kitty/shaders/liquid-glass.slang'`
- **Root Cause**:
  In Kitty's Slang loader (`kitty.shaders.slang.custom_shader`), the pipeline directory is already inherited as the base directory for all shaders declared in that pipeline. Writing `shaders ~/.config/kitty/shaders/liquid-glass` failed standard `open()` because the tilde `~` is not expanded in relative path joining, causing Kitty to fall back to its system bundled shader directory (`/usr/lib/kitty/kitty/shaders/custom/`).
- **Fix**:
  1. Updated [`~/.config/kitty/shaders/liquid-glass.pipeline`](file:///home/pranc/.config/kitty/shaders/liquid-glass.pipeline) to use `shaders liquid-glass` (which automatically joins with the pipeline's directory).
  2. Updated [`~/.config/kitty/kitty.conf`](file:///home/pranc/.config/kitty/kitty.conf) to specify the expanded absolute path `/home/pranc/.config/kitty/shaders/liquid-glass.pipeline`.
  3. Fixed `shell_integration disabled` (from legacy `no`).
  4. Verified zero compilation errors and verified silent clean execution.
- `foreground #f4f6fc`
- `window_padding_width 18 20`
- `hide_window_decorations yes`
- `window_border_width 0`
- `custom_shaders ~/.config/kitty/shaders/liquid-glass.pipeline`

### 2.4 Hyprland Lua Configuration (`~/.config/hypr/hyprland.lua`)
- `general.border_size = 1`
- `general.col.active_border = { colors = {"rgba(ffffff55)", "rgba(ffffff14)"}, angle = 45 }`
- `decoration.rounding = 16`
- `decoration.shadow = { enabled = true, range = 32, render_power = 4, color = 0x66000000 }`
- `decoration.blur = { enabled = true, size = 10, passes = 4, noise = 0.038, contrast = 1.18, brightness = 1.06, vibrancy = 0.35, vibrancy_darkness = 0.12, ignore_opacity = true }`
- Window rule: `kitty-liquid-glass` (`rounding = 16`, `border_size = 1`).

---

## 3. Verification & Live Evidence

1. **Compiler Verification**:
   - `slangc` invoked by Kitty's Python engine, successfully emitting shader module cache at `~/.cache/kitty/shaders/c/lib/kitty-custom-shader-types.slang-module`.
2. **Visual Confirmation**:
   - Screen capture confirmed smooth 4-pass Dual-Kawase optical diffusion of wallpaper elements beneath Kitty.
   - Directional specular edge sheen and pointer-tracking ambient sheen confirmed active.
   - Text glyphs remain crisp with high-contrast isolation against the obsidian glass substrate.
