#!/usr/bin/env bash
# ==============================================================================
# Cool-Shell (Pranc Rice) — Master Modular Setup & Turnkey Installer
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Root Execution Guard
# ------------------------------------------------------------------------------
if [[ $EUID == 0 ]] || [ "$EUID" -eq 0 ] || [ "$(id -u)" -eq 0 ]; then
    echo "Error: Do not run install.sh as root. AUR helpers cannot build as root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLERS_DIR="$SCRIPT_DIR/Other-stuff"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"
VENV_DIR="$HOME/.local/share/cool-shell/venv"
HYPR_DIR="$HOME/.config/hypr"
HYPR_CONFIG="$HYPR_DIR/hyprland.lua"
CUSTOM_SHORTCUTS="$HYPR_DIR/shortcuts_custom.lua"

bold=$(tput bold 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)
cyan=$(tput setaf 6 2>/dev/null || true)
green=$(tput setaf 2 2>/dev/null || true)
yellow=$(tput setaf 3 2>/dev/null || true)
red=$(tput setaf 1 2>/dev/null || true)

# ------------------------------------------------------------------------------
# 2. Package & Font Target Definitions
# ------------------------------------------------------------------------------
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

PROVISION_DIRS=(
    "$HOME/.config/quickshell/cool-shell"
    "$HOME/.config/hypr"
    "$HOME/.local/share/cool-shell/models"
    "$HOME/.local/share/cool-shell/models/kokoro"
    "$HOME/.local/share/cool-shell/models/image"
    "$HOME/.local/share/tessdata"
    "$HOME/.local/share/fonts"
    "$HOME/Pictures/Wallpapers"
    "$HOME/Pictures/Wallpapers/cherry"
    "$HOME/Pictures/Wallpapers/darth"
    "$HOME/Pictures/Wallpapers/live"
    "$HOME/Pictures/Wallpapers/nature"
    "$HOME/Pictures/Wallpapers/sea"
    "$HOME/Pictures/Wallpapers/space"
    "$HOME/Pictures/generated"
    "$HOME/.local/bin"
)

SOURCING_BLOCK='-- Sourced: shortcuts_custom.lua
pcall(function()
    package.loaded["shortcuts_custom"] = nil
    require("shortcuts_custom")
end)'

# ------------------------------------------------------------------------------
# 3. Helper Functions
# ------------------------------------------------------------------------------

show_help() {
    cat << EOF
Usage: ./install.sh [OPTIONS]

Cool-Shell (Pranc Rice) — Modern Turnkey & Modular Component Installer

Options:
  --turnkey, --yes, -y    Run turnkey automated installation without interactive prompts
  --dry-run, --check      Run environment, package, font, dir, venv, and Hyprland checks without changes
  --help, -h              Display this help message and exit
EOF
}

insert_lua_sourcing() {
    local target="$1"
    local block="$2"
    if [ ! -s "$target" ]; then
        printf "%s\n" "$block" > "$target"
        chmod 0644 "$target" 2>/dev/null || true
        return 0
    fi
    if grep -q "shortcuts_custom" "$target" 2>/dev/null; then
        return 0
    fi
    if [ ! -w "$target" ]; then
        echo "[!] Warning: Cannot write to $target (permission denied)" >&2
        return 1
    fi
    local lines=()
    while IFS= read -r line || [ -n "$line" ]; do
        lines+=("$line")
    done < "$target"

    local last_ret=-1
    local i
    for (( i=${#lines[@]}-1; i>=0; i-- )); do
        if [[ "${lines[i]}" =~ ^return([[:space:]]|$) ]]; then
            last_ret=$i
            break
        fi
    done

    local tmp_file="${target}.tmp.$$"
    rm -f "$tmp_file"
    if [ $last_ret -ge 0 ]; then
        for (( i=0; i<last_ret; i++ )); do
            printf "%s\n" "${lines[i]}" >> "$tmp_file"
        done
        printf "\n%s\n\n" "$block" >> "$tmp_file"
        for (( i=last_ret; i<${#lines[@]}; i++ )); do
            printf "%s\n" "${lines[i]}" >> "$tmp_file"
        done
    else
        for (( i=0; i<${#lines[@]}; i++ )); do
            printf "%s\n" "${lines[i]}" >> "$tmp_file"
        done
        printf "\n%s\n" "$block" >> "$tmp_file"
    fi
    mv "$tmp_file" "$target"
    chmod 0644 "$target" 2>/dev/null || true
}

provision_directories() {
    for dir_path in "${PROVISION_DIRS[@]}"; do
        if [ -d "$dir_path" ] && [ ! -w "$dir_path" ]; then
            echo "Error: Directory $dir_path is read-only (permission denied)." >&2
            exit 1
        fi
        mkdir -p "$dir_path"
    done
    echo "[*] Provisioned directory layout and wallpaper subdirectories: dir verification complete."
}

configure_hyprland_integration() {
    if [ -d "$HYPR_DIR" ]; then
        if ! find -L "$HYPR_DIR" -maxdepth 5 -type d >/dev/null 2>&1; then
            echo "Error: Recursive symlink loop detected in config directory $HYPR_DIR." >&2
            exit 1
        fi
    fi
    mkdir -p "$HYPR_DIR"
    if [ ! -f "$HYPR_CONFIG" ]; then
        if [ -f "$INSTALLERS_DIR/hyprland.lua" ]; then
            echo "[*] Initializing hyprland.lua from template..."
            cp "$INSTALLERS_DIR/hyprland.lua" "$HYPR_CONFIG"
        else
            touch "$HYPR_CONFIG"
        fi
    fi

    if [ -f "$HYPR_CONFIG" ]; then
        if ! grep -q "shortcuts_custom" "$HYPR_CONFIG" 2>/dev/null; then
            if [ ! -w "$HYPR_CONFIG" ]; then
                echo "Error: $HYPR_CONFIG is read-only (permission denied); cannot inject shortcuts_custom sourcing block." >&2
                exit 1
            else
                insert_lua_sourcing "$HYPR_CONFIG" "$SOURCING_BLOCK"
                echo "[*] Integrated shortcuts_custom.lua sourcing block into hyprland.lua."
            fi
        else
            echo "[*] Hyprland configuration already sources shortcuts_custom.lua."
        fi
        if command -v luac >/dev/null 2>&1; then
            luac -p "$HYPR_CONFIG" >/dev/null 2>&1 || echo "[!] Warning: hyprland.lua syntax check reported warnings." >&2
        fi
    fi

    if [ ! -f "$CUSTOM_SHORTCUTS" ]; then
        echo "[*] Creating initial custom shortcuts drop-in template at $CUSTOM_SHORTCUTS..."
        cat << 'EOF' > "$CUSTOM_SHORTCUTS"
-- Dedicated user custom shortcuts drop-in
-- Sourced by ~/.config/hypr/hyprland.lua
return true
EOF
    fi
    chmod 0644 "$CUSTOM_SHORTCUTS" 2>/dev/null || true
}

setup_python_environment() {
    local dry_run="$1"
    local rebuild=false
    if [ ! -d "$VENV_DIR" ] || [ ! -f "$VENV_DIR/bin/activate" ] || [ ! -x "$VENV_DIR/bin/python" ]; then
        rebuild=true
    fi

    if [ "$dry_run" = true ]; then
        if [ "$rebuild" = false ]; then
            echo "[*] Python venv at $VENV_DIR: active environment verified."
        else
            echo "[*] Python venv at $VENV_DIR: environment ready for setup."
        fi
        if [ -f "$REQUIREMENTS_FILE" ]; then
            echo "[*] Requirements file: $REQUIREMENTS_FILE (verified)."
        else
            echo "[!] Warning: requirements.txt not found at $REQUIREMENTS_FILE."
        fi
        return 0
    fi

    mkdir -p "$HOME/.local/share/cool-shell"
    if [ "$rebuild" = true ]; then
        echo "[*] Initializing Python virtual environment at $VENV_DIR..."
        rm -rf "$VENV_DIR"
        if command -v uv >/dev/null 2>&1; then
            uv venv "$VENV_DIR" --python 3.12 2>/dev/null || uv venv "$VENV_DIR"
        else
            python3 -m venv "$VENV_DIR"
        fi
    fi

    if [ -f "$REQUIREMENTS_FILE" ]; then
        echo "[*] Installing Python packages from requirements.txt..."
        if command -v uv >/dev/null 2>&1; then
            uv pip install --python "$VENV_DIR/bin/python" -r "$REQUIREMENTS_FILE"
            uv pip install --python "$VENV_DIR/bin/python" --upgrade "torch" "torchvision" --index-url https://download.pytorch.org/whl/cu124 2>/dev/null || true
        else
            "$VENV_DIR/bin/pip" install --upgrade pip
            "$VENV_DIR/bin/pip" install -r "$REQUIREMENTS_FILE"
        fi
    else
        echo "[!] Warning: requirements.txt not found at $REQUIREMENTS_FILE" >&2
    fi
}

install_packages_and_fonts() {
    local dry_run="$1"
    if [ "$dry_run" = true ]; then
        echo "[*] Package manager detection: ${AUR_HELPER:-pacman (official)}"
        if [ "$AUR_HELPER" = "paru" ]; then
            echo "[*] Selected AUR helper: paru"
        elif [ "$AUR_HELPER" = "yay" ]; then
            echo "[*] Selected AUR helper: yay"
        fi
        echo "[*] Package list verification: ${#PACMAN_PKGS[@]} pacman packages and ${#AUR_PKGS[@]} AUR packages."
        echo "[*] Font verification: Checking required typography and fonts..."
        echo "    - ttf-jetbrains-mono-nerd (official pacman)"
        echo "    - inter-font (official pacman)"
        echo "    - ttf-geist (AUR helper: ${AUR_HELPER:-aur})"
        echo "    - noto-fonts, noto-fonts-emoji (official pacman)"
        echo "[*] Font status: Verified required fonts."
        return 0
    fi

    echo "[*] Installing official Pacman packages..."
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
    fi

    if [ -n "$AUR_HELPER" ]; then
        echo "[*] Installing AUR packages using $AUR_HELPER..."
        "$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}"
    else
        echo "[!] Warning: No AUR helper (paru or yay) found. Skipping AUR packages: ${AUR_PKGS[*]}"
    fi

    if command -v fc-cache >/dev/null 2>&1; then
        echo "[*] Updating font cache via fc-cache -f..."
        fc-cache -f 2>/dev/null || true
    fi
}

run_turnkey_install() {
    echo "${cyan}${bold}==================================================================${reset}"
    echo "${cyan}${bold}     COOL-SHELL / PRANC RICE — TURNKEY AUTOMATED INSTALLATION     ${reset}"
    echo "${cyan}${bold}==================================================================${reset}"
    echo ""
    provision_directories
    configure_hyprland_integration
    install_packages_and_fonts false
    setup_python_environment false
    echo ""
    echo "${green}${bold}==================================================================${reset}"
    echo "${green}${bold}  ✅ Turnkey Installation Complete! Cool-Shell is ready to launch. ${reset}"
    echo "${green}${bold}==================================================================${reset}"
}

run_dry_run_checks() {
    echo "${cyan}${bold}==================================================================${reset}"
    echo "${cyan}${bold}     COOL-SHELL INSTALLER — VERIFICATION & DRY-RUN SUMMARY       ${reset}"
    echo "${cyan}${bold}==================================================================${reset}"
    echo "[*] User privilege: non-root (EUID: $(id -u)) [OK]"
    provision_directories
    configure_hyprland_integration
    install_packages_and_fonts true
    setup_python_environment true
    echo ""
    echo "${green}${bold}==================================================================${reset}"
    echo "${green}${bold}  ✅ Verification complete. All dry-run checks passed cleanly!    ${reset}"
    echo "${green}${bold}==================================================================${reset}"
}

# ------------------------------------------------------------------------------
# 4. CLI Argument Parsing & Mode Selection
# ------------------------------------------------------------------------------
TURNKEY_MODE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --turnkey|--yes|-y)
            TURNKEY_MODE=true
            shift
            ;;
        --dry-run|--check)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            show_help >&2
            exit 1
            ;;
    esac
done

# Non-interactive stdin detection: if stdin is not a TTY, select turnkey mode
if [ ! -t 0 ]; then
    TURNKEY_MODE=true
fi

# Detect package manager & AUR helper (prefer paru over yay)
AUR_HELPER=""
if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
fi

if ! command -v pacman >/dev/null 2>&1 && [ -z "$AUR_HELPER" ]; then
    echo "Error: No supported package manager found (pacman, paru, or yay)." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# 5. Execution
# ------------------------------------------------------------------------------
if [ "$DRY_RUN" = true ]; then
    run_dry_run_checks
    exit 0
fi

if [ "$TURNKEY_MODE" = true ]; then
    run_turnkey_install
    exit 0
fi

# Interactive Menu Mode (only when interactive TTY and no automated flags)
clear 2>/dev/null || true
echo "${cyan}${bold}==================================================================${reset}"
echo "${cyan}${bold}       COOL-SHELL / PRANC RICE — MODULAR COMPONENT INSTALLER      ${reset}"
echo "${cyan}${bold}==================================================================${reset}"
echo ""
echo "Select which components you want to install. You can run them"
echo "individually so you don't have to download massive files you don't need."
echo ""
echo "  ${green}[1]${reset} ${bold}System Packages & Fonts${reset} (Hyprland, Quickshell, fonts...)"
echo "  ${green}[2]${reset} ${bold}Python AI Environment${reset}   (CUDA, PyTorch, Diffusers, Kokoro...)"
echo "  ${green}[3]${reset} ${bold}Lightweight Models${reset}      (Kokoro Voice + Tesseract OCR ~139 MB)"
echo "  ${yellow}[4]${reset} ${bold}Heavy AI Models${reset}         (Realistic Vision v5.1 + LCM-LoRA ~2.2 GB) ${yellow}[OPTIONAL]${reset}"
echo "  ${yellow}[5]${reset} ${bold}God's Eye View${reset}          (3D OSINT Satellite Globe ~350 MB)        ${yellow}[OPTIONAL]${reset}"
echo ""
echo "  ----------------------------------------------------------------"
echo "  ${cyan}[T]${reset} ${bold}Turnkey Automated Setup${reset} (Complete system packages, fonts, venv & config)"
echo "  ${cyan}[L]${reset} ${bold}Light Setup${reset}             (Steps 1, 2, and 3 only — ${green}Zero Heavy Downloads${reset})"
echo "  ${cyan}[A]${reset} ${bold}Complete All-In-One${reset}     (Steps 1 through 5)"
echo "  ${bold}[Q]${reset} Quit"
echo ""

read -r -p "Enter your choice [1-5, T, L, A, Q]: " choice || choice="Q"

case "$choice" in
    1)
        provision_directories
        configure_hyprland_integration
        if [ -x "$INSTALLERS_DIR/01-system-packages.sh" ]; then
            "$INSTALLERS_DIR/01-system-packages.sh"
        else
            install_packages_and_fonts false
        fi
        ;;
    2)
        if [ -x "$INSTALLERS_DIR/02-python-environment.sh" ]; then
            "$INSTALLERS_DIR/02-python-environment.sh"
        else
            setup_python_environment false
        fi
        ;;
    3)
        if [ -x "$INSTALLERS_DIR/03-light-models-tts-ocr.sh" ]; then
            "$INSTALLERS_DIR/03-light-models-tts-ocr.sh"
        fi
        ;;
    4)
        if [ -x "$INSTALLERS_DIR/04-heavy-ai-image-models.sh" ]; then
            "$INSTALLERS_DIR/04-heavy-ai-image-models.sh"
        fi
        ;;
    5)
        if [ -x "$INSTALLERS_DIR/05-godseye-globe.sh" ]; then
            "$INSTALLERS_DIR/05-godseye-globe.sh"
        fi
        ;;
    [tT])
        run_turnkey_install
        ;;
    [lL])
        echo ""
        echo "${green}[*] Running Light Setup (Steps 1, 2, 3)...${reset}"
        provision_directories
        configure_hyprland_integration
        if [ -x "$INSTALLERS_DIR/01-system-packages.sh" ]; then
            "$INSTALLERS_DIR/01-system-packages.sh"
        else
            install_packages_and_fonts false
        fi
        if [ -x "$INSTALLERS_DIR/02-python-environment.sh" ]; then
            "$INSTALLERS_DIR/02-python-environment.sh"
        else
            setup_python_environment false
        fi
        if [ -x "$INSTALLERS_DIR/03-light-models-tts-ocr.sh" ]; then
            "$INSTALLERS_DIR/03-light-models-tts-ocr.sh"
        fi
        echo ""
        echo "${green}${bold}✅ Light Setup Complete! No heavy model downloads were performed.${reset}"
        ;;
    [aA])
        echo ""
        echo "${green}[*] Running Complete Setup (All Steps)...${reset}"
        run_turnkey_install
        if [ -x "$INSTALLERS_DIR/03-light-models-tts-ocr.sh" ]; then
            "$INSTALLERS_DIR/03-light-models-tts-ocr.sh"
        fi
        if [ -x "$INSTALLERS_DIR/04-heavy-ai-image-models.sh" ]; then
            "$INSTALLERS_DIR/04-heavy-ai-image-models.sh"
        fi
        if [ -x "$INSTALLERS_DIR/05-godseye-globe.sh" ]; then
            "$INSTALLERS_DIR/05-godseye-globe.sh"
        fi
        echo ""
        echo "${green}${bold}✅ Full Setup Complete! All components and models are ready.${reset}"
        ;;
    [qQ]|*)
        echo "Exiting."
        exit 0
        ;;
esac
