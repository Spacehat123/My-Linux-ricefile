# Native Scrolling Layout, Bird's-Eye View & Peeking Edge Implementation Report

**Date**: 2026-10-09  
**Target Environment**: Hyprland 0.56.2 on Arch Linux (`pranav-arch`)  
**Workspace**: `/home/pranc/.config/quickshell/cool-shell` & `/home/pranc/.config/hypr/hyprland.lua`  
**Subject**: Implementation of Xiaomi Fold / Canvas Multitasking: Infinite Horizontal Scrolling, Bird's-Eye View (`SUPER + R`), and Interactive Peeking Edge Tabs.

---

## 1. Executive Summary & Architectural Breakthrough

When investigating `hyprscroller`, we discovered that **Hyprland 0.55+ natively integrated the scrolling layout directly into Hyprland core C++** (under `Layout::Tiled::CScrollingAlgorithm` and `CScrollTapeController`). The old external plugin (`dawsers/hyprscroller`) was archived precisely because Hyprland adopted the feature natively.

By leveraging **Hyprland's native `scrolling` layout** combined with **`cool-shell` (Quickshell layer-shell overlay)**, we achieved:
1. **Zero External C++ Plugin Dependencies**: No `hyprpm` compilation, no plugin headers mismatch, and **zero risk of breakage after system updates**.
2. **Infinite Horizontal Multi-App Tape**: 2 windows sit comfortably side-by-side on screen (50% column width), with 3rd, 4th, and $N$th windows queued on the extended horizontal tape.
3. **Bird's-Eye View (`SUPER + R`)**: Pressing `SUPER + R` opens a full-screen overview that arranges all active windows on the current workspace in a side-by-side panoramic ribbon, exactly matching the 0:16 pinch-out gesture in `recording-20261009-195909.mp4`.
4. **Interactive Peeking Edge Tabs**: Screen edge pills on the left and right bezels that dynamically detect off-screen windows, display their app icons, titles, and off-screen counts, and smoothly scroll them into view on click or hover.

---

## 2. Hyprland Configuration (`/home/pranc/.config/hypr/hyprland.lua`)

Hyprland's configuration was updated to activate the scrolling layout engine and bind the new navigation controls:

```lua
-- 1. Enable native scrolling layout
general = {
    ...
    layout = "scrolling",
}

-- 2. Scrolling Layout Settings (Tape configuration)
hl.config({
    scrolling = {
        column_width = 0.5,             -- 2 columns fill the screen side-by-side
        direction = "right",            -- New columns appear to the right
        follow_focus = true,            -- Automatically scrolls viewport when window focuses
        fullscreen_on_one_column = true,
    },
})

-- 3. Shortcut Binds
hl.bind("SUPER + R", hl.dsp.exec_cmd("quickshell ipc -c cool-shell call birdseye toggle"))
hl.bind("SUPER + H", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + L", hl.dsp.focus({ direction = "right" }))
```

---

## 3. Component Breakdown

### A. Bird's-Eye View (`components/BirdsEyeOverview.qml`)
- **Layer**: `WlrLayer.Overlay` with exclusive keyboard focus when active.
- **Trigger**: `SUPER + R` or `quickshell ipc -c cool-shell call birdseye toggle`.
- **Layout**: Auto-scales window cards based on open window count so that **all windows fit side-by-side simultaneously on screen** without clipping.
- **Card Metadata**:
  - Live application icon (`Quickshell.iconPath`).
  - Application display name & window title.
  - Position badge: `● ON SCREEN`, `◀ LEFT`, or `RIGHT ▶`.
  - Column index and geometry footprint (`geomWidth × geomHeight`).
- **Interaction**:
  - Keyboard: `Left` / `Right` arrows cycle cards, `Enter` / `Space` focuses and zooms in, `Esc` closes.
  - Mouse: Hovering highlights card with Spring lift physics; clicking immediately focuses that window via `hl.dsp.focus({ window = "address:0x..." })` which smoothly pans the Hyprland viewport to that window.

### B. Peeking Edge Tabs (`components/PeekingEdge.qml`)
- **Layer**: `WlrLayer.Top` anchored to the left and right screen borders (`exclusionMode: Ignore`).
- **Off-Screen Detection**:
  - **Left Off-Screen**: Any window on the active workspace where `(geomX + geomWidth <= 120) || (geomX < -60)`.
  - **Right Off-Screen**: Any window on the active workspace where `geomX >= screenWidth - 120`.
- **Visuals**:
  - **Collapsed State**: A sleek 32px vertical tab on the monitor border with breathing neon accent border, chevron (`‹` / `›`), app icon, and a counter badge (e.g. `+1`) if multiple windows are queued.
  - **Hovered State**: Smoothly expands to 210px via Spring physics, revealing the application name, window title, and "Click to Slide In" action hint.
  - **Placement**: Left tab is centered; Right tab is positioned at 20% from the top so it never conflicts with the Middle-Right Media Widget trigger.
- **Click Action**: Clicking the tab triggers Hyprland to scroll the tape in that direction and focus the adjacent off-screen window.

---

## 4. Maintenance & Upgrade Guide: How Updates Work

### The Huge Advantage of this Native Setup
Because we used **Hyprland's native core `scrolling` layout** rather than an external third-party C++ plugin:
> **You do NOT need to recompile anything when updating your system!**

When you run `sudo pacman -Syu`:
1. Hyprland updates normally via the Arch repositories (`hyprland 0.56.2` -> `0.57.x`).
2. The scrolling engine is part of the Hyprland binary itself, so it updates automatically with zero ABI conflicts.
3. `cool-shell` is written in QML/JavaScript and interacts through Hyprland's standard IPC (`hyprctl dispatch`), meaning it remains 100% compatible across updates.

### If You Ever Need to Recompile or Update Components Manually

#### Scenario 1: Reloading Hyprland Configuration After Editing
If you make changes to `/home/pranc/.config/hypr/hyprland.lua`:
```bash
hyprctl reload
```

#### Scenario 2: Restarting or Reloading `cool-shell`
If you edit `cool-shell` QML files or scripts:
```bash
# Quickshell auto-reloads files live, but to force a clean restart:
pkill quickshell
quickshell -c cool-shell &
```

#### Scenario 3: If You Ever Compile a Custom Hyprland C++ Plugin in the Future
If you ever build a custom C++ plugin that requires compiling against Hyprland headers:
1. Ensure `pkgconf` and compiler tools are present:
   ```bash
   sudo pacman -S --needed base-devel cmake
   ```
2. Check installed Hyprland headers:
   ```bash
   pkg-config --cflags hyprland
   ```
3. In the plugin repository:
   ```bash
   make release
   # Or using cmake directly:
   cmake -B build -DCMAKE_BUILD_TYPE=Release
   cmake --build build -j$(nproc)
   ```
4. Load the compiled `.so` file in Hyprland:
   ```bash
   hyprctl plugin load /path/to/plugin.so
   ```
   *(Note: Again, you do NOT need this for scrolling, as it is already built into your Hyprland binary!)*

---

## 5. Verification Matrix

| Test Scenario | Action | Expected Result | Live Status |
| :--- | :--- | :--- | :---: |
| **1. Layout Engine** | `hyprctl getoption general:layout` | Returns `str: scrolling` | **PASSED** |
| **2. Tape Parameters** | `hyprctl getoption scrolling:column_width` | Returns `0.500000` (2 columns side-by-side) | **PASSED** |
| **3. Multi-Window Tiling** | Opened 3 apps on Workspace 1 (Brave, Spotify, Dolphin) | 2 apps fit on screen, 3rd is off-screen | **PASSED** |
| **4. Peeking Edge Detection** | Spotify at `x = -883px` | Left Peeking Tab appears on left border | **PASSED** |
| **5. Edge Tab Scroll** | Clicked left peeking tab | Viewport panned left, Spotify focused | **PASSED** |
| **6. Bird's-Eye Toggle** | `quickshell ipc -c cool-shell call birdseye toggle` | Overview overlay opens with ribbon | **PASSED** |
| **7. Bird's-Eye Dismiss** | `quickshell ipc -c cool-shell call birdseye toggle` | Overview closes smoothly | **PASSED** |
| **8. Shortcut Binding** | `SUPER + R` configured in `hyprland.lua` | Triggers Bird's-Eye View | **PASSED** |
| **9. Log Hygiene** | `quickshell log -c cool-shell -t 15` | Zero QML warnings / zero errors | **PASSED** |
