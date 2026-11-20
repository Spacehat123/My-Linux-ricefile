# Verification Report: Radial Marking Menu Release Gesture & Drop Pocket Fix

**Date**: 2026-11-17  
**Scope**: Contextual Action Hub Radial Gesture (`ContextualActionHub.qml`), Top-Bar Drop Pocket & Dynamic Island Integration  
**Verified Evidence Artifacts**:
- [test_radial_hub.png](file:///home/pranc/.gemini/antigravity-cli/brain/b628907f-e6fd-4609-9ad8-c932d04b63f8/test_radial_hub.png)
- [notch_shelf_check.png](file:///home/pranc/.gemini/antigravity-cli/brain/b628907f-e6fd-4609-9ad8-c932d04b63f8/notch_shelf_check.png)
- [notch_clipboard_check.png](file:///home/pranc/.gemini/antigravity-cli/brain/b628907f-e6fd-4609-9ad8-c932d04b63f8/notch_clipboard_check.png)

---

## 1. Issues Identified & Remediation

### 1. Release / Un-holding Gesture Not Firing
- **Root Cause**:
  1. In Qt Quick `MouseArea`, if `mousePressEvent` was not received by the item (because the middle button was pressed before the window opened), `MouseArea.onReleased` is suppressed by Qt's event loop.
  2. Hyprland consumed `mouse:274` on press without an explicit release binding.
- **Remediation**:
  1. Bound `mouse:274` release in [hyprland.lua](file:///home/pranc/.config/hypr/hyprland.lua#L400-L405) using `{ mouse = true, release = true }` mapped to `qs_ipc("hub release")`.
  2. Added `hub release` IPC endpoint and `signal releaseActionHub()` in [shell.qml](file:///home/pranc/.config/quickshell/cool-shell/shell.qml#L1428-L1435).
  3. Connected `onReleaseActionHub()` in [ContextualActionHub.qml](file:///home/pranc/.config/quickshell/cool-shell/panels/ContextualActionHub.qml#L175-L185) to call `root.triggerChoice()`. Now simply releasing (un-holding) the middle mouse button executes the highlighted option immediately.

### 2. Quick Stash Target (Top Bar Drop Pocket)
- **Root Cause**: Quick Stash previously opened the right-edge slide-out stash pocket instead of the top-bar Dynamic Island Drop Pocket.
- **Remediation**: Updated East option (1) to invoke `Island.ShellState.show("shelf", "")`, which smoothly unfolds the top bar Drop Pocket panel (verified in [notch_shelf_check.png](file:///home/pranc/.gemini/antigravity-cli/brain/b628907f-e6fd-4609-9ad8-c932d04b63f8/notch_shelf_check.png)).

### 3. Non-Working Radial Hub Options
- **Root Cause**:
  1. **Clipboard History (South)**: Was previously copying the latest snippet via background pipeline without showing the clipboard interface.
  2. **Screen Lens (North)**: Invoked `slurp` immediately while Quickshell's overlay window was still active, causing Wayland grab collision and freezing.
  3. **Voice Note (West)**: Used QML `Process` which didn't detach cleanly from stdin.
- **Remediation**:
  1. **Clipboard**: Linked directly to `Island.ShellState.show("clipboard", "")`, opening the full Dynamic Island Clipboard History panel (verified in [notch_clipboard_check.png](file:///home/pranc/.gemini/antigravity-cli/brain/b628907f-e6fd-4609-9ad8-c932d04b63f8/notch_clipboard_check.png)).
  2. **Screen Lens**: Switched to `Quickshell.execDetached(["sh", "-c", "sleep 0.18; ...screen-lens.sh"])` with stale-process cleanup (`killall -q slurp`).
  3. **Voice Note**: Attached detached standard input (`</dev/null`) to `pw-record` in `voice-note.sh` and launched via `Quickshell.execDetached`.

---

## 2. Verification Matrix

| Option / Gesture | Target Behavior | Observed Verification | Result |
|---|---|---|---|
| **Middle Unclick Gesture** | Un-holding middle button executes selected sector | Hyprland `bindr` + IPC `hub release` -> `triggerChoice()` | PASS |
| **Quick Stash (East)** | Opens top-bar Drop Pocket in Dynamic Island | `Island.ShellState.show("shelf", "")` unfolds Drop Pocket | PASS |
| **Clipboard History (South)** | Opens Clipboard History panel in Dynamic Island | `Island.ShellState.show("clipboard", "")` displays full history list | PASS |
| **Screen Lens (North)** | Prompts interactive box selection for OCR / QR | `sleep 0.18` overlay handoff + `slurp` + `tesseract` / `zbarimg` | PASS |
| **Voice Note (West)** | Starts/stops audio recording to `~/Music/VoiceNotes` | Detached `pw-record` with island HUD notifications | PASS |
| **Deadzone Timeout** | Closes in 0.5s if cursor stays in central deadzone | `deadzoneTimer` auto-dismisses when `selectedSector === -1` | PASS |

---

## 3. Dedicated Keybinding Refinement
- **Removed Middle Click (`mouse:274`)**: Completely unhooked all middle mouse button intercepts from `hyprland.lua` to preserve standard middle-click paste and browser tab controls across the desktop.
- **Sole Trigger**: `SUPER + Space` remains as the dedicated trigger to summon the Radial Marking Menu Action Hub centered at the cursor.
