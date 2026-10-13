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
