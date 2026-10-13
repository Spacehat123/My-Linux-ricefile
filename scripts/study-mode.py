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
    # Browsers
    "brave",
    "brave-browser",

    # File Explorers & Managers (All)
    "dolphin",
    "org.kde.dolphin",
    "nautilus",
    "org.gnome.nautilus",
    "nemo",
    "org.nemo",
    "thunar",
    "org.xfce.thunar",
    "pcmanfm",
    "pcmanfm-qt",
    "org.lxde.pcmanfm",
    "caja",
    "org.mate.caja",
    "spacefm",
    "krusader",
    "org.kde.krusader",
    "doublecmd",
    "mc",
    "ranger",
    "yazi",
    "vifm",
    "ark",
    "org.kde.ark",
    "file-roller",
    "org.gnome.fileroller",
    "engrampa",
    "peazip",

    # Desktop Portals & File Choosers
    "xdg-desktop-portal",
    "xdg-desktop-portal-gtk",
    "org.freedesktop.impl.portal.desktop.gtk",
    "xdg-desktop-portal-kde",
    "org.freedesktop.impl.portal.desktop.kde",
    "xdg-desktop-portal-hyprland",
    "org.freedesktop.impl.portal.desktop.hyprland",
    "xdg-desktop-portal-gnome",
    "org.freedesktop.impl.portal.desktop.gnome",
    "xdg-desktop-portal-wlr",
    "kdialog",
    "org.kde.kdialog",
    "zenity",
    "org.gnome.zenity",
    "yad",
    "qarma",
    "gcr-prompter",
    "polkit-kde-authentication-agent-1",
    "org.kde.polkit-kde-authentication-agent-1",

    # Document & Media Viewers
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
    "mpv",

    # Text & Code Editors
    "kate",
    "org.kde.kate",
    "kwrite",
    "org.kde.kwrite",

    # Terminals & System
    "foot",
    "kitty",
    "alacritty",
    "quickshell",
    "rofi"
}

# Whitelist allowed domains / keywords in Brave browser window titles
ALLOWED_BRAVE_KEYWORDS = [
    # ICAI / Board of Studies (BOS) / CA Study Materials
    "bos", "boslive", "icai", "cdn.icai.org", "resource.cdn.icai.org", "icai.org", "icaiexam",
    "ca ", "foundation", "intermediate", "final", "chapter", "module",

    # Document formats & PDF reading
    ".pdf", "pdf",

    # File actions & download dialogs
    "save", "save file", "save as", "open file", "open", "upload", "download", "downloads", "print",

    # Allowed study tools
    "notebook", "gemini notebook", "notebooklm", "whatsapp",
    "new tab", "untitled", "settings", "extensions", "sign in", "login",
    "accounts.google", "drive.google", "docs.google"
]

# Explicit distraction titles that trigger immediate tab closure
DISTRACTION_KEYWORDS = [
    "youtube", "reddit", "twitter", "x.com", "instagram", "twitch",
    "tiktok", "netflix", "prime video", "anime", "manga", "facebook",
    "discord", "chess", "kick.com", "hulu", "steam"
]

def is_file_manager_or_dialog(c_class: str, c_initial: str, c_title: str) -> bool:
    cls = (c_class or "").lower()
    init_cls = (c_initial or "").lower()
    t = (c_title or "").lower()

    # Substring match on file managers / portals / choosers
    fm_patterns = [
        "dolphin", "nautilus", "nemo", "thunar", "pcmanfm", "caja",
        "spacefm", "krusader", "doublecmd", "portal", "kdialog",
        "zenity", "yad", "qarma", "file-roller", "ark", "engrampa",
        "peazip", "file manager", "file chooser", "file picker",
        "open files", "save file"
    ]
    if any(p in cls or p in init_cls for p in fm_patterns):
        return True

    # Standard dialog titles
    dialog_titles = [
        "save file", "save as", "open file", "open files", "select a file",
        "select file", "select folder", "select directory", "file upload",
        "choose file", "choose files", "all files", "save", "open"
    ]
    if any(d == t or t.startswith(d) for d in dialog_titles):
        return True

    return False

def is_allowed_class(c_class: str, c_initial: str, c_title: str) -> bool:
    cls = (c_class or "").lower()
    init_cls = (c_initial or "").lower()

    if cls in ALLOWED_CLASSES or init_cls in ALLOWED_CLASSES:
        return True

    if is_file_manager_or_dialog(c_class, c_initial, c_title):
        return True

    return False

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
            "target_duration": 1800,  # 30 minutes (1800s)
            "expiry_time": 0,
            "subject": "CA / ICAI Study",
            "overtime": False,
            "overtime_seconds": 0,
            "credited": False,
            "bonus_sessions_credited": 0,
            "lofi_enabled": True
        }
    for _ in range(3):
        try:
            with open(STATE_FILE, "r") as f:
                content = f.read().strip()
                if content:
                    return json.loads(content)
        except Exception:
            time.sleep(0.05)
    return {"active": False}

def save_state(state: dict):
    tmp_file = STATE_FILE.with_suffix(".tmp")
    try:
        with open(tmp_file, "w") as f:
            json.dump(state, f, indent=2)
        os.chmod(tmp_file, 0o600)
        os.replace(tmp_file, STATE_FILE)
    except Exception as e:
        print(f"Error saving state: {e}", file=sys.stderr)

def get_history() -> dict:
    if not HISTORY_FILE.exists():
        return {}
    for _ in range(3):
        try:
            with open(HISTORY_FILE, "r") as f:
                content = f.read().strip()
                if content:
                    return json.loads(content)
        except Exception:
            time.sleep(0.05)
    return {}

def record_completed_session():
    history = get_history()
    today = time.strftime("%Y-%m-%d")
    history[today] = history.get(today, 0) + 1
    tmp_file = HISTORY_FILE.with_suffix(".tmp")
    try:
        with open(tmp_file, "w") as f:
            json.dump(history, f, indent=2)
        os.chmod(tmp_file, 0o600)
        os.replace(tmp_file, HISTORY_FILE)
    except Exception as e:
        print(f"Error recording history: {e}", file=sys.stderr)


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

def hypr_close_window(addr: str, pid: int = None):
    raw_addr = addr.replace("address:", "")
    lua_close = f'hl.dispatch(hl.dsp.window.close({{ address = "{raw_addr}" }}))'
    subprocess.run(["hyprctl", "repl", lua_close], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1)
    if pid and pid > 0:
        try:
            os.kill(pid, signal.SIGTERM)
        except Exception:
            pass

def hypr_close_tab(addr: str):
    raw_addr = addr.replace("address:", "")
    lua_send = f'hl.dispatch(hl.dsp.send_shortcut({{ mods = "CTRL", key = "w", window = "address:{raw_addr}" }}))'
    subprocess.run(["hyprctl", "repl", lua_send], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1)

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
        c_initial_class = (client.get("initialClass") or "").lower()
        c_title = (client.get("title") or "").lower()
        c_addr = client.get("address")
        c_pid = client.get("pid")

        if not c_addr:
            continue

        # Check application whitelist (all whitelisted apps, all file managers, portals, and file dialogs)
        if not is_allowed_class(c_class, c_initial_class, c_title):
            hypr_close_window(c_addr, c_pid)
            continue

        # Check Brave browser tabs for forbidden websites
        if "brave" in c_class or "brave" in c_initial_class:
            # File save/download/upload dialogs or portals opened by Brave must never be closed
            if is_file_manager_or_dialog(c_class, c_initial_class, c_title):
                continue

            blocked = False
            for dist in DISTRACTION_KEYWORDS:
                if dist in c_title:
                    hypr_close_tab(c_addr)
                    notify_island(f"🚫 Study Mode: Blocked {dist.capitalize()}", 3000)
                    blocked = True
                    break

            if not blocked and c_title:
                clean_title = re.sub(r'[\s\-—]+brave.*$', '', c_title, flags=re.IGNORECASE).strip().lower()
                if clean_title:
                    # Allow all PDF documents, Board of Studies (BOS) files, and whitelisted domains
                    is_allowed = (
                        ".pdf" in clean_title
                        or clean_title.endswith(".pdf")
                        or any(kw in clean_title for kw in ALLOWED_BRAVE_KEYWORDS)
                    )
                    if not is_allowed:
                        hypr_close_tab(c_addr)
                        notify_island("🚫 Study Mode: Whitelist Only (ICAI / Notebook / WhatsApp / PDFs)", 3000)

def is_pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    try:
        cmdline_path = Path(f"/proc/{pid}/cmdline")
        if cmdline_path.exists():
            cmdline = cmdline_path.read_bytes().decode("utf-8", errors="ignore")
            if "study-mode.py" in cmdline:
                return True
    except Exception:
        return True
    return False

def is_daemon_running() -> bool:
    if not PID_FILE.exists():
        return False
    try:
        pid = int(PID_FILE.read_text().strip())
        return is_pid_alive(pid)
    except Exception:
        return False

def ensure_daemon():
    """Self-healing: If study mode is active but daemon is dead, resurrect immediately."""
    state = get_state()
    if not state.get("active"):
        return
    if is_daemon_running():
        return

    script_path = os.path.abspath(__file__)
    try:
        subprocess.Popen(
            [sys.executable, script_path, "daemon"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True
        )
    except Exception as e:
        print(f"Failed to resurrect daemon: {e}", file=sys.stderr)

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
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True
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
    # Record PID atomically
    pid = os.getpid()
    tmp_pid = PID_FILE.with_suffix(".tmp")
    tmp_pid.write_text(str(pid))
    os.replace(tmp_pid, PID_FILE)

    last_hypr_check = 0.0

    while True:
        try:
            state = get_state()
            if not state.get("active"):
                break

            now = time.time()
            expiry = state.get("expiry_time", 0)
            target = state.get("target_duration", 1800)

            # Hyprland distraction enforcement every 300ms
            if now - last_hypr_check >= 0.3:
                try:
                    enforce_distractions()
                except Exception:
                    pass
                last_hypr_check = now

            # Overtime check & milestone crediting
            if now >= expiry:
                # First base session milestone
                if not state.get("credited", False):
                    record_completed_session()
                    state["credited"] = True
                    state["overtime"] = True
                    save_state(state)
                    target_str = f"{target // 60}m" if target >= 60 else f"{target}s"
                    notify_island(f"🎉 Session Complete ({target_str})! Overtime Flow Active", 6000)

                # Overtime milestone crediting: every 1800s (30m) of overtime
                overtime_sec = int(now - expiry)
                bonus_count = overtime_sec // 1800
                recorded_bonus = state.get("bonus_sessions_credited", 0)
                if bonus_count > recorded_bonus:
                    record_completed_session()
                    state["bonus_sessions_credited"] = bonus_count
                    save_state(state)
                    notify_island("🔥 +30m Deep Work Milestone Reached!", 5000)

            time.sleep(0.15)
        except Exception:
            time.sleep(0.5)

    # Clean up PID only if it matches our PID
    if PID_FILE.exists():
        try:
            current_pid = int(PID_FILE.read_text().strip())
            if current_pid == os.getpid():
                PID_FILE.unlink(missing_ok=True)
        except Exception:
            pass

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
        "bonus_sessions_credited": 0,
        "lofi_enabled": True
    }
    save_state(new_state)

    # Kill open distractions immediately
    try:
        enforce_distractions()
    except Exception:
        pass

    # Start background lo-fi player if tracks exist
    start_lofi_player()

    # Launch daemon detached
    script_path = os.path.abspath(__file__)
    subprocess.Popen(
        [sys.executable, script_path, "daemon"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        close_fds=True
    )

    dur_str = f"{duration // 60}m" if duration >= 60 else f"{duration}s"
    notify_island(f"󰑴 Study Mode Started ({dur_str} lock)", 4000)
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

    expiry = state.get("expiry_time", 0)
    is_overtime = (now >= expiry) or state.get("overtime", False)

    # Hard lock check: if not in overtime and timer hasn't expired, REFUSE to stop!
    if not is_overtime:
        remaining = int(expiry - now)
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
    ensure_daemon()
    state = get_state()
    history = get_history()
    today = time.strftime("%Y-%m-%d")
    today_sessions = history.get(today, 0)
    total_sessions = sum(history.values())

    now = time.time()
    active = state.get("active", False)
    expiry = state.get("expiry_time", 0)
    target = state.get("target_duration", 1800)

    if active:
        if now < expiry:
            remaining = int(expiry - now)
            overtime = False
            overtime_seconds = 0
        else:
            remaining = 0
            overtime = True
            overtime_seconds = int(now - expiry)
            # Automatic crediting fallback if not yet credited
            if not state.get("credited", False):
                record_completed_session()
                state["credited"] = True
                state["overtime"] = True
                save_state(state)
    else:
        remaining = 0
        overtime = False
        overtime_seconds = 0

    return {
        "active": active,
        "remaining_seconds": remaining,
        "target_duration": target,
        "expiry_time": expiry,
        "subject": state.get("subject", "CA / ICAI Study"),
        "overtime": overtime,
        "overtime_seconds": overtime_seconds,
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
