#!/usr/bin/env bash
set -euo pipefail

UNSLOTH_CUDA="$HOME/.unsloth/studio/unsloth_studio/lib/python3.13/site-packages/nvidia/cu13/lib"
UNSLOTH_CUDNN="$HOME/.unsloth/studio/unsloth_studio/lib/python3.13/site-packages/nvidia/cudnn/lib"

if [ -x "$HOME/.unsloth/studio/unsloth_studio/bin/python3" ]; then
    PYTHON_BIN="$HOME/.unsloth/studio/unsloth_studio/bin/python3"
elif [ -x "$HOME/.local/share/cool-shell/venv/bin/python3" ]; then
    PYTHON_BIN="$HOME/.local/share/cool-shell/venv/bin/python3"
else
    PYTHON_BIN="python3"
fi

export PATH="$HOME/.local/bin:$PATH:/usr/local/bin:/usr/bin"
if [ -d "$UNSLOTH_CUDA" ] && [ -d "$UNSLOTH_CUDNN" ]; then
    export LD_LIBRARY_PATH="$UNSLOTH_CUDA:$UNSLOTH_CUDNN:$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
else
    export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$PYTHON_BIN" "$SCRIPT_DIR/image-engine.py" "$@"
