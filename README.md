# cool-shell

> **A high-performance, cyber-tactical desktop environment and unified operating cockpit built natively for Hyprland on Wayland using Quickshell 0.3.1 and Qt 6.**

`cool-shell` unifies tactile hardware control, intelligent system modes, local machine intelligence, and mobile device bridging into a single, cohesive Wayland desktop surface with zero latency, spring physics, and hardware telemetry.

---

## 🏛️ System Architecture

`cool-shell` enforces a strict **unidirectional reactive architecture** that separates compositor observation from compositor mutation, preventing race conditions and stale UI states:

```
┌────────────────────────────────────────────────────────────────────────┐
│                      Observation Pipeline (Read-Only)                  │
│                                                                        │
│   Hyprland / Wayland C++ Singletons                                    │
│          ↓                                                             │
│   WorkspaceManager / SurfaceManager (Authoritative Wrappers)           │
│          ↓                                                             │
│   WorkspaceModel / SurfaceModel (Normalized Projections)               │
│          ↓                                                             │
│   DesktopModel (Multi-Level Composition Graph)                         │
│          ↓                                                             │
│   DesktopState (Presentation State & Transition Driver)                │
│          ↓                                                             │
│   Shell Surfaces: Notch, Sidebars, BottomBar, Ambient, Transitions     │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      Mutation Pipeline (Actuation Barrier)             │
│                                                                        │
│   User Interaction (Tactile UI HUD / Gestures / IPC)                   │
│          ↓                                                             │
│   InteractionModel (Pre-flight Target Validation)                      │
│          ↓                                                             │
│   CompositorActionLayer (Strict Allowlist Barrier)                     │
│          ↓                                                             │
│   Native Quickshell C++ APIs (Hyprland.dispatch, Toplevel.activate)    │
│          ↓                                                             │
│   Hyprland Wayland Compositor                                          │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```text
~/.config/quickshell/cool-shell/
├── shell.qml                     # Root entry point, singletons, and IPC registration
├── theme/
│   └── Theme.qml                 # Single semantic token authority (metrics, colors, durations)
├── core/                         # Authoritative compositor wrappers and data models
├── island/                       # Dynamic Island notch, state machines, and modal panels
│   ├── Notch.qml                 # Floating tactile notch with spring physics
│   ├── IslandHub.qml             # Central priority arbitration and transient notifications
│   ├── ShellState.qml            # Panel geometry, dimensions, and active monitor routing
│   └── panels/                   # Interactive drop-down island panels
├── components/                   # Left and Right sidebar tactical HUD components
├── panels/                       # Slide-out sidebar containers and Settings window
├── desktop/                      # Ambient idle layer, telemetry reticles, and contribution heatmap
├── wallpaper/                    # Procedural GLSL harmonic interference GPU wallpaper
└── scripts/                      # Autonomous daemons, hardware controls, and intelligence tools
```

---

## 🏝️ Apple-Style Dynamic Island (The Notch)

At the apex of the screen sits the **Dynamic Island** ([`island/Notch.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/Notch.qml)), a tactile, hardware-accelerated floating pill powered by spring physics (`SpringAnimation`, damping=0.3) and elastic morphing.

### Collapsed Ambient Pill
When idle, the notch remains a compact, unobtrusive capsule displaying real-time situational awareness:
- **🎵 Synced Live Lyrics**: Integrates with `sptlrx` daemon to stream synchronized karaoke lyrics directly across the pill surface.
- **📊 4-Bar Audio Visualizer**: Real-time FFT audio levels (`level-meter.py`) pulse to music playback.
- **⚡ Battery & Charging**: Glows primary accent with charging wattage and percentage when plugged in.
- **🔴 Screen Recording**: Displays active recording duration with pulsing red safety beacon.
- **📬 Unread Counter**: Discreet notification badge indicating unseen system events.

### Modal Panel Ecosystem
Clicking or triggering shortcuts on the notch smoothly morphs it into 16 full-featured tactile tools:

| Panel | Identifier | Description |
| :--- | :--- | :--- |
| **Control Center** | `control` | Quick toggles (Night Light, DND, Bluetooth, Mic, Cam), brightness/volume sliders, power profiles. |
| **App Launcher** | `launcher` | Fast keyboard-driven fuzzy desktop application launcher. |
| **Clipboard** | `clipboard` | Persistent history of copied text and media with 1-tap copy/delete. |
| **Drop Pocket** | `shelf` | Drag-and-drop workspace shelf storing file references for later retrieval. |
| **Quick Notes** | `notes` | Persistent scratchpad with instant autosave and markdown formatting. |
| **Todo List** | `todo` | Interactive checklist with priority markers and completion tracking. |
| **Theme & Accents**| `theme` | Real-time accent palette switcher and semantic color tuning. |
| **Wallpaper** | `wallpaper` | Live procedural GPU shader and desktop wallpaper selector. |
| **Media Player** | `media` | Extended MPRIS player with track scrubber, volume wheel, and full lyrics display. |
| **Notifications** | `notifications` | Notification history center with dismiss-all and actionable cards. |
| **Timer / Stopwatch**| `timer` | Pomodoro focus intervals, multi-duration countdowns, and precision stopwatch. |
| **Weather HUD** | `weather` | Real-time localized weather reports, temperature, and forecasts via `wttr.in`. |
| **Game Mode** | `gamemode` | High-priority compositor mode disabling animations and background noise. |
| **AI Studio** | `ai` | Text-to-image prompt interface powered by local Realistic Vision / LCM. |
| **Phone Hub** | `phone` | Android device mirroring, wireless ADB status, and mobile controls. |
| **Media Caption** | `caption` | Frictionless drag-and-drop subtitle generator prompt. |

