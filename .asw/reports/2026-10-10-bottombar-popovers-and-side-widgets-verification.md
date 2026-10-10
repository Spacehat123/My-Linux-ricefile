# Verification Report: BottomBar Theme Tint, Popover Widgets, and Side Widget Hover Continuity

**Date:** 2026-10-10  
**Environment:** Arch Linux, Hyprland 0.56.2, Quickshell 0.3.1  
**Target Subsystems:**
- `panels/BottomBar.qml`: 1px workspace pills, monochrome gray/black inner color, deep theme tint background, dedicated hover popovers for Wi-Fi, Sound, Battery, and zero click-blocking mask discipline.
- `panels/MediaWidget.qml`: Root-level full-coverage `HoverHandler` and `MouseArea` hover guards, zero-clipping mask discipline when open, unmapped when closed.
- `components/StashPocket.qml`: Multi-layer hover continuity (`rootHoverHandler`, `windowMouseArea`, `drawerMouseArea`, `drawerHover`), full-window mask when open, 28px pill mask when closed.
- `shell.qml`: Debounce timer calibration (800ms), `stashPocketOpen` state synchronization, and `isAnimating` guards on edge trigger deactivation.

---

## 1. Executive Summary

All features and fixes requested by the user have been successfully implemented, verified, and confirmed working:
1. **Workspace Pills in BottomBar**:
   - `border.width` is fixed to exactly `1px` across active, occupied, and idle pills.
   - Inner pill background colors strictly use monochrome glass (`Island.Theme.glassCard` / `glassCardHover`) without primary/pink tint, preserving the dark minimal aesthetic.
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
5. **Side Widgets Hover Continuity & Edge-Leave Resolution (`MediaWidget` & `StashPocket`)**:
   - **Root Cause of Initial Premature Closure**:
     1. Inner slide-in translation (`Translate { x: 430 }` and `Translate { x: 295 }`) moved content items offscreen during the 240ms open animation.
     2. Restrictive `mask: Region` tracking the translated inner items caused Wayland to clip the input region offscreen during transit.
     3. The 3px `EdgeTrigger` deactivation fired immediately when the cursor crossed 3px inward, scheduling dismissal before hover could register on the animated body.
   - **Complete Resolution**:
     1. Placed root-level `HoverHandler` + `MouseArea` (`acceptedButtons: Qt.NoButton`) outside content translation, spanning the entire window from the screen edge.
     2. Input regions: `MediaWidget` is completely unmapped (`visible: false`) when closed, and maintains full unclipped input region when open. `StashPocket` masks to `pocketContent` (full window) when open, and to the 28px indicator pill when closed with stashed windows.
     3. State synchronization: Bound `desktopState.stashPocketOpen` and `monitorScope.stashPocketOpen`, guarded `onDeactivated` against closing while animating (`!isAnimating`), and calibrated debounce timers to 800ms.

---

## 2. Verification Matrix

| Requirement | Implementation Detail | Target File | Status |
| :--- | :--- | :--- | :--- |
| **Pill Border Width** | `border.width: 1` universally across all states | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L204) | **PASS** |
| **Pill Inner Color** | Active pill uses `Island.Theme.glassCardHover` (monochrome gray/black) instead of primary tint | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L197-L203) | **PASS** |
| **Dock Background Tint** | `Qt.tint("#07070a", Qt.rgba(Island.Theme.primary.r, ..., 0.08))` with 300ms animation | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L157-L162) | **PASS** |
| **Sound Popover Widget** | Floating volume widget with sink info, interactive slider, mute button, pavucontrol launcher | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L465-L640) | **PASS** |
| **Wi-Fi Popover Widget** | Floating network widget with SSID, signal strength badge, and settings shortcut | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L642-L765) | **PASS** |
| **Battery Popover Widget** | Floating battery widget with charging telemetry, time remaining, progress gauge | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L767-L910) | **PASS** |
| **Click-Through Safety** | `mask: Region` strictly limits input regions to visible elements; zero blocked clicks behind | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml#L65-L85) | **PASS** |
| **MediaWidget Continuity** | Multi-layer hover guard (`rootHoverHandler`, `windowMouseArea`, `cardHoverHandler`), zero-clipping mask | [`panels/MediaWidget.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/MediaWidget.qml#L37-L75) | **PASS** |
| **StashPocket Continuity** | Multi-layer hover guard (`rootHoverHandler`, `windowMouseArea`, `drawerMouseArea`, `drawerHover`), dynamic mask | [`components/StashPocket.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/StashPocket.qml#L102-L175) | **PASS** |
| **Edge Trigger Guarding** | Guarded `onDeactivated` against closing while animating (`!isAnimating`), 800ms debounce | [`shell.qml`](file:///home/pranc/.config/quickshell/cool-shell/shell.qml#L1958-L2108) | **PASS** |
| **LayerShell Validation** | Verified via `hyprctl layers`: unmapped when closed (0 clicks blocked), mapped when active | Compositor runtime | **PASS** |
| **User Live QA** | Live testing by user confirmed working with fluid hover entry and stable interaction | User feedback | **PASS** |

---

## 3. Operational Verification

1. **Quickshell Daemon Reload**:
   - Restarted via `quickshell kill -c cool-shell && quickshell -c cool-shell -d`.
   - Loaded cleanly with `INFO: Configuration Loaded` and zero runtime errors.
2. **LayerShell Mapping (`hyprctl layers`)**:
   - When idle: Top layer contains 0 side widgets; full click-through to background applications.
   - When active: Surface maps at exact screen edge (`x=1500, w=420` for MediaWidget, `x=1620, w=300` for StashPocket).
3. **IPC Interactivity**:
   - Verified via `quickshell ipc -c cool-shell call state setMediaWidgetOpen ...` and `setStashPocketOpen ...`.
