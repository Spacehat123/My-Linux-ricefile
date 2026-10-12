#!/usr/bin/env bash
# ==============================================================================
# Step 1: System Packages Installer (Arch Linux / Pacman / AUR)
# ==============================================================================
set -euo pipefail

echo "=========================================================="
echo "  📦 [1/5] Installing Cool-Shell System Packages"
echo "=========================================================="

PACMAN_PKGS=(
    hyprland
    hyprlock
    pipewire
    wireplumber
    pipewire-pulse
    pipewire-alsa
    playerctl
    grim
    slurp
    wf-recorder
    tesseract
    tesseract-data-eng
    leptonica
    zbar
    imagemagick
    swappy
    wl-clipboard
    cliphist
    brightnessctl
    swww
    espeak-ng
    python
    uv
    nodejs
    npm
    jq
    curl
    socat
    psmisc
    procps-ng
    coreutils
    findutils
    fd
    ufw
    bitwarden
)

AUR_PKGS=(
    quickshell-git
    hyprsunset
    sptlrx-bin
    matugen-bin
)

echo "[*] Checking and installing official Pacman packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

# Detect AUR helper (paru or yay)
AUR_HELPER=""
if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
fi

if [ -n "$AUR_HELPER" ]; then
    echo "[*] Installing AUR packages using $AUR_HELPER..."
    "$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}"
else
    echo "[!] Warning: No AUR helper (paru or yay) found."
    echo "    Please manually install: ${AUR_PKGS[*]}"
fi

echo "=========================================================="
echo "  ✅ Step 1 Complete: System packages installed!"
echo "=========================================================="
