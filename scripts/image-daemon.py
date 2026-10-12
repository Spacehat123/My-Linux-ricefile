#!/home/pranc/.unsloth/studio/unsloth_studio/bin/python3
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
last_activity_time = time.time()

LOCK_FILE = "/tmp/cool-shell-image.lock"

def notify_island_ai(generating: bool, msg: str = ""):
    """Notify Dynamic Island via Quickshell IPC."""
    val = "true" if generating else "false"
    try:
        subprocess.run(
            ["qs", "-c", "cool-shell", "ipc", "call", "island", "setAiGenerating", val, msg],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=4
        )
    except Exception:
        try:
            subprocess.run(
                ["quickshell", "-c", "cool-shell", "ipc", "call", "island", "setAiGenerating", val, msg],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=4
            )
        except Exception:
            pass

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
    negative = ', '.join(base_negative)
    return positive, negative

def load_pipeline():
    global pipe
    if pipe is not None:
        return pipe

    import torch
    from diffusers import AutoPipelineForText2Image, LCMScheduler

    # Disable cuDNN to prevent Turing FP16 numerical overflow on GTX 1650 TU117
    torch.backends.cudnn.enabled = False

    print("[*] Loading Realistic Vision v5.1 + LCM-LoRA into CPU memory...")
    t0 = time.time()
    pipe = AutoPipelineForText2Image.from_pretrained(
        MODEL_ID,
        torch_dtype=torch.float16,
        cache_dir=CACHE_DIR,
        safety_checker=None
    )
    pipe.scheduler = LCMScheduler.from_config(pipe.scheduler.config)
    pipe.load_lora_weights(LORA_ID, cache_dir=CACHE_DIR)
    pipe.fuse_lora()
    pipe.to("cpu")
    torch.cuda.empty_cache()
    print(f"[*] Pipeline loaded in {time.time()-t0:.2f}s (Resident in CPU RAM, 0 MB VRAM).")
    return pipe

def run_generation(prompt: str, out_path: str = None) -> dict:
    global pipe, last_activity_time
    last_activity_time = time.time()
    t_start = time.time()
    notify_island_ai(True, "Generating Image...")

    try:
        import torch
        if pipe is None:
            load_pipeline()

        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        if not out_path:
            out_path = os.path.join(OUTPUT_DIR, f"ai_{timestamp}.png")

        pos_prompt, neg_prompt = distill_prompt(prompt, pipe.tokenizer)
        print(f"[*] Distilled Positive: {pos_prompt}")
        print(f"[*] Distilled Negative: {neg_prompt}")

        # Move to CUDA for diffusion
        t_gpu = time.time()
        pipe.to("cuda")
        pipe.enable_attention_slicing()
        print(f"[*] Transferred to CUDA in {time.time()-t_gpu:.2f}s")

        # Native 512x512 resolution (4 steps LCM-LoRA)
        t_diff = time.time()
        latents = pipe(
            prompt=pos_prompt,
            negative_prompt=neg_prompt,
            num_inference_steps=4,
            guidance_scale=1.5,
            width=512,
            height=512,
            output_type="latent"
        ).images
        diff_time = time.time() - t_diff
        print(f"[*] Native 512x512 diffusion completed in {diff_time:.2f}s")

        # Offload UNet to CPU to preserve VRAM for VAE decode
        pipe.unet.to("cpu")
        torch.cuda.empty_cache()

        # VAE decode on CUDA
        with torch.no_grad():
            latents = (latents / pipe.vae.config.scaling_factor).to(pipe.vae.device)
            img_tensor = pipe.vae.decode(latents).sample
            img = pipe.image_processor.postprocess(img_tensor, output_type="pil")[0]

        # Smart exposure check to prevent underexposed/dark renders
        from PIL import ImageEnhance, ImageStat
        stat = ImageStat.Stat(img.convert("L"))
        avg_lum = stat.mean[0]
        if avg_lum < 85:
            factor = min(1.8, 95.0 / max(avg_lum, 25.0))
            img = ImageEnhance.Brightness(img).enhance(factor)
            img = ImageEnhance.Contrast(img).enhance(1.1)

        # Save native 512x512 image
        img.save(out_path, format="PNG", quality=95)

        # Offload all pipeline components back to CPU RAM (Zero idle VRAM)
        pipe.to("cpu")
        torch.cuda.empty_cache()

        elapsed = time.time() - t_start
        print(f"[+] Generation successful: {out_path} in {elapsed:.2f}s (Idle VRAM: 0 MB)")

        # Open in swappy (with xdg-open fallback)
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

    if os.path.exists(SOCKET_PATH):
        try:
            os.unlink(SOCKET_PATH)
        except OSError:
            pass

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(5)
    server.settimeout(5.0)  # Check idle timeout every 5 seconds

    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    print(f"[*] Image Daemon socket opened on {SOCKET_PATH} (PID {os.getpid()})")

    # Load pipeline into CPU memory
    load_pipeline()

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
                resp = {"status": "ok", "loaded": True, "idle_sec": idle_sec, "timeout": IDLE_TIMEOUT_SECONDS}
            elif action == "stop":
                resp = {"status": "stopping"}
                conn.sendall(json.dumps(resp).encode("utf-8"))
                conn.close()
                print("[*] Manual stop requested via socket.")
                break
            elif action == "generate":
                prompt = req.get("prompt", "")
                out_path = req.get("out_path", None)
                resp = run_generation(prompt, out_path)
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
        res = run_generation(prompt)
        print(json.dumps(res))
