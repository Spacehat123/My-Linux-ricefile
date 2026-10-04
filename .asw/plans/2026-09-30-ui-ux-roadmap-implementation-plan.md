# IMPLEMENTATION PLAN: COMPLETE UI/UX ROADMAP FOR COOL-SHELL

**Date:** 2026-09-30  
**Target Repository:** `~/.config/quickshell/cool-shell/`  
**Reference Document:** `Roadmap` (1,109 lines)  
**Execution Mode:** Decision-Complete Architectural Implementation Plan (Read-Only Planning)

---

## 1. TL;DR & OBJECTIVE

This document provides a decision-complete, phased implementation plan to transform `cool-shell` from a dual-subsystem power-user shell into a mainstream, accessible, safe, and intuitive Wayland desktop environment as specified in `Roadmap`.

The plan translates all 13 roadmap domains into concrete, atomic QML components, state managers, and compositor dispatchers that integrate seamlessly with `cool-shell`'s existing 4-layer architecture (`core/`, `island/`, `panels/`, `components/`, `desktop/`).

### Non-Goals
- No modification of Hyprland source code or replacement of the Hyprland compositor.
- No regression of existing low-latency features (GPU procedural wallpaper, Dynamic Island spring physics, PipeWire zero-fork streaming).
- No blocking modal dialogs that lock the compositor without Escape/timeout fallbacks.

---

## 2. ARCHITECTURAL INTEGRATION MATRIX

| Roadmap Domain | Primary New/Modified Components | Integration Layer | Upstream Singletons / Daemons |
|---|---|---|---|
| **1. Onboarding Wizard** | `components/FirstRunWizard.qml`, `components/WizardStep.qml`, `components/RegionHighlight.qml` | Presentation (Overlay) | `DesktopState`, `ShellState`, `QSettings` (`first-run.json`) |
| **2. Safety & Recovery** | `components/ConfirmationDialog.qml`, `core/UndoManager.qml`, `core/CrashRecoveryManager.qml` | Core Mutation & UI | `CompositorActionLayer`, `SurfaceModel`, `WorkspaceModel` |
| **3. Visual Feedback** | `components/HoverIndicators.qml`, `desktop/DesktopContextBreadcrumb.qml`, `components/Tooltip.qml` | Presentation (Top/Bottom) | `DesktopState.hoverProgress`, `WorkspaceManager`, `SurfaceManager` |
| **4. Accessibility** | `core/AccessibilityManager.qml`, `components/AppSwitcher.qml`, `components/GlobalKeyNav.qml` | Core & Presentation | `theme/Theme.qml`, `espeak-ng` via `Process`, `Quickshell.Wayland` |
| **5. App Discovery** | `components/ApplicationLauncher.qml`, `components/TaskbarDock.qml`, `components/DesktopIconGrid.qml` | Presentation (Overlay/Top) | `SurfaceModel.runningApplications`, `XdgEntries` |
| **6. System Status** | `panels/BottomBar.qml` (enhanced), `components/SystemTray.qml` | Presentation (Bar) | `Quickshell.Services.Pipewire`, `UPower`, `Quickshell.Networking` |
| **7. Animation Easing** | `theme/Theme.qml` (central tokens), `desktop/DesktopTransition.qml` | Global Theming | QtQuick `SpringAnimation`, `Easing.OutCubic` |
| **8. Performance Monitor** | `components/SystemMonitor.qml`, `core/PerformanceAlert.qml` | Components & Core | Linux `/proc/stat`, `/proc/meminfo`, `/sys/class/thermal/`, `desktopState.averageFPS` |
| **9. Central Settings** | `components/SettingsPanel.qml`, `components/tabs/*` | Control Center Extension | `AppearanceState`, `idleManager`, `CompositorActionLayer` |
| **10. Notifications** | `components/NotificationCenter.qml`, `components/ToastNotification.qml`, `components/CrashNotification.qml` | Island & Overlay | `NotificationServer`, `IslandHub` |
| **11. Window Management** | `core/WindowSnapper.qml`, `core/WindowArrangements.qml` | Core Intelligence | `CompositorActionLayer` (Lua dispatch `hl.dsp.window.*`) |
| **12. Multi-Monitor** | `components/MultiMonitorManager.qml`, `components/WorkspaceLayoutVisualizer.qml` | Components & Core | `desktopModel.monitors`, `Quickshell.Hyprland` |
| **13. Quick Tips** | `core/DynamicTips.qml`, `components/FloatingTip.qml` | Core Intelligence & UI | `workspaceModel.count`, `surfaceModel.count`, `idleManager` |

---

## 3. IMPLEMENTATION PHASING (6 SEQUENTIAL WAVES)

```text
WAVE 1: Foundations & Core Services (Safety, Undo, Accessibility, Theming)
   ├── Task 1.1: Theme Easing & Accessibility Tokens (Theme.qml, AccessibilityManager.qml)
   ├── Task 1.2: Core Undo & Crash Recovery Managers (core/UndoManager.qml, CrashRecoveryManager.qml)
   └── Task 1.3: Shared Tooltip & Confirmation Dialog System (components/ConfirmationDialog.qml, Tooltip.qml)

WAVE 2: Discoverability & First-Run Experience
   ├── Task 2.1: Edge Hover Indicators & Visual Region Guides (components/HoverIndicators.qml)
   ├── Task 2.2: Desktop Context Breadcrumb (desktop/DesktopContextBreadcrumb.qml)
   └── Task 2.3: First-Run Onboarding Wizard (components/FirstRunWizard.qml, WizardStep.qml)

WAVE 3: Navigation, App Discovery & Window Management
   ├── Task 3.1: Global Keyboard Navigation & Alt+Tab App Switcher (components/AppSwitcher.qml)
   ├── Task 3.2: Full-Featured Application Search & Dock (components/ApplicationLauncher.qml, TaskbarDock.qml)
   └── Task 3.3: Window Snapper & Layout Presets (core/WindowSnapper.qml, WindowArrangements.qml)

WAVE 4: System Telemetry, Performance & Status Bar
   ├── Task 4.1: Real-Time System Telemetry & Graphs (components/SystemMonitor.qml)
   ├── Task 4.2: Resource Threshold Performance Alerts (core/PerformanceAlert.qml)
   └── Task 4.3: Comprehensive Bottom Bar & Tray Consolidation (panels/BottomBar.qml)

WAVE 5: Settings, Notifications & Feedback Hub
   ├── Task 5.1: Centralized Tabbed Settings Panel (components/SettingsPanel.qml)
   ├── Task 5.2: Rich Actionable Notification Center & History (components/NotificationCenter.qml)
   └── Task 5.3: Ephemeral Toasts & Crash Recovery Banners (components/ToastNotification.qml)

WAVE 6: Multi-Monitor Visualizer, Dynamic Tips & Verification
   ├── Task 6.1: Multi-Monitor Workspace Visualizer (components/MultiMonitorManager.qml)
   ├── Task 6.2: Contextual Dynamic Tips Queue (core/DynamicTips.qml, components/FloatingTip.qml)
   └── Task 6.3: End-to-End Test Suite & Verification Matrix
```

---

## 4. DETAILED SPECIFICATION PER DOMAIN

### Phase 1: Foundations & Core Services

#### Task 1.1: Easing Tokens & Accessibility Engine
- **Files:** `theme/Theme.qml`, `core/AccessibilityManager.qml`
- **Specification:**
  - In `theme/Theme.qml`, establish standard animation duration constants: `animFast: 150`, `animNormal: 280`, `animSlow: 500`, `animBounce: 350`.
  - In `core/AccessibilityManager.qml`, implement properties:
    - `highContrastMode` (bool): boosts border widths to 2px, contrast ratios to > 7:1, disables translucent washes.
    - `reduceAnimations` (bool): forces all animation durations to 0ms when active.
    - `screenReaderMode` (bool): invokes `espeak-ng` on focus changes via `Quickshell.Io.Process`.
    - `keyboardFocusSize` (int): 3px outline around active focus items.

#### Task 1.2: UndoManager & CrashRecoveryManager
- **Files:** `core/UndoManager.qml`, `core/CrashRecoveryManager.qml`
- **Specification:**
  - `UndoManager.qml`:
    - Ring buffer of 20 items: `{ type: "workspace_switch" | "window_move" | "window_close", previousState: {...}, timestamp: int }`.
    - Hooked into `CompositorActionLayer.qml`.
    - Bound to shortcut `Ctrl+Z` and IPC `action undo`.
  - `CrashRecoveryManager.qml`:
    - Recurring 30s `Timer` dumps current workspace window distribution (`workspaceModel.workspaces` + addresses) to `$XDG_STATE_HOME/cool-shell/desktop-recovery.json`.
    - On startup, if recovery file timestamp is < 5 minutes old and shutdown was non-clean, triggers recovery banner.

#### Task 1.3: ConfirmationDialog & Tooltip Framework
- **Files:** `components/ConfirmationDialog.qml`, `components/Tooltip.qml`
- **Specification:**
  - `ConfirmationDialog.qml`:
    - Layer-shell modal overlay (`WlrLayer.Overlay`) with keyboard grab.
    - Props: `title`, `message`, `primaryButton`, `secondaryButton`, `destructive` (bool).
    - Keys: `Enter` accepts, `Escape` rejects. Focus trapped within dialog buttons.
  - `Tooltip.qml`:
    - Reusable hover bubble with 400ms delay timer and auto-placement relative to parent edges.

---

### Phase 2: Discoverability & First-Run Experience

#### Task 2.1: Visual Edge Hover Indicators
- **Files:** `components/HoverIndicators.qml`, `components/EdgeTrigger.qml`, `shell.qml`
- **Specification:**
  - Render subtle 24×6px translucent pills along screen edges with icons and labels:
    - Left corner: `⚙️ Control Center`
    - Bottom center: `📍 Workspaces`
    - Right corner: `🪟 Applications`
  - Subtle breathing opacity animation (`0.25` $\leftrightarrow$ `0.55` over 1200ms `InOutCubic`).
  - Track interaction count in `QSettings`: auto-hides permanently after 3 successful edge entries.
  - Shortcut `Alt+?` or `?` temporarily re-shows indicators for 5 seconds.

#### Task 2.2: Desktop Context Breadcrumb
- **Files:** `desktop/DesktopContextBreadcrumb.qml`, `desktop/AmbientLayer.qml`
- **Specification:**
  - Centered below the Dynamic Island at the top of the screen.
  - Text binding: `${WorkspaceManager.focusedWorkspaceName} // ${SurfaceManager.activeTitle || "Desktop"}`.
  - Truncates cleanly with ellipsis at 60 characters.
  - Opacity bound to `desktopState.hoverProgress` and mouse motion; fades away when focusing windows.

#### Task 2.3: First-Run Onboarding Wizard
- **Files:** `components/FirstRunWizard.qml`, `components/WizardStep.qml`
- **Specification:**
  - Multi-step guided tour on `WlrLayer.Overlay`:
    - Step 1: Welcome & Philosophy.
    - Step 2: Workspace Navigation (highlights bottom bar).
    - Step 3: Control Center (highlights bottom-left corner).
    - Step 4: Application Overview (highlights bottom-right corner).
    - Step 5: Dynamic Island & Shortcuts reference.
  - Uses `Region` inverted masks to darken the display while cutting out a bright transparent aperture around the highlighted element.
  - Can be re-launched at any time from Control Center.

---

### Phase 3: Navigation, App Discovery & Window Management

#### Task 3.1: Global Keyboard Navigation & App Switcher (Alt+Tab)
- **Files:** `components/AppSwitcher.qml`, `core/InteractionModel.qml`
- **Specification:**
  - Modal window on `WlrLayer.Overlay` activated by `Alt+Tab`.
  - Displays horizontal carousel of cards representing all running applications in `SurfaceModel`.
  - Each card shows application icon, window title, workspace badge, and active status.
  - Key bindings: `Tab` / `Right` advances, `Shift+Tab` / `Left` steps back, releasing `Alt` or hitting `Enter` immediately focuses the selected surface via `CompositorActionLayer.focusSurface()`. `Escape` cancels without switching.

#### Task 3.2: Unified Application Launcher & Dock
- **Files:** `components/ApplicationLauncher.qml`, `components/TaskbarDock.qml`
- **Specification:**
  - `ApplicationLauncher.qml`:
    - Spotlight-style modal search dialog on `WlrLayer.Overlay`.
    - Parses `.desktop` files from `/usr/share/applications` and `~/.local/share/applications`.
    - Instant substring and fuzzy matching over app name, executable, and categories.
    - Displays recent applications, categories grid ("System", "Office", "Media", "Development", "Graphics"), and inline calculation support via `Expression.js`.
  - `TaskbarDock.qml`:
    - Optional bottom dock showing pinned favorites + active running apps with running dot indicator and window count badges.

#### Task 3.3: Window Snapper & Layout Presets
- **Files:** `core/WindowSnapper.qml`, `core/WindowArrangements.qml`
- **Specification:**
  - `WindowSnapper.qml`:
    - Evaluates 8 snap zones: Left Half, Right Half, Top Half, Bottom Half, and 4 Quadrants.
    - Keybinds: `Super+Left` (Left Half), `Super+Right` (Right Half), `Super+Up` (Maximize), `Super+Down` (Restore).
    - Translates targets to Hyprland 0.47+ Lua dispatch:
      `hl.dsp.window.move({ window = "address:<addr>", x = ..., y = ..., width = ..., height = ... })`
  - `WindowArrangements.qml`:
    - Layout presets: Single Focus (fullscreen active), Side-by-Side (50/50 split), Picture-in-Picture (primary + 400×300 floating preview in bottom-right), 3-Column (33/33/33 split).

---

### Phase 4: System Telemetry & Performance

#### Task 4.1: SystemMonitor Component
- **Files:** `components/SystemMonitor.qml`, `components/TextualGraph.qml`
- **Specification:**
  - Integrated into `components/ControlCenter.qml`.
  - Non-polling / efficient telemetry:
    - CPU usage: reads `/proc/stat` delta on a 1000ms timer; maintains a 30-sample ring buffer rendered as a sparkline graph.
    - Memory: reads `/proc/meminfo` (MemTotal, MemAvailable). Renders colored progress bar (green $< 70\%$, orange $70-90\%$, red $> 90\%$).
    - GPU: reads `nvidia-smi` or `/sys/class/drm/card0/device/gpu_busy_percent` if available.
    - Temperature: reads `/sys/class/thermal/thermal_zone*/temp`.
    - FPS: exposes `desktopState.averageFPS` and wallpaper renderer VSync frame timing.

#### Task 4.2: Resource Threshold Performance Alerts
- **Files:** `core/PerformanceAlert.qml`
- **Specification:**
  - Emits desktop notifications when:
    - CPU usage remains $> 85\%$ for 10 consecutive seconds.
    - Free memory drops below 500MB (provides "Open Task Manager" button).
    - Shell frame rate drops below 45 FPS (provides "Disable Procedural Wallpaper" toggle button).

---

### Phase 5: Settings & Notifications Hub

#### Task 5.1: Central Tabbed Settings Panel
- **Files:** `components/SettingsPanel.qml`, `components/tabs/*`
- **Specification:**
  - Tabbed interface hosted within `LeftSidebar.qml` or full window:
    - **Tab 1: Appearance:** Dark/Light mode toggle, UI scale (0.8x to 1.5x), Panel opacity, Blur effects toggle, Theme selector, Wallpaper picker.
    - **Tab 2: Behavior:** Desktop icons toggle, Ambient idle HUD toggle, Idle timeout slider (30s to 600s), Focus-follows-mouse toggle.
    - **Tab 3: Keyboard:** Visual shortcuts reference and custom keybind recording.
    - **Tab 4: System:** OS version, Kernel version, Hyprland version, Wayland protocol status, system settings launcher.

#### Task 5.2: Enhanced Notification Center & Actionable Cards
- **Files:** `components/NotificationCenter.qml`, `components/ToastNotification.qml`
- **Specification:**
  - Full notification center with category filtering, clear-all, and persistent history (last 50 items).
  - Action buttons (`ActionButton.qml`) allowing inline responses (e.g. "Update", "Dismiss", "Reopen").
  - `ToastNotification.qml`: lightweight 3-second status pills in bottom-center for non-intrusive feedback ("Workspace switched", "Theme applied").

---

### Phase 6: Multi-Monitor Visualizer & Dynamic Tips

#### Task 6.1: Multi-Monitor Manager & Layout Visualizer
- **Files:** `components/MultiMonitorManager.qml`, `components/WorkspaceLayoutVisualizer.qml`
- **Specification:**
  - Card view showing all connected physical monitors (`desktopModel.monitors`).
  - Visual display of assigned workspaces per display, active workspace indicators, and window count badges.
  - Configuration options for independent workspace numbering vs mirrored workspaces.

#### Task 6.2: Dynamic Tips & Contextual Help Engine
- **Files:** `core/DynamicTips.qml`, `components/FloatingTip.qml`
- **Specification:**
  - Observes user behavior and queues subtle, dismissible tips:
    - If `workspaceModel.count > 1` and no keyboard switch occurred: `"💡 Tip: Press Alt+Tab or Super+1..N to switch workspaces quickly"`.
    - If `surfaceModel.count > 3`: `"💡 Tip: Hover the bottom-right corner to manage all running windows"`.
    - If a window is fullscreen: `"💡 Tip: Press Super+F or Esc to toggle fullscreen"`.
  - Auto-dismisses after 5 seconds; never repeats a tip dismissed more than twice.

---

## 5. DEPENDENCY & EXECUTION MATRIX

| Task ID | Domain / Component | Dependencies | Blocks | Can Parallelize With |
|---|---|---|---|---|
| **1.1** | Theme Tokens & Accessibility Engine | None | 2.1, 3.1, 5.1 | 1.2, 1.3 |
| **1.2** | UndoManager & Crash Recovery | None | 2.1, 3.3 | 1.1, 1.3 |
| **1.3** | ConfirmationDialog & Tooltips | None | 2.1, 2.3 | 1.1, 1.2 |
| **2.1** | Edge Hover Indicators | 1.1, 1.3 | 2.3 | 2.2, 3.1 |
| **2.2** | Desktop Context Breadcrumb | 1.1 | 2.3 | 2.1, 3.1 |
| **2.3** | First-Run Onboarding Wizard | 2.1, 2.2 | None | 3.2, 4.1 |
| **3.1** | Alt+Tab App Switcher | 1.1 | None | 3.2, 3.3 |
| **3.2** | App Launcher & Dock | 1.1 | None | 3.1, 3.3 |
| **3.3** | Window Snapper & Arrangements | 1.2 | None | 3.1, 3.2 |
| **4.1** | System Monitor Telemetry | None | 4.2 | 4.3, 5.1 |
| **4.2** | Performance Threshold Alerts | 4.1 | None | 4.3, 5.1 |
| **4.3** | Bottom Bar Status Consolidation | 1.1 | None | 4.1, 5.1 |
| **5.1** | Tabbed Settings Panel | 1.1, 4.1 | None | 5.2, 5.3 |
| **5.2** | Actionable Notification Center | 1.1 | None | 5.1, 5.3 |
| **5.3** | Toasts & Crash Banners | 1.2 | None | 5.1, 5.2 |
| **6.1** | Multi-Monitor Visualizer | None | None | 6.2 |
| **6.2** | Dynamic Contextual Tips | 2.1 | None | 6.1 |
| **6.3** | End-to-End Test Suite | All | None | None (Final) |

---

## 6. VERIFICATION SCENARIOS & QUALITY GATES

1. **Onboarding Smoke Test:** Clear `first-run.json`; verify wizard pops up on `WlrLayer.Overlay`, steps through all 5 cards, cuts out apertures around bottom bar and sidebars, and sets completion flag on finish.
2. **Safety & Destructive Action Test:** Trigger application close from `ApplicationOverview`; verify `ConfirmationDialog` appears, traps focus, confirms closure upon `Enter`, and cancels without effect upon `Escape`.
3. **Undo Verification:** Switch workspaces, move a window via Lua dispatch; press `Ctrl+Z`; verify `UndoManager` reverses the operation cleanly.
4. **Alt+Tab App Switcher Test:** Open 4 windows; hold `Alt`, press `Tab` repeatedly; verify card selection advances; release `Alt`; verify focused surface activates immediately.
5. **Accessibility Test:** Toggle `AccessibilityManager.highContrastMode`; verify borders thicken to 2px, contrast ratios exceed 7:1; toggle `reduceAnimations`; verify all transition times immediately drop to 0ms.
6. **Window Snapping Test:** Press `Super+Left` on active window; verify window snaps to exact left 50% boundary via Hyprland Lua dispatch.
7. **Performance Guard Test:** Simulate high CPU; verify `PerformanceAlert` fires a notification offering the "Open Task Manager" action.

---

## 7. NEXT STEP RECOMMENDATION

This implementation plan is decision-complete and organized into 6 atomic waves. When ready to proceed with implementation, execute **Wave 1** (Theme tokens, Accessibility Engine, UndoManager, and ConfirmationDialog).
