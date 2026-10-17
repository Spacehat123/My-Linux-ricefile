# Engineering Report: Dynamic Island Drag-and-Drop Captioning Architecture

**Date**: 2026-10-13  
**Author**: Antigravity  
**Topic**: Frictionless Dynamic Island Drag-and-Drop Video/Audio Captioning Engine  
**Status**: Verified & Operational  

---

## 1. Executive Summary

A zero-terminal, tactile Dynamic Island workflow has been engineered for audio/video media files. Users can drag and drop any video or audio file directly onto the Dynamic Island Notch. Instead of opening a terminal or directly dumping media into the Drop Pocket, the island intelligently detects the media MIME type, intercepts the drop with a fluid absorption animation, and opens an interactive Dynamic Island choice panel presenting three actions:

1. **🎬 Embed in Video**: Automatically transcribes/extracts subtitles, muxes them into a lossless soft-subtitle track (`<name>_subtitled.mp4`), writes `<name>.srt`, and archives the captions into `~/Music/caption_extracts/<name>.srt`.
2. **📝 Caption File Only**: Extracts or generates standalone `.srt` files into both the source directory and `~/Music/caption_extracts/` without altering or producing duplicate video files.
3. **󰏫 Stash in Pocket**: Retains standard Drop Pocket behavior by stashing the file path onto the shelf without triggering transcription.

All execution occurs strictly in the background via Quickshell native `Process` workers. No terminal window is ever spawned. The collapsed pill reflects live transcription progress and delivers visual feedback upon completion (green border flash, burst animation, and transient completion notification).

---

## 2. Architecture & Component Blueprint

```
+-----------------------------------------------------------------------------------+
|                           User Drops File onto Island                             |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        island/Notch.qml (shelfDropArea)                           |
|       - Evaluates drop.urls using CaptionState.checkMedia(path)                   |
|       - If non-media (e.g. PDF, PNG, txt): ShelfState.addUrls (standard shelf)    |
|       - If media (video/audio): Plays absorption animation & triggers caption panel|
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                   island/panels/CaptionActionPanel.qml                             |
|       - Media Header & Type Badge ("VIDEO" / "AUDIO")                             |
|       - Choice 1: "Embed in Video" (soft-sub video + archive)                     |
|       - Choice 2: "Caption File Only" (.srt in dir + archive)                     |
|       - Choice 3: "Stash in Pocket" (ShelfState.addFile)                          |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                         island/CaptionState.qml                                   |
|       - Background Process controller                                            |
|       - Spawns ~/.local/bin/fast-caption (NVIDIA FastConformer-CTC + ffmpeg)      |
|       - Emits IslandHub notifications & border indications                        |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                      Underlying Engine: scripts/caption.py                        |
|       - Instant extraction (~0.06s) if embedded subtitle track already exists     |
|       - NVIDIA FastConformer-CTC (NeMo 244M) GPU inference (~40x real-time)       |
|       - Dual-destination persistence: local directory & ~/Music/caption_extracts  |
+-----------------------------------------------------------------------------------+
```

---

## 3. Implementation Details

### 3.1 Background Caption Runner (`island/CaptionState.qml`)
- Singleton handling media classification (`isVideo`, `isAudio`), file path sanitization (`ShelfState.cleanPath`), and background `Process` lifecycle.
- When `startCaption("embed")` or `startCaption("file_only")` is triggered:
  - Invokes `~/.local/bin/fast-caption <filepath> [--no-embed]`.
  - Dispatches `IslandHub.showTransient()` and `IslandHub.flashBorder()`.
  - Listens on `onExited`:
    - Code 0: Triggers green border `#22c55e`, particle burst `IslandHub.burst()`, and notification `"✔ Captions saved to ~/Music/caption_extracts"`.
    - Non-zero: Triggers red border warning.

### 3.2 Dynamic Island Modal (`island/panels/CaptionActionPanel.qml`)
- Tactile panel styled to match `cool-shell` design language (`Theme.bg0`, `Theme.primary`, `Theme.radiusSmall`).
- Dynamically adapts based on media type:
  - For video files: displays all 3 choices ("Embed in Video", "Caption File Only", "Stash in Pocket").
  - For audio files: intelligently hides "Embed in Video" and shows "Generate Caption File (.srt)" and "Stash in Pocket".

### 3.3 Notch Interception (`island/Notch.qml`)
- Extends `shelfDropArea`'s `onDropped`:
  - Inspects `drop.urls` against media extension regex: `/\.(mp4|mkv|webm|mov|avi|m4v|flv|ts|wmv|mp3|wav|m4a|aac|flac|ogg|opus|wma)$/i`.
  - If media is detected, sets `CaptionState.pendingFile` and opens `ShellState.show("caption")`.
  - If non-media, cleanly routes to standard `ShelfState.addUrls(drop.urls)`.

### 3.4 IPC Extensibility (`shell.qml`)
- Added `captionMedia(path)` to allow programmatic or simulated media drops.
- Added `captionAction(action)` supporting `"embed"`, `"file_only"`, `"stash"`, and `"cancel"`.

---

## 4. Verification Matrix

| Test Scenario | Input | Method | Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Embed in Video** | `/tmp/test_drop_video.mp4` | IPC `captionAction "embed"` | Generated `.srt` in `/tmp` & `~/Music/caption_extracts/` + muxed `_subtitled.mp4` with `mov_text` subtitle track. Zero terminal windows opened. | **PASS** |
| **Caption File Only** | `/tmp/test_drop_video.mp4` | IPC `captionAction "file_only"` | Produced `.srt` in `/tmp` & `~/Music/caption_extracts/`. Video left completely untouched. | **PASS** |
| **Instant Subtitle Extraction** | `/tmp/test_already_subbed.mp4` | Existing track probe | Extracted existing track in **0.06s** directly to `.srt` without GPU re-transcription. | **PASS** |
| **Stash in Pocket** | `/tmp/test_stash.mp4` | IPC `captionAction "stash"` | Saved file path directly to `ShelfState` Drop Pocket. No transcription triggered. | **PASS** |
| **Panel Retention on Drop** | Any media file | Drop on Notch | Fixed: `absorbFly.onFinished` was hardcoded to call `ShellState.show("shelf")` after 300ms. Added condition in `Notch.qml` to stay on `"caption"` when media is pending. | **PASS** |
| **Non-Media Drop** | Generic files | Normal drop flow | Stashed directly on shelf with absorption animation. | **PASS** |
| **QML Diagnostics** | `quickshell -c cool-shell` | `quickshell log` | Clean reload, zero syntax/runtime errors. | **PASS** |

---

## 5. Artifacts & Deliverables

- [`island/CaptionState.qml`](file://$HOME/.config/quickshell/cool-shell/island/CaptionState.qml): Background process controller and singleton state.
- [`island/panels/CaptionActionPanel.qml`](file://$HOME/.config/quickshell/cool-shell/island/panels/CaptionActionPanel.qml): Dynamic Island media prompt UI.
- [`island/Notch.qml`](file://$HOME/.config/quickshell/cool-shell/island/Notch.qml): Drag-and-drop interception and panel mapping.
- [`island/ShellState.qml`](file://$HOME/.config/quickshell/cool-shell/island/ShellState.qml): Registered panel dimensions and geometry.
- [`island/IslandHub.qml`](file://$HOME/.config/quickshell/cool-shell/island/IslandHub.qml): Dynamic Island priority arbitration and live progress display.
- [`scripts/caption.py`](file://$HOME/.config/quickshell/cool-shell/scripts/caption.py): Transcription and extraction core backend.
- [`~/.local/bin/fast-caption`](file://$HOME/.local/bin/fast-caption): Global CLI runner script.
