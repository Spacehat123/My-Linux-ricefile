# Architectural Blueprint & Migration Specification: Nectar Dynamic Island for Quickshell / Hyprland

**Document ID:** `2026-10-27-nectar-dynamic-island-migration`  
**Date:** 2026-10-27  
**Target Platform:** Arch Linux / Hyprland (Wayland Layer-Shell) / Quickshell (Qt 6 QML)  
**Upstream Reference:** `https://github.com/kua8/Nectar.git` (`/tmp/nectar-clone`)  
**Host Target:** `/home/pranc/.config/quickshell/cool-shell/island/`  
**Invariant Constraint:** Strictly zero modifications to `hyprland.lua`.

---

## 1. Executive Summary & Architectural Vision

The Quickshell Dynamic Island currently in `/home/pranc/.config/quickshell/cool-shell/island/` possesses an extensive backend infrastructure (15+ feature panels, PipeWire level monitoring, MPRIS control, study timer quotas, ADB phone pairing, AI generation, and file pocketing), but suffers from visual glitchiness, imprecise pill geometry, and unanchored floating layout.

`Nectar` (`/tmp/nectar-clone`) provides a battle-tested, pixel-perfect Apple Dynamic Island implementation built with Framer Motion spring kinematics, concave top bezel bridge wings (13px × 13px), ambient album art backlight glow, SF Symbols iconography, 5-bar audio visualization, and a 3-row compact media player layout.

This specification provides the complete architectural blueprint for transplanting Nectar's source design, kinematics, SVG assets, and layouts into pure Qt Quick QML components while wiring seamlessly into all existing backend services with zero regressions.

---

## 2. Component Hierarchy & Decomposition

```
Notch.qml (Wayland PanelWindow container, layer Overlay, mask Region, monitor routing)
└── NectarFrame.qml (Core visual shell & kinematic spring engine)
    ├── NectarAmbientGlow.qml (Backlight blurred album art reflection)
    ├── NectarWings.qml (Concave top bridge wings: left & right 13x13 fillets)
    └── NectarBody.qml (Core stadium pill / expanded card chassis)
        ├── SurfaceWashLayer.qml (Volume fill wash, recording breathing red pulse, sweep scans)
        ├── NectarCollapsed.qml (Idle 36px height Dynamic Island pill)
        │   ├── Left Zone: 5-bar Visualizer / Update Indicator / Passive Status Widget (Weather/CPU)
        │   ├── Center Zone: NectarFlipClock.qml (3D Flip Clock / Stopwatch / Timer readout)
        │   ├── Right Zone: Album Art Thumbnail / Battery Icon with Charging Bolt / Trailing Activity
        │   ├── Pulse Banner: 200px width expander for Charging, Low Battery (<20%), Update pulses
        │   └── Volume Takeover: Exclusive horizontal level meter
        ├── NectarCompactPlayer.qml (Nectar Compact Media Player layout)
        │   ├── Row 1: Album Art (3D flip) + Title Marquee + Artist + 5-bar Visualizer
        │   ├── Row 2: Live Extrapolated Progress Bar + Seek Scrub + Remaining Time
        │   ├── Row 3: Audio Output Picker + Slide-Push Prev/Next + Pop Play/Pause + Volume Drawer
        │   └── Row 4 (Collapsible): Smooth volume slider track
        └── NectarPanelHost.qml (Staged reveal container for existing 15+ backend panels)
            ├── Staged reveal controller (150ms delay, scale/fade/translate)
            └── Panel Registry: ControlPanel, LauncherPanel, ClipboardPanel, ShelfPanel,
                CapturePanel, TimerPanel, AiPromptPanel, MediaPanel, WeatherPanel,
                QuickNotesPanel, PhonePanel, NotifCenterPanel, TodoPanel, ThemePanel,
                GameModePanel, CaptionActionPanel
```

---

## 3. Kinematics & Spring Parameters: Framer Motion to Qt Quick

| Dimension / Target | Framer Motion ($k, c, m$) | Damping Ratio $\zeta$ | Natural Frequency $\omega_n$ | Qt Quick `SpringAnimation` Specification |
|---|---|---|---|---|
| **Width** | $k=400, c=31, m=1.0$ | $\zeta = 0.775$ | $20.0\text{ rad/s}$ ($3.18\text{ Hz}$) | `spring: 4.0, damping: 0.775, epsilon: 0.25` |
| **Height** | $k=450, c=29, m=1.0$ | $\zeta = 0.683$ | $21.2\text{ rad/s}$ ($3.38\text{ Hz}$) | `spring: 4.5, damping: 0.683, epsilon: 0.25` |
| **Y Translation** | $k=550, c=45, m=0.8$ | $\zeta = 1.072$ | $26.2\text{ rad/s}$ ($4.17\text{ Hz}$) | `spring: 5.5, damping: 0.950, epsilon: 0.10` |
| **Corner Radius** | $k=1000, c=40, m=1.0$ | $\zeta = 0.632$ | $31.6\text{ rad/s}$ ($5.03\text{ Hz}$) | `spring: 8.0, damping: 0.632, epsilon: 0.10` |
| **3D Clock Flip** | $k=600, c=30, m=1.0$ | $\zeta = 0.612$ | $24.5\text{ rad/s}$ ($3.90\text{ Hz}$) | `spring: 5.0, damping: 0.612, epsilon: 0.05` |
| **Visualizer Bars**| $k=600, c=30, m=0.5$ | $\zeta = 0.866$ | $34.6\text{ rad/s}$ ($5.51\text{ Hz}$) | `spring: 6.0, damping: 0.866, epsilon: 0.01` |
| **Slide Prev/Next**| Duration: $180\text{ms}$ | Ease: `[0.4, 0, 0.2, 1]` | Cubic Bezier | `NumberAnimation { duration: 180; easing.type: Easing.OutCubic }` |

---

## 4. Concave Top Wing & Bezel Bridge Architecture

In Nectar's CSS (`App.css` lines 206–241):
- Dimensions: exactly $13\text{px} \times 13\text{px}$.
- Position: Flush with top bezel ($y = 0$). Left wing at `x = notchBody.x - 13`, Right wing at `x = notchBody.x + notchBody.width`.
- Mask: Radial gradient centered at outer bottom corners with radius $13\text{px}$, forming a concave transition.
- Specular line: A $1\text{px}$ stroke along the circular boundary with `rgba(255, 255, 255, 0.10)`.

---

## 5. Implementation Status

This plan is enacted without touching `hyprland.lua`. All 15+ backend panels, IPC methods, study mode quotas, and scripts remain 100% intact.
