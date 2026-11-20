#!/usr/bin/env python3
"""
Cool-Shell Image Engine Client
Connects to the background image daemon (/tmp/cool-shell-image.sock) for warm <10-25s inference.
If the daemon is not running, it auto-spawns it in the background and delivers the prompt.
"""
import sys
import os
import time
import socket
import json
import subprocess

os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["TRANSFORMERS_OFFLINE"] = "1"
os.environ["HF_DATASETS_OFFLINE"] = "1"
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

SOCKET_PATH = "/tmp/cool-shell-image.sock"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DAEMON_SCRIPT = os.path.join(SCRIPT_DIR, "image-daemon.py")

PID_FILE = "/tmp/cool-shell-image.pid"
LOCK_FILE = "/tmp/cool-shell-image.lock"

def is_socket_alive() -> bool:
    if not os.path.exists(SOCKET_PATH):
        return False
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(1.5)
        s.connect(SOCKET_PATH)
        s.sendall(json.dumps({"action": "ping"}).encode("utf-8"))
        data = s.recv(1024)
        s.close()
        res = json.loads(data.decode("utf-8"))
        return res.get("status") == "pong"
    except Exception:
        return False

def is_daemon_process_alive() -> bool:
    if not os.path.exists(PID_FILE):
        return False
    try:
        with open(PID_FILE, "r") as f:
            pid = int(f.read().strip())
        os.kill(pid, 0)
        return True
    except Exception:
        return False

def ensure_daemon_running() -> bool:
    if is_socket_alive():
        return True

    # Avoid spawning multiple daemons concurrently
    if not is_daemon_process_alive():
        print("[*] Image daemon not running. Spawning in background...", file=sys.stderr)
        try:
            subprocess.Popen(
                [sys.executable, DAEMON_SCRIPT, "--daemon"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )
        except Exception as e:
            print(f"[-] Failed to spawn image daemon: {e}", file=sys.stderr)
            return False

    # Wait up to 180s for daemon to initialize and load weights into CPU RAM
    t_start = time.time()
    while time.time() - t_start < 180:
        time.sleep(0.5)
        if is_socket_alive():
            print(f"[+] Daemon ready in {time.time()-t_start:.1f}s", file=sys.stderr)
            return True
        if not is_daemon_process_alive():
            print("[-] Daemon process terminated unexpectedly.", file=sys.stderr)
            break

    print("[-] Daemon did not respond in time.", file=sys.stderr)
    return False

def send_prompt(
    prompt: str,
    out_path: str = None,
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
    if not ensure_daemon_running():
        # Fallback to direct import and run
        print("[!] Falling back to direct execution...", file=sys.stderr)
        import importlib.util
        spec = importlib.util.spec_from_file_location("image_daemon", DAEMON_SCRIPT)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod.run_generation(
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

    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(180) # 3 min max timeout for safety
        s.connect(SOCKET_PATH)
        req = {
            "action": "generate",
            "prompt": prompt,
            "width": width,
            "height": height,
            "steps": steps,
            "cfg": cfg,
            "image_path": image_path,
            "strength": strength,
            "negative_prompt": negative_prompt,
            "seed": seed,
            "purge_previous": purge_previous
        }
        if out_path:
            req["out_path"] = out_path
        s.sendall(json.dumps(req).encode("utf-8"))
        data = s.recv(16384)
        s.close()
        return json.loads(data.decode("utf-8"))
    except Exception as e:
        print(f"[-] Error communicating with daemon: {e}", file=sys.stderr)
        return {"status": "error", "error": str(e)}

def get_process_rss_mb_by_pid(pid: int) -> float:
    try:
        with open(f"/proc/{pid}/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return round(int(line.split()[1]) / 1024.0, 1)
    except Exception:
        pass
    return 0.0

def get_status() -> dict:
    if os.path.exists(SOCKET_PATH):
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(1.5)
            s.connect(SOCKET_PATH)
            s.sendall(json.dumps({"action": "status"}).encode("utf-8"))
            data = s.recv(1024)
            s.close()
            res = json.loads(data.decode("utf-8"))
            return {
                "loaded": res.get("loaded", False),
                "loading": False,
                "pid": res.get("pid", 0),
                "ram_mb": res.get("ram_mb", 0.0),
                "idle_sec": res.get("idle_sec", 0)
            }
        except Exception:
            pass

    # Check if daemon process is currently starting/loading in background
    if is_daemon_process_alive():
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            rss = get_process_rss_mb_by_pid(pid)
            return {
                "loaded": False,
                "loading": True,
                "pid": pid,
                "ram_mb": rss,
                "idle_sec": 0.0
            }
        except Exception:
            pass

    return {"loaded": False, "loading": False, "ram_mb": 0.0}

def stop_daemon() -> dict:
    if os.path.exists(SOCKET_PATH):
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(1.5)
            s.connect(SOCKET_PATH)
            s.sendall(json.dumps({"action": "stop"}).encode("utf-8"))
            data = s.recv(1024)
            s.close()
        except Exception:
            pass

    # Force kill any lingering daemon process if PID file exists
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            t_wait = time.time()
            while time.time() - t_wait < 1.5:
                try:
                    os.kill(pid, 0)
                    time.sleep(0.1)
                except ProcessLookupError:
                    break
            try:
                os.kill(pid, 9)
            except Exception:
                pass
        except Exception:
            pass

    for p in (SOCKET_PATH, PID_FILE, "/tmp/cool-shell-image.lock"):
        if os.path.exists(p):
            try:
                os.unlink(p)
            except Exception:
                pass

    return {"loaded": False, "loading": False, "ram_mb": 0.0}

SETTINGS_FILE = os.path.join(os.path.dirname(SCRIPT_DIR), "island", "ai-settings.json")

def get_saved_setting(key: str, default):
    if os.path.exists(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r") as f:
                data = json.load(f)
                if isinstance(data, dict) and key in data:
                    return data[key]
        except Exception:
            pass
    return default

def should_auto_open(flag_override: bool = None) -> bool:
    if flag_override is not None:
        return flag_override
    return bool(get_saved_setting("autoOpen", True))

def open_viewer(path: str):
    if not path or not os.path.exists(path):
        return
    env = os.environ.copy()
    try:
        subprocess.Popen(["swappy", "-f", path], env=env, start_new_session=True)
        return
    except Exception as e:
        print(f"[-] swappy failed: {e}", file=sys.stderr)
    try:
        subprocess.Popen(["xdg-open", path], env=env, start_new_session=True)
    except Exception:
        pass

def notify_island_done(status_msg: str = ""):
    for cmd in [
        ["quickshell", "-c", "cool-shell", "ipc", "call", "island", "setAiGenerating", "false", status_msg],
        ["qs", "-c", "cool-shell", "ipc", "call", "island", "setAiGenerating", "false", status_msg],
        ["qs", "-p", "/home/pranc/.config/quickshell/cool-shell", "ipc", "call", "island", "setAiGenerating", "false", status_msg]
    ]:
        try:
            res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
            if res.returncode == 0:
                break
        except Exception:
            pass

def main():
    if len(sys.argv) < 2:
        print("Usage: image-engine.py [--preload | --status | --stop | [--no-open | --open] [--aspect 1:1|16:9] [--steps N] [--cfg F] <prompt>] [out_path]")
        sys.exit(1)

    args = sys.argv[1:]
    if args[0] == "--preload":
        success = ensure_daemon_running()
        print(json.dumps({"loaded": success}))
        sys.exit(0 if success else 1)
    elif args[0] == "--status":
        print(json.dumps(get_status()))
        sys.exit(0)
    elif args[0] == "--stop":
        print(json.dumps(stop_daemon()))
        sys.exit(0)

    auto_open_flag = None
    aspect_arg = None
    steps_arg = None
    cfg_arg = None
    image_arg = None
    strength_arg = None
    filtered_args = []

    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--no-open":
            auto_open_flag = False
        elif arg == "--open":
            auto_open_flag = True
        elif arg == "--aspect":
            i += 1
            if i < len(args):
                aspect_arg = args[i]
        elif arg.startswith("--aspect="):
            aspect_arg = arg.split("=", 1)[1]
        elif arg == "--steps":
            i += 1
            if i < len(args):
                try:
                    steps_arg = int(args[i])
                except ValueError:
                    pass
        elif arg.startswith("--steps="):
            try:
                steps_arg = int(arg.split("=", 1)[1])
            except ValueError:
                pass
        elif arg == "--cfg":
            i += 1
            if i < len(args):
                try:
                    cfg_arg = float(args[i])
                except ValueError:
                    pass
        elif arg.startswith("--cfg="):
            try:
                cfg_arg = float(arg.split("=", 1)[1])
            except ValueError:
                pass
        elif arg in ("--image", "--ref"):
            i += 1
            if i < len(args):
                image_arg = args[i]
        elif arg.startswith("--image=") or arg.startswith("--ref="):
            image_arg = arg.split("=", 1)[1]
        elif arg == "--strength":
            i += 1
            if i < len(args):
                try:
                    strength_arg = float(args[i])
                except ValueError:
                    pass
        elif arg.startswith("--strength="):
            try:
                strength_arg = float(arg.split("=", 1)[1])
            except ValueError:
                pass
        else:
            filtered_args.append(arg)
        i += 1

    if not filtered_args:
        print("Usage: image-engine.py [--preload | --status | --stop | [--no-open | --open] [--aspect 1:1|16:9] [--steps N] [--cfg F] [--ref <image>] [--strength <0.1-0.95>] <prompt>] [out_path]")
        sys.exit(1)

    prompt = filtered_args[0]
    out_path = filtered_args[1] if len(filtered_args) > 1 else None
    auto_open = should_auto_open(auto_open_flag)

    aspect = aspect_arg if aspect_arg else get_saved_setting("aspectRatio", "1:1")
    steps = steps_arg if steps_arg is not None else int(get_saved_setting("steps", 8))
    cfg = cfg_arg if cfg_arg is not None else float(get_saved_setting("cfg", 1.8))
    strength = strength_arg if strength_arg is not None else float(get_saved_setting("strength", 0.65))
    image_path = image_arg

    if aspect == "16:9":
        width, height = 768, 432
    else:
        width, height = 512, 512

    exit_code = 0
    try:
        result = send_prompt(
            prompt,
            out_path=out_path,
            width=width,
            height=height,
            steps=steps,
            cfg=cfg,
            image_path=image_path,
            strength=strength
        )
        if result.get("status") == "ok":
            img_path = result.get("path", "")
            print(f"RESULT:{img_path}")
            print(f"Successfully generated in {result.get('elapsed')}s: {img_path}")
            if auto_open:
                print(f"[*] Auto-opening viewer for {img_path}")
                open_viewer(img_path)
            else:
                print(f"[*] Auto-open is disabled. Image saved at {img_path}")
            notify_island_done("Image Ready!" if auto_open else "Image Saved!")
        else:
            err = result.get("error", "unknown error")
            print(f"Generation failed: {err}", file=sys.stderr)
            notify_island_done(f"Failed: {err[:22]}")
            exit_code = 1
    except Exception as e:
        print(f"Exception during generation: {e}", file=sys.stderr)
        notify_island_done(f"Failed: {str(e)[:22]}")
        exit_code = 1
    sys.exit(exit_code)

if __name__ == "__main__":
    main()
