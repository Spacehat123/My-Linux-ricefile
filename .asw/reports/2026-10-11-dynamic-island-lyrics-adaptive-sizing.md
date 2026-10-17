# Dynamic Island Adaptive Lyric Sizing & Zero-Regression Verification

**Date**: 2026-10-11  
**Target Subsystem**: Dynamic Island (`island/Notch.qml`, `island/ShellState.qml`, `island/CollapsedStatus.qml`, `island/panels/MediaPanel.qml`, `island/IslandHub.qml`)  
**Status**: Verified & Active

---

## 1. Overview & User Objective

The user requested that the Dynamic Island expand in both length (width) and height to fit music information and live synchronized lyrics legibly, with the explicit constraint:
> *"not permanent, only when it can find the lyrics."*

When lyrics cannot be found (or music is paused / stopped / instrumental), the island must remain at its standard, compact dimensions with zero visual distortion or wasted screen real estate.

---

## 2. Architecture of Adaptive Dynamic Sizing

```
                   [ Spotify / MPRIS Playing ]
                                |
                   [ sptlrx pipe -p mpris ]
                                |
             +------------------+------------------+
             |                                     |
    [ Lyrics Detected ]                    [ No Lyrics Found ]
             |                                     |
   `hasLiveLyrics: true`                 `hasLiveLyrics: false`
             |                                     |
+----------------------------+     +----------------------------+
| Collapsed Pill:            |     | Collapsed Pill:            |
| - Height: 30px (+25%)      |     | - Height: 24px (compact)   |
| - Width: 220px - 380px     |     | - Width: 145px (compact)   |
|   (proportional to text)   |     | - Text elided to 104px     |
| - Label Width: up to 300px |     |                            |
| - Font Size: 12px DemiBold |     |                            |
|                            |     |                            |
| Expanded Media Panel:      |     | Expanded Media Panel:      |
| - Width: 540px             |     | - Width: 460px             |
| - Panel Height: 265px      |     | - Panel Height: 220px      |
| - Card Height: 230px       |     | - Card Height: 190px       |
| - Lyric Row: visible       |     | - Lyric Row: hidden        |
+----------------------------+     +----------------------------+
```

---

## 3. Modified Components & Implementation Details

### 1. `island/Notch.qml`
- **Canvas Width**: Increased `canvasWidth` from `552` to `600` to prevent clipping when the media panel expands to `540px` (+ corner wings).
- **Reactive State**: Added `hasLiveLyrics`:
  ```qml
  readonly property bool hasLiveLyrics: IslandHub.mediaPlaying && IslandHub.liveLyric.length > 0 && !ShellState.gameMode
  ```
- **Dynamic Collapsed Dimensions**:
  ```qml
  readonly property real collapsedLyricWidth: Math.min(380, Math.max(220, Math.round(IslandHub.liveLyric.length * 7.2 + 65)))
  readonly property int collapsedHeight: (!isExpanded && window.hasLiveLyrics) ? 30 : 24
  readonly property real targetVisualWidth: (isExpanded ? ShellState.targetWidth : (window.hasLiveLyrics ? window.collapsedLyricWidth : 145)) + cornerWing * 2
  readonly property real panelContentHeight: isExpanded ? Math.max(
      (ShellState.panel === "media" ? (window.hasLiveLyrics ? 265 : 220) : (ShellState.panelHeights[ShellState.panel] || 0)),
      requestedPanel ? requestedPanel.implicitHeight : 0
  ) : 0
  ```
- **Live Status Feed**: Wired `hasLyrics: window.hasLiveLyrics` to `CollapsedStatus`.

### 2. `island/CollapsedStatus.qml`
- **Property**: Added `property bool hasLyrics: false`.
- **Text Width Expansion**: Upgraded `primaryLabel.width` from a hardcoded `104px` ceiling to dynamically fill available space up to `300px` when `hasLyrics` is active:
  ```qml
  width: root.hasLyrics
      ? Math.min(implicitWidth, Math.max(160, root.width - (root.unread > 0 ? 24 : 0) - (waveRow.visible ? 20 : 0) - (root.weatherMini !== "" ? 45 : 0) - (root.micActive ? 12 : 0) - (root.camActive ? 12 : 0) - 24))
      : Math.min(implicitWidth, root.weatherMini !== "" ? 68 : 104)
  font.pixelSize: root.hasLyrics ? 12 : 11
  ```

### 3. `island/ShellState.qml`
- **Reactive `targetWidth`**:
  ```qml
  readonly property bool hasLiveLyrics: IslandHub.mediaPlaying && IslandHub.liveLyric.length > 0
  readonly property int targetWidth: {
      if (!expanded)
          return 145;
      if (panel === "media")
          return hasLiveLyrics ? 540 : 460;
      return panelWidths[panel] || 145;
  }
  ```

### 4. `island/panels/MediaPanel.qml`
- **Dynamic Sizing**:
  ```qml
  readonly property bool hasLyrics: IslandHub.liveLyric.length > 0 && IslandHub.mediaPlaying
  implicitWidth: hasLyrics ? 540 : 460
  ...
  Rectangle {
      id: mediaCard
      width: parent.width
      height: root.hasLyrics ? 230 : 190
  }
  ```
- **Lyric Row Visibility**: Tied directly to `root.hasLyrics` with height 24px and crisp typography.

### 5. `island/IslandHub.qml`
- **Track Change Reset**: Added `onTrackTitleChanged` listener on `player` to instantly reset `liveLyric = ""` between tracks until new lyrics are detected.
- **Error Line Filtering**: Strengthened string filtering in `lyricsProc` `SplitParser` to reject `"no lyrics"`, `"error"`, and `"failed"` case-insensitively.

---

## 4. Verification & Testing Matrix

| Scenario | State | Expected Width | Expected Height | Observed Result |
| :--- | :--- | :--- | :--- | :--- |
| **Idle / Nothing Playing** | Collapsed | 145px (+wings) | 24px | PASS |
| **Track Playing (No Lyrics)** | Collapsed | 145px (+wings) | 24px | PASS |
| **Track Playing (Lyrics Found)** | Collapsed | 220px - 380px | 30px | PASS |
| **Track Playing (Lyrics Found)** | Expanded | 540px (+wings) | 265px (Card: 230px) | PASS |
| **Track Playing (No Lyrics)** | Expanded | 460px (+wings) | 220px (Card: 190px) | PASS |
| **Track Swap / Next Song** | Reset | Returns to 145x24 until new lyrics parse | Returns immediately | PASS |
| **IPC Toggle** | Expanded $\to$ Collapsed | Spring animations smooth, zero clipping | Zero log warnings | PASS |
