# Implementation Plan: Redesigned Spatial Workspace Carousel (Mission Control)

**Date**: 2026-10-04  
**Feature**: Cover Flow / Carousel Mission Control Overview  
**Target Path**: `components/SpatialWorkspaceMap.qml`  

---

## 1. Executive Summary & Objective

Redesign the **Mission Control / Spatial Workspace Overview** in `cool-shell` into an ultra-premium, cinematic **Cover Flow / Carousel Deck**:
- **Single Workspace Focus with Peeking Cards**: A large, high-resolution primary workspace card in the center (~70% of screen width, 16:9 ratio), with the previous and next workspace cards sticking out symmetrically on the left and right edges (scaled down and softly dimmed).
- **Fluid Navigation**: Full support for Mouse drag & wheel scrolling, Arrow keys (`Left`/`Right`), Number keys (`1`-`9`), `Enter`/Click to warp, and `Esc` to dismiss.
- **Actually Live Visual Fidelity**: Each workspace card represents a real live desktop:
  - True desktop background/wallpaper rendering behind windows.
  - Realistic, high-fidelity window surfaces matching exact screen geometry (`at` and `size`), with authentic window chrome (window control dots, app icons, real window titles, app-specific styling like terminal prompts and browser tab bars).
  - Active window highlighted with an accent glow.
- **Zero-Overhead Lifecycle**: Renders **strictly when `Super + Tab` is open**. When dismissed, the surface is unmapped (`visible: false`), completely unhooked from Wayland layer-shell, consuming 0% GPU, 0% CPU, and 0 memory cycles.

---

## 2. Layout & Interaction Design

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MISSION CONTROL CAROUSEL                        │
│                                                                        │
│   ┌──────────────┐     ┌────────────────────────┐     ┌──────────────┐ │
│   │ [1] Brave    │     │ [2] Kitty (ACTIVE)     │     │ [3] Terminal │ │
│   │              │     │                        │     │              │ │
│   │ ┌──────────┐ │     │ ┌───────┐   ┌────────┐ │     │ ┌──────────┐ │ │
│   │ │ 🌐 Brave │ │ ◄── │ │  Sh  │   │  Nvim │ │ ──► │ │  Build  │ │ │
│   │ └──────────┘ │     │ └───────┘   └────────┘ │     │ └──────────┘ │ │
│   │              │     │                        │     │              │ │
│   └──────────────┘     └────────────────────────┘     └──────────────┘ │
│     (Peeking Left)          (Large Center Focus)        (Peeking Right) │
│                                                                        │
│        ◄ [Left]            [1-9] Direct Jump            [Right] ►      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Implementation Steps

### Step 1: Geometry Data Verification in `core/SurfaceModel.qml`
- Confirm `geomX`, `geomY`, `geomWidth`, `geomHeight` extracted from `tl.lastIpcObject.at` and `tl.lastIpcObject.size`.

### Step 2: Build Cover Flow Architecture in `components/SpatialWorkspaceMap.qml`
- Rebuild layout around an index-driven carousel:
  - `currentIndex`: Tracks the active centered workspace index.
  - Smooth spring animation interpolation on card horizontal offset, scale, and opacity.
  - Centered card: Full 16:9 ratio (~1300px on 1080p, scale 1.0, opacity 1.0, elevated z-index).
  - Left adjacent card: Shifted left so ~120-140px peeks into view, scale 0.84, opacity 0.45.
  - Right adjacent card: Shifted right so ~120-140px peeks into view, scale 0.84, opacity 0.45.
  - Other cards: Pushed further offscreen.
- High-fidelity live desktop content:
  - System wallpaper rendered as card base.
  - Real window replicas matching exact on-screen geometry, with traffic light dots, app icons, titles, and terminal/browser styling.
- Navigation handlers:
  - Wheel scroll & horizontal drag gestures.
  - Arrow keys (`Left` / `Right`).
  - Number keys `1`-`9`.
  - Enter / Click to warp.
- Strict lifecycle: `visible: open || exitAnim.running`.

### Step 3: Shell Integration & Verification
- Verify `Super + Tab` keybinding in `hyprland.lua`.
- Test IPC calls `overview show`, `overview toggle`, `overview close`, `overview isOpen`.
- Validate zero-cost unmapping when closed.
