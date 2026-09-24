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

## Integration & Control

In `shell.qml`, authoritative state resides on `ShellRoot`:
```qml
ShellRoot {
    id: shellRoot
    property bool wallpaperEnabled: true

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { ... }
        function setEnabled(val: bool): void { ... }
    }

    Variants {
        model: Quickshell.screens
        Scope {
            Wallpaper {
                screen: monitorScope.modelData
                enabled: shellRoot.wallpaperEnabled
            }
        }
    }
}
```

### IPC Commands

During development, wallpaper state can be controlled via the Quickshell CLI without UI overhead:
```bash
# Toggle wallpaper
quickshell ipc -c pranc-shell call wallpaper toggle

# Explicitly enable or disable
quickshell ipc -c pranc-shell call wallpaper setEnabled false
quickshell ipc -c pranc-shell call wallpaper setEnabled true

# Query status property
quickshell ipc -c pranc-shell prop get wallpaper enabled
```

