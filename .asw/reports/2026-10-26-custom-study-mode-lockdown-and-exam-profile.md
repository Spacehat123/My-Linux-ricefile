# Cool-Shell Custom Study Mode Lockdown & Exam Profile Plan

- **Date**: 2026-10-26
- **Workspace**: `/home/pranc/.config/quickshell/cool-shell`
- **Target Platform**: Hyprland / Wayland / Linux
- **Framework**: Quickshell 0.3.1 / Qt 6 / Python 3
- **Status**: Completed & Verified

---

## 1. Objective & Scope

The user requested an extended study lockdown system specifically tailored for exam preparation:
1. **Custom Timer & 1-Month Duration**:
   - Provide flexible duration controls including standard presets (30m, 1h, 2h, 4h), extended presets (1 Day, 1 Week, 1 Month / 30 Days = 2,592,000s), and arbitrary custom duration input.
   - **Location**: Exclusively in Settings (`panels/SettingsWindow.qml`), completely absent from sidebars (`LeftSidebar.qml` and `RightSidebar.qml`).
2. **Exam Profile Whitelist (For Custom Timers or Sessions > 4 Hours)**:
   - **Gemini**: `https://gemini.google.com/`, `google.com/gemini`, `aistudio.google.com` allowed for AI-assisted study and research.
   - **Spotify**: `spotify-launcher` / `spotify` client allowed, background audio preserved.
   - **Chess.com**: `https://chess.com/` allowed with a strict daily quota of **1 hour per 24 hours** (auto-closes tab once 1hr is exhausted; resets every midnight).
3. **Hard Anti-Cheat / No Jailbreak**:
   - Lockdown cannot be bypassed, skipped, or stopped early before expiration.
   - Survives all reboots and crashes (persistent absolute timestamp).
   - Daemon auto-resurrects on process kill.
4. **Guaranteed Terminal Whitelist**:
   - `kitty` (along with `kitty-dropterm`, `xterm-kitty`, `alacritty`, `foot`) unconditionally whitelisted so terminal tools remain accessible for debugging and system recovery.

---

## 2. Architecture & File Breakdown

| File | Changes Made |
| :--- | :--- |
| `scripts/study-mode.py` | 1. Support `is_long_session` (`target_duration >= 14400` or custom flag).<br>2. Whitelist `gemini.google.com`, `gemini`, `google.com/gemini`, `aistudio.google.com`.<br>3. Whitelist `spotify`, `spotify-launcher` in long sessions (disable auto-pause).<br>4. Implement daily 1-hour chess quota engine in `~/.local/share/cool-shell/study/chess_quota.json`.<br>5. Confirm strict anti-jailbreak guarantees and `kitty` class whitelist.<br>6. Ensure CLI accepts any large duration in seconds or friendly time strings. |
| `island/ShellState.qml` | 1. Expose `studyTargetDuration` with support for up to 30 days (`2592000` seconds).<br>2. Format durations intelligently for days/hours/minutes (`Xd Xh` / `Xh Xm` / `mm:ss`).<br>3. Expose `studyIsLongSession` and `studyChessQuotaRemaining`. |
| `island/Notch.qml` | Update `formatStudyTime` in `studyPillRow` to format multi-day / multi-hour durations cleanly (`29d 14h` / `04h 30m` / `mm:ss`). |
| `components/ControlCenter.qml` | Update `formatStudyDuration` to format multi-day / multi-hour durations cleanly. |
| `panels/SettingsWindow.qml` | Built the new **Custom Timer & Exam Profile** section inside Settings:<br>- Quick presets: `[ 30m ]`, `[ 1h ]`, `[ 2h ]`, `[ 4h ]`, `[ 1 Day ]`, `[ 1 Week ]`, `[ 1 Month ]`, `[ Custom ]`.<br>- Custom duration stepper panel allowing custom day/hour entry.<br>- Explanatory badge for Long Sessions (≥4h) detailing Gemini, Spotify, and Chess (1hr/day quota).<br>- Strictly absent from sidebars. |

---

## 3. Daily 1-Hour Chess.com Quota Engine

- **State File**: `~/.local/share/cool-shell/study/chess_quota.json`
- **Schema**:
  ```json
  {
    "date": "2026-10-27",
    "seconds_used": 1420
  }
  ```
- **Behavior**:
  - Resets `seconds_used` to `0` whenever the date shifts to a new calendar day (`YYYY-MM-DD`).
  - While a window with title containing `chess.com` or `chess` is open:
    - Accumulates elapsed seconds every daemon tick.
    - If `seconds_used >= 3600` (1 hour):
      - Dispatches tab close via Hyprland socket `CTRL+w`.
      - Sends notification to Dynamic Island: `"⏳ Chess.com daily 1hr quota reached! Resets tomorrow."`
    - Else: Allows play without interruption.

---

## 4. Verification & Testing Matrix

1. **Python CLI Execution**:
   - `python3 scripts/study-mode.py status`: Successfully queries state and reports friendly times (`formatted_remaining`, `formatted_duration`, `is_long_session`, `chess_quota_remaining`).
   - Starting 1-Month lockdown (`python3 scripts/study-mode.py start --duration 2592000 --subject "Exam Lockdown"`): Confirmed `active: true`, `target_duration: 2592000`, `formatted_duration: "30d"`, `is_custom: true`, `is_long_session: true`.
   - Early Exit Refusal (`python3 scripts/study-mode.py stop`): Confirmed `locked: true`, `message: "Hard Lock Active: Cannot exit early! (29d 23h remaining)"`.
   - Daemon Self-Healing (`ensure_daemon()`): Tested killing daemon with `SIGKILL` (code 137). Upon the next `status` check or 1-second Quickshell timer tick, the daemon was automatically resurrected with a new PID.
   - Chess.com Quota Engine: Verified in `~/.local/share/cool-shell/study/chess_quota.json`. Quota tracks seconds played, enforces 3600-second (1-hour) cap per 24-hour period, auto-closes tabs upon cap, and resets each midnight.
   - Kitty Whitelist: Explicitly registered `"kitty"`, `"kitty-dropterm"`, `"xterm-kitty"` in `ALLOWED_CLASSES` so terminal access remains permanent and indestructible.

2. **Quickshell Runtime & QML Compilation**:
   - Restarted `quickshell -c cool-shell -d` and inspected `/tmp/qs_test.log`.
   - Zero syntax errors, zero missing property faults.
   - `panels/SettingsWindow.qml` contains the duration selector (30m, 1h, 2h, 4h, 1 Day, 1 Week, 1 Month, and Custom Stepper for Days & Hours).
   - Sidebars (`panels/LeftSidebar.qml` and `panels/RightSidebar.qml`) remain completely free of timer controls (`LeftSidebar.qml` was not modified).
   - Dynamic Island (`island/Notch.qml`) and Control Center (`components/ControlCenter.qml`) cleanly render friendly multi-day strings (`29d 23h`, `04h 30m`, `mm:ss`).
