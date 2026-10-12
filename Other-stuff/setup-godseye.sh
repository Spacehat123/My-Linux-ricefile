#!/usr/bin/env bash
# ==============================================================================
# God's Eye View - Automated Setup & Verification Script
# ==============================================================================
set -euo pipefail

TARGET_DIR="$HOME/Desktop/gods-eye-view"
REPO_URL="https://github.com/bilawalsidhu/gods-eye-view.git"

export PATH="$HOME/.local/bin:$PATH:/usr/local/bin:/usr/bin"

echo "=========================================================="
echo "  🌐 Setting up God's Eye View in $TARGET_DIR"
echo "=========================================================="

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    echo "[-] Error: Node.js and npm are required. Please install Node v24 LTS." >&2
    exit 1
fi

echo "[*] Node: $(node -v), npm: $(npm -v)"

if [ ! -d "$TARGET_DIR" ]; then
    echo "[*] Cloning God's Eye View repository..."
    mkdir -p "$(dirname "$TARGET_DIR")"
    git clone "$REPO_URL" "$TARGET_DIR"
else
    echo "[*] Target directory $TARGET_DIR already exists."
fi

cd "$TARGET_DIR"

echo "[*] Installing dependencies with npm ci..."
npm ci

echo "[*] Running setup doctor check..."
npm run doctor || true

echo "[*] Creating launcher script start.sh..."
cat << 'EOF' > start.sh
#!/usr/bin/env bash
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:$PATH"
exec npm run dev
EOF
chmod +x start.sh

echo "=========================================================="
echo "  ✅ God's Eye View installed successfully!"
echo "  👉 Accessible at: http://localhost:4173"
echo "  👉 Toggled via Left Sidebar Control Center"
echo "=========================================================="
