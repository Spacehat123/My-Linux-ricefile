#!/usr/bin/env bash
# ==============================================================================
# Step 1: System Packages Installer (Arch Linux / Pacman / AUR)
# ==============================================================================
set -euo pipefail

echo "=========================================================="
echo "  📦 [1/5] Installing Cool-Shell System Packages"
echo "=========================================================="

PACMAN_PKGS=(
    # Compositor & Wayland infrastructure
    hyprland
    hyprlock
    hyprsunset

    # Qt6 Runtime & QML Modules
    qt6-base
    qt6-declarative
    qt6-5compat
    qt6-multimedia
    qt6-multimedia-ffmpeg
    qt6-wayland
    qt6-shadertools
    qt6-svg

    # Audio & MPRIS Subsystem
    pipewire
    wireplumber
    pipewire-pulse
    pipewire-alsa
    playerctl
    cava
    mpv

    # Screen Capture, OCR & Multimodal Vision
    grim
    slurp
    wf-recorder
    tesseract
    tesseract-data-eng
    leptonica
    zbar
    imagemagick
    swappy
    ffmpeg

    # Input, Clipboard & Hardware
    wl-clipboard
    cliphist
    brightnessctl
    awww
    upower
    networkmanager
    bluez
    bluez-utils
    lm_sensors

    # Voice Synthesis Runtime
    espeak-ng

    # Mobile Bridging & Mirroring
    android-tools
    scrcpy

    # System Utilities, IPC & Dialogue
    zenity
    jq
    curl
    socat
    fd
    psmisc
    procps-ng
    coreutils
    findutils
    git

    # Security & Networking
    ufw
    bitwarden

    # Runtimes & Interpreters
    python
    uv
    nodejs
    npm

    # Typography & Fonts
    ttf-jetbrains-mono-nerd
    inter-font
    noto-fonts
    noto-fonts-emoji
)

AUR_PKGS=(
    quickshell-git
    sptlrx-bin
    matugen-bin
    ttf-geist
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
