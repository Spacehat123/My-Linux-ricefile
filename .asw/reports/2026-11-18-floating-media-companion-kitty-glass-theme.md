# Floating Media Companion: Wide Typography, Waveform Visualizer & Borderless Glass

**Date**: 2026-11-18  
**Component**: [panels/FloatingMediaCompanion.qml](file:///home/pranc/.config/quickshell/cool-shell/panels/FloatingMediaCompanion.qml)  
**Evidence**: [.asw/reports/media_companion_wide_lyrics_waveform.png](file:///home/pranc/.config/quickshell/cool-shell/.asw/reports/media_companion_wide_lyrics_waveform.png)  

---

## 1. Modifications Implemented

1. **Wide Lyrics Typography (matching uploaded reference)**:
   - Restored and wired `Fredoka Bold` variable font across all 3 synchronized lyric rows (previous, active, and upcoming).
   - Applied wide, bold rounded letterforms (`font.family: "Fredoka"`, `font.weight: Font.Bold`, `font.pixelSize: 14..15`, `font.letterSpacing: 0.5`) with high-contrast white foreground matching the user's reference.

2. **Border Removal**:
   - Removed the outer border on `cardBody` (`border.width: 0`, `border.color: "transparent"`).

3. **Removed Tab Title Pill**:
   - Completely deleted the `» 1: mpris*` rectangle badge from the top header row, leaving only the centered grab handle and top-right close button.

4. **Bidirectional Title Waveform Visualizer**:
   - Completely removed the 14-bar bottom underlay visualizer (`cavaSpectrumUnderlay`).
   - Replaced it with a compact, inline bidirectional audio visualizer directly next to the track title in `metaBlock`.
   - Visualizer consists of 7 vertical bars (`width: 2.5`, `radius: 1.25`) anchored at their vertical midline (`anchors.verticalCenter: parent.verticalCenter`). As frequency levels modulate, the bars expand symmetrically **both up and down** around the center horizontal axis, styled in `kittyActiveBorder` (`#a5b4fc`).

---

## 2. Verification Matrix

| Target | Specification | Result |
|---|---|---|
| Outer Border | None | `border.width: 0`, `border.color: "transparent"` (**PASS**) |
| Tab Badge | Removed | `» 1: mpris*` deleted from header (**PASS**) |
| Lyrics Font | Wide / Fredoka Bold | `Fredoka Bold` (15px active, 11px preview) (**PASS**) |
| Visualizer Placement | Next to Track Title | Inline inside `metaBlock.Row` (**PASS**) |
| Visualizer Direction | Symmetrical both ways (up/down) | `anchors.verticalCenter: parent.verticalCenter` (**PASS**) |
| Live Playback | Verified | *The Clash - "London Calling"* (**PASS**) |
