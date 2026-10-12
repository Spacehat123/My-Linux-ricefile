#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "kokoro-onnx",
#   "onnxruntime-gpu",
#   "soundfile",
#   "numpy",
# ]
# [tool.uv]
# override-dependencies = [
#   "onnxruntime==0.0.0; extra == 'none'"
# ]
# ///
import sys
import os
import re
import subprocess
import signal

os.environ["OMP_THREAD_LIMIT"] = "2"

LOCAL_BIN = os.path.expanduser("~/.local/bin")
LOCAL_LIB = os.path.expanduser("~/.local/lib")
ESPEAK_DATA = os.path.expanduser("~/.local/share/espeak-ng-data")

# Wire up local CUDA 13 / cuDNN 9 libraries if present
UNSLOTH_CUDA = os.path.expanduser("~/.unsloth/studio/unsloth_studio/lib/python3.13/site-packages/nvidia/cu13/lib")
UNSLOTH_CUDNN = os.path.expanduser("~/.unsloth/studio/unsloth_studio/lib/python3.13/site-packages/nvidia/cudnn/lib")
if os.path.isdir(UNSLOTH_CUDA) and os.path.isdir(UNSLOTH_CUDNN):
    current_ld = os.environ.get("LD_LIBRARY_PATH", "")
    if UNSLOTH_CUDA not in current_ld:
        os.environ["LD_LIBRARY_PATH"] = f"{UNSLOTH_CUDA}:{UNSLOTH_CUDNN}:{LOCAL_LIB}:{current_ld}"
        if not os.environ.get("_VOICE_CUDA_REEXEC"):
            os.environ["_VOICE_CUDA_REEXEC"] = "1"
            os.execv(sys.executable, [sys.executable] + sys.argv)

env = os.environ.copy()
env["PATH"] = f"{LOCAL_BIN}:{env.get('PATH', '')}"
env["LD_LIBRARY_PATH"] = f"{LOCAL_LIB}:{env.get('LD_LIBRARY_PATH', '')}"
env["ESPEAK_DATA_PATH"] = ESPEAK_DATA

MODEL_DIR = os.path.expanduser("~/.local/share/cool-shell/models")
KOKORO_MODEL = os.path.join(MODEL_DIR, "kokoro", "kokoro-v1.0.int8.onnx")
KOKORO_VOICES = os.path.join(MODEL_DIR, "kokoro", "voices-v1.0.bin")

KITTEN_MODEL = os.path.join(MODEL_DIR, "kitten", "kitten_tts_nano_v0_8.onnx")
KITTEN_VOICES = os.path.join(MODEL_DIR, "kitten", "voices.npz")

WAV_OUT = "/tmp/screen_lens_read.wav"
ALERT_OUT = "/tmp/system_alert.wav"

def notify_island_voice(playing: bool):
    try:
        subprocess.run(
            ["qs", "-c", "cool-shell", "ipc", "call", "island", "setVoicePlaying", "true" if playing else "false"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1
        )
    except Exception:
        pass

def stop_playback():
    try:
        subprocess.run(["pkill", "-f", "voice-engine.*read"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["pkill", "-f", "pw-play.*--raw"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["pkill", "-f", "pw-play /tmp/screen_lens_read.wav"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["pkill", "-f", "pw-play /tmp/system_alert.wav"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass
    notify_island_voice(False)

def split_clauses(text: str) -> list[str]:
    clean = re.sub(r'\s+', ' ', text).strip()
    parts = re.split(r'(?<=[.!?:;\n—–])\s+|(?<=,)\s+', clean)
    merged = []
    buf = ''
    for p in parts:
        p = p.strip()
        if not p:
            continue
        if len(buf.split()) < 4:
            buf = (buf + ' ' + p).strip()
        else:
            merged.append(buf)
            buf = p
    if buf:
        merged.append(buf)
    return merged or [clean]

def read_aloud_kokoro(text: str, voice: str = "af_heart"):
    """High-fidelity uninterrupted streaming reading via Kokoro-82M (85 MB int8)."""
    if not text.strip():
        return
    import threading
    import queue
    from kokoro_onnx import Kokoro

    notify_island_voice(True)

    proc = None
    stop_event = threading.Event()
    audio_q = queue.Queue()
    producer_done = threading.Event()

    try:
        import onnxruntime as ort
        sess_opts = ort.SessionOptions()
        sess_opts.log_severity_level = 3

        avail = ort.get_available_providers()
        providers = []
        if "CUDAExecutionProvider" in avail:
            providers.append("CUDAExecutionProvider")
        providers.append("CPUExecutionProvider")

        try:
            sess = ort.InferenceSession(KOKORO_MODEL, sess_opts, providers=providers)
            active_provider = sess.get_providers()[0] if sess.get_providers() else "CPUExecutionProvider"
            kokoro = Kokoro.from_session(sess, KOKORO_VOICES)
        except Exception:
            kokoro = Kokoro(KOKORO_MODEL, KOKORO_VOICES)
            active_provider = "CPUExecutionProvider"

        is_gpu = "CUDAExecutionProvider" in active_provider
        cushion_threshold = 2.0 if is_gpu else 5.0

        clauses = split_clauses(text)
        if not clauses:
            return

        def producer():
            for clause in clauses:
                if stop_event.is_set():
                    break
                try:
                    samples, sr = kokoro.create(clause, voice=voice, speed=1.05, lang="en-us")
                    audio_q.put((samples, sr))
                except Exception:
                    break
            producer_done.set()

        prod_thread = threading.Thread(target=producer, daemon=True)
        prod_thread.start()

        # Lookahead pre-buffer: on GPU 2.0s starts in ~1.5s; on CPU 5.0s guarantees 0 stutter
        buffered_dur = 0.0
        buffer_chunks = []
        while buffered_dur < cushion_threshold and not producer_done.is_set() and not stop_event.is_set():
            try:
                samples, sr = audio_q.get(timeout=0.1)
                buffered_dur += len(samples) / sr
                buffer_chunks.append(samples)
            except queue.Empty:
                pass

        if not buffer_chunks and audio_q.empty():
            return

        proc = subprocess.Popen(
            ["pw-play", "--raw", "--rate", "24000", "--channels", "1", "--format", "f32", "-"],
            stdin=subprocess.PIPE
        )

        for samples in buffer_chunks:
            if proc.poll() is not None:
                stop_event.set()
                break
            proc.stdin.write(samples.tobytes())
            proc.stdin.flush()

        while (not producer_done.is_set() or not audio_q.empty()) and not stop_event.is_set():
            try:
                samples, sr = audio_q.get(timeout=0.2)
                if proc.poll() is not None:
                    stop_event.set()
                    break
                proc.stdin.write(samples.tobytes())
                proc.stdin.flush()
            except queue.Empty:
                if proc.poll() is not None:
                    break

        if proc and proc.stdin:
            proc.stdin.close()
            proc.wait()
    except Exception as e:
        print(f"Error in Kokoro read aloud: {e}", file=sys.stderr)
    finally:
        stop_event.set()
        if proc and proc.poll() is None:
            proc.terminate()
        notify_island_voice(False)

def alert_kitten(text: str, voice_key: str = "expr-voice-2-f"):
    """Ultra-low-latency system announcer via KittenTTS nano (25 MB int8)."""
    if not text.strip():
        return
    import numpy as np
    import soundfile as sf
    import onnxruntime as ort

    try:
        # 1. Phonemize text via espeak-ng
        p = subprocess.run(
            ["espeak-ng", "-q", "--ipa=3", "-v", "en-us", text.strip()],
            capture_output=True,
            text=True,
            env=env
        )
        raw_ipa = p.stdout.strip()
        if not raw_ipa:
            return

        # 2. Tokenize phonemes
        _pad = "$"
        _punctuation = ';:,.!?¡¿—…"«»"" '
        _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
        _letters_ipa = "ɑɐɒæɓʙβɔɕçɗɖðʤəɘɚɛɜɝɞɟʄɡɠɢʛɦɧħɥʜɨɪʝɭɬɫɮʟɱɯɰŋɳɲɴøɵɸθœɶʘɹɺɾɻʀʁɽʂʃʈʧʉʊʋⱱʌɣɤʍχʎʏʑʐʒʔʡʕʢǀǁǂǃˈˌːˑʼʴʰʱʲʷˠˤ˞↓↑→↗↘'̩'ᵻ"
        symbols = [_pad] + list(_punctuation) + list(_letters) + list(_letters_ipa)
        word_index = {sym: idx for idx, sym in enumerate(symbols)}

        tokens_words = re.findall(r"\w+|[^\w\s]", raw_ipa)
        phonemes = " ".join(tokens_words)
        tokens = [word_index[c] for c in phonemes if c in word_index]
        tokens = [0] + tokens + [10, 0]
        input_ids = np.array([tokens], dtype=np.int64)

        # 3. Load ONNX and voice style
        session = ort.InferenceSession(KITTEN_MODEL)
        voices = np.load(KITTEN_VOICES)
        if voice_key not in voices:
            voice_key = list(voices.keys())[0]
        style = voices[voice_key][0:1]
        speed = np.array([1.0], dtype=np.float32)

        outputs = session.run(None, {"input_ids": input_ids, "style": style, "speed": speed})
        audio = outputs[0][..., :-5000]
        sf.write(ALERT_OUT, audio, 24000)

        # 4. Play alert
        subprocess.run(["pw-play", ALERT_OUT], check=True)
    except Exception as e:
        print(f"Error in KittenTTS alert: {e}", file=sys.stderr)

def main():
    if len(sys.argv) < 2:
        print("Usage: voice-engine.py <read|alert|stop> [text_or_file]")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "stop":
        stop_playback()
        return

    if cmd == "alert":
        msg = " ".join(sys.argv[2:]) if len(sys.argv) >= 3 else "System alert"
        alert_kitten(msg)
        return

    if cmd == "read":
        text = ""
        if len(sys.argv) >= 3:
            arg = sys.argv[2]
            if os.path.isfile(arg):
                with open(arg, "r", encoding="utf-8", errors="ignore") as f:
                    text = f.read()
            else:
                text = " ".join(sys.argv[2:])
        else:
            default_file = "/tmp/screen-lens-last.txt"
            if os.path.isfile(default_file):
                with open(default_file, "r", encoding="utf-8", errors="ignore") as f:
                    text = f.read()

        read_aloud_kokoro(text)
        return

if __name__ == "__main__":
    main()
