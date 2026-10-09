# Hyprscroller Architectural Evaluation: Xiaomi Canvas Multitasking & Bird's-Eye View

**Date**: 2026-10-09  
**Target Project**: `cool-shell` / Hyprland  
**Subject**: Evaluation of `hyprscroller` for horizontal strip multitasking, Peeking Edge tabs, and Bird's-Eye View (`SUPER + R`) based on `recording-20261009-195909.mp4`.

---

## 1. Executive Summary

Based on the analysis of `recording-20261009-195909.mp4` (Xiaomi Fold / HyperOS Canvas multitasking) and the architecture of `hyprscroller` (`hyprscrolling`), the conclusion is:

> **`hyprscroller` CAN deliver the horizontal strip layout and the Bird's-Eye View (`scroller:toggleoverview`) almost identically to the recording.**  
> **However, `hyprscroller` ALONE CANNOT deliver the Peeking Edge tabs.**  
> To achieve the full vision, a **Hybrid Architecture** is required: **`hyprscroller` handles window tiling & Bird's-Eye overview**, while **`cool-shell` (Quickshell) renders the interactive Peeking Edge tabs on the screen borders.**

---

## 2. Feature-by-Feature Comparison Matrix

| Feature from Recording | How it behaves in Video (`recording-20261009-195909.mp4`) | Can `hyprscroller` do it alone? | Hybrid (`hyprscroller` + `cool-shell`) |
| :--- | :--- | :---: | :---: |
| **1. Multi-App Horizontal Strip** | 3-4 full-height apps sit side-by-side on 1 workspace; viewport pans across them. | **YES** (`scroller` layout engine) | **YES** |
| **2. Bird's-Eye View (`SUPER + R`)** | At 0:16, pinch gesture zooms out all apps into a horizontal mini ribbon across the screen. | **YES** (`scroller:toggleoverview`) | **YES** |
| **3. Window Zoom Selection** | Clicking or focusing an app in overview zooms back into that app. | **YES** (native to `scroller:toggleoverview`) | **YES** |
| **4. Peeking Edge Tabs** | Colored edge tabs/pills on the screen border showing off-screen apps. | ❌ **NO** (hyprscroller has no GUI overlay) | **YES** (rendered via `cool-shell` Layer Shell) |
| **5. Edge Tab Click-to-Scroll** | Clicking the edge tab brings that specific off-screen app into view. | ❌ **NO** | **YES** (Quickshell triggers `hyprctl dispatch scroller:movefocus`) |

---

## 3. Deep Dive: Bird's-Eye View (`scroller:toggleoverview`)

### Video Behavior (0:16 in `recording-20261009-195909.mp4`)
In the video:
- Two active apps are visible on the screen, while a third app (e.g. Chrome/Notes) is parked just off-screen to the right.
- The user initiates a pinch gesture.
- The viewport smoothly zooms out.
- All 3 apps scale down proportionally side-by-side into a horizontal panoramic strip fitting within the screen width.
- Tapping on any scaled window brings it immediately into the center viewport at full scale.

### `hyprscroller` Implementation
`hyprscroller` has a built-in overview dispatcher:
```text
scroller:toggleoverview
```
- **How it works**: Hyprscroller takes all active columns on the current workspace and calculates a scale factor such that all columns fit within the monitor width in a single horizontal row.
- **Keybinding**: Binding `SUPER + R` to `hyprctl dispatch scroller:toggleoverview` activates and deactivates this mode.
- **Interaction**: While in overview, keyboard navigation (`left`/`right`) or mouse clicking any window focuses that column and exits overview mode, zooming back into that window.
- **Aesthetic difference**: Hyprscroller renders the live Wayland surfaces scaled on the GPU. It does not draw a blurred mobile wallpaper behind them, but the physical positioning and zooming behavior matches the recording.

---

## 4. Deep Dive: Peeking Edge Tabs

### Why `hyprscroller` Cannot Do This Alone
- `hyprscroller` is strictly an internal C++ window tiling engine within Hyprland.
- Its responsibility is solely calculating window bounding boxes `(x, y, w, h)`.
- When an app is off-screen, it is simply placed at an X coordinate outside the monitor's bounds (e.g., `x = 1920` on a 1080p display).
- It has **zero GUI rendering capability**: no layer-shell surfaces, no app icon loaders, no edge hover tabs, and no clickable pills on the monitor borders.

### How `cool-shell` Delivers the Peeking Edge
Because `cool-shell` runs on Quickshell (Wayland Layer Shell):
1. **Window Coordinate Observation**: Quickshell tracks all open windows on the active workspace and their geometry (`at[0]`, `at[1]`, `size[0]`, `size[1]`).
2. **Edge Detection**:
   - Any window with `x < 0` is categorized as **Off-Screen Left**.
   - Any window with `x >= monitor.width` is categorized as **Off-Screen Right**.
3. **Visual Edge Tab Rendering**:
   - `cool-shell` renders slim, elegant vertical pills on the left and right screen borders (`WlrLayer.Overlay`).
   - Each pill displays the app icon (e.g., Spotify, Chrome, Terminal) and a subtle accent glow.
4. **Interaction**:
   - Clicking or hovering the left/right tab executes `hyprctl dispatch scroller:movefocus, l` or `scroller:movefocus, r`, scrolling the selected app smoothly onto the screen.

---

## 5. Technical Environment & Prerequisites

1. **Hyprland Version**: `0.56.2-4` (Git commit `efb50993780079460b0cbed1363e2166a2de1d9f`).
2. **Arch Package Status**:
   - `extra/hyprpm 0.56.2-4` is available in Arch Linux official repositories.
   - Hyprscroller's active fork (`hyprscrolling` / `hyprscroller-ng`) is compatible with Hyprland 0.56.x.
3. **Configuration Interface**:
   - The user's system utilizes Lua configuration (`/home/pranc/.config/hypr/hyprland.lua`).
   - Plugin loading syntax in Lua: `hypr.plugin = { ... }` or via `hyprpm load hyprscroller`.

---

## 6. Architectural Decision Matrix

| Approach | Pros | Cons | Recommendation |
| :--- | :--- | :--- | :--- |
| **Option 1: Hybrid (`hyprscroller` + `cool-shell`)** | • Native Wayland GPU performance<br>• Real `scroller:toggleoverview` side-by-side scaling<br>• Sleek Quickshell Peeking Edge tabs | • Requires installing `hyprpm` & compiling the plugin against Hyprland 0.56.2 ABI | **Recommended** if user wants true window manager scrolling |
| **Option 2: Pure `cool-shell` Canvas + Hyprland Floating/IPC** | • Zero C++ plugin compilation<br>• 100% custom styling & animations in QML<br>• No ABI breakage across Hyprland updates | • Windows must be managed via floating coordinate offsets or workspace transitions | **Alternative** if user prefers zero external plugin dependencies |

---

## 7. Next Steps (Pending User Approval)

1. Await confirmation on whether to proceed with **Option 1 (Hybrid `hyprscroller` + `cool-shell`)**.
2. If approved:
   - Install `hyprpm` and build `hyprscroller`.
   - Configure `scroller` layout and bind `SUPER + R` to `scroller:toggleoverview` in `hyprland.lua`.
   - Implement `PeekingEdge.qml` in `cool-shell` to render the edge tabs for off-screen apps.
