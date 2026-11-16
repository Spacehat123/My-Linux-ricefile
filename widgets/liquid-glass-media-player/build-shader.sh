#!/usr/bin/env bash
# Compiles liquid_glass.frag into Qt 6 multi-backend .qsb bytecode
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

QSB_BIN="/usr/lib/qt6/bin/qsb"
if ! command -v "$QSB_BIN" >/dev/null 2>&1; then
    QSB_BIN="$(which qsb 2>/dev/null || true)"
fi

if [[ -z "$QSB_BIN" || ! -x "$QSB_BIN" ]]; then
    echo "ERROR: qsb compiler not found in /usr/lib/qt6/bin/qsb or PATH" >&2
    exit 1
fi

echo "Compiling liquid_glass.frag with $QSB_BIN..."
"$QSB_BIN" --qt6 -o liquid_glass.frag.qsb liquid_glass.frag
echo "Success: liquid_glass.frag.qsb built ($(du -h liquid_glass.frag.qsb | cut -f1))."
