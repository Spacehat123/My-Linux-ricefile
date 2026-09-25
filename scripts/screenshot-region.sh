#!/usr/bin/env bash
# Region Screenshot Script for pranc-shell
# - Left click & drag: select resizable region on any part of the screen
# - Left click release: take screenshot of that region
# - Right click or Escape: cancel selection
# - Copies screenshot to clipboard
# - Saves screenshot to $(xdg-user-dir PICTURES)/Screenshots/
# - Sends desktop notification with image preview

# Prevent concurrent instances of slurp
if pidof slurp >/dev/null 2>&1; then
    exit 0
fi

# Run slurp for interactive region selection:
# -d: display selection dimensions (e.g. 800x600)
# -c: border color (#00bfff cyan matching pranc-shell)
# -s: selection background (#00bfff25 translucent cyan)
# -b: overlay backdrop (#00000060 translucent dark)
# -w: border width 2px
GEOM=$(slurp -d -c '#00bfff' -b '#00000060' -s '#00bfff25' -w 2 2>/dev/null)

# Exit cleanly if cancelled (right click or Escape exits with code 1 or empty GEOM)
if [ $? -ne 0 ] || [ -z "$GEOM" ]; then
    exit 0
fi

# Determine screenshots folder
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
SCREENSHOT_DIR="$PICTURES_DIR/Screenshots"
mkdir -p "$SCREENSHOT_DIR"

TIMESTAMP="$(date '+%Y-%m-%d_%H.%M.%S')"
FILENAME="Screenshot_${TIMESTAMP}.png"
FILEPATH="${SCREENSHOT_DIR}/${FILENAME}"

# Capture region using grim
if grim -g "$GEOM" "$FILEPATH" 2>/dev/null && [ -f "$FILEPATH" ]; then
    # Copy to clipboard
    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy < "$FILEPATH"
    fi

    # Send desktop notification
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Screenshot Captured" "Saved to Screenshots/${FILENAME}\nCopied to clipboard" -i "$FILEPATH" -a "pranc-shell"
    fi
fi
