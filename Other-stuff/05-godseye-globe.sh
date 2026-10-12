#!/usr/bin/env bash
# ==============================================================================
# Step 5: [OPTIONAL] God's Eye View 3D Globe Installer (~350 MB Total)
# Clones & installs the 3D OSINT Satellite & Intelligence Globe
# Skip this if you don't use the God's Eye mode in the Left Sidebar!
# ==============================================================================
set -euo pipefail

TARGET_DIR="$HOME/Desktop/gods-eye-view"
REPO_URL="https://github.com/bilawalsidhu/gods-eye-view.git"

export PATH="$HOME/.local/bin:$PATH:/usr/local/bin:/usr/bin"

echo "=========================================================="
echo "  🌐 [5/5] God's Eye View 3D Globe Setup"
echo "  Target: $TARGET_DIR"
echo "=========================================================="
echo ""
echo "  ⚠️  NOTICE: This clones the 3D globe repo and installs"
echo "  Node.js dependencies (~350 MB). It is toggled in the Left Sidebar."
echo ""

read -r -p "  Do you want to install God's Eye View? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY])
        ;;
    *)
        echo "  [-] Skipped. God's Eye View will NOT be installed."
        exit 0
        ;;
esac

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    echo "[-] Error: Node.js and npm are required. Please install Node v24 LTS first!" >&2
    exit 1
fi

echo "[*] Node version: $(node -v), npm version: $(npm -v)"

if [ ! -d "$TARGET_DIR" ]; then
    echo "[*] Cloning repository..."
    mkdir -p "$(dirname "$TARGET_DIR")"
    git clone "$REPO_URL" "$TARGET_DIR"
else
    echo "[*] Directory already exists, updating dependencies..."
fi

cd "$TARGET_DIR"

echo "[*] Running npm ci (171 packages)..."
npm ci

echo "[*] Running setup doctor check..."
npm run doctor || true

echo "[*] Creating launcher start.sh..."
cat << 'EOF' > start.sh
#!/usr/bin/env bash
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:$PATH"
exec npm run dev
EOF
chmod +x start.sh

echo "=========================================================="
echo "  ✅ Step 5 Complete: God's Eye View ready on port 4173!"
echo "=========================================================="
