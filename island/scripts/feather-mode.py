#!/usr/bin/env python3
"""
The Feather - Absolute Battery Mode for cool-shell / Hyprland
Keeps Hyprland running at bare-minimum resource usage so apps can start on demand:
- Halts all compositor animations, blur shaders, and window drop-shadows
- Enables Hyprland Variable Frame Rate (misc:vfr 1) for 0 FPS idle GPU consumption
- Terminates wallpaper daemon (awww-daemon) and video decoding
- Prunes all non-essential user applications (browsers, discord, spotify, media players, bloat)
- Preserves Linux kernel, distro minimum (systemd, dbus, logind, polkit, upowerd, pipewire), Hyprland, and quickshell
- Restoring / Turning off cleanly returns the normal Hyprland desktop with full visual fidelity and wallpaper
"""

import sys
import os
import signal
import json
import subprocess
import time
from pathlib import Path

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "cool-shell"
STATE_FILE = STATE_DIR / "feather-mode.json"

# Process names that MUST NEVER be killed
ESSENTIAL_EXACT_NAMES = {
    # System & session init (distro minimum)
    "systemd", "(sd-pam)", "systemd-journald", "systemd-udevd", "systemd-logind", "systemd-resolved",
    "systemd-timesyncd", "systemd-boot", "systemd-homed", "systemd-userdbd",
    # D-Bus IPC
    "dbus-daemon", "dbus-broker", "dbus-broker-launch", "dbus-broker-lau",
    # Polkit & authorization
    "polkitd", "polkit-kde-authentication-agent-1", "polkit-gnome-authentication-agent-1", "hyprpolkitagent", "dconf-service",
    "fusermount", "fusermount3",
    # Distro login managers, TTYs, login shells
    "-fish", "-bash", "-zsh", "-sh",
    "login", "agetty", "getty", "greetd", "tuigreet", "sddm", "gdm", "lightdm",
    # Compositor & Display (Kept alive at bare minimum so apps can start)
    "Hyprland", "hyprland", "start-hyprland", "Xwayland", "hypridle", "hyprlock", "hyprpm",
    # Desktop Shell (keeps Left Sidebar operable for clean restoration)
    "quickshell",
    # Distro hardware, power & networking
    "upowerd", "NetworkManager", "wpa_supplicant", "iwd", "bluetoothd", "rtkit-daemon",
    "brightnessctl",
    # Distro audio stack (PipeWire / WirePlumber)
    "pipewire", "wireplumber", "pipewire-pulse", "pipewire-media-session",
    # Agent & Coding Environment (keeps pair-programming alive)
    "antigravity", "agy", "python3"
}

ESSENTIAL_SUBSTRINGS = [
    "hypr", "quickshell", "systemd", "dbus", "polkit", "antigravity", "agy", "wireplumber", "pipewire"
]

# Applications to be pruned when The Feather is activated
ALWAYS_KILL_SUBSTRINGS = [
    "brave", "chrome", "firefox", "chromium", "zen", "opera", "vivaldi", "edge", "librewolf", "thorium",
    "discord", "spotify", "slack", "obsidian", "steam", "lutris", "heroic", "bottles",
    "vlc", "mpv", "awww-daemon", "swww-daemon", "cava", "glava", "peaclock",
    "telegram", "signal", "thunderbird", "element", "electron"
]

def ensure_state_dir():
    STATE_DIR.mkdir(parents=True, exist_ok=True)

def read_state():
    try:
        if STATE_FILE.exists():
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
    except Exception:
        pass
    return {"featherMode": False, "killedCount": 0}

def write_state(data):
    ensure_state_dir()
    tmp_path = STATE_FILE.with_suffix(".tmp")
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    tmp_path.replace(STATE_FILE)

def get_all_processes():
    """Reads all processes across the entire system so full ancestor chains can be built."""
    procs = {}
    for entry in os.scandir("/proc"):
        if entry.is_dir() and entry.name.isdigit():
            pid = int(entry.name)
            try:
                stat_path = os.path.join(entry.path, "status")
                name = None
                ppid = None
                proc_uid = None
                with open(stat_path, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        if line.startswith("Name:"):
                            name = line.split(":", 1)[1].strip()
                        elif line.startswith("PPid:"):
                            ppid = int(line.split(":", 1)[1].strip())
                        elif line.startswith("Uid:"):
                            parts = line.split()
                            if len(parts) > 1:
                                proc_uid = int(parts[1])
                if name is not None:
                    procs[pid] = {"pid": pid, "ppid": ppid, "name": name, "uid": proc_uid}
            except (FileNotFoundError, PermissionError, ProcessLookupError, IndexError):
                continue
    return procs

def is_always_kill(name: str) -> bool:
    lower = name.lower()
    return any(k in lower for k in ALWAYS_KILL_SUBSTRINGS)

def build_protected_pids(all_procs, my_pid):
    protected = set()

    # 1. Map parent -> children for tree propagation
    ch_map = {}
    for pid, info in all_procs.items():
        ppid = info.get("ppid")
        if ppid is not None:
            ch_map.setdefault(ppid, []).append(pid)

    # 2. Protect exact essential names, login shells (-fish, -bash), and critical substrings
    for pid, info in all_procs.items():
        name = info.get("name", "")
        lower_name = name.lower()
        if name in ESSENTIAL_EXACT_NAMES or name.startswith("-"):
            if not is_always_kill(name):
                protected.add(pid)
        elif any(sub in lower_name for sub in ESSENTIAL_SUBSTRINGS):
            if not is_always_kill(name):
                protected.add(pid)

    # 3. Explicit Compositor & Shell Protection: Hyprland, Xwayland, quickshell
    for pid, info in all_procs.items():
        name = info.get("name", "").lower()
        if "hyprland" in name or name == "xwayland" or name == "quickshell":
            protected.add(pid)
            for child in ch_map.get(pid, []):
                cname = all_procs.get(child, {}).get("name", "").lower()
                if "xwayland" in cname or "hypr" in cname or "portal" in cname or "polkit" in cname:
                    protected.add(child)

    # 4. Protect active AGY / Antigravity pair-programming session
    for pid, info in all_procs.items():
        name = info.get("name", "").lower()
        if "agy" in name or "antigravity" in name:
            protected.add(pid)

    # 5. Protect current script execution process
    protected.add(my_pid)

    # 6. UNIVERSAL ANCESTOR WALK
    # Walk UP parent tree of protected processes all the way to PID 1.
    for pid in list(protected):
        p = pid
        visited = set()
        while p in all_procs and p not in visited and p > 1:
            visited.add(p)
            protected.add(p)
            p = all_procs[p].get("ppid", 1)

    return protected

def get_current_brightness():
    try:
        res = subprocess.run(["brightnessctl", "g"], capture_output=True, text=True, check=True)
        return int(res.stdout.strip())
    except Exception:
        return None

def set_brightness(val):
    try:
        subprocess.run(["brightnessctl", "set", str(val)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def enable_feather_mode():
    my_pid = os.getpid()
    uid = os.getuid()
    all_procs = get_all_processes()
    protected_pids = build_protected_pids(all_procs, my_pid)

    candidates = {}
    for pid, info in all_procs.items():
        if info.get("uid") == uid and pid not in protected_pids:
            candidates[pid] = info.get("name", "unknown")

    # Step 1: SIGTERM non-essential user bloat
    killed_names = []
    for pid, name in candidates.items():
        try:
            os.kill(pid, signal.SIGTERM)
            killed_names.append(name)
        except (ProcessLookupError, PermissionError):
            pass

    time.sleep(0.12)

    # Step 2: SIGKILL remaining stubborn bloat
    for pid in list(candidates.keys()):
        try:
            os.kill(pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass

    # Step 3: Strip Hyprland to absolute bare minimum (0 animations, 0 blur, 0 shadows, VFR active)
    try:
        subprocess.run(["hyprctl", "keyword", "animations:enabled", "0"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["hyprctl", "keyword", "decoration:blur:enabled", "0"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["hyprctl", "keyword", "decoration:shadow:enabled", "0"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["hyprctl", "keyword", "misc:vfr", "1"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    # Step 4: Halt wallpaper daemon to stop GPU decoding
    try:
        subprocess.run(["pkill", "-TERM", "awww-daemon"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    # Step 5: Save and drop display brightness to battery-preserving 15%
    saved_bright = get_current_brightness()
    set_brightness("15%")

    state = {
        "featherMode": True,
        "killedCount": len(killed_names),
        "killedNames": killed_names[:25],
        "savedBrightness": saved_bright,
        "timestamp": int(time.time())
    }
    write_state(state)
    return state

def disable_feather_mode():
    curr = read_state()
    saved_bright = curr.get("savedBrightness")

    state = {
        "featherMode": False,
        "killedCount": 0,
        "killedNames": [],
        "savedBrightness": None,
        "timestamp": int(time.time())
    }
    write_state(state)

    # Step 1: Restore full Hyprland visual fidelity (animations, blur, shadows)
    try:
        subprocess.run(["hyprctl", "keyword", "animations:enabled", "1"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["hyprctl", "keyword", "decoration:blur:enabled", "1"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["hyprctl", "keyword", "decoration:shadow:enabled", "1"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    # Step 2: Restore display brightness
    if saved_bright is not None:
        set_brightness(saved_bright)

    # Step 3: Relaunch wallpaper daemon and restore normal wallpaper
    try:
        subprocess.Popen(["awww-daemon"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        time.sleep(0.2)
        theme_script = Path(__file__).resolve().parent / "theme-system.sh"
        if theme_script.exists():
            subprocess.Popen([str(theme_script), "restore-wallpaper"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except Exception:
        pass

    return state

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd in ("enable", "on"):
        result = enable_feather_mode()
        print(json.dumps(result))
    elif cmd in ("disable", "off"):
        result = disable_feather_mode()
        print(json.dumps(result))
    elif cmd == "toggle":
        curr = read_state()
        if curr.get("featherMode", False):
            result = disable_feather_mode()
        else:
            result = enable_feather_mode()
        print(json.dumps(result))
    elif cmd == "status":
        curr = read_state()
        print(json.dumps(curr))
    elif cmd == "dry-run":
        my_pid = os.getpid()
        uid = os.getuid()
        all_procs = get_all_processes()
        protected = build_protected_pids(all_procs, my_pid)
        candidates = {pid: info['name'] for pid, info in all_procs.items() if info.get('uid') == uid and pid not in protected}
        print(json.dumps({
            "mode": "dry-run (bare-minimum Hyprland)",
            "protectedCount": len(protected),
            "candidatesCount": len(candidates),
            "candidates": candidates
        }, indent=2))
    else:
        print(json.dumps({"error": f"Unknown command {cmd}", "usage": "feather-mode.py [status|enable|disable|toggle|dry-run]"}))
        sys.exit(1)

if __name__ == "__main__":
    main()
