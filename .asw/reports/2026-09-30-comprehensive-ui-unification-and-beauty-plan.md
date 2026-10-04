# Comprehensive Visual Makeover & Unified Design Plan: Making Cool-Shell Truly Gorgeous

**Date:** 2026-09-30  
**Target:** [`cool-shell`](file:///home/pranc/.config/quickshell/cool-shell/)  
**Document Type:** Visual Design Architecture Plan & UI Surface Catalog  
**Status:** Approved for Review (Planning Only — No Code Implemented)  
**Rule Compliance:** [`.agents/rules/reports.md`](file:///home/pranc/.config/quickshell/cool-shell/.agents/rules/reports.md)

---

## 1. Executive Summary & Design Vision

Cool-Shell currently has two completely conflicting visual personalities:
1. **The Modern Dynamic Island (`island/`):** A sleek, rounded floating capsule inspired by modern Apple Live Activities and high-end Linux customization, featuring spring physics, a 360-degree border progress ring, and cohesive theme palettes.
2. **The Prototype Sidebars and Bottom Bar (`panels/`, `components/`, `theme/`):** A relic from an early prototype consisting of hard-edged dark boxes (`radius: 0`), harsh monospace text (`// CONTROL CENTER`, `SYS.ONLINE`, `// SURFACES`), retro-sci-fi brackets, and a barebones 30px Waybar replica.

### The Objective
Transform **every single visual surface that a user can ever see** into a unified, breathtaking, modern desktop experience. Everything will look intentional, harmonious, tactile, and luxurious—like a cohesive blend of macOS frosted glass, modern iOS control centers, and high-end Wayland aesthetics.

### Key Architectural Change: Detached Settings Window
As requested, **Settings is completely removed from inside the Dynamic Island**. 
* The Dynamic Island will feature a clean **Settings Button (`󰒓`)** in the Control Center header and tools grid.
* Clicking this button smoothly closes the Island and opens a **spacious, standalone, centered floating Settings Window (780 × 540)**. 
* This provides infinite room for multi-category sidebar navigation, wallpaper galleries, sound device managers, keyboard shortcut maps, and future expansion without crowding the nimble Dynamic Island.

---

## 2. Inventory: Everything the User Can Ever See

Below is the complete catalog of every user-visible surface in Cool-Shell, what it looks like today, why it falls short, and how it will be completely redesigned.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   COMPLETE USER-VISIBLE SURFACE MAP                    │
├────────────────────────────────┬───────────────────────────────────────┤
│ 1. Dynamic Island & Panels     │ 7. Toast Notification Cards           │
│ 2. Dedicated Settings Window   │ 8. Screen Capture & Region Selector   │
│ 3. Left Control Drawer         │ 9. Workspace Spatial Transition HUD   │
│ 4. Right Window Hub Drawer     │ 10. Ambient Desktop Screensaver       │
│ 5. Floating Liquid Bottom Dock │ 11. Onboarding Welcome Guide          │
│ 6. Edge Trigger Glow Lines     │                                       │
└────────────────────────────────┴───────────────────────────────────────┘
```

---

### Surface 1: The Dynamic Island (Notch & Panels)
* **What It Controls:** Collapsed status capsule and 12 expandable activity panels (Control, Media, Launcher, Notifications, Timers, Capture, Shelf, Todo, Notes, Weather, Themes, Power).
* **Current State:**
  * Collapsed pill is solid and functional (spring physics, 360° border ring, audio waveforms).
  * Expanded panels still have cramped margins (6px–8px), flat inactive buttons, and basic square album art.
* **The Makeover:**
  * **Spacious Margins:** Standardize 16px container margins and 12px item gaps across all 12 panels.
  * **Tactile Buttons:** Every icon button and action tile gets physical micro-haptics: gentle hover illumination (+8% brightness) and a 3% physical compression (`scale: 0.97`) on click.
  * **Smart Launcher:** Squircles for app icons, category tags, and a slide-down card for instant math calculations (`250 * 1.15`).
  * **Media Player:** Album cover with 14px rounded corners and a soft diffused drop-shadow halo, paired with a pill scrub bar and glowing transport buttons.
  * **Settings Button:** A prominent gear button (`󰒓`) in the top-right header and a dedicated pill in the tools grid that cleanly triggers the standalone Settings window.

---

### Surface 2: The Dedicated Settings App / Window (New Standalone Window)
* **What It Controls:** Global shell preferences, themes, sound, wallpaper, window recovery, accessibility, and about info.
* **Current State:** Previously squeezed inside the 480 × 380 Dynamic Island notch, making it feel cramped and unable to host rich configurations.
* **The Makeover:**
  * **Form Factor:** A standalone floating glass window (780px wide × 540px high) centered on screen with 24px corner curvature and a soft 1px border sheen.
  * **Split Navigation Layout:**
    * **Left Navigation Sidebar (220px):** Beautiful rounded category pills with vibrant icons:
      1. 🎨 *Appearance & Themes* (theme cards, color preview swatches, dark mode accents)
      2. 🖼️ *Wallpaper & Background* (visual thumbnail grid, awww daemon status)
      3. 🔊 *Sound & PipeWire* (sink/source selector, per-app stream sliders)
      4. 🗣️ *Accessibility & Speech* (screen reader toggle, voice speed, speech-dispatcher health)
      5. 💾 *Window Recovery & State* (atomic layout tracking, snapshot history, commit button)
      6. ⌨️ *Keybindings & Gestures* (visual cheat sheet of all Super-key and gesture shortcuts)
      7. ℹ️ *About Cool-Shell* (version badge, system specs, replay onboarding guide)
    * **Right Content Canvas (560px):** Smoothly scrollable settings cards with iOS-style pill switches, rounded numeric sliders, and clean descriptive labels.
  * **Dismissal:** Easily closed with `Escape`, a sleek top-right close button (`×`), or clicking outside.

---

### Surface 3: The Left Sidebar (Control & Quick Glance Drawer)
* **File:** [`panels/LeftSidebar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/LeftSidebar.qml) & [`components/ControlCenter.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/ControlCenter.qml)
* **Current State:** 
  * Harsh 320px width rectangle with zero corner radius (`radius: 0` in `PanelSurface.qml`).
  * Monospace retro-cyber text: `"// CONTROL CENTER"`, `"SYS.ONLINE"`, `"WALLPAPER ENGINE ACTIVE // 60 FPS VSYNC"`, `"SYS // PRANC.SHELL v0.27"`.
  * Sharp 1px neon green dividers and awkward switches. Looks completely disconnected from the rest of the shell.
* **The Makeover:**
  * **Floating Glass Drawer:** 360px width with 24px rounded right corners and a 12px outer screen margin. Made of dark smoked frosted glass (`rgba(17, 17, 27, 0.90)`) with a delicate white top-rim highlight.
  * **Header Greeting:** Clean typography welcoming the user with live time, day/date, and battery health pill.
  * **System Control Cards:**
    * 2×2 grid of squircle control tiles (Wallpaper Engine toggle, Ambient Dimmer, Night Light, Do Not Disturb) that softly glow with theme accent colors when active.
  * **Audio Output Card:** Native PipeWire sink selector with a thick rounded volume slider and live percentage pill.
  * **Minimal Telemetry:** Replaces the messy text dump with sleek status capsules showing active workspace, display resolution (`1920×1080`), and system uptime.
  * **Spring Motion:** Slides smoothly from the left with spring dynamics (`x: -360 -> 0`) rather than linear easing.

---

### Surface 4: The Right Sidebar (Window & Application Hub)
* **File:** [`panels/RightSidebar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/RightSidebar.qml) & [`components/ApplicationOverview.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/ApplicationOverview.qml)
* **Current State:**
  * Cyber-tactical monospace layout with raw ASCII symbols: `"// SURFACES"`, `"WS 1"`, `"◈"`, `"◇"`, `"⛶"`, `"❐"`, `"⇄"`, `"×"`.
  * Hard rectangular cards with no app icons and confusing micro-buttons.
  * Empty state displays a raw text dump: `"[ // ] // NO ACTIVE SURFACES"`.
* **The Makeover:**
  * **Mission Control Window Dock:** 380px floating glass drawer with 24px rounded left corners.
  * **Header:** "Active Windows" with a total count badge and an instant search/filter bar to locate open windows quickly.
  * **Window Cards:**
    * High-resolution application icons (Brave, Kitty, Dolphin, etc.) in smooth squircle frames.
    * App title in crisp bold sans-serif, accompanied by window title in soft muted text.
    * Pill badge indicating which workspace the window currently lives on.
  * **Action Pills:** Hovering over a window smoothly reveals clean micro-buttons:
    * Focus (`󰖲`), Fullscreen (`⛶`), Move to Workspace (`⇄`), and Close (`×`) with 0.97 press compression.
  * **Empty State:** A warm, minimalist illustration with "All Workspaces Clear" and a subtitle "No windows currently open."

---

### Surface 5: The Bottom Bar (Floating Liquid Dock)
* **File:** [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml)
* **Current State:**
  * Flat 30px Waybar replica with hard 1px border and basic Nerd Font icons (``, ``).
  * No dock capsule, no spring animations, no frosted glass depth.
* **The Makeover:**
  * **Floating Glass Dock Capsule:**
    * Height increased to 44px with a 22px pill curvature and 10px bottom screen margin.
    * Frosted smoked glass body (`rgba(17, 17, 27, 0.88)`) with a subtle 1px white rim sheen.
  * **Left (Liquid Workspace Capsules):**
    * Active workspace displays as an elongated glowing pill with the workspace number and accent tint.
    * Inactive workspaces display as clean minimal dots that expand into numbered capsules when hovered.
    * Occupied workspaces feature a delicate internal dot indicator.
  * **Center (Typographic Clock):**
    * A refined two-line time and date widget: bold 12px time (`15:30`) above a delicate 9px date (`Wed, 30 Sep`).
  * **Right (System Status Cluster):**
    * Pill cluster grouping Wi-Fi (shows SSID on hover), PipeWire Audio (interactive scrollable volume pill), and Battery (dynamic filling level with charging lightning bolt).
    * Hovering over any module gently illuminates its background capsule.

---

### Surface 6: Edge Triggers & Screen Gestures
* **File:** [`components/EdgeTrigger.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/EdgeTrigger.qml)
* **Current State:** 2px solid colored lines (`#00ff88`, `#00bfff`, `#ff0088`) at the bottom of the screen.
* **The Makeover:**
  * Completely invisible at rest (0% opacity, zero Scene Graph overhead).
  * When the cursor touches the bottom-left, bottom-center, or bottom-right screen edge, a soft 3px diffused ambient glow line fades in smoothly (150ms) matching the current theme accent color, signaling that the drawer or dock is ready to emerge.

---

### Surface 7: Toast Notifications & Popups
* **File:** [`island/NotificationPopups.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/NotificationPopups.qml) & [`island/NotificationCard.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/NotificationCard.qml)
* **Current State:** Flat cards in the top-right corner with basic outlines and instant dismissals.
* **The Makeover:**
  * Floating frosted glass notification cards with 20px curvature and soft drop shadows.
  * Large, crisp app icons with an ambient color halo matching notification urgency (e.g. crimson halo for low battery or errors).
  * Action button pills with gentle hover highlights and satisfying click compression.
  * Smooth slide-and-fade entrance (`x: +40 -> 0`, `opacity: 0 -> 1`) using spring dynamics.

---

### Surface 8: Screen Capture & Region Selection Overlay
* **File:** [`island/CaptureSelector.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/CaptureSelector.qml)
* **Current State:** Basic crosshair with hard 1px outlines and an unstyled coordinate tooltip.
* **The Makeover:**
  * Dark semi-translucent backdrop (`rgba(0, 0, 0, 0.55)`) that dims background windows.
  * Glowing selection box with rounded corners and an animated dashed border.
  * Sleek floating glass dimension pill (`1920 × 1080`) that follows the cursor smoothly.
  * Window hover halo that highlights entire windows with a gentle rounded tint before clicking.

---

### Surface 9: Workspace Spatial Transition HUD
* **File:** [`desktop/DesktopTransition.qml`](file:///home/pranc/.config/quickshell/cool-shell/desktop/DesktopTransition.qml)
* **Current State:** Monospace military HUD reticle: `"FROM 01 ──► DEST 02"`.
* **The Makeover:**
  * Minimalist, elegant floating glass pill in the exact center of the screen during workspace switching.
  * Displays smooth horizontal sliding numbers (`1 → 2`) alongside an animated dot tracker.
  * Disappears instantly (150ms fade-out) so it never gets in the way of active work.

---

### Surface 10: Desktop Ambient Layer (Idle Screensaver)
* **File:** [`desktop/AmbientLayer.qml`](file:///home/pranc/.config/quickshell/cool-shell/desktop/AmbientLayer.qml) & related ambient components
* **Current State:** Tactical crosshairs and corner brackets.
* **The Makeover:**
  * Peaceful, modern ambient mode when the computer goes idle.
  * Soft desktop dimming paired with a large, elegant clock in the center of the display, subtle local weather information, and battery percentage.
  * Disappears the millisecond the mouse moves or a key is pressed.

---

### Surface 11: Onboarding Welcome Guide
* **File:** [`island/components/OnboardingManager.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/components/OnboardingManager.qml) & [`OnboardingCard.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/components/OnboardingCard.qml)
* **Current State:** Basic introductory banner.
* **The Makeover:**
  * A welcoming, high-end floating card that introduces the user to Cool-Shell's gestures:
    1. *The Dynamic Island* (top center for media, volume, and launcher).
    2. *The Sidebars* (bottom-left for system controls, bottom-right for open windows).
    3. *The Floating Dock* (bottom center for workspaces and time).
    4. *Settings* (the gear icon for full desktop customization).
  * Interactive "Try it" buttons and smooth completion feedback.

---

## 3. The 4 Universal Design Rules (Unifying Everything)

To ensure that every component feels like part of a single, handcrafted operating system, all surfaces will strictly obey these four rules:

```
┌────────────────────────────────────────────────────────┐
│             THE 4 UNIVERSAL DESIGN RULES               │
├────────────────────────────────────────────────────────┤
│ 1. Smoked Frosted Glass (Layered depth & white sheens) │
│ 2. Consistent Geometry (24px window, 16px card, pill)  │
│ 3. Tactile Spring Physics (0.97 press compression)     │
│ 4. Single Token Engine (Theme.qml powers everything)   │
└────────────────────────────────────────────────────────┘
```

1. **Smoked Frosted Glass Materials:**
   * Outer boundary: 1px subtle highlight (`rgba(255, 255, 255, 0.08)`) simulating light hitting the top edge of real glass.
   * Container fill: Deep semi-translucent dark background (`rgba(17, 17, 27, 0.90)`), letting desktop wallpaper warmth peek through without muddying readability.
   * Cards & items inside: Frosted contrast surfaces (`rgba(255, 255, 255, 0.04)` to `0.08`).

2. **Consistent Rounded Geometry:**
   * Window & Drawer Curvature: **24px** smooth radii.
   * Container & Subpanel Cards: **16px** squircle radii.
   * Action Tiles & List Items: **12px** rounded corners.
   * Status Badges, Switches & Sliders: **999px** full capsule curves.

3. **Tactile Spring Physics ("Micro-Haptics"):**
   * Every clickable element compresses down by 3% (`scale: 0.97`) on click and bounces back up on release.
   * Every hoverable element lifts in brightness (+8%) within 140ms.
   * All opening and closing transitions use tuned spring physics rather than rigid linear animations.

4. **Single Source of Truth Theme Engine:**
   * Completely retire the old diverging tokens in `theme/Theme.qml`.
   * Every single surface, sidebar, dock, popup, and window will import and bind directly to [`island/Theme.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/Theme.qml).
   * Switching between *Catppuccin Mocha, Macchiato, Tokyo Night, Nord, and Midnight* in Settings will transform the entire desktop instantly.

---

## 4. Architectural Blueprint: Standalone Settings Window

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          STANDALONE SETTINGS WINDOW                         │
├───────────────────────┬─────────────────────────────────────────────────────┤
│   CATEGORIES (220px)  │                 SETTINGS CANVAS (560px)             │
├───────────────────────┼─────────────────────────────────────────────────────┤
│ 🎨 Appearance & Theme │  Theme Selector (Preview Swatches)                 │
│ 🖼️ Wallpaper & Desk   │  [Catppuccin] [Tokyo Night] [Nord] [Midnight]       │
│ 🔊 Sound & Audio      │                                                     │
│ 🗣️ Accessibility      │  Accent Glow Level                                  │
│ 💾 Window Recovery    │  [● Subtle Glow  ]                                  │
│ ⌨️ Shortcuts & Keys   │                                                     │
│ ℹ️ About Cool-Shell   │  Frosted Glass Opacity                              │
│                       │  ├───○───────────────┤ 90%                          │
└───────────────────────┴─────────────────────────────────────────────────────┘
```

### Wiring Flow:
1. **Dynamic Island Trigger:**
   * In [`island/panels/ControlPanel.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/panels/ControlPanel.qml), clicking the Header Gear Button (`󰒓`) or the "Settings" pill button triggers:
     ```qml
     onClicked: {
         ShellState.close();
         settingsWindow.toggle();
     }
     ```
2. **Window Container (`panels/SettingsWindow.qml`):**
   * Implemented as a top-level `PanelWindow` anchored to screen center with `exclusionMode: ExclusionMode.Ignore`.
   * Size: 780 × 540.
   * Dismissable via `Escape` key, top-right `×` button, or clicking outside.
3. **IPC Command:**
   ```bash
   quickshell ipc -c cool-shell call settings toggle
   ```

---

## 5. Phased Implementation Roadmap & Execution Checklists

- [ ] **Task 1: Master Glass Tokens & Theme Unification**
  - Files: `island/Theme.qml`, `theme/Theme.qml`
  - Action: Update `island/Theme.qml` with master smoked glass tokens, rim-sheen borders, and geometry radii. Re-target `theme/Theme.qml` so that legacy components inherit the new styling without breaking.
  - Verification: `quickshell -c cool-shell` loads cleanly with 0 syntax errors or unresolved Theme properties.

- [ ] **Task 2: Standalone Settings Window & Island Decoupling**
  - Files: `panels/SettingsWindow.qml`, `island/Notch.qml`, `island/panels/ControlPanel.qml`, `island/ShellState.qml`, `shell.qml`
  - Action: Create standalone `panels/SettingsWindow.qml` (780×540 centered glass window). Remove inline `SettingsPanel` from Dynamic Island stack. Wire Island Gear button and tools pill to toggle `SettingsWindow`. Add IPC target in `shell.qml`.
  - Verification: `quickshell ipc -c cool-shell call settings toggle` opens and closes the window smoothly.

- [ ] **Task 3: Floating Liquid Bottom Dock**
  - Files: `panels/BottomBar.qml`
  - Action: Transform bottom bar into a 44px floating glass capsule with 22px curvature. Implement expanding liquid workspace capsules, refined typographic clock, and system status cluster.
  - Verification: Hovering bottom-center edge reveals the floating dock; workspace clicks switch workspaces cleanly.

- [ ] **Task 4: Left & Right Sidebar Drawers Makeover**
  - Files: `panels/LeftSidebar.qml`, `components/ControlCenter.qml`, `panels/RightSidebar.qml`, `components/ApplicationOverview.qml`, `components/PanelSurface.qml`
  - Action: Replace monospace cyber-tactical layout with modern frosted smoked glass styling, 24px corner radii, squircle quick toggles, volume sliders, app icons, and hover action pills.
  - Verification: Triggering left and right sidebars reveals beautiful glass drawers with 0 QML errors.

- [ ] **Task 5: Micro-Haptics, Ambient Layer & Polish**
  - Files: `island/components/IconButton.qml`, `island/components/ActionTile.qml`, `components/EdgeTrigger.qml`, `desktop/DesktopTransition.qml`, `desktop/AmbientLayer.qml`
  - Action: Add 3% press compression (`scale: 0.97`) to buttons, polish edge trigger hover glow lines, and modernize workspace transition reticle.
  - Verification: Visual inspection and interaction testing with zero idle CPU overhead.

- [ ] **Task 6: Final Verification & Review Delegation**
  - Subagent: Invoke `asw-reviewer` via `invoke_subagent` to audit git diff and runtime logs.
  - Verification: All features working, 0 QML errors, 0.00% idle CPU.

---

## 6. Zero-Overhead Performance Guarantee

Every visual enhancement in this plan strictly preserves our **Zero-Overhead Rule**:
* **0.00% idle CPU utilization:** All animations halt completely when resting.
* **No expensive multi-pass blur shaders:** Depth is achieved through layered semi-translucency and rim highlights, maintaining a rock-solid 60+ FPS on all displays.
* **Bounded memory & zero leaks:** Clean QML component lifecycles with immediate resource cleanup.
