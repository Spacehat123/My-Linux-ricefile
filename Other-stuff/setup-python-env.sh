#!/usr/bin/env bash
# ==============================================================================
# Cool-Shell - Standalone Python AI & CUDA Environment Setup
# ==============================================================================
set -euo pipefail

VENV_DIR="$HOME/.local/share/cool-shell/venv"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIREMENTS="$SCRIPT_DIR/../requirements.txt"

echo "=========================================================="
echo "  🐍 Setting up Cool-Shell Python Environment"
echo "=========================================================="

# Check if uv is installed, otherwise fallback to python3 -m venv
if command -v uv >/dev/null 2>&1; then
    echo "[*] Using fast uv installer..."
    if [ ! -d "$VENV_DIR" ]; then
        echo "[*] Creating virtual environment at $VENV_DIR..."
        uv venv "$VENV_DIR" --python 3.12 2>/dev/null || uv venv "$VENV_DIR"
    fi
    echo "[*] Installing Python dependencies with CUDA support..."
    uv pip --python "$VENV_DIR/bin/python" install -r "$REQUIREMENTS"
    uv pip --python "$VENV_DIR/bin/python" install --upgrade "torch" "torchvision" --index-url https://download.pytorch.org/whl/cu124 || true
else
    echo "[*] Using python3 -m venv..."
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR"
    fi
    "$VENV_DIR/bin/pip" install --upgrade pip
    "$VENV_DIR/bin/pip" install -r "$REQUIREMENTS"
fi

echo "=========================================================="
echo "  ✅ Python AI Environment ready at: $VENV_DIR"
echo "=========================================================="
