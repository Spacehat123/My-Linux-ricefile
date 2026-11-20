#!/usr/bin/env bash
# Fast Voice Note recorder helper for cool-shell
DIR="$HOME/Music/VoiceNotes"
mkdir -p "$DIR"

PID=$(pgrep -f "pw-record.*VoiceNotes" || true)

if [ -n "$PID" ]; then
    kill -INT $PID 2>/dev/null || true
    quickshell -c cool-shell ipc call island showTransient "󰍬 Voice Note Saved to ~/Music/VoiceNotes" 3000 2>/dev/null || true
    echo "STOPPED"
else
    FILE="$DIR/Note_$(date +%Y%m%d_%H%M%S).wav"
    nohup pw-record "$FILE" </dev/null >/dev/null 2>&1 &
    quickshell -c cool-shell ipc call island showTransient "󰍬 Recording Voice Note... (Tap again to save)" 3500 2>/dev/null || true
    echo "RECORDING"
fi
