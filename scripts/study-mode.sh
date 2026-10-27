#!/usr/bin/env bash
# ==============================================================================
# Cool-Shell Study Mode Wrapper Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/study-mode.py"

case "${1:-status}" in
    start)
        duration="${2:-1800}"
        subject="${3:-CA / ICAI Study}"
        is_custom="${4:-false}"
        extra=""
        if [ "$is_custom" = "true" ] || [ "$is_custom" = "1" ] || [ "$is_custom" = "custom" ]; then
            extra="--custom"
        fi
        python3 "$PYTHON_SCRIPT" start --duration "$duration" --subject "$subject" $extra
        ;;
    stop)
        python3 "$PYTHON_SCRIPT" stop
        ;;
    status)
        python3 "$PYTHON_SCRIPT" status
        ;;
    history)
        python3 "$PYTHON_SCRIPT" history
        ;;
    verify)
        pass="${2:-}"
        python3 "$PYTHON_SCRIPT" verify-password --password "$pass"
        ;;
    prompt|prompt-and-start)
        duration="${2:-1800}"
        subject="${3:-CA / ICAI Study}"
        is_custom="${4:-false}"
        extra=""
        if [ "$is_custom" = "true" ] || [ "$is_custom" = "1" ] || [ "$is_custom" = "custom" ]; then
            extra="--custom"
        fi
        python3 "$PYTHON_SCRIPT" prompt-and-start --duration "$duration" --subject "$subject" $extra
        ;;
    *)
        echo "Usage: $0 {start [duration] [subject]|stop|status|history|verify [password]}"
        exit 1
        ;;
esac
