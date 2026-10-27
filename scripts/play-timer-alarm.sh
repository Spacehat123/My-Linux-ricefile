#!/usr/bin/env bash
# ==============================================================================
# Timer Alarm Chime: Plays alarm sound for 10 seconds or until dismissed
# ==============================================================================
set -euo pipefail

SOUND="/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
if [ ! -f "$SOUND" ]; then
    SOUND="/usr/share/sounds/freedesktop/stereo/complete.oga"
fi

end_time=$((SECONDS + 10))

while [ $SECONDS -lt $end_time ]; do
    if command -v paplay >/dev/null 2>&1; then
        paplay "$SOUND" 2>/dev/null || sleep 1
    elif command -v pw-play >/dev/null 2>&1; then
        pw-play "$SOUND" 2>/dev/null || sleep 1
    else
        break
    fi
done
