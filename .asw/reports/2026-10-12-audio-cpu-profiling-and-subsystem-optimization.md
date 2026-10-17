# Audio Telemetry CPU Profiling & Subsystem Optimization Report

- **Date**: 2026-10-12
- **Status**: Completed & Verified (<0.5% Shell CPU achieved)
- **Scope**: Music playback CPU profiling, Spotify Electron footprint, PipeWire level-meter daemon elimination, Left Sidebar controls

---

## 1. Deep CPU Profiling Breakdown (Why 8% – 14% Occurred)

When profiling active system processes during Spotify music playback across the 12-core CPU, the exact culprits were identified:

| Process | PID | Actual CPU Core Usage | Role |
| :--- | :--- | :--- | :--- |
| `spotify` (renderer) | 3216, 3120 | **~75% - 90% of a core** (~7% system total) | Spotify's Chromium/CEF UI + audio stream decoder |
| `level-meter.py` | 52171 | **~3.0% - 4.0% of a core** | PipeWire audio tap polling `pw-record` at 12Hz |
| `quickshell` (QSGRenderThread) | 791 | **~5.0% - 8.0% of a core** | 60 FPS Qt Quick SceneGraph animation of 4 bars (`waveRow`) |
| `sptlrx` (Go binary) | 52172 | **~0.1% of a core** | Lyrics pipe daemon |

### Key Discovery:
1. **The Lyrics daemon (`sptlrx`) was only consuming 0.1% CPU.**
2. When the user turned off lyrics, the system CPU stayed between 8% and 14% because:
   - **Spotify itself** is a heavy Chromium application consuming ~8% of total machine CPU.
   - **`level-meter.py`** was still polling PipeWire at 12Hz, writing to disk, and triggering continuous SceneGraph re-renders of the 4 waveform bars in `CollapsedStatus.qml`.

---

## 2. Remediation & Hard Compute Toggles

1. **Guarded Level-Meter Daemon**:
   - Added `IslandHub.visualizerEnabled` (default: `false`).
   - If disabled, `level-meter.py` **never spawns**, the watchdog restart timer never triggers, and `waveRow` in `CollapsedStatus.qml` does not animate.
2. **Dual Toggles in Left Sidebar** ([`components/ControlCenter.qml`](file://$HOME/.config/quickshell/cool-shell/components/ControlCenter.qml#L735-L815)):
   - **`♪ Lyrics On / Off`**: Toggles `IslandHub.lyricsEnabled`. When off, kills `sptlrx` via SIGTERM and disables auto-restart.
   - **`󰎆 Waveform On / Off`**: Toggles `IslandHub.visualizerEnabled`. When off, terminates `level-meter.py` and stops all SceneGraph 60 FPS bar animations.
3. **IPC Controls Added to [`shell.qml`](file://$HOME/.config/quickshell/cool-shell/shell.qml#L1755-L1775)**:
   - `qs -c cool-shell ipc call island setLyricsEnabled <bool>`
   - `qs -c cool-shell ipc call island setVisualizerEnabled <bool>`
   - `qs -c cool-shell ipc call island toggleLyrics`
   - `qs -c cool-shell ipc call island toggleVisualizer`

---

## 3. Verification Matrix

- [x] **Shell CPU with Both Toggles Off**: `quickshell` dropped to **< 0.5% CPU** (below detection threshold in top 15 processes).
- [x] **No lingering background daemons**: Verified `ps aux | grep -E "sptlrx|level-meter"` returns 0 processes.
- [x] **Spotify Isolation**: Clarified that Spotify's own Chromium process consumes ~70-90% of a core while playing music.
