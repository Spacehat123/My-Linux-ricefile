# Pre-Flight Execution Plan: Modular Control Center Pods & 4-Stage Roadmap

**Date**: 2026-11-17  
**Phased Roadmap Sequence**:
1. **Phase 1 (Immediate)**: Modular Control Center Pods (Tile & Vial Capsule Sliders)
2. **Phase 2**: Glass Volume & Brightness OSD Popups (1.5s HUD)
3. **Phase 3**: Desktop Ambient Weather & Clock Slate
4. **Phase 4 ("The Big One")**: Floating Contextual Action Hub (`Super + Space` at cursor)

---

## 1. Phase 1 Objective: Modular Control Center Pods

Refine and elevate [components/ControlCenter.qml](file:///home/pranc/.config/quickshell/cool-shell/components/ControlCenter.qml) and [components/VerticalCapsuleSlider.qml](file:///home/pranc/.config/quickshell/cool-shell/components/VerticalCapsuleSlider.qml) to achieve the visionOS aesthetic:
1. **Connectivity Tile (2×2 Squircle)**:
   - Encased in a frosted rounded glass slab (radius 22px).
   - Four circular quick-toggles:
     - **Wi-Fi**: Connected SSID / Off (`#0a84ff`).
     - **Bluetooth**: Connected device / Off (`#0a84ff`).
     - **VPN / Secure Tunnel**: Live WireGuard / Tailscale / OpenVPN network toggle with active shield icon (`󰒘` / `󰦝`).
     - **Airplane / Do Not Disturb**: Hardware radio inhibit (`rfkill`) or silent notification toggle (`󰀝` / `󰂛`).
2. **Vial Capsule Sliders (Vertical Pill Tubes)**:
   - Refactor [components/VerticalCapsuleSlider.qml](file:///home/pranc/.config/quickshell/cool-shell/components/VerticalCapsuleSlider.qml):
   - **Glass Vial Outer Tube**: 2px thick glass bezel with a vertical specular highlight gradient down the left shoulder (`x = 5px`, 1.5px wide highlight strip).
   - **Dense Liquid Fill**:
     - Fluid level rendered with a glowing meniscus line at the liquid surface (`1.5px` brighter cap).
     - Subtle vertical inner depth gradient (dense fluid settling at the bottom, glowing at the surface).
     - High-contrast text & icon color inversion as the liquid level rises above them.
   - **Pure Vector / QML Scenegraph (0.0% CPU)**: Zero GLSL raymarching or continuous GPU recalculations.

---

## 2. Phase 2 Preview: Glass Volume & Brightness OSD Popups
- Dedicated standalone layer-shell overlay window: [panels/OsdOverlay.qml](file:///home/pranc/.config/quickshell/cool-shell/panels/OsdOverlay.qml).
- Subscribed to PipeWire volume changes and brightness sysfs updates.
- Ephemeral 1.5s auto-dismiss timer with 160ms cubic ease fade.
- Floats centered in bottom screen zone (`y = screen.height - 120`).

---

## 3. Phase 3 Preview: Desktop Ambient Weather & Clock Slate
- Workspace-attached slate: [components/DesktopAmbientSlate.qml](file:///home/pranc/.config/quickshell/cool-shell/components/DesktopAmbientSlate.qml).
- Rendered only on empty workspaces or desktop background layer.
- Architectural typography, live weather icon + temp, battery charge ring, and gentle 5s hardware polling.

---

## 4. Phase 4 Preview: Floating Contextual Action Hub ("The Big One")
- Summoned near cursor on `Super + Space` or middle-click.
- Clamped to screen bounds (`x = Math.min(cursorX, screen.width - width)`).
- 4 Power Tools:
  1. Stash File Pocket
  2. Voice Note / Dictation
  3. Screen Lens (OCR / QR)
  4. Clipboard Snippets History

---

## 5. Phase 1 Verification Criteria
- [ ] Connectivity 2x2 Tile contains Wi-Fi, Bluetooth, VPN, and Airplane/DND.
- [ ] Sliders feature distinct vial glass walls, meniscus caps, and specular side streaks.
- [ ] Zero frame-rate drops or background CPU usage when Left Sidebar is open or idle.
- [ ] Seamless integration with current light and dark themes.
