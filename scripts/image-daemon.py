#!/usr/bin/env python3
"""
Cool-Shell AI Image Studio Daemon (Native 512x512)
Features:
- Native 512x512 Resolution: Runs at the exact resolution Stable Diffusion 1.5 was trained for.
- Zero Idle VRAM: Kept in CPU RAM, transferred to CUDA only during inference, and offloaded immediately.
- Auto-Shutdown Timer: Automatically exits and frees 100% of CPU RAM after 3 minutes of inactivity.
- Prompt Distillation: Automatically strips conversational fluff, extracts negative cues,
  suppresses humans for product shots, and caps prompt strictly within CLIP's 75 tokens.
- Instant Swappy viewer: Automatically opens swappy in a detached session.
- Dynamic Island IPC: Flashes violet during generation and emerald green toast upon completion.
"""
import sys
import os
import time
import socket
import json
import signal
import datetime
import re
import subprocess
from PIL import Image

os.environ["CUDA_VISIBLE_DEVICES"] = "0"
os.environ["TOKENIZERS_PARALLELISM"] = "false"
os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["TRANSFORMERS_OFFLINE"] = "1"
os.environ["HF_DATASETS_OFFLINE"] = "1"
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

SOCKET_PATH = "/tmp/cool-shell-image.sock"
PID_FILE = "/tmp/cool-shell-image.pid"
OUTPUT_DIR = os.path.expanduser("~/Pictures/generated")
os.makedirs(OUTPUT_DIR, exist_ok=True)
CACHE_DIR = os.path.expanduser("~/.local/share/cool-shell/models/image")
os.makedirs(CACHE_DIR, exist_ok=True)

MODEL_ID = "SG161222/Realistic_Vision_V5.1_noVAE"
LORA_ID = "latent-consistency/lcm-lora-sdv1-5"
IDLE_TIMEOUT_SECONDS = 180  # 3 minutes of inactivity before auto-shutdown

# Global pipeline state and activity tracker
pipe = None
pipe_img2img = None
last_activity_time = time.time()

LOCK_FILE = "/tmp/cool-shell-image.lock"

def notify_island_ai(generating: bool, msg: str = ""):
    """Notify Dynamic Island via Quickshell IPC."""
    val = "true" if generating else "false"
    for cmd in [
        ["qs", "-c", "cool-shell", "ipc", "call", "island", "setAiGenerating", val, msg],
        ["qs", "-p", "/home/pranc/.config/quickshell/cool-shell", "ipc", "call", "island", "setAiGenerating", val, msg],
        ["quickshell", "-c", "cool-shell", "ipc", "call", "island", "setAiGenerating", val, msg]
    ]:
        try:
            res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
            if res.returncode == 0:
                break
        except Exception:
            pass

def get_process_rss_mb() -> float:
    """Get current resident set size (RAM) in megabytes."""
    try:
        with open(f"/proc/{os.getpid()}/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return round(int(line.split()[1]) / 1024.0, 1)
    except Exception:
        pass
    return 0.0

def distill_prompt(raw_text: str, tokenizer):
    """
    Sanitize and distill raw user prompt for Stable Diffusion 1.5 CLIP encoder.
    Extracts negative cues, eliminates conversational fluff, and stays strictly within 75 tokens.
    """
    text = raw_text.strip()
    text = re.sub(r'\*+', '', text)
    text = re.sub(r'[\`_]', '', text)

    # Extract negative cues like 'no watermarks, distorted shapes, extra objects...'
    neg_patterns = [
        r'(?:no|without|avoid|free of)\s+([a-zA-Z0-9\s,]+?)(?:\.|$)',
    ]
    extracted_negs = []
    for pat in neg_patterns:
        for match in re.finditer(pat, text, re.IGNORECASE):
            extracted_negs.append(match.group(1).strip())
            text = text.replace(match.group(0), ' ')

    # Strip conversational verb prefixes
    fluff_patterns = [
        r'^(?:please\s+)?(?:create|generate|make|render|draw|produce)\s+(?:an?|the)?\s*',
        r'feature the\s+[^,.]+\s+as the main subject,?\s*',
        r'leave (?:clean\s+)?negative space (?:for|to)[^,.]*,?\s*',
        r'suitable for (?:an?|the)?[^,.]*,?\s*',
        r'use dramatic',
        r'use a refined',
        r'use cinematic',
        r'use soft',
        r'use ',
        r'position the\s+',
    ]
    for pat in fluff_patterns:
        text = re.sub(pat, '', text, flags=re.IGNORECASE)

    # Replace gloomy or shadow-inducing descriptions with clean illumination
    text = re.sub(r'\bdark background[^\,.]*', 'illuminated studio background', text, flags=re.IGNORECASE)
    text = re.sub(r'\bcinematic shadows[^\,.]*', 'soft studio reflections', text, flags=re.IGNORECASE)
    text = re.sub(r'\bsubtle gradients[^\,.]*', 'clean studio lighting', text, flags=re.IGNORECASE)

    base_negative = [
        'duplicate', 'multiple subjects', 'second headband', 'deformed', 'distorted',
        'disfigured', 'blurry', 'low quality', 'lowres', 'artifacts', 'bad geometry',
        'bad anatomy', 'watermark', 'signature', 'text', 'cropped', 'out of frame',
        'underexposed', 'pitch black', 'gloomy', 'silhouette', 'dark shadows', 'obscured', 'dimly lit',
        'soft focus', 'depth of field', 'bokeh', 'out of focus'
    ]

    # If prompt describes an inanimate product shot without requesting people/models, suppress human figures
    human_keywords = {'person', 'woman', 'man', 'girl', 'boy', 'model', 'face', 'portrait', 'human', 'lady', 'guy'}
    prompt_words = set(re.findall(r'\b\w+\b', raw_text.lower()))
    if not (human_keywords & prompt_words):
        base_negative.extend(['person', 'human', 'woman', 'man', 'face', 'portrait', 'skin', 'eyes', 'wearing'])

    for neg in extracted_negs:
        for item in re.split(r'[,;]|\band\b|\bor\b', neg):
            item = item.strip()
            if item and len(item) > 2 and item not in base_negative:
                base_negative.append(item)

    text = re.sub(r'\s+', ' ', text)
    text = re.sub(r'\s*([,.;])\s*', r'\1 ', text).strip(' ,.')

    quality_suffix = ', bright studio lighting, softbox illumination, metallic reflections, 8k, sharp crisp focus'
    tokens = tokenizer.encode(text, truncation=False)
    suffix_tokens = tokenizer.encode(quality_suffix, truncation=False)
    max_body_tokens = 75 - len(suffix_tokens)

    if len(tokens) > max_body_tokens:
        body_tokens = tokens[1:max_body_tokens + 1]
        text = tokenizer.decode(body_tokens, clean_up_tokenization_spaces=True).rstrip(' ,.')

    positive = text + quality_suffix
    neg_str = ', '.join(base_negative)
    neg_tokens = tokenizer.encode(neg_str, truncation=False)
    if len(neg_tokens) > 77:
        neg_tokens = neg_tokens[1:76]
        negative = tokenizer.decode(neg_tokens, clean_up_tokenization_spaces=True).rstrip(' ,.')
    else:
        negative = neg_str
    return positive, negative

def load_pipeline():
    global pipe
    if pipe is not None:
        return pipe

    import torch
    from diffusers import AutoPipelineForText2Image, LCMScheduler

    # Disable cuDNN to prevent Turing FP16 numerical overflow on GTX 1650 TU117
    torch.backends.cudnn.enabled = False

    print("[*] Loading Realistic Vision v5.1 + LCM-LoRA into CPU memory (100% offline)...")
    t0 = time.time()
    pipe = AutoPipelineForText2Image.from_pretrained(
        MODEL_ID,
        torch_dtype=torch.float16,
        cache_dir=CACHE_DIR,
        local_files_only=True,
        safety_checker=None
    )
    pipe.scheduler = LCMScheduler.from_config(pipe.scheduler.config)
    pipe.load_lora_weights(
        LORA_ID,
        weight_name="pytorch_lora_weights.safetensors",
        cache_dir=CACHE_DIR,
        local_files_only=True
    )
    pipe.fuse_lora(lora_scale=0.8)
    pipe.enable_attention_slicing(1)
    if hasattr(pipe, "enable_vae_slicing"):
        pipe.enable_vae_slicing()
    if hasattr(pipe, "enable_vae_tiling"):
        pipe.enable_vae_tiling()
    pipe.to("cpu")
    torch.cuda.empty_cache()
    print(f"[*] Pipeline loaded in {time.time()-t0:.2f}s (Resident in CPU RAM, 0 MB VRAM, LoRA scale: 0.8).")
    return pipe

def get_img2img_pipeline():
    global pipe, pipe_img2img
    if pipe_img2img is not None:
        return pipe_img2img
    if pipe is None:
        load_pipeline()
    from diffusers import AutoPipelineForImage2Image
    print("[*] Creating AutoPipelineForImage2Image sharing in-memory weights (0 MB extra download)...")
    pipe_img2img = AutoPipelineForImage2Image.from_pipe(pipe)
    pipe_img2img.enable_attention_slicing(1)
    if hasattr(pipe_img2img, "enable_vae_slicing"):
        pipe_img2img.enable_vae_slicing()
    if hasattr(pipe_img2img, "enable_vae_tiling"):
        pipe_img2img.enable_vae_tiling()
    return pipe_img2img

SINGLE_OUTPUT_PATH = os.path.join(OUTPUT_DIR, "ai_output.png")

def run_generation(
    prompt: str,
    out_path: str = None,
    open_viewer: bool = False,
    width: int = 512,
    height: int = 512,
    steps: int = 8,
    cfg: float = 1.8,
    image_path: str = None,
    strength: float = 0.65,
    negative_prompt: str = None,
    seed: int = -1,
    purge_previous: bool = True
) -> dict:
    global pipe, pipe_img2img, last_activity_time
    last_activity_time = time.time()
    t_start = time.time()

    # Sanitize and resolve reference image path
    clean_ref = None
    if image_path:
        clean_ref = str(image_path).strip().strip("'\"")
        if clean_ref.startswith("file://"):
            import urllib.parse
            clean_ref = urllib.parse.unquote(clean_ref[7:])
        clean_ref = os.path.abspath(os.path.expanduser(clean_ref))

    is_img2img = bool(clean_ref and os.path.exists(clean_ref))
    if clean_ref and not is_img2img:
        err_msg = f"Reference image not found: {clean_ref}"
        print(f"[-] {err_msg}", file=sys.stderr)
        return {"status": "error", "error": err_msg}

    if is_img2img:
        notify_island_ai(True, f"Styling Photo ({width}×{height}, str={strength})...")
    else:
        notify_island_ai(True, f"Generating ({width}×{height}, {steps} steps)...")

    active_pipe = None
    try:
        import torch
        if pipe is None:
            load_pipeline()

        if is_img2img:
            active_pipe = get_img2img_pipeline()
            with Image.open(clean_ref) as raw_img:
                init_img = raw_img.convert("RGB").resize((width, height), Image.Resampling.LANCZOS)
            # Privacy policy: If reference image was in /tmp or cache, clean it up immediately
            if clean_ref.startswith("/tmp/") or "cache" in clean_ref.lower():
                try:
                    os.remove(clean_ref)
                except Exception:
                    pass
        else:
            active_pipe = pipe

        # Enforce single output copy: overwrite deterministic path and purge any lingering outputs
        if not out_path:
            out_path = SINGLE_OUTPUT_PATH

        if purge_previous:
            try:
                for f in os.listdir(OUTPUT_DIR):
                    full_f = os.path.join(OUTPUT_DIR, f)
                    if os.path.isfile(full_f) and f.startswith("ai_") and full_f != out_path:
                        try:
                            os.remove(full_f)
                        except Exception:
                            pass
            except Exception:
                pass

        pos_prompt, default_neg = distill_prompt(prompt, active_pipe.tokenizer)
        if negative_prompt and str(negative_prompt).strip():
            neg_prompt = str(negative_prompt).strip()
        else:
            neg_prompt = default_neg
        # Privacy policy: Prompts are never printed, logged, or saved to disk
        print(f"[*] Prompt distilled into memory.")

        # Configure memory optimizations before GPU transfer
        active_pipe.enable_attention_slicing(1)
        if hasattr(active_pipe, "enable_vae_slicing"):
            active_pipe.enable_vae_slicing()
        if hasattr(active_pipe, "enable_vae_tiling"):
            active_pipe.enable_vae_tiling()

        # Move to CUDA for diffusion
        t_gpu = time.time()
        active_pipe.to("cuda")
        print(f"[*] Transferred to CUDA in {time.time()-t_gpu:.2f}s")

        generator = None
        if seed is not None and int(seed) >= 0:
            generator = torch.Generator(device="cuda").manual_seed(int(seed))

        # Native diffusion (LCM-LoRA)
        t_diff = time.time()
        if is_img2img:
            latents = active_pipe(
                prompt=pos_prompt,
                negative_prompt=neg_prompt,
                image=init_img,
                strength=strength,
                num_inference_steps=steps,
                guidance_scale=cfg,
                generator=generator,
                output_type="latent"
            ).images
            diff_time = time.time() - t_diff
            print(f"[*] Img2Img Diffusion ({width}x{height}, {steps} steps, strength={strength}, cfg={cfg}) completed in {diff_time:.2f}s")
        else:
            latents = active_pipe(
                prompt=pos_prompt,
                negative_prompt=neg_prompt,
                num_inference_steps=steps,
                guidance_scale=cfg,
                width=width,
                height=height,
                generator=generator,
                output_type="latent"
            ).images
            diff_time = time.time() - t_diff
            print(f"[*] Text2Img Diffusion ({width}x{height}, {steps} steps, cfg={cfg}) completed in {diff_time:.2f}s")

        # Offload UNet to CPU to preserve VRAM for VAE decode
        active_pipe.unet.to("cpu")
        torch.cuda.empty_cache()

        # VAE decode on CUDA
        with torch.no_grad():
            latents = (latents / active_pipe.vae.config.scaling_factor).to(active_pipe.vae.device)
            img_tensor = active_pipe.vae.decode(latents).sample
            img = active_pipe.image_processor.postprocess(img_tensor, output_type="pil")[0]

        # Smart exposure check to prevent underexposed/dark renders
        from PIL import ImageEnhance, ImageStat
        stat = ImageStat.Stat(img.convert("L"))
        avg_lum = stat.mean[0]
        if avg_lum < 85:
            factor = min(1.8, 95.0 / max(avg_lum, 25.0))
            img = ImageEnhance.Brightness(img).enhance(factor)
            img = ImageEnhance.Contrast(img).enhance(1.1)

        # Save native image
        img.save(out_path, format="PNG", quality=95)

        # Offload all pipeline components back to CPU RAM (Zero idle VRAM)
        active_pipe.to("cpu")
        torch.cuda.empty_cache()

        elapsed = time.time() - t_start
        print(f"[+] Generation successful: {out_path} in {elapsed:.2f}s (Idle VRAM: 0 MB)")

        # Open in swappy (with xdg-open fallback) only when requested directly
        if open_viewer:
            try:
                subprocess.Popen(["swappy", "-f", out_path], env=os.environ.copy(), start_new_session=True)
            except Exception as e:
                print(f"[-] Swappy launch failed: {e}", file=sys.stderr)
                try:
                    subprocess.Popen(["xdg-open", out_path], env=os.environ.copy(), start_new_session=True)
                except Exception:
                    pass

        last_activity_time = time.time()
        return {"status": "ok", "path": out_path, "elapsed": round(elapsed, 2)}
    except Exception as e:
        print(f"[-] Error during generation: {e}", file=sys.stderr)
        try:
            if active_pipe is not None:
                active_pipe.to("cpu")
            if pipe is not None:
                pipe.to("cpu")
            torch.cuda.empty_cache()
        except Exception:
            pass
        return {"status": "error", "error": str(e)}
    finally:
        notify_island_ai(False, "")

def start_server():
    global last_activity_time
    import fcntl

    # Single-instance file lock
    try:
        lock_fd = open(LOCK_FILE, "w")
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except (IOError, BlockingIOError):
        print("[!] Another image daemon instance is already starting or running. Exiting.", file=sys.stderr)
        sys.exit(0)

    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    # Load pipeline into CPU memory FIRST before opening socket
    print(f"[*] Image Daemon PID {os.getpid()} loading weights into CPU RAM...")
    load_pipeline()

    if os.path.exists(SOCKET_PATH):
        try:
            os.unlink(SOCKET_PATH)
        except OSError:
            pass

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(5)
    server.settimeout(5.0)  # Check idle timeout every 5 seconds

    print(f"[*] Image Daemon socket opened on {SOCKET_PATH} (PID {os.getpid()})")
    print(f"[*] Image Daemon fully initialized and ready to serve requests.")
    last_activity_time = time.time()

    def handle_signal(sig, frame):
        print("[*] Shutting down Image Daemon and freeing memory...")
        try:
            server.close()
            if os.path.exists(SOCKET_PATH):
                os.unlink(SOCKET_PATH)
            if os.path.exists(PID_FILE):
                os.unlink(PID_FILE)
            if os.path.exists(LOCK_FILE):
                os.unlink(LOCK_FILE)
        except Exception:
            pass
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    while True:
        try:
            try:
                conn, _ = server.accept()
            except socket.timeout:
                # Check idle timeout
                idle_sec = time.time() - last_activity_time
                if idle_sec >= IDLE_TIMEOUT_SECONDS:
                    print(f"[*] Idle timeout ({IDLE_TIMEOUT_SECONDS}s) reached. Auto-shutting down to free 100% CPU RAM...")
                    break
                continue

            # Connection received: reset timeout and process
            last_activity_time = time.time()
            data = conn.recv(16384)
            if not data:
                conn.close()
                continue

            req = json.loads(data.decode("utf-8"))
            action = req.get("action", "generate")

            if action == "ping":
                resp = {"status": "pong", "loaded": True}
            elif action == "status":
                idle_sec = round(time.time() - last_activity_time, 1)
                rss_mb = get_process_rss_mb()
                resp = {
                    "status": "ok",
                    "loaded": True,
                    "pid": os.getpid(),
                    "ram_mb": rss_mb,
                    "idle_sec": idle_sec,
                    "timeout": IDLE_TIMEOUT_SECONDS
                }
            elif action == "stop":
                resp = {"status": "stopping"}
                conn.sendall(json.dumps(resp).encode("utf-8"))
                conn.close()
                print("[*] Manual stop requested via socket.")
                break
            elif action == "generate":
                prompt = req.get("prompt", "")
                out_path = req.get("out_path", None)
                width = int(req.get("width", 512))
                height = int(req.get("height", 512))
                steps = int(req.get("steps", 8))
                cfg = float(req.get("cfg", 1.8))
                image_path = req.get("image_path", None)
                strength = float(req.get("strength", 0.65))
                negative_prompt = req.get("negative_prompt", None)
                seed = req.get("seed", -1)
                purge_previous = req.get("purge_previous", True)
                resp = run_generation(
                    prompt,
                    out_path=out_path,
                    width=width,
                    height=height,
                    steps=steps,
                    cfg=cfg,
                    image_path=image_path,
                    strength=strength,
                    negative_prompt=negative_prompt,
                    seed=seed,
                    purge_previous=purge_previous
                )
            else:
                resp = {"status": "unknown_action"}

            conn.sendall(json.dumps(resp).encode("utf-8"))
            conn.close()
            last_activity_time = time.time()
        except Exception as e:
            print(f"[-] Error handling request: {e}", file=sys.stderr)

    handle_signal(None, None)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--daemon":
        start_server()
    else:
        prompt = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else ""
        if not prompt:
            print("Usage: image-daemon.py [--daemon | <prompt>]")
            sys.exit(1)
        settings_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "island", "ai-settings.json")
        auto_open = True
        width = 512
        height = 512
        steps = 8
        cfg = 1.8
        if os.path.exists(settings_file):
            try:
                with open(settings_file, "r") as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        if "autoOpen" in data:
                            auto_open = bool(data["autoOpen"])
                        if data.get("aspectRatio") == "16:9":
                            width, height = 768, 432
                        if "steps" in data:
                            steps = int(data["steps"])
                        if "cfg" in data:
                            cfg = float(data["cfg"])
            except Exception:
                pass
        res = run_generation(prompt, open_viewer=auto_open, width=width, height=height, steps=steps, cfg=cfg)
        print(json.dumps(res))
