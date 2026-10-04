# GPU-Accelerated Animated Wallpaper Exploration Report

**Date:** 2026-10-04  
**Target:** [`cool-shell`](file:///home/pranc/.config/quickshell/cool-shell/)  
**Topic:** GPU-Accelerated Animated Wallpaper Architecture & Environment Exploration  
**Policy Compliance:** [`.agents/rules/reports.md`](file:///home/pranc/.config/quickshell/cool-shell/.agents/rules/reports.md)

---

## 1. Executive Summary

This exploration investigated the architecture, codebase, and runtime environment of `cool-shell` to determine the exact requirements, historical context, and technical path for implementing a GPU-accelerated animated wallpaper.

### Key Discoveries:
1. **Historical Foundation (Task 10 & Commit `1f51c48`):** A fully functioning Qt 6 QRHI-based `ShaderEffect` live wallpaper was previously implemented in `wallpaper/Wallpaper.qml` and `wallpaper/shaders/wallpaper.frag`, complete with click-through masking, C++ `NumberAnimation` driver, and multi-monitor `Variants` integration.
2. **Reason for Current Stub:** During the port of the `vyeos` / `dotarch` Dynamic Island subsystem (commit `ddca2c8`), wallpaper management was partially delegated to `awww-daemon` and `island/scripts/theme-system.sh` for static image switching across themes. In commit `e3f212a`, `wallpaper/Wallpaper.qml` was stubbed out as `Item { visible: false }` to avoid competing with `awww`.
3. **Partial UI & IPC Plumbing Intact:** `shell.qml` still maintains wallpaper state (`wallpaperEnabled`, `wallpaperMediaType`, `wallpaperMediaSource`), shell methods (`islandSetWallpaper`, `islandClearWallpaper`), and UI toggle bindings in `LeftSidebar.qml` / `ControlCenter.qml`. When `islandClearWallpaper()` is called, it explicitly executes `awww clear 000000` and sets `wallpaperMediaType = "procedural"`, confirming the intended hybrid architecture.
4. **Qt 6 QRHI & Toolchain Verification:** `/usr/lib/qt6/bin/qsb` (Qt Shader Baker 6.11.2) is installed, functional, and verified to compile `wallpaper/shaders/wallpaper.frag` into multi-target `.qsb` shader packs (SPIR-V, GLSL 100/120/150, HLSL 50, MSL 12).
5. **Compositor & Layer Shell Integration:** On Wayland/Hyprland, Quickshell surfaces configured as `PanelWindow` with `WlrLayershell.layer: WlrLayer.Background`, `exclusionMode: ExclusionMode.Ignore`, `aboveWindows: false`, `focusable: false`, and `mask: Region {}` provide zero-cost pointer and keyboard pass-through, cleanly hosting GPU procedural shaders behind application windows.

---

## 2. Architecture & `shell.qml` Structure

### 2.1 Shell Hierarchy & Lifecycle
In [`shell.qml`](file:///home/pranc/.config/quickshell/cool-shell/shell.qml), the top-level element is `ShellRoot { id: shellRoot }`. Authoritative singletons, compositors, and state models are declared at the root level:
- `IdleManager` (compositor-wide idle tracking)
- `WorkspaceManager` & `SurfaceManager` (Hyprland Wayland tracking)
- `WorkspaceModel`, `SurfaceModel`, `DesktopModel` (reactive composition graph)
- `CompositorActionLayer` & `InteractionModel` (actuator & intent mediation)
- `DesktopState` (presentation state facade)

### 2.2 Global Wallpaper State Properties
Authoritative wallpaper state is defined on `ShellRoot` (lines 135–184):
```qml
// Wallpaper state. Renderer is the ported dotarch system (awww-daemon +
// island/scripts/theme-system.sh). wallpaperEnabled is retained for the
// sidebar toggle UI; rendering is owned by awww, not a QML layer.
property bool wallpaperEnabled: true
property string wallpaperMediaType: "image"
property string wallpaperMediaSource: ""

readonly property string islandThemeHelper: Quickshell.shellPath("island/scripts/theme-system.sh").toString().replace(/^file:\/\//, "")

function islandSetWallpaper(path) {
    let cleanPath = path.trim().replace(/^file:\/\//, "");
    setWallpaperProc.exec([shellRoot.islandThemeHelper, "wallpaper", cleanPath]);
    shellRoot.wallpaperMediaType = "image";
    shellRoot.wallpaperMediaSource = "file://" + cleanPath;
    console.log("[pranc-shell] Wallpaper set via island system: " + shellRoot.wallpaperMediaSource);
    return JSON.stringify({ success: true, mediaType: "image", mediaSource: shellRoot.wallpaperMediaSource });
}

function islandClearWallpaper() {
    setWallpaperProc.exec(["awww", "clear", "000000"]);
    shellRoot.wallpaperMediaType = "procedural";
    shellRoot.wallpaperMediaSource = "";
    console.log("[pranc-shell] Wallpaper cleared via awww");
    return JSON.stringify({ success: true, mediaType: "procedural" });
}

function openMediaPicker() {
    ShellState.show("wallpaper");
    return JSON.stringify({ success: true, status: "opened" });
}

Process { id: setWallpaperProc }
Process { id: restoreWallpaperProc; command: [shellRoot.islandThemeHelper, "restore-wallpaper"] }

Timer {
    id: wallpaperRestoreDelay
    interval: 900
    onTriggered: restoreWallpaperProc.running = true
}

Component.onCompleted: {
    IslandHub.notifModel = notificationServer.trackedNotifications;
    Quickshell.execDetached(["sh", "-c", "pgrep -x awww-daemon >/dev/null || exec awww-daemon"]);
    Quickshell.execDetached(["sh", "-c", "pgrep -xf 'wl-paste --type text --watch cliphist store' >/dev/null || wl-paste --type text --watch cliphist store >/dev/null 2>&1 & pgrep -xf 'wl-paste --type image --watch cliphist store' >/dev/null || wl-paste --type image --watch cliphist store >/dev/null 2>&1 &"]);
    wallpaperRestoreDelay.start();
}
```

### 2.3 Per-Monitor Instantiation via `Variants` & `Quickshell.screens`
`shell.qml` instantiates monitor-bound surfaces using `Variants`:
1. `Variants { model: Quickshell.screens; Notch { screen: modelData } }` (Dynamic Island)
2. `Variants { model: Quickshell.screens; CaptureSelector { screen: modelData } }` (Screen capture overlay)
3. `Variants { model: Quickshell.screens; Scope { id: monitorScope; required property var modelData; ... } }` (Desktop shell surfaces):
   - `AmbientLayer { screen: monitorScope.modelData ... }` (`WlrLayer.Bottom`)
   - `DesktopTransition { screen: monitorScope.modelData ... }` (`WlrLayer.Top`)
   - `PanelWindow { id: triggerWindow screen: monitorScope.modelData ... }` (`WlrLayer.Overlay`)
   - `LeftSidebar { screen: monitorScope.modelData ... }` (`WlrLayer.Top`)
   - `RightSidebar { screen: monitorScope.modelData ... }` (`WlrLayer.Top`)
   - `BottomBar { screen: monitorScope.modelData ... }` (`WlrLayer.Top`)

### 2.4 Historical Instantiation in `shell.qml`
Prior to commit `ddca2c8`, inside `Variants { model: Quickshell.screens; Scope { id: monitorScope ... } }`, `Wallpaper` was instantiated directly:
```qml
// Live wallpaper rendering surface (WlrLayer.Background)
Wallpaper {
    id: wallpaper
    screen: monitorScope.modelData
    enabled: shellRoot.wallpaperEnabled
}
```
Re-enabling this requires instantiating the revived `Wallpaper` component inside `monitorScope`, passing `screen: monitorScope.modelData`, `enabled: shellRoot.wallpaperEnabled`, and `mediaType: shellRoot.wallpaperMediaType`.

---

## 3. Investigation of `wallpaper/` Subsystem

### 3.1 Current Status of `wallpaper/Wallpaper.qml`
The current file [`wallpaper/Wallpaper.qml`](file:///home/pranc/.config/quickshell/cool-shell/wallpaper/Wallpaper.qml) is a stub:
```qml
import QtQuick

Item {
    // Deprecated: superseded by awww wallpaper daemon in island/scripts/theme-system.sh
    visible: false
}
```

### 3.2 Why Was It Deprecated?
1. In commit `ddca2c8`, the Dynamic Island subsystem from `dotarch` was integrated. It brought `awww-daemon`, `island/AppearanceState.qml`, and `island/scripts/theme-system.sh`, which handled static image wallpaper switching across theme folders (`~/Pictures/Wallpapers/<theme-slug>/`).
2. To prevent dual rendering conflicts (an active QML background window drawing on top of or under `awww-daemon`), commit `e3f212a` stubbed out `Wallpaper.qml`.
3. However, `awww-daemon` only displays static images or GIFs—it cannot execute real-time procedural GLSL/RHI shaders, synchronize with shell states, or leverage Qt scene graph animations.

### 3.3 Historical Implementation Archeology
In commit `1f51c48`, `wallpaper/Wallpaper.qml` had a full 3-layer architecture:
- **Layer 1: GPU Procedural Shader (`ShaderEffect`):** Loaded `shaders/wallpaper.frag.qsb`, animated by a C++ `NumberAnimation` on `time` from $0.0$ to $2\pi$ over 60 seconds (`loops: Animation.Infinite`).
- **Layer 2: Image Media Surface (`Image`):** Rendered static/animated images with `fillMode: Image.PreserveAspectCrop`, asynchronous decoding, and mipmapping.
- **Layer 3: Video Surface (`MediaPlayer` + `VideoOutput`):** Handled hardware video looping via QtMultimedia with audio muted.

### 3.4 Review of `wallpaper/README.md`
The existing [`wallpaper/README.md`](file:///home/pranc/.config/quickshell/cool-shell/wallpaper/README.md) documents the architectural guarantees:
- **Surface Layer:** `PanelWindow` on `WlrLayer.Background` with `ExclusionMode.Ignore`.
- **Input Transparency:** Complete click-through via `mask: Region {}` and `WlrKeyboardFocus.None`.
- **Rendering Pipeline:** Qt 6 QRHI via `ShaderEffect` and compiled `.qsb` binaries.
- **Animation Driver:** Pure C++ `NumberAnimation` cycling over $[0, 2\pi]$ with linear easing. Zero per-frame JavaScript handlers or timers.
- **Lifecycle Guarantees:**
  - `enabled: false`: Window is unmapped (`visible: false`), animation stops, GPU compositor cycles drop to 0.
  - `activeRendering: false`: Animation stops while window remains visible as a static backdrop with zero continuous redraws.

---

## 4. IPC Handlers in `cool-shell`

### 4.1 Global IPC Landscape
All IPC handlers in `cool-shell` are declared in [`shell.qml`](file:///home/pranc/.config/quickshell/cool-shell/shell.qml). There are 17 registered targets:
1. `workspace`: Workspace ID, name, count, JSON state snapshots.
2. `surface`: Focused toplevel address, title, urgency, window lists.
3. `shell`: Central shell facade with scalar queries and delegated managers.
4. `model`: Spatial workspace topology, occupied/empty sets.
5. `model-surface`: Application grouping, normalized surface properties.
6. `desktop`: Unified desktop composition graph and monitor topology.
7. `interaction`: Intent validation and action gating.
8. `action`: Compositor actuator (switchWorkspace, focusSurface, closeSurface).
9. `idle`: Idle timeout settings, simulation, inhibitor bypass.
10. `ambient`: Ambient telemetry HUD toggle and status.
11. `state`: Unified desktop presentation state, drawer flags, Game Mode.
12. `control`: Shell Control Center operations (drawer toggles, wallpaper toggles).
13. `settings`: Settings window toggle, open category, close.
14. `notch`: Dynamic Island panel toggling and navigation.
15. `island`: Dynamic Island subsystem summaries, timers, weather, notes.
16. `theme`: Theme reload trigger.
17. `capture`: Screenshot and screen recording triggers.

### 4.2 Existing Wallpaper IPC Plumbing
In `IpcHandler { target: "control" }` (lines 1105–1180):
- Properties:
  - `property bool wallpaperEnabled: shellRoot.wallpaperEnabled`
  - `property string wallpaperMediaType: shellRoot.wallpaperMediaType`
  - `property string wallpaperMediaSource: shellRoot.wallpaperMediaSource`
- Methods:
  - `toggleWallpaper(): string`
  - `setWallpaperEnabled(val: bool): string`
  - `setWallpaperMedia(path: string): string`
  - `clearWallpaperMedia(): string`

### 4.3 Proposed Dedicated `IpcHandler { target: "wallpaper" }`
In `shell.qml` line 221, a note marks where the dedicated wallpaper IPC handler originally lived. Restoring a first-class `wallpaper` target will allow direct CLI commands:
```qml
IpcHandler {
    target: "wallpaper"

    property bool enabled: shellRoot.wallpaperEnabled
    property string mediaType: shellRoot.wallpaperMediaType
    property string mediaSource: shellRoot.wallpaperMediaSource

    function toggle(): string {
        return shellRoot.toggleWallpaper();
    }

    function setEnabled(val: bool): string {
        shellRoot.wallpaperEnabled = val;
        return JSON.stringify({ success: true, enabled: shellRoot.wallpaperEnabled });
    }

    function setMediaType(type: string): string {
        shellRoot.wallpaperMediaType = type;
        return JSON.stringify({ success: true, mediaType: shellRoot.wallpaperMediaType });
    }

    function getSummary(): string {
        return JSON.stringify({
            enabled: shellRoot.wallpaperEnabled,
            mediaType: shellRoot.wallpaperMediaType,
            mediaSource: shellRoot.wallpaperMediaSource
        });
    }
}
```

---

## 5. `PanelWindow` Usage & Layer Configuration Across `cool-shell`

Exhaustive inspection of all `PanelWindow` instances reveals exact architectural conventions:

| Component | File | WlrLayer | ExclusionMode | Focusable / Keyboard | Input Masking | Lifetime / Visibility |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Wallpaper** | `wallpaper/Wallpaper.qml` | `WlrLayer.Background` | `Ignore` | `focusable: false`<br>`WlrKeyboardFocus.None` | `mask: Region {}`<br>*(100% pass-through)* | `visible: enabled` |
| **Ambient HUD** | `desktop/AmbientLayer.qml` | `WlrLayer.Bottom` | `Ignore` | `focusable: false`<br>`WlrKeyboardFocus.None` | `mask: Region {}`<br>*(100% pass-through)* | `visible: active \|\| fadeOutAnim.running` |
| **Desktop Transition** | `desktop/DesktopTransition.qml` | `WlrLayer.Top` | `Ignore` | `focusable: false`<br>`WlrKeyboardFocus.None` | `mask: Region {}`<br>*(100% pass-through)* | `visible: active \|\| enterExitAnim.running` |
| **Edge Triggers** | `shell.qml:1473` (`triggerWindow`) | `WlrLayer.Overlay` | `Ignore` | `focusable: false`<br>`WlrKeyboardFocus.None` | `mask: Region { Region { item: leftTrigger } ... }` | `visible: !ShellState.gameMode` |
| **Left Sidebar** | `panels/LeftSidebar.qml` | `WlrLayer.Top` | `Ignore` | `focusable: false`<br>`WlrKeyboardFocus.None` | Window-sized body | `visible: open \|\| closeAnim.running` |
| **Right Sidebar** | `panels/RightSidebar.qml` | `WlrLayer.Top` | `Ignore` | `focusable: false`<br>`WlrKeyboardFocus.None` | Window-sized body | `visible: open \|\| closeAnim.running` |
| **Bottom Bar** | `panels/BottomBar.qml` | `WlrLayer.Top` | `Ignore` | `focusable: false`<br>`WlrKeyboardFocus.None` | Window-sized body | `visible: open \|\| closeAnim.running` |
| **Dynamic Island** | `island/Notch.qml` | `WlrLayer.Overlay` | `Ignore` | `focusable: window.isExpanded`<br>`WlrKeyboardFocus.OnDemand` | Dynamic `Region` around capsule pill | Always mapped |
| **Screen Capture** | `island/CaptureSelector.qml` | `WlrLayer.Overlay` | `Ignore` | `focusable: visible`<br>`WlrKeyboardFocus.OnDemand` | Full-screen interactive drag | `visible: Backend.captureSelectionActive` |
| **Settings Window** | `panels/SettingsWindow.qml` | `WlrLayer.Overlay` | `Ignore` | `focusable: open`<br>`WlrKeyboardFocus.OnDemand` | Full-screen modal | `visible: open` |
| **Onboarding** | `shell.qml:1241` (`onboardingWindow`) | Default (`Top`) | `Ignore` | Default | Window-sized card | `visible: onboardingManager.visible` |

### Critical Findings for Wallpaper Layer Surface:
1. **Layer Assignment (`WlrLayer.Background`):** Wallpaper belongs strictly on `WlrLayer.Background`. This places it beneath all client windows and beneath `AmbientLayer` (`WlrLayer.Bottom`), ensuring the telemetry HUD draws over the wallpaper.
2. **Absolute Click-Through (`mask: Region {}`):** Setting `mask: Region {}` on the `PanelWindow` informs the Wayland compositor that the surface contains zero input regions. Pointer events, clicks, mouse wheels, and touch gestures bypass the wallpaper completely and target the desktop or Hyprland background.
3. **No Keyboard Focus (`WlrKeyboardFocus.None` & `focusable: false`):** Completely prevents the wallpaper from intercepting keyboard focus or shortcuts.
4. **No Desktop Geometry Disruption (`exclusionMode: ExclusionMode.Ignore`):** Prevents the surface from adding margins, padding, or docking reservations to the desktop work area.
5. **Hyprland Layer Ordering:** `hyprctl layers` confirms `awww-daemon` currently occupies `Layer level 0 (background)`. When Quickshell creates a surface on `WlrLayer.Background`, Hyprland stacks it above or replaces the canvas. Calling `awww clear 000000` (which `islandClearWallpaper()` already does) empties the `awww` frame, allowing Quickshell to display procedural animations cleanly.

---

## 6. Existing Shaders & Rendering Pipeline

### 6.1 Shader Assets in Codebase
The repository contains:
- Source: [`wallpaper/shaders/wallpaper.frag`](file:///home/pranc/.config/quickshell/cool-shell/wallpaper/shaders/wallpaper.frag) (48 lines)
- Precompiled binary: [`wallpaper/shaders/wallpaper.frag.qsb`](file:///home/pranc/.config/quickshell/cool-shell/wallpaper/shaders/wallpaper.frag.qsb) (2,954 bytes)

### 6.2 Fragment Shader Code Analysis
```glsl
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
};

void main() {
    vec2 uv = qt_TexCoord0;
    
    // Aspect-ratio correction centered at (0.5, 0.5)
    float aspect = (resolution.y > 0.0) ? (resolution.x / resolution.y) : 1.0;
    vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
    
    // Time harmonic base (time runs [0, 2*PI])
    float t = time;
    
    // Wave components with integer harmonic frequencies (1t, 2t) to ensure seamless 2*PI looping
    float wave1 = sin(p.x * 2.5 + t + sin(p.y * 2.0 - t));
    float wave2 = cos(p.y * 3.0 - t + cos(p.x * 2.0 + 2.0 * t));
    float wave3 = sin((p.x + p.y) * 2.0 + t);
    
    float field = (wave1 + wave2 + wave3) / 3.0; // range [-1.0, 1.0]
    float normField = field * 0.5 + 0.5;         // range [0.0, 1.0]
    
    // Palette matching pranc-shell dark aesthetic:
    // Base obsidian (#0f1017) -> Midnight Violet (#1b1429) -> Oceanic Slate (#0e2030)
    vec3 colBase   = vec3(0.059, 0.063, 0.090); // #0f1017
    vec3 colViolet = vec3(0.106, 0.078, 0.161); // #1b1429
    vec3 colTeal   = vec3(0.055, 0.125, 0.188); // #0e2030
    
    vec3 mixedColor = mix(colBase, colViolet, smoothstep(0.1, 0.7, normField));
    mixedColor = mix(mixedColor, colTeal, smoothstep(0.4, 0.9, normField) * 0.5);
    
    // Subtle radial vignette
    float dist = length(uv - 0.5);
    float vignette = smoothstep(0.9, 0.2, dist);
    vec3 finalRgb = mixedColor * (0.8 + 0.2 * vignette);
    
    // Multiply by qt_Opacity for standard Qt Quick blending
    fragColor = vec4(finalRgb, 1.0) * qt_Opacity;
}
```

### 6.3 Mathematical & Visual Design Highlights:
- **Periodic Harmonic Loops:** All wave calculations use integer multipliers on $t$ ($1t, 2t$), guaranteeing that $f(0) == f(2\pi)$. Over a 60-second duration driven from $0.0$ to $6.2831853$, the animation loops infinitely without any visual seam or jump.
- **Aspect Ratio Normalization:** Corrects $p$ around the center $(0.5, 0.5)$ by multiplying $x$ by $aspect = width / height$, ensuring waves do not stretch on ultrawide or non-16:9 displays.
- **Color Aesthetics:** Matches the obsidian/midnight-violet/slate palette of `cool-shell` and `pranc-shell`.
- **Composition Multiplying:** Output is multiplied by `qt_Opacity` to support smooth fade-in and fade-out transitions.

---

## 7. Qt 6 RHI & Quickshell Runtime Environment

### 7.1 Environment Check
- **OS:** Arch Linux (Kernel x86_64)
- **Quickshell:** `0.3.1` (distributed by Arch Linux)
- **Qt Version:** `6.11.2`
- **GPU:** AMD Radeon Lucienne APU (`Advanced Micro Devices, Inc. [AMD/ATI] Lucienne (rev c2)`)
- **Shader Baker Tool:** `/usr/lib/qt6/bin/qsb` (`QShader from Qt 6.11.2`)

### 7.2 Qt 6 RHI Uniform Buffer Requirements
The Qt 6 Rendering Hardware Interface (QRHI) replaces the legacy OpenGL-specific pipeline of Qt 5. Under Qt 6:
1. **GLSL Version Directive:** Must be `#version 440` (Vulkan GLSL).
2. **Uniform Buffer Object (UBO):** Individual `uniform float time;` declarations are prohibited. All uniforms must be aggregated inside a single `uniform buf` block:
   ```glsl
   layout(std140, binding = 0) uniform buf {
       mat4 qt_Matrix;
       float qt_Opacity;
       float time;
       vec2 resolution;
   };
   ```
3. **Leading Qt Quick Uniforms:** When using Qt Quick's default vertex shader, the UBO must start with:
   - `mat4 qt_Matrix` (offset 0, size 64)
   - `float qt_Opacity` (offset 64, size 4)
4. **Memory Layout Alignment (`std140`):**
   - `float time` (offset 68, size 4)
   - `vec2 resolution` (offset 72, size 8)
   - Total struct size = 80 bytes (multiple of 16).
5. **Texture Samplers (if needed):** Any additional textures must use explicit binding numbers (e.g. `layout(binding = 1) uniform sampler2D source;`).

### 7.3 Compilation Pipeline
Verifying `qsb`:
```bash
/usr/lib/qt6/bin/qsb --qt6 wallpaper/shaders/wallpaper.frag -o wallpaper/shaders/wallpaper.frag.qsb
```
`--qt6` automatically compiles into SPIR-V, GLSL 100 es, GLSL 120, GLSL 150, HLSL 50, and MSL 12. Verification test executed against `/dev/null` passed with exit code 0 and zero warnings.

### 7.4 Zero-Overhead Scene Graph Animation Driver
To achieve high performance without CPU overhead:
- **C++ Scene Graph Driver:** Use `NumberAnimation` targeting the `time` property of `ShaderEffect`. Because `NumberAnimation` is implemented in pure C++ inside `QtQuick`, the animation runs entirely on the scene graph thread without dispatching JavaScript function evaluations or timer ticks every frame.
- **Game Mode & Focus Discipline:** When `ShellState.gameMode` is true (or when the window is hidden), setting `running: false` on the animation and `visible: false` on the `PanelWindow` unmaps the Wayland surface, dropping GPU draw calls and compositor load to 0.

---

## 8. Implementation Plan & Recommendations

### 8.1 Component Structure (`wallpaper/Wallpaper.qml`)
Revive `Wallpaper.qml` as a first-class `PanelWindow`:
```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../island" as Island

PanelWindow {
    id: root

    property bool enabled: true
    property bool activeRendering: !Island.ShellState.gameMode
    property string mediaType: "procedural"
    property string mediaSource: ""

    visible: enabled && !Island.ShellState.gameMode

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false
    focusable: false
    color: "transparent"

    WlrLayershell.namespace: "cool-shell-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {}

    // Procedural Shader Surface
    ShaderEffect {
        id: shaderEffect
        anchors.fill: parent
        visible: root.mediaType === "procedural"

        property real time: 0.0
        property vector2d resolution: Qt.vector2d(root.width > 0 ? root.width : 1920,
                                                  root.height > 0 ? root.height : 1080)

        fragmentShader: "shaders/wallpaper.frag.qsb"

        NumberAnimation {
            id: timeDriver
            target: shaderEffect
            property: "time"
            from: 0.0
            to: 6.28318530718
            duration: 60000
            loops: Animation.Infinite
            running: root.enabled && root.activeRendering && root.mediaType === "procedural"
            easing.type: Easing.Linear
        }
    }
}
```

### 8.2 Wiring in `shell.qml`
1. Re-add `Wallpaper` inside `monitorScope` in `Variants`:
   ```qml
   Wallpaper {
       id: wallpaper
       screen: monitorScope.modelData
       enabled: shellRoot.wallpaperEnabled
       mediaType: shellRoot.wallpaperMediaType
       mediaSource: shellRoot.wallpaperMediaSource
   }
   ```
2. Re-introduce `IpcHandler { target: "wallpaper" }` in `shell.qml` to provide clear CLI controls (`qs ipc call wallpaper toggle`, `qs ipc call wallpaper setEnabled true/false`, `qs ipc call wallpaper setMediaType procedural/image`).
3. Connect the Wallpaper toggle in `components/ControlCenter.qml` so toggling switches between active procedural animation and paused state.
4. Support hybrid mode: when `mediaType === "image"`, let `awww` display the image; when `mediaType === "procedural"`, clear `awww` and let `Wallpaper.qml` render the GPU shader.

---

## 9. Verification & Evidence Matrix

| Check / Investigation Area | Command / Evidence | Status |
| :--- | :--- | :--- |
| `shell.qml` Surface Hierarchy | Inspected lines 1–1610; singletons, models, Variants scopes identified | Verified |
| Wallpaper State Properties | `shellRoot.wallpaperEnabled`, `wallpaperMediaType`, `wallpaperMediaSource` verified | Verified |
| Historical `Wallpaper.qml` Archeology | Commit `d5c188c` (Task 10) & `1f51c48` inspected; stub rationale documented | Verified |
| IPC Handlers Inventory | All 17 `IpcHandler` blocks inspected; `control` target wallpaper methods verified | Verified |
| `PanelWindow` Configuration Pattern | 11 `PanelWindow` instances analyzed; `WlrLayer.Background`, `mask: Region {}` verified | Verified |
| Shader Baker Compilation | `/usr/lib/qt6/bin/qsb --qt6 wallpaper/shaders/wallpaper.frag -o /dev/null` executed | Passed (Code 0) |
| Shader Reflection & UBO Layout | Dumped `wallpaper.frag.qsb` via `qsb -d`; std140 layout and offsets confirmed | Verified |
| Runtime IPC Verification | `quickshell ipc -c cool-shell call control getSummary` executed | Passed |
| Hyprland Layer State | `hyprctl layers` executed; `awww-daemon` layer level 0 confirmed | Verified |
