# Quickshell Active Media Playback CPU Suppression & Performance Verification

- **Date**: 2026-11-17
- **Target**: Quickshell Desktop Environment (`cool-shell`)
- **Status**: Complete & Verified (Peak CPU reduced from ~35% to 0.0%–3.0%)

---

## 1. Executive Summary

When audio or video media was actively playing, `quickshell` CPU consumption periodically spiked up to **35%**, hovering around 15%–35% during continuous playback. 

Through thread-level CPU profiling and fine-grained state tracking, we isolated and resolved five compounding architectural bottlenecks that caused continuous reactive binding evaluations, geometry invalidations, and offscreen FBO shader passes during media playback.

Following these targeted interventions, `quickshell` CPU consumption during active media playback dropped from **35%** down to **0.0%–3.0%** (averaging **0.95%**), achieving near-zero compute overhead.

---

## 2. Root Cause Analysis

### Culprit A: Audio Daemon Redundant Disk I/O & Jitter
- **Location**: [`island/scripts/level-meter.py`](file:///home/pranc/.config/quickshell/cool-shell/island/scripts/level-meter.py#L129-L140)
- **Mechanism**: Every 80ms (12.5 times/second), `level-meter.py` opened, formatted, and wrote `$XDG_RUNTIME_DIR/cool-shell-levels.tmp` and executed `os.replace` on the file system. Because Quickshell reads level data via standard output (`SplitParser`), the disk write was obsolete and created ~750 I/O syscalls every minute.

### Culprit B: Sub-Pixel Amplitude Noise Invalidation Loop
- **Location**: [`island/IslandHub.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/IslandHub.qml#L438-L454)
- **Mechanism**: `levelProc.stdout: SplitParser` evaluated incoming 4-band audio levels. A threshold of `diff > 0.012` (1.2% variation) triggered on sub-pixel noise. Because the visualizer bars have a maximum height of 10–12 pixels, variations below 5% (0.05) cannot alter integer pixel heights. Yet every 80ms, `root.levels = next` was re-assigned, forcing every QML item bound to `IslandHub.levels` to recalculate bindings and re-render scene graph nodes.

### Culprit C: Recurring 8-Second SVG Shape Animation Cycle
- **Location**: [`island/components/MinflairSparkle.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/components/MinflairSparkle.qml#L65-L73) and [`panels/TopConvexBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/TopConvexBar.qml#L358-L364)
- **Mechanism**: `MinflairSparkle` had an active background timer firing every 8,000ms, triggering a 900ms rotation & scale animation on two SVG star paths rendered via `Shape.CurveRenderer`. This accounted for recurring 9%–13% spikes every 8 seconds even with no user interaction.

### Culprit D: Dynamic Visualizer Geometry Churn in TopConvexBar
- **Location**: [`panels/TopConvexBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/TopConvexBar.qml#L473-L515)
- **Mechanism**: Mini visualizer bars inside `leftMusicCapsule` utilized dynamic `Repeater` delegates with unfixed row widths. Whenever `IslandHub.levels` fluctuated, `leftMusicRow.implicitWidth` signaled changes, exciting `Behavior on width` on `leftMusicCapsule`, which recalculated `leftW`, which in turn invoked `PathSvg { path: root.getConvexPath(...) }`, tessellating the entire top convex bar shape on every frame.

### Culprit E: Offscreen FBO Shader Pass on Transparent Rectangle
- **Location**: [`panels/FloatingMediaCompanion.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/FloatingMediaCompanion.qml#L209-L224)
- **Mechanism**: A `shadowLayer` rectangle with `color: "transparent"` had `layer.enabled: true` and `MultiEffect { shadowEnabled: true; shadowBlur: 0.65 }`. Because the item was completely transparent, the GPU executed multi-pass blur shaders on an empty texture.

---

## 3. Engineering Remediation

1. **Streamlined `level-meter.py`**:
   - Removed all disk write operations (`open`, `os.replace`). Retained stdout streaming via `sys.stdout.write` and `sys.stdout.flush`.
2. **Quantized Audio Level Gating in `IslandHub.qml`**:
   - Quantized audio levels to 0.05 steps (`Math.round(raw * 20) / 20`) and raised update threshold to `diff > 0.04`. Noise and sub-pixel changes now pass through silently without firing QML signal emissions.
3. **Disabled Background Sparkle Timer**:
   - Set `enableIntervalAnim: false` on `minflairIcon` in `TopConvexBar.qml`. Sparkle animations now only run on explicit user interaction.
4. **Decoupled Visualizer Row in `TopConvexBar.qml`**:
   - Implemented 4 static rectangles in a fixed-geometry row (`width: 16`, `height: 12`, `anchors.bottom: parent.bottom`), isolating bar height changes from `leftMusicRow.implicitWidth` and `leftW`.
5. **Eliminated `MultiEffect` FBO Pass in `FloatingMediaCompanion.qml`**:
   - Removed the empty `shadowLayer` and `MultiEffect`. Refined the static 1px hairline border and top chamfer highlight.
   - Replaced dynamic Repeater in `cavaRow` with static bottom-anchored bars in a fixed-geometry box (`width: 18`, `height: 14`).
6. **Optimized Clock Label Timer**:
   - Replaced dynamic `Qt.binding(() => ...)` closure creation every 1,000ms with direct string assignment.

---

## 4. Verification & Live Telemetry

Continuous 20-sample profiling (`top -b -d 1 -n 20 -p <pid>`) during active media playback:

| Sample Index | Timestamp | Quickshell CPU (%) | Status |
|---|---|---|---|
| 1 | 0:05.58 | **0.0%** | Idle baseline |
| 2 | 0:05.60 | **2.0%** | Audio tick |
| 3 | 0:05.60 | **0.0%** | Steady state |
| 4 | 0:05.62 | **2.0%** | Audio tick |
| 5 | 0:05.62 | **0.0%** | Steady state |
| 6 | 0:05.63 | **1.0%** | Audio tick |
| 7 | 0:05.63 | **0.0%** | Steady state |
| 8 | 0:05.65 | **2.0%** | Audio tick |
| 9 | 0:05.65 | **0.0%** | Steady state |
| 10 | 0:05.66 | **1.0%** | Audio tick |
| 11 | 0:05.66 | **0.0%** | Steady state |
| 12 | 0:05.67 | **1.0%** | Audio tick |
| 13 | 0:05.68 | **1.0%** | Audio tick |
| 14 | 0:05.69 | **1.0%** | Audio tick |
| 15 | 0:05.69 | **0.0%** | Steady state |
| 16 | 0:05.71 | **2.0%** | Audio tick |
| 17 | 0:05.71 | **0.0%** | Steady state |
| 18 | 0:05.72 | **1.0%** | Audio tick |
| 19 | 0:05.74 | **2.0%** | Audio tick |
| 20 | 0:05.77 | **3.0%** | Position update |

- **Average CPU**: **0.95%**
- **Peak CPU**: **3.0%** (down from **35%**)
- **Zero 30%+ Spikes**: Confirmed.
