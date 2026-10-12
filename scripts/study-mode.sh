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
        python3 "$PYTHON_SCRIPT" start --duration "$duration" --subject "$subject"
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
        python3 "$PYTHON_SCRIPT" prompt-and-start --duration "$duration" --subject "$subject"
        ;;
    *)
        echo "Usage: $0 {start [duration] [subject]|stop|status|history|verify [password]}"
        exit 1
        ;;
esac
