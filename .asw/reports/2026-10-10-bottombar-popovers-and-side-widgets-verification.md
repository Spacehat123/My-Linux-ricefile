# Verification Report: BottomBar Theme Tint, Popover Widgets, and Side Widget Hover Continuity

**Date:** 2026-10-10  
**Environment:** Arch Linux, Hyprland 0.56.2, Quickshell 0.3.1  
**Target Subsystems:**
- `panels/BottomBar.qml`: 1px workspace pills, gray/black inner color, deep theme tint background, dedicated hover popovers for Wi-Fi, Sound, Battery, and zero click-blocking mask discipline.
- `panels/MediaWidget.qml`: 12px right margin pointer bridge, non-blocking full-coverage hover detection.
- `components/StashPocket.qml`: Full-coverage non-blocking hover area across internal drawer.
- `shell.qml`: Debounce timer calibration (600ms).

---

## 1. Executive Summary

All objectives requested by the user have been successfully implemented and verified:
1. **Workspace Pills in BottomBar**:
   - `border.width` is fixed to exactly `1px` across active, occupied, and idle pills.
   - Inner pill background colors strictly use monochrome glass (`Island.Theme.glassCard` / `glassCardHover`) without pink or primary tint, preserving the dark minimal aesthetic.
2. **BottomBar Dynamic Theme Tint**:
   - The entire dock capsule background dynamically calculates `Qt.tint("#07070a", Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.08))`.
   - Transitions smoothly across theme switches with a 300ms `ColorAnimation`.
3. **Dedicated Status Popover Widgets**:
   - **Sound & Volume Popover (`volPopover`)**: Shows active sink name, large volume percentage, Mute/Unmute toggle, fluid interactive volume slider, and Pavucontrol mixer launcher.
   - **Wi-Fi & Network Popover (`netPopover`)**: Shows active connection type (Wi-Fi / Ethernet), SSID, signal strength gauge, and quick link to network settings.
   - **Power & Battery Popover (`batPopover`)**: Displays live battery percentage, charging state (AC power vs battery), remaining time estimation, battery gauge bar, and power settings shortcut.
   - **Hover Bridge & Continuity**: Popovers appear when hovering their respective pills, bridge cursor movement via `popoverHoverBridge`, remain open while hovered, and smoothly close after a 280ms debounce when the pointer leaves.
4. **Click-Through Mask Discipline (`mask: Region`)**:
   - While popovers are closed, `mask: Region` strictly covers only `dockBody` (the 44px dock capsule). All space above the bar passes clicks through 100% to background application windows.
   - While a popover is active, `mask: Region` includes only `dockBody`, `activePopoverItem`, and `popoverHoverBridge`. Regions outside the card pass clicks through completely.
5. **Side Widgets Hover Continuity Fix (`MediaWidget` & `StashPocket`)**:
   - Eliminated the 12px dead zone between the right screen edge and `cardBody` in `MediaWidget.qml` by masking and bridging `hoverBridge`.
   - Replaced fragile single `HoverHandler` with non-blocking full-coverage `MouseArea` (`acceptedButtons: Qt.NoButton`, `hoverEnabled: true`) in both `MediaWidget.qml` and `StashPocket.qml`.
   - Increased dismiss debounces in `shell.qml` to 600ms. Side widgets now stay open reliably while moving the cursor across buttons, sliders, and drop targets.

---

## 2. Verification Matrix

| Requirement | Implementation Detail | Target File | Status |
| :--- | :--- | :--- | :---: |
| **Pill Border Width** | `border.width: 1` universally across all states | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L204) | **PASS** |
| **Pill Inner Color** | Active pill uses `Island.Theme.glassCardHover` (monochrome gray/black) instead of primary tint | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L197-L203) | **PASS** |
| **Dock Background Tint** | `Qt.tint("#07070a", Qt.rgba(Island.Theme.primary.r, ..., 0.08))` with 300ms animation | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L157-L162) | **PASS** |
| **Sound Popover Widget** | Floating volume widget with sink info, interactive slider, mute button, pavucontrol launcher | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L465-L640) | **PASS** |
| **Wi-Fi Popover Widget** | Floating network widget with SSID, signal strength badge, and settings shortcut | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L642-L765) | **PASS** |
| **Battery Popover Widget** | Floating battery widget with charging telemetry, time remaining, progress gauge | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L767-L910) | **PASS** |
| **Click-Through Safety** | `mask: Region` strictly limits input regions to visible elements; zero blocked clicks behind | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L47-L68) | **PASS** |
| **MediaWidget Continuity** | Added `hoverBridge` (12px edge margin) and `cardMouseArea` (`containsMouse` tracking) | [`panels/MediaWidget.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/MediaWidget.qml#L37-L65) | **PASS** |
| **StashPocket Continuity** | Added `drawerMouseArea` across drawer body; `windowHovered` tracks child button hover | [`components/StashPocket.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/StashPocket.qml#L144-L148) | **PASS** |
| **Daemon Reload & IPC** | Daemon reloads cleanly with zero QML runtime errors or layout warnings | Shell runtime | **PASS** |

---

## 3. Implementation Code Diffs Summary

### A. `panels/BottomBar.qml`
- Extended `implicitHeight` from 44px to 220px to host floating popovers above `dockBody`.
- Formulated `mask: Region` with conditional `activePopoverItem` and `popoverHoverBridge`.
- Replaced pink workspace pill background with `Island.Theme.glassCardHover`.
- Fixed workspace pill border to `1px`.
- Created three dedicated popover widgets with auto-centering over their respective trigger pills.

### B. `panels/MediaWidget.qml`
- Added `hoverBridge` item to bridge the 12px right margin.
- Included `hoverBridge` in `mask: Region`.
- Added non-blocking `cardMouseArea` to ensure hover state is retained when cursor interacts with playback buttons and audio visualizer canvas.

### C. `components/StashPocket.qml`
- Added non-blocking `drawerMouseArea` inside `drawer`.
- Updated `windowHovered` to monitor `drawerMouseArea.containsMouse`, preventing premature drawer collapse when cursor hovers action buttons (`stashBtnMouse`, `restoreMouse`, `toggleMouse`).

### D. `shell.qml`
- Calibrated `mediaCloseDebounce` and `stashCloseDebounce` intervals to 600ms for comfortable pointer transit.

---

## 4. Operational Status
- Quickshell configuration reloaded cleanly.
- IPC commands verified via `quickshell -c cool-shell ipc call state ...`.
- No click interception on background desktop surfaces.
