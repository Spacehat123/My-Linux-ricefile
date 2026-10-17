#!/usr/bin/env python3
"""
Fast-Caption: Ultra-fast Video/Audio Subtitle Generator & Extractor
Powered by NVIDIA FastConformer-CTC (NeMo 244M) via sherpa-onnx.

Features:
- Instant Extraction: If video already contains an embedded subtitle track, rips it in ~0.2s.
- Ultra-Fast Local Transcription: Uses NVIDIA FastConformer-CTC on GPU (<30s for 1-hour audio).
- Dual Output Structure:
  1. Standalone editable caption file: <video_dir>/<name>.srt
  2. Centralized study/notes archive: ~/Music/caption_extracts/<name>.srt
  3. Soft-subtitled video: <video_dir>/<name>_subtitled.mp4 (lossless, toggleable CC track)
"""

import sys
import os
import time
import json
import shutil
import argparse
import tempfile
import subprocess
from pathlib import Path

# Paths
DEFAULT_ARCHIVE_DIR = Path.home() / "Music/caption_extracts"
MODELS_DIR = Path.home() / ".local/share/cool-shell/models"
MODEL_REPO = "csukuangfj/sherpa-onnx-nemo-fast-conformer-ctc-en-24500"

def ensure_dirs():
    DEFAULT_ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
    MODELS_DIR.mkdir(parents=True, exist_ok=True)

def format_timestamp(seconds: float) -> str:
    """Formats float seconds into SRT timestamp HH:MM:SS,mmm"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int(round((seconds - int(seconds)) * 1000))
    if millis >= 1000:
        millis = 999
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"

def probe_video(video_path: Path):
    """Probes media file with ffprobe for duration and streams."""
    cmd = [
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration:stream=index,codec_type,codec_name:stream_tags=language,title",
        "-of", "json",
        str(video_path)
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return json.loads(res.stdout)
    except Exception as e:
        print(f"[!] Warning: ffprobe failed ({e})", file=sys.stderr)
        return {}

def extract_existing_subtitles(video_path: Path, stream_idx: int, out_srt_path: Path) -> bool:
    """Rips an embedded subtitle stream directly to .srt in ~0.2s."""
    cmd = [
        "ffmpeg", "-y", "-v", "error",
        "-i", str(video_path),
        "-map", f"0:{stream_idx}",
        "-c:s", "srt",
        str(out_srt_path)
    ]
    res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return res.returncode == 0 and out_srt_path.exists() and out_srt_path.stat().st_size > 0

def extract_audio_wav(video_path: Path, out_wav_path: Path) -> bool:
    """Extracts 16kHz mono PCM WAV from media file using ffmpeg."""
    cmd = [
        "ffmpeg", "-y", "-v", "error",
        "-i", str(video_path),
        "-vn",
        "-ac", "1",
        "-ar", "16000",
        "-c:a", "pcm_s16le",
        str(out_wav_path)
    ]
    res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return res.returncode == 0 and out_wav_path.exists()

def get_or_download_model():
    """Returns (model_path, tokens_path), downloading from HuggingFace if not cached."""
    try:
        from huggingface_hub import hf_hub_download
    except ImportError:
        subprocess.run(["uv", "pip", "install", "huggingface_hub"], check=True)
        from huggingface_hub import hf_hub_download

    print("[*] Checking FastConformer-CTC (244M) model files...")
    model_path = hf_hub_download(repo_id=MODEL_REPO, filename="model.onnx")
    tokens_path = hf_hub_download(repo_id=MODEL_REPO, filename="tokens.txt")
    return model_path, tokens_path

def build_srt_blocks(result, audio_duration: float) -> list:
    """
    Constructs clean, professional SRT subtitle blocks from FastConformer result.
    Groups tokens/words by pauses (>0.5s) or line length (max 8 words / 3.5s).
    """
    text = getattr(result, "text", "").strip()
    if not text:
        return []

    words = getattr(result, "words", [])
    timestamps = getattr(result, "timestamps", [])

    blocks = []

    # If word-level / token-level timestamps are provided
    if timestamps and len(timestamps) > 0:
        raw_tokens = getattr(result, "tokens", [])
        
        # Merge BPE / subword tokens into full words with timestamps
        items = []
        cur_word = ""
        cur_start = None
        cur_end = None
        
        for i, tok in enumerate(raw_tokens):
            t_start = timestamps[i]
            t_end = t_start + 0.3
            if i + 1 < len(timestamps):
                t_end = min(t_start + 0.5, timestamps[i + 1])
                
            if tok.startswith(" ") or tok.startswith(" "):
                if cur_word and cur_start is not None:
                    items.append((cur_word.strip(), cur_start, cur_end))
                cur_word = tok.replace(" ", "").replace(" ", "")
                cur_start = t_start
                cur_end = t_end
            else:
                cur_word += tok
                cur_end = t_end
                if cur_start is None:
                    cur_start = t_start

        if cur_word and cur_start is not None:
            items.append((cur_word.strip(), cur_start, cur_end))

        # Group words into clean subtitle blocks
        cur_block_words = []
        block_start = None
        block_end = None

        for word, w_start, w_end in items:
            if not word:
                continue
            if block_start is None:
                block_start = w_start
                block_end = w_end
                cur_block_words = [word]
                continue

            # Check break conditions: pause > 0.55s, or line too long (>8 words), or duration > 3.8s
            pause = w_start - block_end
            too_many_words = len(cur_block_words) >= 8
            too_long_time = (w_end - block_start) >= 3.8

            if pause > 0.55 or too_many_words or too_long_time:
                sentence = " ".join(cur_block_words)
                sentence = sentence[0].upper() + sentence[1:] if len(sentence) > 1 else sentence.upper()
                blocks.append((block_start, block_end, sentence))
                
                block_start = w_start
                block_end = w_end
                cur_block_words = [word]
            else:
                cur_block_words.append(word)
                block_end = w_end

        if cur_block_words and block_start is not None:
            sentence = " ".join(cur_block_words)
            sentence = sentence[0].upper() + sentence[1:] if len(sentence) > 1 else sentence.upper()
            blocks.append((block_start, min(audio_duration, block_end + 0.4), sentence))

    else:
        # Fallback: segment-level breakdown or single block
        blocks.append((0.0, audio_duration, text))

    return blocks

def write_srt_file(blocks: list, out_path: Path):
    """Writes list of (start_s, end_s, text) tuples to an SRT file."""
    with open(out_path, "w", encoding="utf-8") as f:
        for idx, (start_s, end_s, text) in enumerate(blocks, start=1):
            f.write(f"{idx}\n")
            f.write(f"{format_timestamp(start_s)} --> {format_timestamp(end_s)}\n")
            f.write(f"{text.strip()}\n\n")

def embed_soft_subtitles(video_path: Path, srt_path: Path, output_video_path: Path) -> bool:
    """Losslessly multiplexes subtitle stream into video container using ffmpeg stream copy."""
    ext = video_path.suffix.lower()
    sub_codec = "mov_text" if ext in (".mp4", ".m4v", ".mov") else "srt"
    
    cmd = [
        "ffmpeg", "-y", "-v", "error",
        "-i", str(video_path),
        "-i", str(srt_path),
        "-c", "copy",
        "-c:s", sub_codec,
        "-metadata:s:s:0", "language=eng",
        "-metadata:s:s:0", "title=English",
        str(output_video_path)
    ]
    res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return res.returncode == 0 and output_video_path.exists()

def transcribe_audio_with_fastconformer(wav_path: Path, provider: str = "cuda"):
    """Runs NVIDIA FastConformer-CTC using sherpa-onnx on GPU/CPU."""
    import sherpa_onnx
    import soundfile as sf

    model_path, tokens_path = get_or_download_model()

    print(f"[*] Initializing FastConformer-CTC runtime (provider={provider})...")
    try:
        recognizer = sherpa_onnx.OfflineRecognizer.from_nemo_ctc(
            model=model_path,
            tokens=tokens_path,
            num_threads=4,
            sample_rate=16000,
            feature_dim=80,
            decoding_method="greedy_search",
            debug=False,
            provider=provider
        )
    except Exception as e:
        if provider == "cuda":
            print(f"[!] CUDA provider error ({e}). Falling back to optimized multi-thread CPU...")
            recognizer = sherpa_onnx.OfflineRecognizer.from_nemo_ctc(
                model=model_path,
                tokens=tokens_path,
                num_threads=6,
                sample_rate=16000,
                feature_dim=80,
                decoding_method="greedy_search",
                debug=False,
                provider="cpu"
            )
        else:
            raise e

    # Read audio samples
    samples, sample_rate = sf.read(str(wav_path), dtype="float32")
    audio_duration = len(samples) / sample_rate

    # Create stream and decode
    stream = recognizer.create_stream()
    stream.accept_waveform(sample_rate, samples)

    t0 = time.time()
    recognizer.decode_stream(stream)
    elapsed = time.time() - t0

    result = stream.result
    return result, audio_duration, elapsed

def process_video(video_file: Path, args):
    video_path = video_file.resolve()
    if not video_path.exists():
        print(f"[!] Error: File '{video_path}' does not exist.", file=sys.stderr)
        return False

    ensure_dirs()
    archive_dir = Path(args.archive_dir).expanduser() if args.archive_dir else DEFAULT_ARCHIVE_DIR
    archive_dir.mkdir(parents=True, exist_ok=True)

    base_name = video_path.stem
    parent_dir = video_path.parent
    local_srt_path = parent_dir / f"{base_name}.srt"
    archive_srt_path = archive_dir / f"{base_name}.srt"
    subtitled_video_path = parent_dir / f"{base_name}_subtitled{video_path.suffix}"

    print("=" * 64)
    print(f"🎬 Processing: {video_path.name}")
    print("=" * 64)

    t_start_total = time.time()

    # Step 1: Probe for existing subtitle track
    probe_info = probe_video(video_path)
    streams = probe_info.get("streams", [])
    format_info = probe_info.get("format", {})
    duration_sec = float(format_info.get("duration", 0.0))

    sub_streams = [s for s in streams if s.get("codec_type") == "subtitle"]

    if sub_streams and not args.force:
        sub_stream = sub_streams[0]
        s_idx = sub_stream.get("index", 2)
        lang = sub_stream.get("tags", {}).get("language", "unknown")
        print(f"[⚡] Existing subtitle track detected! (Stream #{s_idx}, lang={lang})")
        print(f"[*] Extracting track instantly (skipping speech-to-text)...")

        t0 = time.time()
        ok = extract_existing_subtitles(video_path, s_idx, local_srt_path)
        t_extract = time.time() - t0

        if ok:
            # Copy to archive
            shutil.copy2(local_srt_path, archive_srt_path)
            print(f"[✔] Extracted in {t_extract:.2f}s!")
            print(f"  • Local Caption:   {local_srt_path}")
            print(f"  • Archive Library: {archive_srt_path}")
            print("=" * 64)
            return True
        else:
            print("[!] Extraction returned empty. Proceeding to GPU speech-to-text...")

    # Step 2: Extract audio to temporary WAV
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_wav:
        tmp_wav_path = Path(tmp_wav.name)

    try:
        print("[*] Extracting 16kHz mono audio stream...")
        t_audio_0 = time.time()
        if not extract_audio_wav(video_path, tmp_wav_path):
            print("[!] Error extracting audio from video.", file=sys.stderr)
            return False
        t_audio = time.time() - t_audio_0
        print(f"[✔] Audio extracted in {t_audio:.2f}s")

        # Step 3: Run FastConformer-CTC Transcription
        print("[*] Running NVIDIA FastConformer-CTC transcription on GPU...")
        result, audio_dur, t_infer = transcribe_audio_with_fastconformer(tmp_wav_path, provider=args.provider)
        rtf = t_infer / max(1.0, audio_dur)
        print(f"[✔] Transcribed {audio_dur:.1f}s of audio in {t_infer:.2f}s! (Speed: {1/rtf:.1f}x real-time)")

        # Step 4: Write SRT files
        blocks = build_srt_blocks(result, audio_dur)
        write_srt_file(blocks, local_srt_path)
        shutil.copy2(local_srt_path, archive_srt_path)
        print(f"[✔] Generated {len(blocks)} subtitle lines.")

        # Step 5: Embed Soft Subtitles into Video
        has_video = any(s.get("codec_type") == "video" for s in streams)
        if not args.no_embed and has_video:
            print(f"[*] Embedding soft subtitle track into video container...")
            t_mux_0 = time.time()
            if embed_soft_subtitles(video_path, local_srt_path, subtitled_video_path):
                t_mux = time.time() - t_mux_0
                print(f"[✔] Embedded in {t_mux:.2f}s (lossless copy mode)!")
            else:
                print("[!] Subtitle muxing warning: failed to embed soft-sub track.")
        elif not has_video:
            print("[*] Audio-only media detected; skipping video embed.")

        t_total = time.time() - t_start_total

        print("=" * 64)
        print(f"🎉 Complete in {t_total:.1f} seconds total!")
        print(f"  1. Caption File:     {local_srt_path}")
        print(f"  2. Archive Library:  {archive_srt_path}")
        if not args.no_embed and has_video and subtitled_video_path.exists():
            print(f"  3. Subtitled Video:  {subtitled_video_path}")
        print("=" * 64)
        return True

    finally:
        if tmp_wav_path.exists():
            tmp_wav_path.unlink(missing_ok=True)

def main():
    parser = argparse.ArgumentParser(
        description="Fast-Caption: Sub-minute video captions with NVIDIA FastConformer-CTC"
    )
    parser.add_argument("video", help="Path to input video or audio file")
    parser.add_argument("--archive-dir", help="Directory to save central copy of captions (default: ~/Music/caption_extracts)")
    parser.add_argument("--no-embed", action="store_true", help="Do not create a subtitled video file; only produce .srt")
    parser.add_argument("--force", action="store_true", help="Force GPU transcription even if video already has embedded subtitles")
    parser.add_argument("--provider", default="cuda", choices=["cuda", "cpu"], help="Inference provider (default: cuda)")

    args = parser.parse_args()
    success = process_video(Path(args.video), args)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
