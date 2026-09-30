# Media Progress Perimeter Border Ring Implementation Report

**Date:** 2026-09-30  
**Target:** `island/Notch.qml` in `~/.config/quickshell/cool-shell/`  
**Topic:** Media Progress Perimeter Border Ring & Interior Tint Elimination

---

## 1. Executive Summary

When playing media in `cool-shell`, two visual defects were present in the Dynamic Island (`island/Notch.qml`):
1. **Interior Fill Defect:** An interior translucent tint rectangle (`mediaFillClip`) filled the left portion of the island corresponding to media progress. Crucially, this interior fill remained visible even after the island was clicked and expanded into full panel view, causing an unsightly colored wash across open panels.
2. **Abrupt Vertical Cutoff on Ring:** The media progress ring was implemented using `mediaRingClip`, which clipped a full-capsule border rectangle with a horizontal bounding box `width = notchBody.width * window.mediaFraction`. This created an unnatural, abrupt vertical line slicing through the top and bottom borders simultaneously as media progressed.

The interior fill (`mediaFillClip`) was removed entirely, eliminating background tinting during both collapsed and expanded states. `mediaRingClip` was replaced with a dedicated `Canvas` item (`mediaRing`) that dynamically strokes along the 360° perimeter of the capsule border. The stroke starts at bottom-center $(W/2, H)$, travels around the perimeter (bottom-center $\to$ bottom-right $\to$ right semicircle $\to$ top-right $\to$ top-left $\to$ left semicircle $\to$ bottom-left $\to$ bottom-center), reaching a full 360° completion at 100% progress.

---

## 2. Review Findings & Fixes Over Prior Attempt

During rigorous skeptical review of the prior attempt, the following defects and weaknesses were identified and fixed:

1. **Capsule Arc Discontinuity (Fatal Jump Artifact):**
   - *Issue:* The prior implementation defined the arc radius as `const r = Math.max(0.1, Math.min(notchBody.radius - offset, h / 2));`. In any state where `notchBody.radius - offset < h / 2` (such as during dynamic spring collapse or panel resizing), $2r < h$. Because the arc centers were fixed at $y_0 + r$, the bottom of the right arc ended at $y_0 + 2r < y_0 + h = \text{startY}$. When `ctx.arc()` was called, the Canvas 2D engine inserted an automatic straight vertical jump line across the inside of the capsule between $(x_0 + w - r, \text{startY})$ and the arc's start point $(x_0 + w - r, y_0 + 2r)$.
   - *Fix:* Replaced with `const r = Math.min(h / 2, Math.max(0.1, w / 2));`. For a true capsule geometry, the semicircular ends must have radius $h / 2$ to span the vertical distance between top edge $y_0$ and bottom edge $y_0 + h$. This mathematically guarantees $C^1$ continuity at all four segment transition vertices under any dimensions.

2. **Imperative Connections to Theme Singleton:**
   - *Issue:* The prior attempt attached a `Connections { target: Theme; function onPrimaryChanged() { ... } }` block. Theme is a singleton and imperative signal handlers are non-idiomatic in QML, producing unnecessary QObject subscription overhead.
   - *Fix:* Replaced with declarative property binding:
     ```qml
     property color strokeColor: Theme.primary
     onStrokeColorChanged: requestPaint()
     ```
     and referenced `strokeColor` directly within `onPaint`.

3. **Unhandled Null Target in islandPlayer Connections:**
   - *Issue:* `Connections { target: window.islandPlayer ... }` lacked guards against a `null` or undefined player object at application startup (before any MPRIS player launches).
   - *Fix:* Added `enabled: target !== null && target !== undefined` and `ignoreUnknownSignals: true` to prevent any runtime warnings.

---

## 3. Mathematical Geometry & Design Details

### Capsule Dimension Parameters
Given `notchBody`:
- Visual Width: $W = \text{notchBody.width}$ (collapsed: $145\text{ px}$)
- Visual Height: $H = \text{notchBody.height}$ (collapsed: $24\text{ px}$)
- Capsule Radius: $R = \text{notchBody.radius}$ (collapsed: $12\text{ px}$)
- Stroke Width: $\text{lw} = 2\text{ px}$
- Inset Offset: $\text{offset} = \text{lw} / 2 = 1\text{ px}$
- Path Width: $w = W - \text{lw} = 143\text{ px}$
- Path Height: $h = H - \text{lw} = 22\text{ px}$
- Path Radius: $r = \min(h / 2, \max(0.1, w / 2)) = 11\text{ px}$

With $\text{lw} = 2$ and $\text{offset} = 1$:
The outer boundary of the stroke aligns exactly at $[0, W]$ and $[0, H]$ with an outer radius of $r + 1 = 12\text{ px} = R$. This is completely congruent with `notchBody`'s outer contour, avoiding both clipping by the compositor window mask and blurring.

### Segment Lengths & Traversal Order
1. **Segment 1 (Bottom Right Straight):**
   - Start: $(x_0 + w/2, y_0 + h) = (72.5, 23)$
   - End: $(x_0 + w - r, y_0 + h) = (133, 23)$
   - Length: $L_1 = (w / 2) - r = 60.5\text{ px}$

2. **Segment 2 (Right Semicircle Arc):**
   - Center: $(x_0 + w - r, y_0 + r) = (133, 12)$
   - Radius: $r = 11\text{ px}$
   - Start Angle: $\pi/2$ ($6\text{ o'clock}$, bottom)
   - Direction: Canvas anticlockwise = `true` (decreasing angle from $\pi/2 \to 0 \to -\pi/2$)
   - End: $(133, 1)$ at angle $-\pi/2$ ($12\text{ o'clock}$, top)
   - Length: $L_2 = \pi \cdot r \approx 34.56\text{ px}$

3. **Segment 3 (Top Straight):**
   - Start: $(x_0 + w - r, y_0) = (133, 1)$
   - End: $(x_0 + r, y_0) = (12, 1)$
   - Length: $L_3 = w - 2r = 121\text{ px}$

4. **Segment 4 (Left Semicircle Arc):**
   - Center: $(x_0 + r, y_0 + r) = (12, 12)$
   - Radius: $r = 11\text{ px}$
   - Start Angle: $-\pi/2$ ($12\text{ o'clock}$, top)
   - Direction: Decreasing angle from $-\pi/2 \to -\pi \to -3\pi/2$ ($6\text{ o'clock}$, bottom)
   - End: $(12, 23)$ at angle $-3\pi/2$
   - Length: $L_4 = \pi \cdot r \approx 34.56\text{ px}$

5. **Segment 5 (Bottom Left Straight):**
   - Start: $(x_0 + r, y_0 + h) = (12, 23)$
   - End: $(x_0 + w/2, y_0 + h) = (72.5, 23)$
   - Length: $L_5 = (w / 2) - r = 60.5\text{ px}$

Total Perimeter:
$$P = L_1 + L_2 + L_3 + L_4 + L_5 = 2(w - 2r) + 2\pi r \approx 311.12\text{ px}$$

---

## 4. Final Code in `island/Notch.qml`

```qml
Canvas {
    id: mediaRing

    x: notchBody.x
    y: notchBody.y
    width: notchBody.width
    height: notchBody.height
    visible: !window.isExpanded && window.mediaActive && !IslandHub.volumeActive
    opacity: 1

    property real animatedFraction: window.mediaFraction
    property color strokeColor: Theme.primary

    Behavior on animatedFraction {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    onAnimatedFractionChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: {
        if (visible)
            requestPaint();
    }
    Component.onCompleted: requestPaint()

    SequentialAnimation {
        id: ringDip

        NumberAnimation {
            target: mediaRing
            property: "opacity"
            to: 0
            duration: 150
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: mediaRing
            property: "opacity"
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    // Track-end ring morph: when a track finishes (isPlaying drops
    // near 100%), dip the ring; it restarts for the next track.
    Connections {
        target: window.islandPlayer
        enabled: target !== null && target !== undefined
        ignoreUnknownSignals: true
        function onIsPlayingChanged() {
            if (window.islandPlayer && !window.islandPlayer.isPlaying && window.mediaFraction > 0.95)
                ringDip.restart();
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const fraction = Math.max(0, Math.min(1, animatedFraction));
        if (fraction <= 0.0001 || width <= 0 || height <= 0)
            return;

        const lw = 2;
        const offset = lw / 2;
        const w = width - lw;
        const h = height - lw;
        const r = Math.min(h / 2, Math.max(0.1, w / 2));
        const x0 = offset;
        const y0 = offset;

        const L1 = Math.max(0, (w / 2) - r);
        const L2 = Math.PI * r;
        const L3 = Math.max(0, w - 2 * r);
        const L4 = Math.PI * r;
        const L5 = Math.max(0, (w / 2) - r);
        const P = L1 + L2 + L3 + L4 + L5;
        if (P <= 0)
            return;

        let rem = P * fraction;

        ctx.save();
        ctx.lineWidth = lw;
        ctx.strokeStyle = "" + strokeColor;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.beginPath();

        const startX = x0 + w / 2;
        const startY = y0 + h;
        ctx.moveTo(startX, startY);

        // Segment 1: Bottom center to right corner
        if (rem <= L1) {
            ctx.lineTo(startX + rem, startY);
            rem = 0;
        } else {
            ctx.lineTo(x0 + w - r, startY);
            rem -= L1;

            // Segment 2: Right semicircle (bottom -> right tip -> top)
            const cx_r = x0 + w - r;
            const cy_r = y0 + r;
            if (rem <= L2) {
                const angle = Math.PI / 2 - (rem / L2) * Math.PI;
                ctx.arc(cx_r, cy_r, r, Math.PI / 2, angle, true);
                rem = 0;
            } else {
                ctx.arc(cx_r, cy_r, r, Math.PI / 2, -Math.PI / 2, true);
                rem -= L2;

                // Segment 3: Top straight line (moving right to left)
                if (rem <= L3) {
                    ctx.lineTo(x0 + w - r - rem, y0);
                    rem = 0;
                } else {
                    ctx.lineTo(x0 + r, y0);
                    rem -= L3;

                    // Segment 4: Left semicircle (top -> left tip -> bottom)
                    const cx_l = x0 + r;
                    const cy_l = y0 + r;
                    if (rem <= L4) {
                        const angle = -Math.PI / 2 - (rem / L4) * Math.PI;
                        ctx.arc(cx_l, cy_l, r, -Math.PI / 2, angle, true);
                        rem = 0;
                    } else {
                        ctx.arc(cx_l, cy_l, r, -Math.PI / 2, -3 * Math.PI / 2, true);
                        rem -= L4;

                        // Segment 5: Bottom straight line from left back to center
                        if (rem <= L5) {
                            ctx.lineTo(x0 + r + rem, startY);
                            rem = 0;
                        } else {
                            ctx.lineTo(startX, startY);
                            rem = 0;
                        }
                    }
                }
            }
        }

        if (fraction >= 0.999)
            ctx.closePath();

        ctx.stroke();
        ctx.restore();
    }
}
```

---

## 5. Invariant Verification Matrix

| Requirement / Invariant | Status | Verification Detail |
| :--- | :--- | :--- |
| **Remove interior tint** | PASS | `mediaFillClip` completely removed; verified via grep that no fill/wash operates on media progress. |
| **360° perimeter trace** | PASS | Exact parametric piecewise curve starting at bottom-center $(W/2, H)$, tracing around capsule perimeter, closing at 100%. |
| **$C^1$ Continuity** | PASS | $r = h/2$ ensures all 4 connection points between straight lines and circular arcs match coordinates identically without jump artifacts. |
| **Only visible when collapsed** | PASS | `visible: !window.isExpanded && window.mediaActive && !IslandHub.volumeActive` guarantees hidden state when expanded or when volume HUD is active. |
| **Smooth progress transitions** | PASS | `Behavior on animatedFraction { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }` provides 250ms smooth interpolation on progress updates. |
| **Track-end ring dip** | PASS | `ringDip` sequential animation preserved on `mediaRing`, triggering when playback ends near 100%. |
| **leftShoulderPath / rightShoulderPath** | PASS | Untouched; lines 760 & 801 remain `visible: false`. |
| **Plain click routing** | PASS | Untouched; lines 876-890 dispatch `ShellState.show("control", window.screen ? window.screen.name : "")`. |
| **Spring physics intact** | PASS | Untouched; width, height, radius, and scale `SpringAnimation` configurations preserved on `notchSurface` and `notchBody`. |
| **Safe null bindings** | PASS | `Connections` guards against null `window.islandPlayer` with `enabled` check and `ignoreUnknownSignals: true`. |
