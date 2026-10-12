#!/home/pranc/.unsloth/studio/unsloth_studio/bin/python3
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

    # Wait up to 45s for daemon to initialize and load weights into CPU RAM
    t_start = time.time()
    while time.time() - t_start < 45:
        time.sleep(0.4)
        if is_socket_alive():
            print(f"[+] Daemon ready in {time.time()-t_start:.1f}s", file=sys.stderr)
            return True

    print("[-] Daemon did not respond in time.", file=sys.stderr)
    return False

def send_prompt(prompt: str, out_path: str = None) -> dict:
    if not ensure_daemon_running():
        # Fallback to direct import and run
        print("[!] Falling back to direct execution...", file=sys.stderr)
        import importlib.util
        spec = importlib.util.spec_from_file_location("image_daemon", DAEMON_SCRIPT)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod.run_generation(prompt, out_path)

    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(180) # 3 min max timeout for safety
        s.connect(SOCKET_PATH)
        req = {"action": "generate", "prompt": prompt}
        if out_path:
            req["out_path"] = out_path
        s.sendall(json.dumps(req).encode("utf-8"))
        data = s.recv(16384)
        s.close()
        return json.loads(data.decode("utf-8"))
    except Exception as e:
        print(f"[-] Error communicating with daemon: {e}", file=sys.stderr)
        return {"status": "error", "error": str(e)}

def get_status() -> dict:
    if not os.path.exists(SOCKET_PATH):
        return {"loaded": False}
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(1.0)
        s.connect(SOCKET_PATH)
        s.sendall(json.dumps({"action": "status"}).encode("utf-8"))
        data = s.recv(1024)
        s.close()
        res = json.loads(data.decode("utf-8"))
        return {"loaded": res.get("loaded", False), "idle_sec": res.get("idle_sec", 0)}
    except Exception:
        return {"loaded": False}

def stop_daemon() -> dict:
    if not os.path.exists(SOCKET_PATH):
        return {"loaded": False}
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
            os.kill(pid, 15)
        except Exception:
            pass
    return {"loaded": False}

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

def notify_island_done():
    try:
        subprocess.run(
            ["qs", "-c", "cool-shell", "ipc", "call", "island", "setAiGenerating", "false", ""],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=3
        )
    except Exception:
        try:
            subprocess.run(
                ["quickshell", "-c", "cool-shell", "ipc", "call", "island", "setAiGenerating", "false", ""],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=3
            )
        except Exception:
            pass

def main():
    if len(sys.argv) < 2:
        print("Usage: image-engine.py [--preload | --status | --stop | <prompt>] [out_path]")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "--preload":
        success = ensure_daemon_running()
        print(json.dumps({"loaded": success}))
        sys.exit(0 if success else 1)
    elif cmd == "--status":
        print(json.dumps(get_status()))
        sys.exit(0)
    elif cmd == "--stop":
        print(json.dumps(stop_daemon()))
        sys.exit(0)

    prompt = cmd
    out_path = sys.argv[2] if len(sys.argv) >= 3 else None

    exit_code = 0
    try:
        result = send_prompt(prompt, out_path)
        if result.get("status") == "ok":
            img_path = result.get("path", "")
            print(f"RESULT:{img_path}")
            print(f"Successfully generated in {result.get('elapsed')}s: {img_path}")
            open_viewer(img_path)
        else:
            print(f"Generation failed: {result.get('error', 'unknown error')}", file=sys.stderr)
            exit_code = 1
    except Exception as e:
        print(f"Exception during generation: {e}", file=sys.stderr)
        exit_code = 1
    finally:
        notify_island_done()
    sys.exit(exit_code)

if __name__ == "__main__":
    main()
