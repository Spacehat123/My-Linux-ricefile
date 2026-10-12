#!/usr/bin/env bash
# ==============================================================================
# Step 4: [OPTIONAL] Heavy AI Image Generation Models (~2.2 GB Total)
# Includes: Realistic Vision v5.1 + LCM-LoRA 512x512
# ONLY needed if you plan to use local text-to-image generation (Super+G).
# Skip this if you don't want a 2.2 GB download!
# ==============================================================================
set -euo pipefail

IMAGE_CACHE="$HOME/.local/share/cool-shell/models/image"

echo "=========================================================="
echo "  🎨 [4/5] Heavy AI Image Models Installer (~2.2 GB)"
echo "  Target: $IMAGE_CACHE"
echo "=========================================================="
echo ""
echo "  ⚠️  NOTICE: This downloads ~2.2 GB of AI model weights."
echo "  It is ONLY required for local Stable Diffusion (Super+G)."
echo ""

read -r -p "  Do you want to proceed with this 2.2 GB download? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY])
        ;;
    *)
        echo "  [-] Skipped. Heavy AI models will NOT be downloaded."
        exit 0
        ;;
esac

mkdir -p "$IMAGE_CACHE"

echo "[*] Detecting Python runtime..."
PYTHON_BIN="python3"
if [ -x "$HOME/.unsloth/studio/unsloth_studio/bin/python3" ]; then
    PYTHON_BIN="$HOME/.unsloth/studio/unsloth_studio/bin/python3"
elif [ -x "$HOME/.local/share/cool-shell/venv/bin/python" ]; then
    PYTHON_BIN="$HOME/.local/share/cool-shell/venv/bin/python"
fi

echo "[*] Using Python: $PYTHON_BIN"
echo "[*] Downloading Realistic Vision v5.1 & LCM-LoRA from Hugging Face..."

"$PYTHON_BIN" - << 'PYEOF'
import os
import sys

try:
    import torch
    from diffusers import AutoPipelineForText2Image, LCMScheduler
except ImportError as e:
    print(f"[-] Error: Missing Python dependencies ({e}).")
    print("    Please run Step 2 (02-python-environment.sh) first!")
    sys.exit(1)

cache_dir = os.path.expanduser("~/.local/share/cool-shell/models/image")
os.makedirs(cache_dir, exist_ok=True)

model_id = "SG161222/Realistic_Vision_V5.1_noVAE"
lora_id = "latent-consistency/lcm-lora-sdv1-5"

print(f"[*] Fetching base model '{model_id}' (~2.1 GB)...")
pipe = AutoPipelineForText2Image.from_pretrained(
    model_id,
    torch_dtype=torch.float16,
    cache_dir=cache_dir,
    safety_checker=None
)

print(f"[*] Fetching LoRA weights '{lora_id}' (~135 MB)...")
pipe.load_lora_weights(lora_id, cache_dir=cache_dir)

print("[+] All Hugging Face image models successfully downloaded and cached!")
PYEOF

echo "=========================================================="
echo "  ✅ Step 4 Complete: 512x512 AI Image Studio models ready!"
echo "=========================================================="
