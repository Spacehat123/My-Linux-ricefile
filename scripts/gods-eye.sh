#!/usr/bin/env bash
# ==============================================================================
# God's Eye View - Background Server Controller & Browser Integration
# ==============================================================================
set -euo pipefail

PROJECT_DIR="${GODS_EYE_DIR:-$HOME/Desktop/gods-eye-view}"
PID_FILE="/tmp/gods-eye-view.pid"
LOG_FILE="/tmp/gods-eye-view.log"
PORT=4173
URL="http://localhost:${PORT}"

export PATH="$HOME/.local/bin:$PATH"

is_running() {
    curl -s -f -m 0.6 "${URL}/" >/dev/null 2>&1
}

open_browser() {
    # Open URL in the default browser (Brave).
    # If Brave is already open, xdg-open creates a new tab in the active session.
    # If no session is active, it launches a new browser session.
    xdg-open "$URL" >/dev/null 2>&1 &
    
    # Give the window manager a moment to route the IPC, then focus Brave under Hyprland
    sleep 0.3
    hyprctl dispatch focuswindow "class:^brave-browser$" >/dev/null 2>&1 || \
    hyprctl dispatch focuswindow "class:^brave$" >/dev/null 2>&1 || true
}

start_server() {
    if is_running; then
        echo "God's Eye View is already running on ${URL}."
        open_browser
        return 0
    fi

    if [ ! -d "$PROJECT_DIR" ]; then
        echo "Error: Directory $PROJECT_DIR not found" >&2
        exit 1
    fi

    echo "Starting God's Eye View dev server..."
    cd "$PROJECT_DIR"

    # Start detached in a new process session
    setsid npm run dev > "$LOG_FILE" 2>&1 &
    local s_pid=$!
    echo "$s_pid" > "$PID_FILE"

    # Wait for Vite dev server to respond
    local ready=false
    for _ in $(seq 1 40); do
        if is_running; then
            ready=true
            break
        fi
        sleep 0.15
    done

    if [ "$ready" = true ]; then
        echo "Server is ready on ${URL}."
        open_browser
    else
        echo "Server failed to start or didn't respond within 6s. Check ${LOG_FILE}" >&2
        return 1
    fi
}

stop_server() {
    echo "Stopping God's Eye View..."
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
            local pgid
            pgid=$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ' || true)
            if [ -n "$pgid" ]; then
                kill -TERM "-$pgid" 2>/dev/null || true
            fi
            kill -TERM "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi

    # Terminate any remaining vite instances in gods-eye-view
    pkill -f "vite.*gods-eye-view" 2>/dev/null || true
    
    # If port 4173 is still occupied by node, force kill it
    if is_running; then
        fuser -k "${PORT}/tcp" 2>/dev/null || true
    fi
    echo "God's Eye View stopped."
}

status_server() {
    if is_running; then
        echo '{"running": true}'
    else
        echo '{"running": false}'
    fi
}

case "${1:-status}" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    toggle)
        if is_running; then
            stop_server
        else
            start_server
        fi
        ;;
    status)
        status_server
        ;;
    open)
        open_browser
        ;;
    *)
        echo "Usage: $0 {start|stop|toggle|status|open}"
        exit 1
        ;;
esac
