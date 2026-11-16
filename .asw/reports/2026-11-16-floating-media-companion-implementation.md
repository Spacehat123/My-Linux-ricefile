# Architectural Report: Floating Media Player Companion Pill & Top Bar Media Decoupling

**Date**: 2026-11-16  
**Topic**: Floating Media Companion Pill Implementation with Kinetic Synchronized Lyrics, Anchored Draggable Lifecycle, and Central Notch Decoupling  
**Target Systems**: `panels/FloatingMediaCompanion.qml`, `panels/TopConvexBar.qml`, `island/Notch.qml`, `island/ShellState.qml`, `shell.qml`

---

## 1. Executive Summary

Per user direction, the legacy middle top bar dropdown media panel (`MediaPanel.qml`) embedded within the Dynamic Island notch has been completely retired and decoupled from `SUPER + M`. In its place, a high-fidelity **Floating Media Companion Pill** (`FloatingMediaCompanion.qml`) has been engineered and deployed into Quickshell.

### Key Architectural Pillars:
1. **Top Bar Left Anchor**: Positioned by default directly below the top convex bar's left mini-visualizer and track title marquee (`x: 140, y: 52`), maintaining spatial cohesion with the existing top bar audio indicators.
2. **Hybrid Movable / Pinned Lifecycle**:
   - **Unmoved ("Leave like normal")**: Automatically wakes on active playback, auto-closes on pause/stop, consuming 0% idle CPU overhead.
   - **Dragged / Moved**: Dragging the capsule beyond a 35px threshold automatically locks it into **Pinned Mode** (`isPinned = true`). It remains anchored wherever the user placed it across track changes and playback pauses.
   - **Dismissal & Reset**: Clicking the tactile `✕` close button or invoking reset immediately animates the pill closed, clears the pin lock, and snaps default coordinates back to `(140, 52)`.
3. **Kinetic Dual-Slot Synchronized Lyrics**:
   - Utilizes dual overlapping typography slots (`prevText` and `currText`) driven by `Island.IslandHub.liveLyric` (fed via `sptlrx pipe -p mpris`).
   - Outgoing line transitions with `Easing.InCubic` (240ms, slide up `0 -> -12px`, fade to 0).
   - Incoming line transitions with `Easing.OutCubic` (320ms, slide up `+14 -> 0px`, fade from 0 to 1).
4. **Dual-Mode Fluid Aesthetics**:
   - **Light Mode**: Warm cream luxury palette (`#f4f0e7` base, `#fcf9f4` elevated card, charcoal typography `#1a1a1f`, raspberry accent `#ff2a5f`).
   - **Dark Mode**: Tinted obsidian glass (`#0b0c10` base, subtle key specular highlights, neon emerald/magenta accents).
5. **Full Click-Through Input Mask**:
   - Implemented using Quickshell `mask: Region { item: capsuleCard }`, ensuring that although the PanelWindow covers the full screen for unrestricted drag translation, 100% of clicks outside the 420x110px capsule pass directly through to underlying desktop windows.

---

## 2. Technical Implementation Details

### A. Middle Top Bar Notch Decoupling
- **`panels/TopConvexBar.qml`**:
  - Removed `MediaPanel` item declaration (`lines 923-927`).
  - Removed `"media": mediaPanel` entry from the internal `panels` lookup map.
  - Linked the left top-bar music visualizer `MouseArea` (`onClicked`) to trigger `Island.ShellState.show("media")`.
- **`island/Notch.qml`**:
  - Removed `MediaPanel` instantiation from the Dynamic Island notch layout.
- **`island/ShellState.qml`**:
  - Added signal `signal toggleMediaCompanionRequested()`.
  - In `ShellState.show(name, screenName)`:
    ```qml
    if (name === "media") {
        close();
        toggleMediaCompanionRequested();
        return;
    }
    ```
  - This ensures that Hyprland's `SUPER + M` binding (`qs -c cool-shell ipc call notch toggle media`) instantly forwards to the companion pill without expanding the central notch.

### B. Floating Media Companion (`panels/FloatingMediaCompanion.qml`)
- **Dimensions**: `420px` width $\times$ `110px` height (`radius: 24`).
- **Draggable Region**: Full-width header handle mouse area (`drag.target: capsuleCard`).
- **Progress Scrubber**: Real-time position tracking (`Island.IslandHub.mediaPosition` / `mediaLength`), formatted `mm:ss` timestamps, interactive seek area.
- **Spectrum Visualizer**: Mini 4-bar live audio spectrum connected to `Island.IslandHub.levels`.
- **IPC Interface**:
  - `media_companion.toggle()`: Toggles visibility.
  - `media_companion.setOpen(bool)`: Explicit open/close state.
  - `media_companion.moveTo(targetX, targetY)`: Moves the card and activates pinned state.
  - `media_companion.getState()`: Returns comprehensive JSON state (`open`, `isPinned`, `x`, `y`, `title`, `artist`, `isPlaying`).

---

## 3. Verification & Evidence Matrix

| Verification Target | Command / Action | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Middle Top Bar Purge** | Inspect `Notch.qml` and `TopConvexBar.qml` | No `MediaPanel` in notch | Completely removed | **PASS** |
| **`SUPER + M` Binding** | `qs -c cool-shell ipc call notch toggle media` | Toggles Floating Media Companion | Companion opened/closed | **PASS** |
| **Top Bar Visualizer Click** | Top-left music row `MouseArea` | Dispatches `ShellState.show("media")` | Companion toggles | **PASS** |
| **Draggable & Pinned Lock** | `qs -c cool-shell ipc call media_companion moveTo 500 300` | Moves card, sets `isPinned = true`, shows `PINNED` badge | Position `(500, 300)`, `isPinned: true` | **PASS** |
| **Close & Reset** | `qs -c cool-shell ipc call media_companion toggle` | Resets `isPinned = false`, snaps back to `(140, 52)` on next open | Position reset to `(140, 52)` | **PASS** |
| **Dark Mode Rendering** | Visual snapshot | Obsidian dark card, neon visualizer, crisp typography | Captured: `media_companion_live.png` | **PASS** |
| **Light Mode Rendering** | Switch to light mode via `theme-system.sh mode light` | Cream `#f4f0e7` card, charcoal text, raspberry accents | Captured: `media_companion_light.png` | **PASS** |
| **Live Pinned UI** | Visual snapshot at `(500, 300)` | Visible `PINNED` pill badge, close button `✕` | Captured: `media_companion_pinned.png` | **PASS** |

---

## 4. Visual Evidence Artifacts

- **Dark Mode Appearance**: [`media_companion_live.png`](file:///home/pranc/.gemini/antigravity-cli/brain/ab1a4395-5e43-4997-afd1-07d69f06f5c4/media_companion_live.png)
- **Light Mode Appearance (Warm Cream)**: [`media_companion_light.png`](file:///home/pranc/.gemini/antigravity-cli/brain/ab1a4395-5e43-4997-afd1-07d69f06f5c4/media_companion_light.png)
- **Live Pinned & Dragged State**: [`media_companion_pinned.png`](file:///home/pranc/.gemini/antigravity-cli/brain/ab1a4395-5e43-4997-afd1-07d69f06f5c4/media_companion_pinned.png)
