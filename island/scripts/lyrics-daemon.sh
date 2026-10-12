#!/usr/bin/env bash
set -euo pipefail

# Ensure ~/.local/bin is in PATH for sptlrx
export PATH="$HOME/.local/bin:$PATH:/usr/local/bin:/usr/bin"

if ! command -v sptlrx >/dev/null 2>&1; then
    exit 1
fi

exec sptlrx pipe 2>/dev/null
