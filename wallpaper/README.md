# Live MP4 Video Wallpaper

GPU-accelerated native live MP4 video wallpaper component for `cool-shell` using Quickshell 0.3.1 and QtMultimedia (FFmpeg backend) on Hyprland/Wayland.

## Architecture

- **Surface Layer:** `PanelWindow` on `WlrLayer.Background` with `ExclusionMode.Ignore`.
- **Input Transparency:** Completely click-through via `mask: Region {}` and `WlrKeyboardFocus.None`. The Wayland compositor ignores this surface during pointer hit-testing.
- **Rendering Pipeline:** Hardware-accelerated QtMultimedia `MediaPlayer` + `VideoOutput` with muted audio and infinite loop.
- **Lifecycle Guarantees:**
  - `enabled: false` or `mediaType != "video"`: Window is unmapped (`visible: false`), playback stops, GPU/CPU cycles drop to 0.
  - Video wallpapers seamlessly take over the background layer without interfering with windows, sidebars, island, or dock.

## Wallpaper Folder

The designated folder for live MP4 wallpapers is:

```bash
~/Pictures/Wallpapers/live/
# (also accessible via ~/Videos/Wallpapers)
```

Place any `.mp4`, `.webm`, `.mkv`, or `.mov` video files into this directory.

## Selecting Wallpapers

1. Press **`Super + A`** to toggle the Wallpaper picker in the Dynamic Island.
2. Live MP4 wallpapers from `~/Pictures/Wallpapers/live/` appear automatically in the grid with high-quality generated video thumbnails and a `󰿎` badge.
3. Click any wallpaper tile to activate it instantly.
4. Click the **`󰿎 Live`** button in the header bar of the picker to immediately open `~/Pictures/Wallpapers/live/` in your file manager to drop in new MP4 files.

## IPC Commands

```bash
# Toggle wallpaper rendering
qs -c cool-shell ipc call wallpaper toggle

# Enable or disable
qs -c cool-shell ipc call wallpaper setEnabled true
qs -c cool-shell ipc call wallpaper setEnabled false

# Set specific video or image wallpaper
qs -c cool-shell ipc call wallpaper setMedia "/home/pranc/Pictures/Wallpapers/live/black-hole-event-horizon.mp4" "video"

# Query status properties
qs -c cool-shell ipc prop get wallpaper enabled
qs -c cool-shell ipc prop get wallpaper mediaType
qs -c cool-shell ipc prop get wallpaper mediaSource
```
