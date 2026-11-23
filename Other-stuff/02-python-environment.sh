#!/usr/bin/env bash
# ==============================================================================
# Step 2: Python AI Runtime & Virtual Environment Setup
# ==============================================================================
set -euo pipefail

VENV_DIR="$HOME/.local/share/cool-shell/venv"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIREMENTS="$SCRIPT_DIR/../requirements.txt"

echo "=========================================================="
echo "  🐍 [2/5] Setting up Python AI Virtual Environment"
echo "  Target: $VENV_DIR"
echo "=========================================================="

mkdir -p "$HOME/.local/share/cool-shell"

# Check if virtual environment is missing, broken, or missing activate script
REBUILD_VENV=false
if [ ! -d "$VENV_DIR" ] || [ ! -f "$VENV_DIR/bin/activate" ] || [ ! -x "$VENV_DIR/bin/python" ]; then
    REBUILD_VENV=true
fi

if command -v uv >/dev/null 2>&1; then
    echo "[*] Using uv for fast package management..."
    if [ "$REBUILD_VENV" = true ]; then
        echo "[*] Creating or rebuilding virtual environment..."
        rm -rf "$VENV_DIR"
        uv venv "$VENV_DIR" --python 3.12 2>/dev/null || uv venv "$VENV_DIR"
    fi
    echo "[*] Installing Python packages with CUDA acceleration..."
    uv pip install --python "$VENV_DIR/bin/python" -r "$REQUIREMENTS"
    uv pip install --python "$VENV_DIR/bin/python" --upgrade "torch" "torchvision" --index-url https://download.pytorch.org/whl/cu124 || true
else
    echo "[*] Using standard python3 -m venv..."
    if [ "$REBUILD_VENV" = true ]; then
        echo "[*] Creating or rebuilding virtual environment..."
        rm -rf "$VENV_DIR"
        python3 -m venv "$VENV_DIR"
    fi
    "$VENV_DIR/bin/pip" install --upgrade pip
    "$VENV_DIR/bin/pip" install -r "$REQUIREMENTS"
fi

# Ensure font cache updated if required by system environment
if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f 2>/dev/null || true
fi

echo "=========================================================="
echo "  ✅ Step 2 Complete: Python virtual environment ready!"
echo "=========================================================="
