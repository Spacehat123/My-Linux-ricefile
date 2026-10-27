# Cool-Shell Dynamic Island Polish, 10s Timer Alarm & Hotstar Quota

- **Date**: 2026-10-27
- **Workspace**: `/home/pranc/.config/quickshell/cool-shell`
- **Target Platform**: Hyprland / Wayland / Linux
- **Framework**: Quickshell 0.3.1 / Qt 6 / Python 3 / PipeWire
- **Status**: Completed & Verified

---

## 1. Summary of Changes

1. **10-Second Timer Completion Alarm**:
   - Implemented `scripts/play-timer-alarm.sh` utilizing native `paplay`/`pw-play` with `/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga`.
   - Wired into `island/TimerState.qml`:
     - Plays for 10 seconds automatically on timer expiration (`raiseCompletion`).
     - Tapping the Dynamic Island or acknowledging the timer immediately silences the alarm cleanly (`stopAlarmSound`).

2. **Dual Live Activity (Timer Visible during Study Mode)**:
   - When Study Mode is active and a timer or countdown is running, the Dynamic Island now smoothly morphs into an Apple-style Dual Live Activity pill:
     - Left: Study status badge & elapsed/remaining time (`󰑴 29d 23h`).
     - Center: Refined micro-divider.
     - Right: Active timer countdown (`󱎫 04:32`) or completion pulse (`󰄬 DONE`).
     - Bottom: Live progress line tracks timer countdown.
   - Automatically expands the collapsed pill width to accommodate both activities cleanly.

3. **Hotstar Daily 1-Hour Quota Whitelist**:
   - Added `https://www.hotstar.com/` and subdomains to the Exam Profile whitelist (`study-mode.py`).
   - Tracked date-by-date (`YYYY-MM-DD`) in `~/.local/share/cool-shell/study/hotstar_quota.json`.
   - Gives 1 hour (3600 seconds) of play time per calendar day. Once exhausted, the tab closes with an Island notification and resets the next day.

4. **Dynamic Island Hardware Glass Polish (Apple & Open-Source Inspired)**:
   - Deep pitch-black `#08080c` OLED body.
   - Refined 1px specular micro-border (`Qt.rgba(1, 1, 1, 0.12)`).
   - Top specular curved glass inner highlight sheen.
   - Smooth tactile spring hover scale (`1.025`) and border glow highlight on cursor entry.
   - Pulse animations during timer completion hold.

---

## 2. Dual Live Activity & Quota Tracking Architecture

1. **Dual Live Activity (Horizontal Fluid Morphing)**:
   - Kept the Dynamic Island at standard collapsed height (`24px`).
   - When Chess or JioHotstar is opened, the island smoothly widens to display a secondary trailing chip:
     - `♟ Chess [mm:ss]` (live decreasing countdown)
     - `🍿 JioHotstar [mm:ss]` (live decreasing countdown)
   - When the window or tab is closed, the trailing chip immediately switches to:
     - `⏸ Paused ([mm]m left)` for 3.0 seconds, giving clear visual confirmation.
     - Retracts smoothly back to normal island dimensions.
   - Full compatibility across both active Study Mode and normal standby mode.

## 3. Full Verification & Lockdown Integrity

- **Terminal Access**: `kitty`, `kitty-dropterm`, and `xterm-kitty` confirmed 100% whitelisted in `is_allowed_class`.
- **Long Session Exam Profile**: Spotify permitted, Gemini whitelisted, Hotstar and Chess quotas enforced.
- **Quota Expiration**: Automatically closes tabs when 3600 seconds are reached in a calendar day; resets every midnight.
- **Anti-Jailbreak**: Hard lock refuses early termination, absolute timestamp survives reboots, daemon auto-resurrects.
- **10s Timer Alarm**: `play-timer-alarm.sh` chimes for 10 seconds on timer completion or until tapped.
- **QML Runtime**: Zero syntax errors or runtime faults in Quickshell.
