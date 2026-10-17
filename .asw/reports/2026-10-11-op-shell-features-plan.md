# Architectural Plan: OP Cool-Shell Features Upgrade

**Document ID**: `.asw/reports/2026-10-11-op-shell-features-plan.md`  
**Date**: 2026-10-11  
**Target Environment**: Arch Linux, Hyprland 0.56.2, Quickshell (Cool-Shell QML)  
**Status**: In Progress — Implementation Phase

---

## 1. Executive Summary

This engineering plan details the implementation of three standout features for **Cool-Shell**:

1. **Live Synchronized Lyrics in Dynamic Island** (`sptlrx`):
   - Zero-overhead, event-driven streaming of time-synced lyrics from MPRIS/Spotify directly into the collapsed Island pill and expanded Media card.
   - Completely idle (0% CPU / 0MB RAM) when no music is playing.
2. **Material You Dynamic Palette Engine** (`matugen`):
   - Real-time extraction of Google Material 3 tonal palettes from active wallpapers and album art.
   - Instantly recalculates and updates Cool-Shell theme colors, Hyprland active border colors, and terminal aesthetics in under 10ms.
3. **Mission Control Upgrade for Bird's-Eye View** (`components/BirdsEyeOverview.qml`):
   - Elevates Bird's Eye into a full macOS Mission Control / Exposé experience while preserving the "Bird's-Eye View" name and hotkeys.
   - Adds a top workspace strip (Space 1, Space 2, Space 3...) with live window counts.
   - Non-overlapping, intelligent 2D window Exposé grid with window titles, app icons, hover close buttons (`✕`), and fluid focus animation.

---

## 2. Feature Specifications

### 2.1 Live Synchronized Lyrics in the Dynamic Island
* **Engine**: `sptlrx` v1.3.1 installed at `~/.local/bin/sptlrx`.
* **Execution Strategy**:
  - Bound to `IslandHub.mediaPlaying`.
  - When music starts: Starts `sptlrx pipe -p mpris` in background process.
  - When music pauses or changes track: Process pauses or restarts cleanly.
  - When music stops: Process terminates immediately to conserve RAM and CPU.
* **UI Delivery**:
  - In `Notch.qml` (collapsed pill): When lyrics are available, displays `♪ <current lyric>` with smooth fade transitions.
  - In `MediaPanel.qml`: Displays a dedicated synced lyrics view beneath the track information.

### 2.2 Material You Dynamic Palette Engine (`matugen`)
* **Engine**: `matugen` 4.2.0 installed at `~/.local/bin/matugen`.
* **Execution Strategy**:
  - Invoked automatically on wallpaper change in `island/scripts/theme-system.sh` (`set_wallpaper`) or manually via Theme panel toggle.
  - Command: `matugen image "<wallpaper_path>" -j hex --source-color-index 0`
  - Maps M3 tonal palette to Cool-Shell's `Theme.palette` format:
    - Primary $\to$ `colors.primary`
    - Container $\to$ `colors.primary_container`
    - Background $\to$ `colors.background`
    - Surface $\to$ `colors.surface`
    - Text $\to$ `colors.on_surface`
  - Automatically updates Hyprland active border colors:  
    `hyprctl keyword general:col.active_border "rgb($primary) rgb($primary_container) 45deg"`

### 2.3 Bird's-Eye View Mission Control Upgrade (`BirdsEyeOverview.qml`)
* **Top Spaces Bar**:
  - Horizontal pill row displaying all workspaces with their status (active, occupied, empty).
  - One-click workspace jump.
* **Exposé Window Grid**:
  - Automatically calculates optimal columns and rows for all windows on the active workspace.
  - Non-overlapping cards with aspect-ratio-scaled snapshot/content frames.
  - Header with application icon, window title, and quick-close button (`✕`).
  - Active selection indicator with glowing accent border.
  - Full keyboard navigation: `Up`, `Down`, `Left`, `Right`, `Return`, `Space`, `Escape`.
  - Click any window card to focus and exit.

---

## 3. Implementation Steps

1. **Step 1: Material You Engine**:
   - Create `scripts/generate-palette.sh` using `matugen`.
   - Hook into `island/scripts/theme-system.sh` and `island/panels/ThemePanel.qml`.
2. **Step 2: Synchronized Lyrics**:
   - Create `island/scripts/lyrics-daemon.sh` (wraps `sptlrx pipe -p mpris`).
   - Wire into `IslandHub.qml` with lifecycle tied to `mediaPlaying`.
   - Display lyrics in `CollapsedStatus.qml` / `Notch.qml` and `MediaPanel.qml`.
3. **Step 3: Bird's-Eye View Mission Control**:
   - Upgrade `components/BirdsEyeOverview.qml` with Spaces bar + 2D Exposé window layout.
   - Verify smooth transitions and lazy-loaded memory behavior.

---
