# Live Wallpaper Rendering Foundation

GPU-accelerated live procedural wallpaper component for `pranc-shell` using Quickshell 0.3.1 and Qt 6 on Hyprland/Wayland.

## Architecture

- **Surface Layer:** `PanelWindow` on `WlrLayer.Background` with `ExclusionMode.Ignore`.
- **Input Transparency:** Completely click-through via `mask: Region {}` and `WlrKeyboardFocus.None`. The Wayland compositor ignores this surface during pointer and keyboard hit-testing.
- **Rendering Pipeline:** Qt 6 QRHI via `ShaderEffect` and compiled `.qsb` shader binaries.
- **Animation Driver:** Pure C++ `NumberAnimation` cycling over $[0, 2\pi]$ with linear easing. Zero per-frame JavaScript handlers or timers.
- **Lifecycle Guarantees:**
  - `enabled: false`: Window is unmapped (`visible: false`), animation stops, GPU compositor cycles drop to 0.
  - `activeRendering: false`: Animation stops while window remains visible as a static backdrop with zero continuous redraws.

## Shader Compilation

The fragment shader is compiled using the Qt 6 Shader Baker (`qsb`):

```bash
cd ~/.config/quickshell/pranc-shell/wallpaper
/usr/lib/qt6/bin/qsb --qt6 shaders/wallpaper.frag -o shaders/wallpaper.frag.qsb
```

## Integration

In `shell.qml`:
```qml
import "wallpaper"

// Inside Variants { model: Quickshell.screens; Scope { id: monitorScope ... } }
Wallpaper {
    id: wallpaper
    screen: monitorScope.modelData
    enabled: true
    activeRendering: true
}
```
