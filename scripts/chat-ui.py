#!/usr/bin/env python3
"""
Cool-Shell AI Studio Chat Interface
A full-featured, lightweight conversational web interface for Realistic Vision v5.1 + LCM-LoRA.
- Runs 100% offline via local weights and UNIX socket connection.
- Completely independent of Super + G island prompts (shares background daemon safely).
- Features multimodal chat (text + photo references), extensive settings drawer, and session gallery.
"""
import os
import sys
import time
import json
import socket
import datetime
import shutil
from pathlib import Path
from PIL import Image
import gradio as gr

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
import importlib.util

# Ensure offline operation
os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["TRANSFORMERS_OFFLINE"] = "1"
os.environ["HF_DATASETS_OFFLINE"] = "1"
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

# Storage paths
CHAT_OUTPUT_DIR = os.path.expanduser("~/Pictures/generated/chat")
os.makedirs(CHAT_OUTPUT_DIR, exist_ok=True)

# Import client engine functions
spec = importlib.util.spec_from_file_location("image_engine", os.path.join(SCRIPT_DIR, "image-engine.py"))
image_engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(image_engine)

# Preset style enhancements
STYLE_PRESETS = {
    "None (Raw Prompt)": ("", ""),
    "Photorealistic Studio": (
        ", ultra-realistic, 8k resolution, professional studio softbox lighting, sharp crisp focus, hyperdetailed, Hasselblad photography",
        "cartoon, render, anime, CGI, blurry, low quality, oversaturated"
    ),
    "Cinematic Cyberpunk": (
        ", cyberpunk aesthetic, volumetric neon lighting, reflective rainy pavement, futuristic city backdrop, 35mm cinematic film still",
        "daylight, sunny, cheerful, drawing, sketch, low quality"
    ),
    "Anime & Digital Art": (
        ", modern anime key visual, Makoto Shinkai aesthetic, luminous color grading, clean delicate lines, masterpiece artwork",
        "photograph, realistic, noisy, grainy, live action"
    ),
    "Dark Fantasy & Chiaroscuro": (
        ", dark gothic fantasy, Rembrandt chiaroscuro lighting, deep mysterious shadows, ethereal mist, epic atmospheric perspective",
        "bright, cheerful, flat lighting, modern, neon"
    ),
    "Analog 35mm Film": (
        ", shot on Kodak Portra 400, 35mm film grain, vintage color warmth, candid film still, natural authentic lighting",
        "digital render, CGI, overly polished, 3D, plastic"
    ),
    "Architectural & Interior": (
        ", architectural digest photography, clean Scandinavian minimalism, natural morning daylight, symmetrical composition, 8k",
        "messy, cluttered, distorted perspective, people, dark"
    )
}

ASPECT_RATIOS = {
    "1:1 Square (512×512)": (512, 512),
    "16:9 Landscape (768×432)": (768, 432),
    "9:16 Portrait (432×768)": (432, 768),
    "4:3 Standard (640×480)": (640, 480),
    "3:4 Portrait (480×640)": (480, 640)
}

# In-memory gallery tracking for the current session
session_gallery_history = []

def get_telemetry_status() -> str:
    """Fetch live status of the background daemon."""
    status = image_engine.get_status()
    if status.get("loaded"):
        ram_mb = status.get("ram_mb", 0.0)
        ram_str = f"{ram_mb/1024:.1f} GB" if ram_mb >= 1024 else f"{int(ram_mb)} MB"
        idle = status.get("idle_sec", 0)
        return f"🟢 **Model Warm in RAM ({ram_str})** • PID {status.get('pid')} • Idle {idle}s • Zero Idle VRAM"
    elif status.get("loading"):
        ram_mb = status.get("ram_mb", 0.0)
        ram_str = f"{ram_mb/1024:.1f} GB" if ram_mb >= 1024 else f"{int(ram_mb)} MB"
        return f"🟡 **Loading weights into RAM ({ram_str})...** Please wait ~15s."
    else:
        return "⚪ **Model Offloaded (0 MB RAM / 0 MB VRAM)** • Starts on first prompt."

def warm_up_model():
    """Manual warm up action."""
    image_engine.ensure_daemon_running()
    return get_telemetry_status()

def offload_model():
    """Manual offload action."""
    image_engine.stop_daemon()
    return get_telemetry_status()

def extract_prompt_and_files(message):
    """Safely extract prompt text and reference file paths from Gradio 6 message objects."""
    text_parts = []
    files = []
    content = message.get("content", "") if isinstance(message, dict) else str(message)
    if isinstance(content, str):
        text_parts.append(content)
    elif isinstance(content, (list, tuple)):
        for item in content:
            if isinstance(item, str):
                text_parts.append(item)
            elif isinstance(item, dict):
                if item.get("type") == "text":
                    text_parts.append(item.get("text", ""))
                elif item.get("type") == "file":
                    file_info = item.get("file", {})
                    if isinstance(file_info, dict) and "path" in file_info:
                        files.append(file_info["path"])
                elif "path" in item:
                    files.append(item["path"])
                elif "text" in item:
                    text_parts.append(item.get("text", ""))
            elif hasattr(item, "path"):
                files.append(item.path)
            elif hasattr(item, "file") and hasattr(item.file, "path"):
                files.append(item.file.path)
    return " ".join([p.strip() for p in text_parts if p.strip()]), files

def process_chat(
    raw_text: str,
    ref_image_path: str | None,
    style_preset: str,
    aspect_choice: str,
    steps: int,
    cfg: float,
    strength: float,
    custom_negative: str,
    seed: int,
    auto_distill: bool
):
    """
    Handle multimodal chat generation.
    Returns: list of content items (image file dict and caption markdown) for Gradio 6 message.
    """
    raw_text = (raw_text or "").strip()

    if not raw_text and not ref_image_path:
        return "Please provide a prompt or attach an image to style!"

    # Resolve style preset modifications
    style_suffix, style_neg = STYLE_PRESETS.get(style_preset, ("", ""))
    final_prompt = raw_text + style_suffix if style_suffix else (raw_text or "photograph, high quality, detailed")
    if auto_distill:
        final_prompt += ", professional cinematic lighting, hdr"

    # Resolve negative prompt
    neg_parts = []
    if custom_negative and custom_negative.strip():
        neg_parts.append(custom_negative.strip())
    if style_neg:
        neg_parts.append(style_neg)
    combined_negative = ", ".join(neg_parts) if neg_parts else None

    # Resolve resolution
    width, height = ASPECT_RATIOS.get(aspect_choice, (512, 512))

    # Deterministic output path for chat history
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:19]
    mode_prefix = "img2img" if ref_image_path else "txt2img"
    out_file = os.path.join(CHAT_OUTPUT_DIR, f"{mode_prefix}_{timestamp}.png")

    # Send prompt to background daemon
    t0 = time.time()
    try:
        result = image_engine.send_prompt(
            prompt=final_prompt,
            out_path=out_file,
            width=width,
            height=height,
            steps=int(steps),
            cfg=float(cfg),
            image_path=ref_image_path,
            strength=float(strength),
            negative_prompt=combined_negative,
            seed=int(seed) if seed is not None else -1,
            purge_previous=False  # Preserve chat gallery
        )
    except Exception as e:
        return f"❌ **Daemon communication error**: {e}"

    elapsed = time.time() - t0

    if result.get("status") == "ok":
        saved_path = result.get("path", out_file)
        session_gallery_history.append(saved_path)

        caption_meta = (
            f"✨ **Generated in {elapsed:.1f}s** | {width}×{height} | {steps} steps | "
            f"CFG {cfg} | {'Strength ' + str(round(strength, 2)) if ref_image_path else 'txt2img'}"
        )
        if seed is not None and int(seed) >= 0:
            caption_meta += f" | Seed: {int(seed)}"

        return [{"path": saved_path}, caption_meta]
    else:
        err = result.get("error", "Unknown diffusion error")
        return f"❌ **Generation failed**: {err}"

def refresh_gallery():
    """Return list of generated images in the current session (newest first)."""
    images = []
    if os.path.exists(CHAT_OUTPUT_DIR):
        for f in sorted(os.listdir(CHAT_OUTPUT_DIR), reverse=True):
            if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
                full_path = os.path.join(CHAT_OUTPUT_DIR, f)
                images.append(full_path)
    return images

def clear_chat():
    """Clear chat conversation."""
    return []

# Custom CSS for dark glass theme matching cool-shell aesthetic
CUSTOM_CSS = """
body, .gradio-container {
    background-color: #121016 !important;
    font-family: 'Fredoka', 'Inter', system-ui, sans-serif !important;
    color: #F3F1F5 !important;
}
.dark .gradio-container {
    background-color: #121016 !important;
}
#chat-header {
    background: linear-gradient(135deg, rgba(168, 85, 247, 0.15), rgba(236, 72, 153, 0.08));
    border: 1px solid rgba(168, 85, 247, 0.25);
    border-radius: 16px;
    padding: 18px 24px;
    margin-bottom: 12px;
}
#telemetry-box {
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 12px;
    padding: 10px 16px;
    font-size: 13px;
}
.sidebar-panel {
    background: rgba(255, 255, 255, 0.03) !important;
    border: 1px solid rgba(255, 255, 255, 0.08) !important;
    border-radius: 16px !important;
    padding: 16px !important;
}
button.primary-btn {
    background: linear-gradient(135deg, #A855F7, #EC4899) !important;
    border: none !important;
    color: #FFFFFF !important;
    font-weight: 600 !important;
    border-radius: 12px !important;
}
"""

def create_ui():
    with gr.Blocks(title="AI Image Studio Chat") as demo:
        # Header Banner
        with gr.Row(elem_id="chat-header"):
            with gr.Column(scale=8):
                gr.Markdown(
                    "## 󱨊 AI Image Studio Chat\n"
                    "**Realistic Vision v5.1 + LCM-LoRA** • Multimodal Chat & Advanced Parameter Studio (100% Offline)\n"
                    "*Independent companion to Super + G island prompts.*"
                )
            with gr.Column(scale=4):
                status_md = gr.Markdown(value=get_telemetry_status(), elem_id="telemetry-box")
                with gr.Row():
                    btn_warm = gr.Button("⚡ Wake Model", size="sm")
                    btn_offload = gr.Button("💤 Offload (0 MB)", size="sm")
                    btn_refresh = gr.Button("🔄 Status", size="sm")

        with gr.Tabs():
            # TAB 1: Conversational Chat Studio
            with gr.TabItem("💬 Conversational Studio"):
                with gr.Row():
                    # Left: Chatbot Stream
                    with gr.Column(scale=7):
                        chatbot = gr.Chatbot(
                            label="Interactive Conversation",
                            height=560
                        )

                        chat_input = gr.MultimodalTextbox(
                            interactive=True,
                            file_types=["image"],
                            placeholder="Type a prompt or attach an image to style...",
                            show_label=False,
                            container=False
                        )

                        with gr.Row():
                            btn_clear = gr.Button("🗑️ Clear Chat", size="sm")

                    # Right: Extra Settings Drawer
                    with gr.Column(scale=5, elem_classes=["sidebar-panel"]):
                        gr.Markdown("### ⚙️ Studio Settings")

                        preset_dropdown = gr.Dropdown(
                            choices=list(STYLE_PRESETS.keys()),
                            value="Photorealistic Studio",
                            label="🎨 Style Preset"
                        )

                        aspect_dropdown = gr.Dropdown(
                            choices=list(ASPECT_RATIOS.keys()),
                            value="16:9 Landscape (768×432)",
                            label="📐 Aspect Ratio & Resolution"
                        )

                        with gr.Row():
                            slider_steps = gr.Slider(
                                minimum=4,
                                maximum=20,
                                value=8,
                                step=1,
                                label="󰑮 Inference Steps (LCM: 6–12)"
                            )
                            slider_cfg = gr.Slider(
                                minimum=1.0,
                                maximum=4.0,
                                value=1.8,
                                step=0.1,
                                label="🎯 CFG Scale (Guidance)"
                            )

                        slider_strength = gr.Slider(
                            minimum=0.10,
                            maximum=0.95,
                            value=0.65,
                            step=0.05,
                            label="󰓎 Img2Img Strength (When photo attached)"
                        )

                        custom_neg_input = gr.Textbox(
                            label="🚫 Negative Prompt",
                            value="blurry, low quality, distorted, bad anatomy, deformed limbs, watermark, text",
                            lines=2
                        )

                        with gr.Row():
                            seed_input = gr.Number(
                                label="🎲 Seed (-1 for random)",
                                value=-1,
                                precision=0
                            )
                            auto_distill_chk = gr.Checkbox(
                                label="Studio Illumination Boost",
                                value=True
                            )

            # TAB 2: Session Gallery
            with gr.TabItem("🖼️ Session Gallery"):
                with gr.Row():
                    btn_refresh_gallery = gr.Button("🔄 Refresh Gallery", size="sm")
                gallery_view = gr.Gallery(
                    label="Generated Images in this Session",
                    columns=4,
                    height=560,
                    preview=True
                )

        # Wire Telemetry Buttons
        btn_warm.click(fn=warm_up_model, outputs=status_md)
        btn_offload.click(fn=offload_model, outputs=status_md)
        btn_refresh.click(fn=get_telemetry_status, outputs=status_md)

        # Wire Gallery Refresh
        btn_refresh_gallery.click(fn=refresh_gallery, outputs=gallery_view)

        # Chat Submission Workflow
        def user_submits(message, history):
            if history is None:
                history = []

            raw_text = ""
            files = []
            if isinstance(message, dict):
                raw_text = message.get("text", "") or ""
                files = message.get("files", []) or []
            elif isinstance(message, str):
                raw_text = message
                files = []

            raw_text = raw_text.strip()
            if not raw_text and not files:
                return history, gr.MultimodalTextbox(interactive=True)

            user_content = []
            for f in files:
                user_content.append({"path": f})
            if raw_text:
                user_content.append(raw_text)

            if len(user_content) == 1 and isinstance(user_content[0], str):
                user_content = user_content[0]

            history.append({"role": "user", "content": user_content})
            return history, gr.MultimodalTextbox(value={"text": "", "files": []}, interactive=False)

        def bot_generates(
            history,
            style_preset,
            aspect_choice,
            steps,
            cfg,
            strength,
            custom_negative,
            seed,
            auto_distill
        ):
            if not history:
                yield history, gr.MultimodalTextbox(interactive=True)
                return

            last_user_msg = None
            for msg in reversed(history):
                if isinstance(msg, dict) and msg.get("role") == "user":
                    last_user_msg = msg
                    break

            if not last_user_msg:
                yield history, gr.MultimodalTextbox(interactive=True)
                return

            raw_text, files = extract_prompt_and_files(last_user_msg)
            ref_image_path = files[0] if files else None

            # Add thinking assistant placeholder
            history.append({
                "role": "assistant",
                "content": "🎨 *Synthesizing diffusion latents on GPU...*"
            })
            yield history, gr.MultimodalTextbox(interactive=False)

            assistant_reply = process_chat(
                raw_text=raw_text,
                ref_image_path=ref_image_path,
                style_preset=style_preset,
                aspect_choice=aspect_choice,
                steps=steps,
                cfg=cfg,
                strength=strength,
                custom_negative=custom_negative,
                seed=seed,
                auto_distill=auto_distill
            )

            history[-1]["content"] = assistant_reply
            yield history, gr.MultimodalTextbox(interactive=True)

        # Wire Chat events
        chat_submission = chat_input.submit(
            fn=user_submits,
            inputs=[chat_input, chatbot],
            outputs=[chatbot, chat_input],
            queue=False
        ).then(
            fn=bot_generates,
            inputs=[
                chatbot,
                preset_dropdown,
                aspect_dropdown,
                slider_steps,
                slider_cfg,
                slider_strength,
                custom_neg_input,
                seed_input,
                auto_distill_chk
            ],
            outputs=[chatbot, chat_input]
        )

        btn_clear.click(fn=clear_chat, outputs=[chatbot])

    return demo

if __name__ == "__main__":
    port = int(os.environ.get("STUDIO_CHAT_PORT", 7860))
    app = create_ui()
    app.queue(default_concurrency_limit=1).launch(
        server_name="127.0.0.1",
        server_port=port,
        share=False,
        inbrowser=False,
        theme=gr.themes.Base(),
        css=CUSTOM_CSS
    )
