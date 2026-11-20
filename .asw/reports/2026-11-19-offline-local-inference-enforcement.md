# AI Studio: Offline Local Inference Enforcement & Zero-Network Guarantee

- **Date**: 2026-11-19
- **Scope**: Hugging Face Hub offline isolation, weight_name explicit specification, and local cache enforcement
- **Target Daemon**: [`scripts/image-daemon.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-daemon.py), [`scripts/image-engine.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-engine.py), [`scripts/image-engine.sh`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-engine.sh)

---

## 1. Problem Identification
When network connectivity is severed, model loading or inference would freeze and fail with 0% GPU activity.

### Root Cause
1. **Hugging Face Hub Metadata Pings**: By default, `AutoPipelineForText2Image.from_pretrained()` and `pipe.load_lora_weights()` attempt to query `https://huggingface.co` to check repository commits and resolve file names.
2. **Missing `weight_name` Exception in Offline Mode**: When `diffusers` operates without internet, it fails with:
   ```
   ValueError: When using the offline mode, you must specify a `weight_name`.
   ```
   Because `load_lora_weights(LORA_ID)` was called without `weight_name="pytorch_lora_weights.safetensors"`, `diffusers` tried to guess the file name via an API call, which failed offline and crashed the daemon before GPU execution could begin.

---

## 2. Remediation
1. **Air-Gapped Environment Enforcement**:
   - In [`scripts/image-daemon.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-daemon.py), [`scripts/image-engine.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-engine.py), and [`scripts/image-engine.sh`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-engine.sh):
     ```bash
     export HF_HUB_OFFLINE=1
     export TRANSFORMERS_OFFLINE=1
     export HF_DATASETS_OFFLINE=1
     ```
2. **Strict Local Files Loading**:
   - `AutoPipelineForText2Image.from_pretrained(..., local_files_only=True)`
   - `pipe.load_lora_weights(..., weight_name="pytorch_lora_weights.safetensors", local_files_only=True)`
3. **Zero Network Latency**:
   - The daemon loads directly from disk cache in `~/.local/share/cool-shell/models/image/` with 0 network calls, allowing full local GPU inference offline.
