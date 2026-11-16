# Control Center Geometry, StarkCAD Decommissioning, and Sidebar Clearance Report

**Date**: 2026-11-16  
**Status**: Completed & Verified Live  
**Target Systems**: `components/VerticalCapsuleSlider.qml`, `components/ControlCenter.qml`, `panels/LeftSidebar.qml`, `panels/RightSidebar.qml`  
**Constraint Enforced**: `panels/TopConvexBar.qml` (Top Bar) was completely untouched.

---

## 1. Problem Identification

### A. Capsule Slider Low-Volume Deformation Bug
- **Symptom**: When volume or brightness was adjusted to lower levels (e.g. 15% - 17%), the white fill appeared squished and poked outside the capsule hull to the left and right (as seen in user screenshot `uploaded_media_1794838440224.png`).
- **Root Cause**:
  - `capsuleBody` had `radius: width / 2` (36px).
  - The fill rectangle had `radius: width / 2` with `anchors.left: parent.left` and `anchors.right: parent.right`.
  - At low volume (e.g., height ~25px), QML clamped the inner rectangle's corner radius to `height / 2 = 12.5px`.
  - Because QML's standard `clip: true` on `Rectangle` only clips to the axis-aligned bounding box (`clipRect()`), it does NOT clip to curved corners.
  - The 72px wide rectangle with 12.5px corner radius protruded ~14px horizontally past the 36px radius curved dome of the parent capsule track.

### B. StarkCAD Studio Decommissioning
- **Symptom**: The user deleted StarkCAD from the system. The Control Center still had polling processes (`starkcadCheckProc`, `starkcadActionProc`, `starkcadPollTimer`) attempting to check and restart `starkcad-studio.service` every 2.5 seconds, as well as a dedicated UI card in Row 5.
- **Requirement**: Completely remove StarkCAD from the UI and background lifecycle.

### C. Sidebar and Top Bar Bounds Interference
- **Symptom**: Both `LeftSidebar` (`margins.top: 12`) and `RightSidebar` (`margins.top: 14`) started higher than the 40px top status bar (`TopConvexBar.qml`, `baseHeight: 40`), causing the upper 26-28px of both sidebars to slip under or clash with the top status bar.
- **Constraint**: Do NOT touch/edit the top bar (`TopConvexBar.qml`).

---

## 2. Technical Remediation & Implementation

### A. The Flawless Congruent Viewport Clipping Architecture (`VerticalCapsuleSlider.qml`)
- **Initial Vector SVG Attempt (>78% Arc Inversion)**:
  - While low levels (16%) rendered correctly with SVG arcs, crossing $78\%$ inverted the SVG sweep flag (`sweep=1` from $(0, 122)$ to $(72, 122)$ swept upwards through $(36, 86)$ instead of downwards, carving a circular void at the bottom as seen in `uploaded_media_1794839482030.png`).
- **The Definite Solution: Viewport-Clipped Congruent Capsule**:
  - Replaced piecewise SVG approximations with an elegant, mathematically bulletproof QML viewport:
    ```qml
    Item {
        id: fillViewport
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(0, Math.min(capsuleBody.height, capsuleBody.height * root.displayValue))
        clip: true
        visible: root.displayValue > 0.005

        Rectangle {
            width: capsuleBody.width
            height: capsuleBody.height
            anchors.bottom: parent.bottom
            radius: width / 2
            color: root.isMuted ? Qt.rgba(0.5, 0.5, 0.5, 0.3) : root.activeFillColor
            opacity: root.isMuted ? 0.4 : 0.95
        }
    }
    ```
  - **Why this is mathematically impossible to break**:
    - The inner `Rectangle` is a **complete capsule** identically dimensioned to `capsuleBody` ($72\times 158$, $\text{radius}: 36$). Its bottom dome and top dome are geometrically identical to the track.
    - `fillViewport` is an axis-aligned clipping container anchored to the bottom with height $H \times \text{displayValue}$.
    - At $16\%$, only the bottom $25\text{px}$ of the capsule is revealed—giving the exact dome curvature at the bottom and a sharp horizontal meniscus at the top.
    - At $79\%$ and $95\%$, the mid-body and upper dome are revealed with $0.00\text{px}$ deviation and zero possibility of arc inversions.
  - Added dynamic high-contrast foreground inversion on percentage text ($>85\%$) and bottom icons ($>35\%$).

### B. Complete StarkCAD Purge & Full-Width CoolPhone Bridge Card (`ControlCenter.qml`)
- Completely removed:
  - `starkcadActive` property
  - `starkcadCheckProc` (`systemctl --user is-active starkcad-studio.service`)
  - `starkcadActionProc`
  - `starkcadPollTimer` (2500ms recurring timer)
  - `toggleStarkcad()` method
- Promoted **CoolPhone Bridge** to a full-width visionOS card in Row 5:
  - Height: 60px, Radius: 18px (matching Row 6 AI Image Studio Card).
  - Blue glowing glyph `󰏲`, device status readout ("Connected • 85% 󱐋" or "Disconnected • Scrcpy Mirror"), and interactive pill action button (`MIRROR` / `STOP`).
  - Perfect visual balance across all stacked cards.

### C. Sidebar Clearance Below Top Bar (`LeftSidebar.qml` & `RightSidebar.qml`)
- Updated `margins.top: 52` in both `panels/LeftSidebar.qml` and `panels/RightSidebar.qml`.
- With `TopConvexBar.qml` having `baseHeight: 40`, both sidebars now start at $y = 52\text{px}$, leaving a clean, symmetric $12\text{px}$ floating margin beneath the top status bar.
- `panels/TopConvexBar.qml` was not modified in any way.

---

## 3. Verification Matrix

| Test Scenario | Verification Method | Result | Evidence |
| :--- | :--- | :--- | :--- |
| **Low Volume Slider (16%)** | `wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.16` + Grim screenshot | **PASSED** | Liquid fill conforms strictly inside bottom capsule dome. No horizontal protrusion. |
| **StarkCAD Removal** | `grep -rn -i starkcad .` + visual inspection | **PASSED** | 0 active references; UI card eliminated; no background systemctl polling. |
| **Left Sidebar Clearance** | Grim screenshot of open LeftSidebar | **PASSED** | Top edge starts at $y = 52\text{px}$, cleanly below $40\text{px}$ convex bar. |
| **Right Sidebar Clearance** | Grim screenshot of open RightSidebar | **PASSED** | Top edge starts at $y = 52\text{px}$, cleanly below $40\text{px}$ convex bar. |
| **Top Bar Non-Interference** | Git status & diff inspection | **PASSED** | `panels/TopConvexBar.qml` was not edited. |
| **Quickshell Daemon Health** | `quickshell log -c cool-shell` | **PASSED** | Zero QML compilation or runtime errors. |
