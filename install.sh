#!/usr/bin/env bash
# ==============================================================================
# Cool-Shell (Pranc Rice) — Master Modular Setup & Component Installer
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLERS_DIR="$SCRIPT_DIR/Other-stuff"

bold=$(tput bold 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)
cyan=$(tput setaf 6 2>/dev/null || true)
green=$(tput setaf 2 2>/dev/null || true)
yellow=$(tput setaf 3 2>/dev/null || true)

clear 2>/dev/null || true
echo "${cyan}${bold}==================================================================${reset}"
echo "${cyan}${bold}       COOL-SHELL / PRANC RICE — MODULAR COMPONENT INSTALLER      ${reset}"
echo "${cyan}${bold}==================================================================${reset}"
echo ""
echo "Select which components you want to install. You can run them"
echo "individually so you don't have to download massive files you don't need."
echo ""
echo "  ${green}[1]${reset} ${bold}System Packages${reset}       (Hyprland, Quickshell, UFW, Bitwarden...)"
echo "  ${green}[2]${reset} ${bold}Python AI Environment${reset} (CUDA, PyTorch, Diffusers, Kokoro...)"
echo "  ${green}[3]${reset} ${bold}Lightweight Models${reset}    (Kokoro Voice + Tesseract OCR ~139 MB)"
echo "  ${yellow}[4]${reset} ${bold}Heavy AI Models${reset}       (Realistic Vision v5.1 + LCM-LoRA ~2.2 GB) ${yellow}[OPTIONAL]${reset}"
echo "  ${yellow}[5]${reset} ${bold}God's Eye View${reset}        (3D OSINT Satellite Globe ~350 MB)        ${yellow}[OPTIONAL]${reset}"
echo ""
echo "  ----------------------------------------------------------------"
echo "  ${cyan}[L]${reset} ${bold}Light Setup${reset}           (Steps 1, 2, and 3 only — ${green}Zero Heavy Downloads${reset})"
echo "  ${cyan}[A]${reset} ${bold}Complete All-In-One${reset}   (Steps 1 through 5)"
echo "  ${bold}[Q]${reset} Quit"
echo ""

read -r -p "Enter your choice [1-5, L, A, Q]: " choice

case "$choice" in
    1)
        "$INSTALLERS_DIR/01-system-packages.sh"
        ;;
    2)
        "$INSTALLERS_DIR/02-python-environment.sh"
        ;;
    3)
        "$INSTALLERS_DIR/03-light-models-tts-ocr.sh"
        ;;
    4)
        "$INSTALLERS_DIR/04-heavy-ai-image-models.sh"
        ;;
    5)
        "$INSTALLERS_DIR/05-godseye-globe.sh"
        ;;
    [lL])
        echo ""
        echo "${green}[*] Running Light Setup (Steps 1, 2, 3)...${reset}"
        "$INSTALLERS_DIR/01-system-packages.sh"
        "$INSTALLERS_DIR/02-python-environment.sh"
        "$INSTALLERS_DIR/03-light-models-tts-ocr.sh"
        echo ""
        echo "${green}${bold}✅ Light Setup Complete! No heavy model downloads were performed.${reset}"
        ;;
    [aA])
        echo ""
        echo "${green}[*] Running Complete Setup (All Steps)...${reset}"
        "$INSTALLERS_DIR/01-system-packages.sh"
        "$INSTALLERS_DIR/02-python-environment.sh"
        "$INSTALLERS_DIR/03-light-models-tts-ocr.sh"
        "$INSTALLERS_DIR/04-heavy-ai-image-models.sh"
        "$INSTALLERS_DIR/05-godseye-globe.sh"
        echo ""
        echo "${green}${bold}✅ Full Setup Complete! All components and models are ready.${reset}"
        ;;
    [qQ]|*)
        echo "Exiting."
        exit 0
        ;;
esac
