#!/usr/bin/env python3
"""
Cool-Shell Study Mode Controller & Enforcement Daemon
Features:
- Dual-warning & cryptographic salted password verification (Studyudsob)
- Hard lockdown: survives reboots via persistent state, blocks early exit during countdown
- Allowed apps whitelist: Dolphin, Brave, PDF/Image readers (Okular, Evince, Zathura, Loupe, Gwenview, Imv, Swappy), terminal, MPV
- Distraction blocking: Auto-kills Spotify, Discord, Steam, games; tab-guard for non-study sites in Brave
- Lo-Fi Study Audio: Plays local MP3s from ~/Music/study/ via mpv without interruption
- Overtime Flow State: Counts UP after target duration with penalty-free exit
- GitHub-style Daily Contribution Tracker: Credits sessions to history.json
"""
import sys
import os
import time
import json
import hashlib
import argparse
import subprocess
import signal
import re
from pathlib import Path

STUDY_DIR = Path.home() / ".local/share/cool-shell/study"
STATE_FILE = STUDY_DIR / "state.json"
AUTH_FILE = STUDY_DIR / "auth.hash"
HISTORY_FILE = STUDY_DIR / "history.json"
PID_FILE = STUDY_DIR / "daemon.pid"
LOFI_DIR = Path.home() / "Music/study"

STUDY_DIR.mkdir(parents=True, exist_ok=True)
LOFI_DIR.mkdir(parents=True, exist_ok=True)

# Whitelisted application window classes in Hyprland
ALLOWED_CLASSES = {
    "brave",
    "brave-browser",
    "dolphin",
    "org.kde.dolphin",
    "kate",
    "org.kde.kate",
    "kwrite",
    "org.kde.kwrite",
    "okular",
    "org.kde.okular",
    "evince",
    "org.gnome.evince",
    "zathura",
    "org.pwmt.zathura",
    "loupe",
    "org.gnome.loupe",
    "gwenview",
    "org.kde.gwenview",
    "imv",
    "swappy",
    "foot",
    "kitty",
    "alacritty",
    "mpv",
    "quickshell",
    "zenity",
    "rofi"
}

# Whitelist allowed domains / keywords in Brave browser window titles
ALLOWED_BRAVE_KEYWORDS = [
    "boslive", "icai", "notebook", "gemini notebook", "notebooklm", "whatsapp",
    "new tab", "untitled", "settings", "extensions", "downloads", "sign in", "login", "accounts.google"
]

# Explicit distraction titles that trigger immediate tab closure
DISTRACTION_KEYWORDS = [
    "youtube", "reddit", "twitter", "x.com", "instagram", "twitch",
    "tiktok", "netflix", "prime video", "anime", "manga", "facebook",
    "discord", "chess", "kick.com", "hulu", "steam"
]

def ensure_auth_file():
    if not AUTH_FILE.exists():
        salt = os.urandom(16).hex()
        # Default password hashed with salt
        pwd = "Studyudsob"
        h = hashlib.sha256((salt + pwd).encode("utf-8")).hexdigest()
        data = {"salt": salt, "hash": h, "algo": "sha256"}
        with open(AUTH_FILE, "w") as f:
            json.dump(data, f)
        os.chmod(AUTH_FILE, 0o600)

def verify_password(candidate: str) -> bool:
    ensure_auth_file()
    try:
        with open(AUTH_FILE, "r") as f:
            data = json.load(f)
        salt = data.get("salt", "")
        expected = data.get("hash", "")
        candidate_hash = hashlib.sha256((salt + candidate).encode("utf-8")).hexdigest()
        return candidate_hash == expected
    except Exception as e:
        print(f"Error reading auth: {e}", file=sys.stderr)
        return False

def get_state() -> dict:
    if not STATE_FILE.exists():
        return {
            "active": False,
            "start_time": 0,
            "target_duration": 1800,  # 30 minutes
            "expiry_time": 0,
            "subject": "CA / ICAI Study",
            "overtime": False,
            "overtime_seconds": 0,
            "credited": False,
            "lofi_enabled": True
        }
    try:
        with open(STATE_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return {"active": False}

def save_state(state: dict):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)
    os.chmod(STATE_FILE, 0o600)

def get_history() -> dict:
    if not HISTORY_FILE.exists():
        return {}
    try:
        with open(HISTORY_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return {}

def record_completed_session():
    history = get_history()
    today = time.strftime("%Y-%m-%d")
    history[today] = history.get(today, 0) + 1
    with open(HISTORY_FILE, "w") as f:
        json.dump(history, f, indent=2)
    os.chmod(HISTORY_FILE, 0o600)

def notify_island(text: str, duration_ms: int = 4000):
    try:
        subprocess.run(
            ["qs", "-c", "cool-shell", "ipc", "call", "island", "showTransient", text, str(duration_ms)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2
        )
    except Exception:
        pass

def get_hyprland_clients() -> list:
    try:
        res = subprocess.run(["hyprctl", "-j", "clients"], capture_output=True, text=True, timeout=1.5)
        if res.returncode == 0 and res.stdout.strip():
            return json.loads(res.stdout)
    except Exception:
        pass
    return []

def enforce_distractions():
    # 1. Ensure Spotify playback is paused
    try:
        subprocess.run(["playerctl", "-p", "spotify", "pause"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1)
    except Exception:
        pass

    # 2. Check running windows
    clients = get_hyprland_clients()
    for client in clients:
        c_class = (client.get("class") or "").lower()
        c_title = (client.get("title") or "").lower()
        c_addr = client.get("address")

        if not c_addr:
            continue

        # Check application whitelist
        if c_class and c_class not in ALLOWED_CLASSES:
            # Check if it's Spotify, Steam, Discord, or any other distracting app
            subprocess.run(["hyprctl", "dispatch", "closewindow", f"address:{c_addr}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            continue

        # Check Brave browser tabs for forbidden websites
        if "brave" in c_class:
            blocked = False
            for dist in DISTRACTION_KEYWORDS:
                if dist in c_title:
                    subprocess.run(["hyprctl", "dispatch", "sendshortcut", f"CTRL,W,address:{c_addr}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    notify_island(f"🚫 Study Mode: Blocked {dist.capitalize()}", 3000)
                    blocked = True
                    break

            if not blocked and c_title:
                clean_title = re.sub(r'[\s\-—]+brave.*$', '', c_title, flags=re.IGNORECASE).strip().lower()
                if clean_title:
                    is_allowed = any(kw in clean_title for kw in ALLOWED_BRAVE_KEYWORDS)
                    if not is_allowed:
                        subprocess.run(["hyprctl", "dispatch", "sendshortcut", f"CTRL,W,address:{c_addr}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        notify_island("🚫 Study Mode: Whitelist Only (ICAI / Notebook / WhatsApp)", 3000)

def start_lofi_player():
    # If audio files exist in ~/Music/study/, play them with mpv in background loop
    files = list(LOFI_DIR.glob("*.mp3")) + list(LOFI_DIR.glob("*.wav")) + list(LOFI_DIR.glob("*.flac")) + list(LOFI_DIR.glob("*.ogg"))
    if not files:
        return None
    try:
        # Check if already playing
        res = subprocess.run(["pgrep", "-f", "mpv.*Music/study"], capture_output=True)
        if res.returncode == 0:
            return None
        proc = subprocess.Popen(
            ["mpv", "--no-video", "--loop-playlist=inf", "--shuffle", str(LOFI_DIR)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        return proc.pid
    except Exception:
        return None

def stop_lofi_player():
    try:
        subprocess.run(["pkill", "-f", "mpv.*Music/study"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def run_daemon():
    # Record PID
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    last_second_tick = time.time()
    last_hypr_check = time.time()

    while True:
        state = get_state()
        if not state.get("active"):
            break

        now = time.time()
        expiry = state.get("expiry_time", 0)
        target = state.get("target_duration", 10)
        overtime = state.get("overtime", False)

        # Hyprland distraction enforcement every 600ms
        if now - last_hypr_check >= 0.6:
            enforce_distractions()
            last_hypr_check = now

        # Timer evaluation
        if now >= expiry and not overtime:
            # First milestone reached: Credit session!
            record_completed_session()
            state["overtime"] = True
            state["credited"] = True
            state["overtime_seconds"] = 0
            save_state(state)
            notify_island(f"🎉 Session Complete ({target}s)! Overtime Flow Active", 6000)

        elif overtime and now - last_second_tick >= 1.0:
            state["overtime_seconds"] = state.get("overtime_seconds", 0) + 1
            # Every 1800s (30m) of overtime, credit another session!
            if state["overtime_seconds"] % 1800 == 0 and state["overtime_seconds"] > 0:
                record_completed_session()
                notify_island("🔥 +30m Deep Work Milestone Reached!", 5000)
            save_state(state)
            last_second_tick = now

        time.sleep(0.4)

    # Clean up PID
    if PID_FILE.exists():
        PID_FILE.unlink(missing_ok=True)

def cmd_start(duration: int, subject: str):
    state = get_state()
    now = time.time()

    # If already active and within lock, prevent restarting
    if state.get("active") and now < state.get("expiry_time", 0):
        remaining = int(state.get("expiry_time") - now)
        return {
            "success": False,
            "locked": True,
            "remaining": remaining,
            "message": f"Lockdown already active ({remaining}s remaining)"
        }

    new_state = {
        "active": True,
        "start_time": now,
        "target_duration": duration,
        "expiry_time": now + duration,
        "subject": subject or "CA / ICAI Study",
        "overtime": False,
        "overtime_seconds": 0,
        "credited": False,
        "lofi_enabled": True
    }
    save_state(new_state)

    # Kill open distractions immediately
    enforce_distractions()

    # Start background lo-fi player if tracks exist
    start_lofi_player()

    # Launch daemon detached
    script_path = os.path.abspath(__file__)
    subprocess.Popen([sys.executable, script_path, "daemon"], start_new_session=True)

    notify_island(f"󰑴 Study Mode Started ({duration}s lock)", 4000)
    return {
        "success": True,
        "expiry": new_state["expiry_time"],
        "duration": duration,
        "subject": new_state["subject"]
    }

def cmd_stop():
    state = get_state()
    now = time.time()

    if not state.get("active"):
        return {"success": True, "message": "Study Mode is not active"}

    # Hard lock check: if not in overtime and timer hasn't expired, REFUSE to stop!
    if not state.get("overtime") and now < state.get("expiry_time", 0):
        remaining = int(state.get("expiry_time", 0) - now)
        return {
            "success": False,
            "locked": True,
            "remaining": remaining,
            "message": f"Hard Lock Active: Cannot exit early! ({remaining}s remaining)"
        }

    # In overtime or expired: Exit cleanly!
    state["active"] = False
    save_state(state)
    stop_lofi_player()

    # Kill daemon process if running
    if PID_FILE.exists():
        try:
            pid = int(PID_FILE.read_text().strip())
            os.kill(pid, signal.SIGTERM)
        except Exception:
            pass
        PID_FILE.unlink(missing_ok=True)

    notify_island("✨ Study Session Finished. Well done!", 4000)
    return {"success": True, "message": "Study Mode finished cleanly"}

def cmd_status() -> dict:
    state = get_state()
    history = get_history()
    today = time.strftime("%Y-%m-%d")
    today_sessions = history.get(today, 0)
    total_sessions = sum(history.values())

    now = time.time()
    active = state.get("active", False)
    expiry = state.get("expiry_time", 0)
    overtime = state.get("overtime", False)
    remaining = max(0, int(expiry - now)) if active and not overtime else 0

    return {
        "active": active,
        "remaining_seconds": remaining,
        "target_duration": state.get("target_duration", 10),
        "expiry_time": expiry,
        "subject": state.get("subject", "CA / ICAI Study"),
        "overtime": overtime,
        "overtime_seconds": state.get("overtime_seconds", 0),
        "today_sessions": today_sessions,
        "total_sessions": total_sessions
    }

def prompt_password_gui() -> str | None:
    # Ensure floating and centered window in Hyprland
    try:
        subprocess.run(["hyprctl", "keyword", "windowrulev2", "float,class:^(zenity)$"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["hyprctl", "keyword", "windowrulev2", "center,class:^(zenity)$"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    # 1. Try Zenity
    try:
        cmd = [
            "zenity",
            "--entry",
            "--title=Cool-Shell Study Mode: Lock In",
            "--text=Enter Study Password to activate Lock In (Hard Lock):",
            "--hide-text"
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            return res.stdout.strip()
        return None
    except Exception:
        pass

    # 2. Fallback to Rofi
    try:
        cmd = ["rofi", "-dmenu", "-password", "-p", "Study Password"]
        res = subprocess.run(cmd, input="", capture_output=True, text=True)
        if res.returncode == 0:
            return res.stdout.strip()
    except Exception:
        pass

    return None

def cmd_prompt_and_start(duration: int, subject: str):
    pwd = prompt_password_gui()
    if pwd is None:
        notify_island("Study Mode activation cancelled", 3000)
        return {"success": False, "cancelled": True}

    if not verify_password(pwd):
        try:
            subprocess.run([
                "zenity", "--error",
                "--title=Study Mode: Authentication Failed",
                "--text=Incorrect password! Lock In aborted."
            ], timeout=5)
        except Exception:
            pass
        notify_island("❌ Incorrect Study Password", 3000)
        return {"success": False, "valid": False, "message": "Incorrect password"}

    # Password verified! Start study mode
    return cmd_start(duration, subject)

def main():
    parser = argparse.ArgumentParser(description="Cool-Shell Study Mode")
    parser.add_argument("action", choices=["status", "start", "stop", "verify-password", "history", "daemon", "prompt-and-start", "prompt"])
    parser.add_argument("extra_args", nargs="*", help="Optional extra positional arguments")
    parser.add_argument("--duration", type=int, default=1800, help="Duration in seconds (default: 1800s / 30m)")
    parser.add_argument("--subject", type=str, default="CA / ICAI Study", help="Study subject name")
    parser.add_argument("--password", type=str, default="", help="Password to verify")

    args = parser.parse_args()

    if args.action == "verify-password":
        pwd = args.password if args.password else (args.extra_args[0] if args.extra_args else "")
        is_valid = verify_password(pwd)
        print(json.dumps({"valid": is_valid}))
    elif args.action in ("prompt-and-start", "prompt"):
        res = cmd_prompt_and_start(args.duration, args.subject)
        print(json.dumps(res))
    elif args.action == "start":
        res = cmd_start(args.duration, args.subject)
        print(json.dumps(res))
    elif args.action == "stop":
        res = cmd_stop()
        print(json.dumps(res))
    elif args.action == "status":
        res = cmd_status()
        print(json.dumps(res))
    elif args.action == "history":
        res = get_history()
        print(json.dumps(res))
    elif args.action == "daemon":
        run_daemon()

if __name__ == "__main__":
    main()
