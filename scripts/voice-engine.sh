#!/usr/bin/env bash
set -euo pipefail

UNSLOTH_CUDA="$HOME/.unsloth/studio/unsloth_studio/lib/python3.13/site-packages/nvidia/cu13/lib"
UNSLOTH_CUDNN="$HOME/.unsloth/studio/unsloth_studio/lib/python3.13/site-packages/nvidia/cudnn/lib"

export PATH="$HOME/.local/bin:$PATH:/usr/local/bin:/usr/bin"
if [ -d "$UNSLOTH_CUDA" ] && [ -d "$UNSLOTH_CUDNN" ]; then
    export LD_LIBRARY_PATH="$UNSLOTH_CUDA:$UNSLOTH_CUDNN:$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
else
    export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
fi
export ESPEAK_DATA_PATH="$HOME/.local/share/espeak-ng-data"
export TESSDATA_PREFIX="$HOME/.local/share/tessdata"
export OMP_THREAD_LIMIT=2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec uv run --script "$SCRIPT_DIR/voice-engine.py" "$@"
