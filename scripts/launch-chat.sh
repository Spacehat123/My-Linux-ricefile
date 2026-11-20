#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=7860

COOL_CUDA="$HOME/.local/share/cool-shell/venv/lib/python3.12/site-packages/nvidia/cu13/lib"
COOL_CUDNN="$HOME/.local/share/cool-shell/venv/lib/python3.12/site-packages/nvidia/cudnn/lib"
UNSLOTH_CUDA="$HOME/.unsloth/studio/unsloth_studio/lib/python3.13/site-packages/nvidia/cu13/lib"
UNSLOTH_CUDNN="$HOME/.unsloth/studio/unsloth_studio/lib/python3.13/site-packages/nvidia/cudnn/lib"

if [ -x "$HOME/.local/share/cool-shell/venv/bin/python3" ]; then
    PYTHON_BIN="$HOME/.local/share/cool-shell/venv/bin/python3"
elif [ -x "$HOME/.unsloth/studio/unsloth_studio/bin/python3" ]; then
    PYTHON_BIN="$HOME/.unsloth/studio/unsloth_studio/bin/python3"
else
    PYTHON_BIN="python3"
fi

export PATH="$HOME/.local/bin:$PATH:/usr/local/bin:/usr/bin"
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export HF_DATASETS_OFFLINE=1
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"

if [ -d "$COOL_CUDA" ] && [ -d "$COOL_CUDNN" ]; then
    export LD_LIBRARY_PATH="$COOL_CUDA:$COOL_CUDNN:$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
elif [ -d "$UNSLOTH_CUDA" ] && [ -d "$UNSLOTH_CUDNN" ]; then
    export LD_LIBRARY_PATH="$UNSLOTH_CUDA:$UNSLOTH_CUDNN:$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
else
    export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
fi

# Check if Chat UI is already listening on PORT 7860
if ss -tuln | grep -q ":${PORT} "; then
    echo "[*] AI Studio Chat already running on port ${PORT}."
    xdg-open "http://127.0.0.1:${PORT}" >/dev/null 2>&1 || true
    exit 0
fi

# Launch chat-ui.py detached using python Popen start_new_session
echo "[*] Starting AI Studio Chat UI on http://127.0.0.1:${PORT}..."
"$PYTHON_BIN" -c "
import subprocess, sys, os
log = open('/tmp/cool-shell-chat-ui.log', 'a')
subprocess.Popen(
    [sys.executable, '$SCRIPT_DIR/chat-ui.py'],
    stdout=log,
    stderr=log,
    start_new_session=True
)
"

# Wait up to 5 seconds for web server to start
for _ in {1..25}; do
    if ss -tuln | grep -q ":${PORT} "; then
        break
    fi
    sleep 0.2
done

xdg-open "http://127.0.0.1:${PORT}" >/dev/null 2>&1 || true
echo "[+] Opened AI Studio Chat: http://127.0.0.1:${PORT}"
