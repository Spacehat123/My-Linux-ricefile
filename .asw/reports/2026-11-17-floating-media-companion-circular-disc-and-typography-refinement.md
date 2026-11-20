# Floating Media Companion: Circular Disc Album Art, Controls Alignment, Top Bar Interaction & Fredoka Typography Verification Report

**Author**: Antigravity Assistant  
**Date**: 2026-11-17  
**Workspace**: `/home/pranc/.config/quickshell/cool-shell`  
**Target Files**:
- [`panels/FloatingMediaCompanion.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/FloatingMediaCompanion.qml)
- [`panels/TopConvexBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/TopConvexBar.qml)
- [`island/ShellState.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/ShellState.qml)
- [`island/scripts/lyrics-fetcher.py`](file:///home/pranc/.config/quickshell/cool-shell/island/scripts/lyrics-fetcher.py)

---

## 1. Executive Summary

This report documents the resolution of five distinct aesthetic and behavioral issues reported on the Floating Media Companion widget:
1. **Circular Album Cover Display**: Fixed the invisible album art bug by replacing an unrendered `MultiEffect` layer mask with a dedicated `OpacityMask` (`Qt5Compat.GraphicalEffects`), seamlessly clipping the album art into a circle without corner leakage.
2. **Button Center Alignment & Placement**: Removed the `-8px` vertical offset and top-aligned `Row` behavior that caused the `⏮` and `⏭` buttons to sit higher than the `⏸` button. All three controls are now centered on the exact horizontal and vertical center of the circular disc.
3. **Decoupled Playback Auto-Reveal & Added Top Bar Hover/Click Triggers**: Removed the intrusive `open = true` behavior on track playback start. The widget now strictly opens when hovering over or clicking the top bar's left music pill (`leftMusicCapsule`). Hover exit closes the widget after a 380ms grace delay unless pinned or hovered directly.
4. **Typography Overhaul to Fredoka Bold**: Installed the official `Fredoka` variable font (`~/.local/share/fonts/Fredoka-VariableFont_wdth,wght.ttf`) and wired `FontLoader` across all text elements in the companion (Track Title, Artist, Synced Lyrics, Time label, and Badges).
5. **Language Filter for Lyrics (English, Kannada, Hindi)**: Enhanced `lyrics-fetcher.py` with multi-tier Unicode script and stopword analysis. Lyrics in disallowed languages (e.g., French, Spanish, Russian, German, CJK) are strictly discarded, while Kannada (`\u0C80-\u0CFF`), Devanagari Hindi (`\u0900-\u097F`), and English / Romanized Hinglish & Kanglish are preserved.

---

## 2. Technical Modifications

### A. Circular Album Cover Clipping (`FloatingMediaCompanion.qml`)
- **Root Cause**: Previously, an invisible `Item` (`visible: false`) was passed to `MultiEffect` as `maskSource`. In Qt Quick, items with `visible: false` that do not have active rendering layers produce empty alpha textures, causing `MultiEffect` to multiply the entire image by zero alpha. Furthermore, standard Qt Quick `Rectangle { clip: true }` only clips rectangular bounding boxes, leaking square corners outside the circular border.
- **Resolution**:
  - Imported `Qt5Compat.GraphicalEffects`.
  - Used `OpacityMask` with an offscreen `Rectangle { id: discCircleMask; radius: 70; color: "#ffffff"; visible: false }` and `Image { id: discArtImage; visible: false }`.
  - Rendered `OpacityMask` directly inside `innerDisc` under a subtle 32% black scrim overlay (`Qt.rgba(0, 0, 0, 0.32)`), ensuring album art remains vibrant while maintaining contrast for playback controls.

### B. Controls Alignment & Centering
- **Root Cause**: `Row` children default to top alignment (`y: 0`). Because Previous/Next were 28px tall and Play/Pause was 42px tall, the side buttons were positioned 7px above the center axis. In addition, `anchors.verticalCenterOffset: -8` shifted the entire control cluster above the disc's equator.
- **Resolution**:
  - Removed `verticalCenterOffset`.
  - Set `controlsRow` to `height: 42` and `anchors.centerIn: parent`.
  - Placed Previous and Next inside dedicated 42px containers with `anchors.centerIn: parent` and `anchors.verticalCenter: parent.verticalCenter` on the Play button. All three button centers now share the exact same horizontal baseline.

### C. Top Bar Trigger & Hover/Click State Machine
- **Changes in `island/ShellState.qml`**:
  - Added reactive property `property bool mediaCompanionHovered: false`.
- **Changes in `panels/TopConvexBar.qml`**:
  - Added `hoverEnabled: true` to `leftMusicCapsule`'s `MouseArea`.
  - On hover `entered`: Sets `ShellState.mediaCompanionHovered = true`.
  - On hover `exited`: Sets `ShellState.mediaCompanionHovered = false`.
  - On click (`LeftButton`): Calls `ShellState.toggleMediaCompanionRequested()`.
- **Changes in `panels/FloatingMediaCompanion.qml`**:
  - Added `isLockedOpen` state flag to differentiate temporary hover peeks from persistent toggle clicks.
  - Added `hoverCloseTimer` (380ms) and `cardHovered` tracking (`cardDragMouse.containsMouse`). Hovering over the top bar opens the companion; moving the cursor into the companion card keeps it open; moving away closes it after 380ms.
  - Removed `open = true` in `onIsPlayingChanged` so the card never pops up uninvited.

### D. Typography Overhaul (`Fredoka Bold`)
- Downloaded `Fredoka[wdth,wght].ttf` into `~/.local/share/fonts/` and refreshed system fontconfig cache.
- Added explicit `FontLoader { id: fredokaFont; source: "file:///home/pranc/.local/share/fonts/Fredoka-VariableFont_wdth,wght.ttf" }`.
- Applied `font.family: fredokaFont.name ? fredokaFont.name : "Fredoka"` and `font.weight: Font.Bold`:
  - **Track Title**: 16px Bold.
  - **Track Artist**: 12px Bold.
  - **Active Lyric Line**: 15px Bold (`primary` accent color).
  - **Previous & Next Lyrics**: 12px Bold (38% and 50% opacity).
  - **Time Label Pill**: 10px Bold.

### E. Language Filter for Lyrics (`island/scripts/lyrics-fetcher.py`)
- Added `is_allowed_language()`:
  - **Kannada**: Unicode block `[\u0C80-\u0CFF]` -> Accepted.
  - **Devanagari Hindi**: Unicode block `[\u0900-\u097F]` -> Accepted.
  - **Foreign Non-Latin Scripts**: Cyrillic, CJK, Arabic, Greek, Thai, Tamil, Telugu, Malayalam, Bengali -> Rejected.
  - **Foreign Latin Accents**: `é, è, ê, à, â, ç, ñ, ¿, ¡, ä, ö, ü, ß, ã, õ` (frequency > 3) -> Rejected.
  - **Stopword Analysis**: French, Spanish, German, Italian stop words are compared against English, Hinglish, and Kanglish vocabularies. Foreign language songs (e.g., *Ainsi bas la vida*) return `[]`.

---

## 3. Verification & Evidence Matrix

| Criterion | Expected Behavior | Observed Result | Status |
| :--- | :--- | :--- | :--- |
| **Album Cover Shape** | Crisply clipped to a circle matching the progress ring border | Captured in `/tmp/media_companion_final.png` showing circular album cover of *Maathu Sothu* with zero square edge bleed | **PASS** |
| **Controls Alignment** | Previous, Play, Next centers aligned on same horizontal baseline | All 3 button centers share exact vertical center axis (`height: 42`, dead center in disc) | **PASS** |
| **No Auto-Open on Playback** | Companion stays closed when media begins playing | Initial state `open: false`, `quickshell ipc call media_companion getState` confirms `open: false` during active playback | **PASS** |
| **Top Bar Hover & Click** | Peeks on hover, locks open on click | `leftMusicCapsule` has `hoverEnabled: true`, sends hover state via `ShellState`, click toggles persistent state | **PASS** |
| **Fredoka Bold Typography** | Big, rounded, bold fonts across title, artist, and lyrics | `Fredoka` font loaded via `FontLoader`, verified visually in live screenshot | **PASS** |
| **Language Filtering** | Only English, Kannada, and Hindi lyrics displayed | *Ainsi bas la vida* (French) -> `[]`; *Nange Allava* & *Madanaari* (Kannada) -> Parsed & Synced | **PASS** |
| **Quickshell Daemon** | Clean launch, zero QML warnings | `INFO: Configuration Loaded` with 0 QML warnings or errors | **PASS** |
