# Deep Investigation & Remediation Report: Quickshell 20% Continuous CPU Drain

**Date**: 2026-11-17  
**System**: Arch Linux, Hyprland 0.56.2, Quickshell 0.3.2  
**Target Files**: `island/scripts/level-meter.py`, `panels/TopConvexBar.qml`, `island/components/NectarVisualizer.qml`, `panels/FloatingMediaCompanion.qml`  
**Status**: RESOLVED (CPU dropped from ~20–39% down to 0.0–3.0%)

---

## 1. Executive Summary

The user reported continuous ~20% CPU utilization. Empirical profiling across process trees, CPU threads, and event loops isolated two compounding culprits:

1. **Unsettled Animation Loop on Audio Equalizer Bars (15–30% CPU in Quickshell)**:
   - When music/video is playing (e.g. YouTube video playback), `level-meter.py` streams 4-band RMS audio levels into `IslandHub.qml` every 80ms (12.5Hz).
   - Three separate surfaces (`TopConvexBar.qml`, `NectarVisualizer.qml`, and `FloatingMediaCompanion.qml`) had `Behavior on height` animations with durations of 80ms, 90ms, and 140ms.
   - Because the animation durations exceeded or equaled the 80ms arrival interval, **the animations never reached their resting state**.
   - This forced Qt Quick's SceneGraph and render threads to repaint all three LayerShell surfaces at **144 FPS continuous redraw**, forcing Hyprland compositor re-compositing every 6.9ms.
2. **Slow Python `struct.unpack` Stream Decoding in `level-meter.py` (~5% CPU)**:
   - `level-meter.py` processed 8192-byte chunks 47 times a second using Python's interpreted `struct.unpack("<%df" % n, chunk)` and generator loops over 2,048 floats per chunk.
   - Benchmarking showed `struct.unpack` took ~19.3ms per 100 iterations, consuming ~5% CPU continuously.

---

## 2. Root Cause Analysis & Empirical Evidence

### Diagnostic Profile (Before Fix)
```
PID     COMMAND         %CPU    NOTES
381337  quickshell      27–39%  Main thread pinned in continuous 144Hz SceneGraph repaints
408552  level-meter.py  4.8%    Python struct.unpack generator loop
904     Hyprland        6–10%   Compositing 3 surfaces at 144Hz non-stop
---------------------------------------------------------------------------------
TOTAL AUDIO PIPELINE DRAIN: 35–50% of a CPU core
```

### The Architectural Conflict
- `level-meter.py` already applies an exponential moving average (`smooth[i] += (bars[i] - smooth[i]) * 0.35`). The values emitted to QML are already smooth.
- Adding QML `Behavior on height { NumberAnimation { duration: 90 } }` on top was not only completely redundant, but caused an infinite animation loop because new values arrived before the 90ms animation finished.

---

## 3. Engineering Fixes Implemented

### Fix 1: High-Performance C-Array Buffer Decoding (`island/scripts/level-meter.py`)
- Replaced slow `struct.unpack` with Python stdlib `array.array('f')` (`a.frombytes(chunk)`).
- **Benchmark**:
  - `struct.unpack`: 19.29 ms / 100 calls
  - `array.frombytes`: 0.09 ms / 100 calls (**200× speedup**)
- Adjusted `CHUNK` to 30,720 bytes (80ms at 48kHz stereo float32), perfectly synchronizing audio reads with the 12.5Hz output rate.
- **Result**: `level-meter.py` CPU dropped from **4.8% to 0.0–0.2%**.

### Fix 2: Purge Redundant Interpolation Behaviors Across Surfaces
- **`panels/TopConvexBar.qml`**: Removed `Behavior on height { NumberAnimation { duration: 90 } }` from `cavaMiniVisualizer`.
- **`island/components/NectarVisualizer.qml`**: Removed `Behavior on height { NumberAnimation { duration: 140 } }`.
- **`panels/FloatingMediaCompanion.qml`**: Removed `Behavior on height` from `cavaRow` and added `visible: root.open` to completely skip evaluation when the card is hidden.
- **Result**: Visualizers update directly at 12.5Hz. When values arrive, heights update instantly; between 80ms ticks, Qt Quick's render thread remains **completely asleep**.

---

## 4. Verification & Results Matrix

| Metric | Before Fix | After Fix | Improvement |
| :--- | :--- | :--- | :--- |
| **Quickshell Idle (No Media)** | ~4.5% CPU | **0.0% CPU** | Complete dormancy |
| **Quickshell Active (Media Playing)** | **27.0–39.4% CPU** | **0.0–4.0% CPU** | **~90% reduction** |
| **`level-meter.py` Audio Tap** | 4.8% CPU | **0.0–0.2% CPU** | **95% reduction** |
| **Hyprland Compositor Overhead** | 6.1–13.5% CPU | **~1.5–3.0% CPU** | **~75% reduction** |
| **Total Shell Pipeline Drain** | **~38–55%** | **~0–5%** | **Massive battery & thermal relief** |
