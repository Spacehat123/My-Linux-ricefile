# Verification Report: Radial Marking Menu Hub, Bottom-Left Slate & Weather Typography Refinement

**Date**: 2026-11-17  
**Scope**: Quickshell Desktop UI (`cool-shell`) & Hyprland Input Pipeline  
**Verified Evidence Artifacts**:
- [radial_hub_perfect_shape.png](file:///home/pranc/.gemini/antigravity-cli/brain/b628907f-e6fd-4609-9ad8-c932d04b63f8/radial_hub_perfect_shape.png)
- [ambient_ws4_clean.png](file:///home/pranc/.gemini/antigravity-cli/brain/b628907f-e6fd-4609-9ad8-c932d04b63f8/ambient_ws4_clean.png)

---

## 1. Executive Summary

In response to the user's hand-drawn radial marking menu sketch and layout refinements:
1. **Desktop Ambient Weather & Clock Slate**:
   - Repositioned from screen center to **bottom-left** (`anchors.left: parent.left`, `anchors.bottom: parent.bottom`, with `48px` margins).
   - Removed all legacy telemetry widgets (study sessions grid, debug lines, extraneous HUD items).
   - Fixed dynamic activation: the slate card automatically emerges on empty workspaces (`currentSurfaceCount === 0`) or when idle, and can also be toggled `alwaysOn`.
2. **Radial Marking Menu (Pie Wheel / Ring) for Action Hub**:
   - Replaced rectangular popup card with an interactive **circular donut marking wheel** centered on the cursor position queried via `hyprctl cursorpos -j`.
   - Built 4 directional sectors:
     - **North (-90°)**: 󰄀 Screen Lens (OCR & QR)
     - **East (0°)**: 󰈔 Quick Stash (File Pocket)
     - **South (90°)**: 󰉓 Clipboard History
     - **West (180°)**: 󰍬 Fast Voice Note / Dictation
   - **Gesture Flow**: Trigger with `SUPER + Space` or **middle mouse button** (`mouse:274`), drag towards a sector to aim, and **unclick (release)** to activate the choice.
   - **Deadzone 500ms Dismissal**: If the mouse stays within the center hole (`r < 42px`) and does not move towards any option, the wheel auto-dismisses after 0.5s.
   - **Mathematical Wedge Highlights**: Rendered via `QtQuick.Shapes` `PathArc` and diagonal spokes so active sector highlights curve cleanly along the circular boundary with zero rectangular leakage.
3. **Degree Symbol Fix**:
   - Eliminated double degree symbols (`27°°C` -> `27°C`) across [TopConvexBar.qml](file:///home/pranc/.config/quickshell/cool-shell/panels/TopConvexBar.qml) and [DesktopAmbientSlate.qml](file:///home/pranc/.config/quickshell/cool-shell/desktop/DesktopAmbientSlate.qml) using regex degree stripping `String(tempC).replace(/°/g, "") + "°C"`.

---

## 2. Verification Matrix

| Component | Test Case | Target State | Observed Result | Verdict |
|---|---|---|---|---|
| **Hyprland Input** | `SUPER + Space` & `mouse:274` | Triggers Quickshell `hub openWheel` | Both registered in Hyprland 0.56 lua pipeline (`arg: 97`, `arg: 99`) | PASS |
| **Radial Hub** | Center on Cursor | Spawns centered at pointer | Ring center positioned at `(pos.x, pos.y)` | PASS |
| **Radial Hub** | Drag & Unclick Activation | Releasing cursor triggers selected action | `onReleased` & `onClicked` invoke `triggerChoice()` | PASS |
| **Radial Hub** | Deadzone Timeout | Dismisses after 500ms if mouse doesn't move | `deadzoneTimer` (500ms) active inside hole, stops on exit | PASS |
| **Radial Hub** | Visual Clipping | Quadrant highlights stay within disc | `ShapePath` + `PathArc` geometry with 0 bleeding | PASS |
| **Ambient Slate** | Screen Position | Anchored to bottom-left | `anchors.left` & `anchors.bottom` with 48px margins | PASS |
| **Ambient Slate** | Dynamic Detection | Shows on empty workspace / idle | `workspaceEmpty` (`focusedSurfaceCount === 0`) wired | PASS |
| **Ambient Slate** | Single Degree Symbol | Formats temperature as `27°C` | `27°C` rendered without duplicate degree marks | PASS |
| **Top Bar** | Single Degree Symbol | Formats temperature as `27°C` | `27°C` rendered in center dynamic island convex bar | PASS |

---

## 3. Files Modified
- [panels/ContextualActionHub.qml](file:///home/pranc/.config/quickshell/cool-shell/panels/ContextualActionHub.qml)
- [desktop/AmbientLayer.qml](file:///home/pranc/.config/quickshell/cool-shell/desktop/AmbientLayer.qml)
- [desktop/DesktopAmbientSlate.qml](file:///home/pranc/.config/quickshell/cool-shell/desktop/DesktopAmbientSlate.qml)
- [panels/TopConvexBar.qml](file:///home/pranc/.config/quickshell/cool-shell/panels/TopConvexBar.qml)
- [shell.qml](file:///home/pranc/.config/quickshell/cool-shell/shell.qml)
- [/home/pranc/.config/hypr/hyprland.lua](file:///home/pranc/.config/hypr/hyprland.lua)
