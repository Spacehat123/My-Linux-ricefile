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

if command -v uv >/dev/null 2>&1; then
    echo "[*] Using uv for fast package management..."
    if [ ! -d "$VENV_DIR" ]; then
        echo "[*] Creating virtual environment..."
        uv venv "$VENV_DIR" --python 3.12 2>/dev/null || uv venv "$VENV_DIR"
    fi
    echo "[*] Installing Python packages with CUDA acceleration..."
    uv pip --python "$VENV_DIR/bin/python" install -r "$REQUIREMENTS"
    uv pip --python "$VENV_DIR/bin/python" install --upgrade "torch" "torchvision" --index-url https://download.pytorch.org/whl/cu124 || true
else
    echo "[*] Using standard python3 -m venv..."
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR"
    fi
    "$VENV_DIR/bin/pip" install --upgrade pip
    "$VENV_DIR/bin/pip" install -r "$REQUIREMENTS"
fi

echo "=========================================================="
echo "  ✅ Step 2 Complete: Python virtual environment ready!"
echo "=========================================================="
