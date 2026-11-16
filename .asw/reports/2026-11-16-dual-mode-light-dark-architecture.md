# Universal Dual-Mode (Light/Dark) Architecture & Capsule Slider Geometry Fix

**Date**: 2026-11-16  
**Status**: Completed & Verified Live  
**Target Systems**: Quickshell (Cool-Shell), GTK 3/4, FreeDesktop Portal, Desktop App Ecosystem  

---

## 1. Executive Summary

This engineering effort resolves two critical interface challenges:
1. **Capsule Slider Geometry Arc Inversion**: Fixed a severe rendering glitch where values above 78% caused the lower arc segment of the capsule slider to invert and punch a circular void into the bottom of the pill. Replaced brittle piecewise SVG arcs with a congruent viewport-clipped capsule system (`fillViewport.clip: true`) that guarantees smooth, glitch-free filling from 0% to 100%.
2. **Universal Dual-Mode Architecture (Dark & Light Mode)**: Implemented an end-to-end, system-wide Light Mode / Dark Mode engine across all Quickshell surfaces (Control Center, Left and Right Sidebars, Top Bar, Bottom Bar, Floating Islands) and desktop applications (GTK, portal-compliant apps like Nautilus, Brave, VS Code).
   - **Aesthetic Direction**: Strictly adheres to the **warm cream / alabaster / parchment base** (`#f4f0e7` to `#f7f1f3`), avoiding pure blinding white (`#ffffff`).
   - **Contrast & Legibility**: Strict dark charcoal and deep espresso typography (`#1d2420` to `#261b22`) preventing any white-on-white text collisions.
   - **Separation of Concerns**: Themes (Nature, Cherry, Sea, Space, Darth) govern artistic accent palettes; Modes (`dark` vs `light`) govern luminance and background/foreground contrast.

---

## 2. Capsule Slider Mathematical Fix

### Problem Analysis
The previous capsule slider in [VerticalCapsuleSlider.qml](file:///home/pranc/.config/quickshell/cool-shell/components/VerticalCapsuleSlider.qml) attempted to render the filled region using a single contiguous SVG path with piecewise `Arc` elements. When the fill fraction $y$ exceeded $0.78$ ($h \approx 122\text{px}$ of the $158\text{px}$ height), the bottom arc `sweep: 1` command from $(0, 122)$ to $(72, 122)$ swept upwards through $(36, 86)$, cutting a circular void out of the lower capsule half.

### Architectural Solution
Instead of approximating capsule boundaries with piecewise SVG math, the slider now uses **congruent viewport geometry clipping**:

```qml
Item {
    id: fillViewport
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: Math.max(0, Math.min(parent.height, parent.height * root.displayValue))
    clip: true

    Rectangle {
        id: fullPill
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: root.height
        radius: width / 2
        color: root.accentColor
    }
}
```

- **Invariance**: The inner `fullPill` has exact width, height, and corner radius identical to the parent track capsule.
- **Clipping**: The outer `fillViewport` anchors to the bottom with `clip: true`, dynamically resizing its height to `parent.height * displayValue`.
- **Result**: Zero protrusions, zero inversions, zero squishing, and exact mathematical adherence to the capsule radius across 0% to 100%.

---

## 3. Universal Dual-Mode Architecture

### A. Cream Light Mode Palette Design
Dedicated `light_colors` blocks were engineered for all theme presets in `theme/presets/` and `~/.config/vyeos/themes/`:

| Palette Token | Dark Mode (`nature`) | Cream Light Mode (`nature`) | Purpose |
| :--- | :--- | :--- | :--- |
| `bg0` | `#1e2326` (deep dark) | `#f4f0e7` (warm cream) | Main canvas & window backgrounds |
| `bg1` | `#272e33` (card surface) | `#fcf9f4` (elevated cream) | Top bar, popovers, elevated surfaces |
| `bg_dim` | `#14181a` (inset background) | `#e8e3da` (soft sand) | Recessed tracks, pill background |
| `foreground`| `#d3c6aa` (pale parchment) | `#1d2420` (deep charcoal)| Primary typography & high-contrast icons |
| `muted` | `#7a8478` (subtle gray) | `#56665c` (dark sage gray)| Subtitles, secondary labels |
| `primary` | `#a7c080` (soft pastel green)| `#2d8a5b` (crisp forest green)| Active controls, slider fills, badges |
| `primary_container`| `#2d353b` | `#d6ede0` (tinted mint cream)| Active button containers, pill badges |

### B. Shell Reactive Theme Singleton (`island/Theme.qml`)
[Theme.qml](file:///home/pranc/.config/quickshell/cool-shell/island/Theme.qml) exposes dynamic properties that respond instantly to mode changes:
- `property string mode: "dark"`
- `readonly property bool isLightMode: mode === "light"`
- **Adaptive Glass Materials**:
  - `glassCard`: Light mode uses `Qt.rgba(1.0, 1.0, 1.0, 0.55)`; Dark mode uses `Qt.rgba(1.0, 1.0, 1.0, 0.04)`.
  - `glassBorder`: Light mode uses subtle dark charcoal boundary `Qt.rgba(0.12, 0.10, 0.12, 0.09)`.
  - `glassBackground`: Dynamically binds to `isLightMode ? "#f4f0e7" : "#08070b"`.

### C. Theme Engine Pipeline (`island/scripts/theme-system.sh`)
The backend CLI manager supports mode querying, toggling, and generation:
- `theme-system.sh mode [dark|light]`: Applies mode, persists to state file `~/.local/state/vyeos/current_mode`.
- `theme-system.sh toggle-mode`: Toggles between dark and light modes.
- `theme-system.sh current-mode`: Queries active mode.
- **GTK & Portal Synchronization**:
  - Automatically executes `gsettings set org.gnome.desktop.interface color-scheme "prefer-light"` (or `"prefer-dark"`).
  - Regenerates `~/.cache/vyeos/theme/gtk.css` linking to GTK3 & GTK4 configurations with `@define-color window_bg_color @vyeos_bg0;` and `@define-color window_fg_color @vyeos_foreground;`.
  - Dispatches `qs -c cool-shell ipc call theme reload` or `setMode`.

### D. Shell IPC & Appearance State
[AppearanceState.qml](file:///home/pranc/.config/quickshell/cool-shell/island/AppearanceState.qml) and [shell.qml](file:///home/pranc/.config/quickshell/cool-shell/shell.qml) bind IPC calls:
- `qs -c cool-shell ipc call theme toggleMode`
- `qs -c cool-shell ipc call theme setMode "light"`

### E. Control Center Modes Pod Integration
In [ControlCenter.qml](file:///home/pranc/.config/quickshell/cool-shell/components/ControlCenter.qml) (Row 3, Tile 3: Quick Modes Pod):
- Button 4 is configured as a live Mode Switcher:
  - Label: `Island.Theme.isLightMode ? "󰖔 Dark" : "󰖨 Light"`
  - Action: Invokes `Island.AppearanceState.toggleMode()` on click.

### F. Top Convex Bar, Bottom Bar & Sidebar Conformance
- **Top Convex Bar** ([TopConvexBar.qml](file:///home/pranc/.config/quickshell/cool-shell/panels/TopConvexBar.qml)):
  - Retained without direct edits to preserve existing layout code.
  - Automatically inherited `Island.Theme.surfaceOpaque` (warm cream) and `Island.Theme.foreground` (charcoal typography), seamlessly transitioning to Light Mode.
- **Bottom Bar Dock & Popovers** ([BottomBar.qml](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml)):
  - Replaced hardcoded `#07070a` dock capsule color with dynamic `Island.Theme.isLightMode ? Island.Theme.surfaceOpaque : Qt.tint("#07070a", ...)`.
  - Replaced hardcoded `#0b0c10` in popovers (Volume, Network, Battery, Tooltips) with `Island.Theme.surfaceElevated`.
  - Replaced gauge background `#20ffffff` with dynamic recessed track `Qt.rgba(0, 0, 0, 0.08)` in light mode.
- **Sidebars & Drawers** ([LeftSidebar.qml](file:///home/pranc/.config/quickshell/cool-shell/panels/LeftSidebar.qml), [RightSidebar.qml](file:///home/pranc/.config/quickshell/cool-shell/panels/RightSidebar.qml)):
  - **Eliminated Discoloration Gradient**: Constrained atmospheric light dispersion gradient to dark mode only (`visible: !Island.Theme.isLightMode`), eliminating green-tinted haze over light cream backgrounds.
  - **Replaced Muddy Dark Cards**: In [RightSidebar.qml](file:///home/pranc/.config/quickshell/cool-shell/panels/RightSidebar.qml), replaced `Qt.rgba(0, 0, 0, 0.40)` on Telemetry, Audio, and Overview cards with `Island.Theme.glassCard` (`Qt.rgba(1.0, 1.0, 1.0, 0.55)`), rendering soft, elevated cream cards with crisp borders.
  - **VU-Meter & Track Recesses**: Made unlit segments and fader tracks dynamic subtle recesses (`Qt.rgba(0, 0, 0, 0.08)` in light mode).

---

## 4. Verification Matrix

| Test Scenario | Test Value / Action | Observed Result | Status |
| :--- | :--- | :--- | :--- |
| Slider Low Value | Brightness 16%, Volume 17% | Full rounded base, no protrusion outside capsule bounds | PASS |
| Slider Mid-High Value | Brightness 79%, Volume 77% | Clean horizontal fill line, zero bottom arc inversion/void | PASS |
| Slider Extreme Value | Volume 95% | Smooth fill conforming to top and bottom arcs | PASS |
| Mode Toggle via CLI | `theme-system.sh toggle-mode` | Instant switch, gsettings updated, shell reloaded | PASS |
| Mode Toggle via IPC | `qs ipc call theme toggleMode` | State synchronized reactively across all windows | PASS |
| Mode Toggle via UI | Control Center Tile 3 Button 4 | Toggles Dark/Light label and active shell theme | PASS |
| Cream Palette Verification | Inspection of active light theme | Warm cream `#f4f0e7` base, `#1d2420` dark charcoal text | PASS |
| GTK Portal Conformance | GNOME interface color-scheme | Set to `'prefer-light'` / `'prefer-dark'` dynamically | PASS |
| Bottom Bar Light Mode | Compact and expanded state | Warm cream pill `#f4f0e7`, high-contrast charcoal text/icons | PASS |
| Right Sidebar Telemetry | Telemetry and Audio cards | Elevated white-cream cards, zero green wash, crisp contrast | PASS |

---

## 5. Artifacts and Live Visual Evidence

- **Right Sidebar (Refined Warm Cream Live)**: [right_sidebar_cream_verified.png](file:///home/pranc/.gemini/antigravity-cli/brain/ab1a4395-5e43-4997-afd1-07d69f06f5c4/right_sidebar_cream_verified.png)
- **Bottom Bar (Warm Cream Live)**: [bottom_bar_cream_verified.png](file:///home/pranc/.gemini/antigravity-cli/brain/ab1a4395-5e43-4997-afd1-07d69f06f5c4/bottom_bar_cream_verified.png)
- **Bottom Bar Expanded (Warm Cream Live)**: [bottom_bar_expanded_cream.png](file:///home/pranc/.gemini/antigravity-cli/brain/ab1a4395-5e43-4997-afd1-07d69f06f5c4/bottom_bar_expanded_cream.png)
- **Left Sidebar (Light Mode Cream)**: [sidebar_light_mode.png](file:///home/pranc/.gemini/antigravity-cli/brain/ab1a4395-5e43-4997-afd1-07d69f06f5c4/sidebar_light_mode.png)
- **Slider Geometry Verification (79%)**: [sidebar_79_verified.png](file:///home/pranc/.gemini/antigravity-cli/brain/ab1a4395-5e43-4997-afd1-07d69f06f5c4/sidebar_79_verified.png)
- **Slider Geometry Verification (95%)**: [sidebar_95_verified.png](file:///home/pranc/.gemini/antigravity-cli/brain/ab1a4395-5e43-4997-afd1-07d69f06f5c4/sidebar_95_verified.png)
