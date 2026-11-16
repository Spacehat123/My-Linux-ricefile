# Pre-Flight Architectural Plan: visionOS Modular Control Center Tiles & Image Engine

**Document Identifier**: `.asw/reports/2026-11-16-modular-control-center-visionos-implementation-plan.md`  
**Date**: November 16, 2026  
**Status**: APPROVED & IN EXECUTION  
**Subject**: Modular Squircle Tile Redesign for `cool-shell` Control Center (`components/ControlCenter.qml`) and End-to-End Image Engine Remediation

---

## 1. Executive Summary & Objective

The objective of this initiative is twofold:
1. **End-to-End Image Generation Remediation (`Super + G`)**:
   - Resolve the module loading and dependency deficit in the Python 3.12 virtual environment (`/home/pranc/.local/share/cool-shell/venv`).
   - Complete caching of Realistic Vision v5.1 + LCM-LoRA model weights.
   - Harden IPC synchronization between `image-engine.py`, `image-daemon.py`, and `IslandHub.qml` to guarantee zero indefinite hangs on "Generating Image...".
2. **Modular Control Center Redesign (visionOS / iOS 18 Style)**:
   - Transform [`components/ControlCenter.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/ControlCenter.qml) into a modular squircle tile grid inspired by Apple visionOS (User Reference Image 1).
   - Implement dual vertical liquid capsule sliders for Display Brightness and Master Volume.
   - Group controls into coherent, tactile frosted-glass pods while strictly preserving 100% of the underlying business logic: Study Mode ceremony, StarkCAD Studio lifecycle, CoolPhone bridge, Feather battery optimization, Game Mode bloat-killer, and audio/display bindings.

---

## 2. Architectural Blueprint: visionOS Tile Hierarchy

The Control Center drawer width is 328px (within the 360px sidebar). The UI grid follows a 2-column layout with 12px gutter spacing:
$$(328\text{px} - 12\text{px}) / 2 = 158\text{px per pod}$$

```
+-------------------------------------------------------------+
| Header: 22px Clock (hh:mm) + Date + Settings Gear           |
+------------------------------+------------------------------+
| [POD 1: Connectivity (2x2)]  | [POD 2: Now Playing Media]   |
| • Wi-Fi Pill/Circle          | • Album Art + Output Icon    |
| • Bluetooth Pill/Circle      | • Track Title & Artist       |
| • Dynamic Wallpaper Toggle   | • Transport: Prev, Play, Next|
| • Ambient HUD Overlay Toggle |                              |
+------------------------------+------------------------------+
| [POD 3: System Modes (2x2)]  | [POD 4: Liquid Dual Sliders] |
| • Game/Perf Mode (Red)       | • Display Brightness Capsule |
| • Feather Battery (Green)    |   (Vertical Fill, Sun Icon)  |
| • Do Not Disturb (Violet)    | • Master Volume Capsule      |
| • Night Light (Amber)        |   (Vertical Fill, Speaker)   |
+------------------------------+------------------------------+
| [POD 5: Study Mode Hard Lockout Banner (Full Width)]        |
| • Status, Subject, Remaining Timer, Password Modal Trigger  |
+-------------------------------------------------------------+
| [POD 6: Pro Systems Pod (2 Columns)]                         |
| • StarkCAD Studio (Toggle + Open HUD Button)                |
| • CoolPhone Mirror & Battery Status                         |
+-------------------------------------------------------------+
| [POD 7: AI Image Studio & Prompt Shortcut Banner]           |
| • Model status (Warm RAM / Offloaded) + Super+G Shortcut     |
+-------------------------------------------------------------+
| [POD 8: Display & Workspace Telemetry + Quick Actions]      |
| • Workspace & Active Surface Count                          |
| • Action Buttons: Screen Capture, Region Clip, Screen Record|
+-------------------------------------------------------------+
```

---

## 3. Detailed Component Specifications

### 3.1 Dual Vertical Liquid Capsule Sliders
- **Visuals**:
  - Width: 72px each, Height: 158px.
  - Corner radius: 36px (continuous capsule).
  - Background: Frosted translucent dark glass (`#16151f80`) with 1px directional border (`Island.Theme.glassBorderSubtle`).
  - Fluid Fill: Rectangular fill anchored to bottom, matching capsule radius, filled smoothly:
    - Brightness: Warm white/amber fill (`#ffffff`).
    - Volume: Cool white/cyan fill (`#ffffff`).
  - Contrast Icon:
    - Sun icon for brightness (`󰃠`), speaker icon for volume (`󰕾` / `󰖁`).
    - Positioned at the lower third with smart contrast inversion.
  - Telemetry:
    - Percentage readout pinned at top (`Island.Backend.brightness + "%"` and `root.audioMuted ? "Muted" : Math.round(root.currentVolume * 100) + "%"`).
- **Interactivity**:
  - Vertical dragging using `MouseArea` or `TapHandler` + drag tracking:
    $$\text{level} = 1.0 - \frac{y}{\text{height}}$$
  - Clamped to $[0.0, 1.0]$.
  - Tapping speaker icon toggles `root.sinkAudio.muted`.

### 3.2 Connectivity Pod (2x2 Squircle)
- Rounded squircle card (158x158px, `radius: 22`, frosted glass).
- 4 circular action buttons (~62x62px):
  1. **Wi-Fi**: Icon `󰤨`. Vibrant blue fill when connected (`#0a84ff`).
  2. **Bluetooth**: Icon `󰂯`. Vibrant blue fill when enabled.
  3. **Wallpaper Dynamic**: Icon `󰸉`. Accent glow when enabled.
  4. **Ambient HUD**: Icon `󰍹`. Cycles through Dynamic $\to$ Always On $\to$ Off.

### 3.3 Now Playing Media Pod
- Rounded squircle card (158x158px, `radius: 22`, frosted glass).
- Integrates `Quickshell.Services.Mpris`:
  - Resolves active Spotify/media player.
  - Shows 40x40 rounded album art or `󰎆` fallback.
  - Track title & artist with `Text.ElideRight`.
  - AirPlay / output badge.
  - Tactile playback controls: Previous, Play/Pause toggle, Next.

### 3.4 System Modes Pod (2x2 Quad)
- 4 interactive round/pill buttons:
  1. **Performance Mode** (`󰓅`, Red accent): Toggles `Island.ShellState.toggleGameMode()`.
  2. **The Feather** (`󰌪`, Emerald green accent): Toggles `Island.ShellState.toggleFeatherMode()`.
  3. **Do Not Disturb** (`󰂛`, Violet accent): Toggles `Island.IslandHub.dnd`.
  4. **Night Light** (`󰖔`, Amber accent): Toggles `Island.Backend.toggleNightLight()`.

---

## 4. Verification & Testing Matrix

| ID | Test Scenario | Expected Outcome | Verification Tool |
|---|---|---|---|
| **V1** | Python Venv Import Test | PyTorch 2.15 + CUDA 13.2 detected, GPU name valid | CLI Python execution |
| **V2** | Cold AI Image Generation | Generates 512×512 image in `~/Pictures/generated/` and opens viewer | `image-engine.sh` CLI test |
| **V3** | IPC Reset Integrity | Dynamic Island returns to normal state without hanging | `qs ipc call island` |
| **V4** | Control Center Layout | Left sidebar opens with visionOS tiles, 2-column alignment | `qs ipc call control setLeftSidebarOpen true` |
| **V5** | Vertical Sliders | Dragging adjusts brightness and volume; mute toggles on tap | Manual interaction + telemetry inspection |
| **V6** | Visual Verification | Screenshot captured and inspected for fidelity | `grim` screenshot |

---

## 5. Execution Order
1. Confirm completion of model caching on disk.
2. Test end-to-end image generation via `image-engine.sh`.
3. Implement `VerticalCapsuleSlider.qml` modular component.
4. Refactor `components/ControlCenter.qml` with the visionOS modular layout.
5. Reload shell via IPC and test sidebar open/close.
6. Capture screenshot with `grim` and verify UI aesthetic.
