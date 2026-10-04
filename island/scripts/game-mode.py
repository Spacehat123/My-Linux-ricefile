#!/usr/bin/env python3
"""
Extreme Game Mode Optimizer for cool-shell / Hyprland
Terminates user applications and background processes to drop RAM to absolute minimum,
while respecting user-configured exceptions (e.g. Steam, Discord, Spotify).
Preserves essential system infrastructure:
- Hyprland & Xwayland
- quickshell (limited to Notch)
- PipeWire & WirePlumber (audio for games)
- systemd & D-Bus & polkit & portals
- active AGY / terminal session
"""

import sys
import os
import signal
import json
import subprocess
import time
from pathlib import Path

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "cool-shell"
STATE_FILE = STATE_DIR / "game-mode.json"
EXCEPTIONS_FILE = STATE_DIR / "game-mode-exceptions.json"

DEFAULT_EXCEPTIONS = ["steam", "discord", "spotify", "obs", "heroic"]

# Process names that MUST NEVER be killed
ESSENTIAL_EXACT_NAMES = {
    # System & session init
    "systemd", "(sd-pam)", "systemd-journald", "systemd-udevd", "systemd-logind", "systemd-resolved",
    "dbus-daemon", "dbus-broker", "dbus-broker-launch", "dbus-broker-lau",
    "polkitd", "polkit-kde-authentication-agent-1", "polkit-gnome-authentication-agent-1", "dconf-service",
    "fusermount", "fusermount3",
    # Login shells, TTYs, Display Managers (killing these destroys the entire user session)
    "-fish", "-bash", "-zsh", "-sh",
    "login", "agetty", "getty", "greetd", "tuigreet", "sddm", "gdm", "lightdm",
    # Compositor & Display
    "Hyprland", "hyprland", "start-hyprland", "hyprlock", "hypridle", "hyprpaper", "hyprpm", "hyprpolkitagent", "Xwayland",
    # Desktop Shell
    "quickshell",
    # Audio & Media (games need sound)
    "pipewire", "wireplumber", "pipewire-pulse", "pipewire-media-session",
    # Wayland utilities & portals
    "wl-paste", "wl-copy",
    "xdg-desktop-portal", "xdg-desktop-portal-hyprland", "xdg-desktop-portal-gtk",
    "xdg-desktop-por", "xdg-document-portal", "xdg-document-po", "xdg-permission-store", "xdg-permission-",
    "at-spi-bus-launcher", "at-spi-bus-laun", "at-spi2-registryd", "at-spi2-registr",
    # Hardware & Network
    "upowerd", "bluetoothd", "NetworkManager", "wpa_supplicant", "iwd", "rtkit-daemon",
    # Agent & Coding Environment (keeps pair-programming alive)
    "antigravity", "agy", "python3"
}

ESSENTIAL_SUBSTRINGS = [
    "hypr", "quickshell", "pipewire", "wireplumber", "systemd", "dbus",
    "portal", "polkit", "antigravity", "agy"
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
    return {"gameMode": False, "killedCount": 0}

def write_state(data):
    ensure_state_dir()
    tmp_path = STATE_FILE.with_suffix(".tmp")
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    tmp_path.replace(STATE_FILE)

def read_exceptions():
    try:
        if EXCEPTIONS_FILE.exists():
            with open(EXCEPTIONS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list) and len(data) > 0:
                    return [str(x).strip().lower() for x in data if str(x).strip()]
    except Exception:
        pass
    return DEFAULT_EXCEPTIONS.copy()

def write_exceptions(data):
    ensure_state_dir()
    clean = sorted(list(set(str(x).strip().lower() for x in data if str(x).strip())))
    tmp_path = EXCEPTIONS_FILE.with_suffix(".tmp")
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(clean, f, indent=2)
    tmp_path.replace(EXCEPTIONS_FILE)
    return clean

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

def build_protected_pids(all_procs, my_pid):
    protected = set()

    # 1. Map parent -> children for tree propagation
    ch_map = {}
    for pid, info in all_procs.items():
        ppid = info.get("ppid")
        if ppid is not None:
            ch_map.setdefault(ppid, []).append(pid)

    # 2. Protect all exact essential names, login shells (-fish, -bash), and critical substrings
    for pid, info in all_procs.items():
        name = info.get("name", "")
        lower_name = name.lower()
        if name in ESSENTIAL_EXACT_NAMES or name.startswith("-"):
            protected.add(pid)
        elif any(sub in lower_name for sub in ESSENTIAL_SUBSTRINGS):
            protected.add(pid)

    # 3. Explicit Compositor Protection: Hyprland, Xwayland, and its compositor helpers
    for pid, info in all_procs.items():
        name = info.get("name", "").lower()
        if "hyprland" in name or name == "xwayland":
            protected.add(pid)
            # protect direct compositor helper children
            for child in ch_map.get(pid, []):
                cname = all_procs.get(child, {}).get("name", "").lower()
                if "xwayland" in cname or "hypr" in cname or "portal" in cname or "polkit" in cname:
                    protected.add(child)

    # 4. Protect user configured exceptions (and their whole process trees)
    exceptions = read_exceptions()
    if exceptions:
        for pid, info in all_procs.items():
            name = info.get("name", "").lower()
            if any(exc in name for exc in exceptions):
                protected.add(pid)
                # Protect all descendants (game child processes, audio helpers)
                q = [pid]
                while q:
                    curr = q.pop()
                    protected.add(curr)
                    for child in ch_map.get(curr, []):
                        if child not in protected:
                            protected.add(child)
                            q.append(child)

    # 5. Protect current script execution tree
    protected.add(my_pid)

    # 6. Protect AGY (agent session) and its parent terminal tree (kitty/alacritty/etc)
    for pid, info in all_procs.items():
        name = info.get("name", "")
        if "agy" in name or "antigravity" in name:
            protected.add(pid)

    # 7. CRITICAL: UNIVERSAL ANCESTOR WALK
    # Walk UP the parent tree of EVERY protected process all the way to PID 1.
    # This guarantees that Hyprland's parent login shell (e.g. -fish on tty1),
    # PAM session leaders, and display managers are NEVER killed!
    for pid in list(protected):
        p = pid
        visited = set()
        while p in all_procs and p not in visited and p > 1:
            visited.add(p)
            protected.add(p)
            p = all_procs[p].get("ppid", 1)

    # 8. Protect child shells/processes of AGY / terminal / session
    q = list(protected)
    while q:
        c = q.pop()
        for child in ch_map.get(c, []):
            if child not in protected:
                pname = all_procs.get(child, {}).get("name", "")
                if pname in ("fish", "bash", "sh", "python3", "agy", "antigravity", "ps", "sed", "kitten"):
                    protected.add(child)
                    q.append(child)

    return protected

def enable_game_mode():
    my_pid = os.getpid()
    uid = os.getuid()
    all_procs = get_all_processes()
    protected_pids = build_protected_pids(all_procs, my_pid)

    candidates = {}
    for pid, info in all_procs.items():
        # ONLY consider processes belonging to the current user that are NOT protected
        if info.get("uid") == uid and pid not in protected_pids:
            candidates[pid] = info.get("name", "unknown")

    # Step 1: SIGTERM
    killed_names = []
    for pid, name in candidates.items():
        try:
            os.kill(pid, signal.SIGTERM)
            killed_names.append(name)
        except (ProcessLookupError, PermissionError):
            pass

    # Give apps 150ms to release locks and exit gracefully
    time.sleep(0.15)

    # Step 2: SIGKILL remaining stubborn processes
    for pid in list(candidates.keys()):
        try:
            os.kill(pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass

    # Step 3: Compositor latency optimizations
    try:
        subprocess.run(["hyprctl", "keyword", "animations:enabled", "0"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["hyprctl", "keyword", "decoration:blur:enabled", "0"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    # Step 4: Launch dedicated ultra-low RAM GameModeIsland (software backend ~50-80MB)
    shell_dir = Path(__file__).resolve().parent.parent.parent
    island_file = shell_dir / "island" / "GameModeIsland.qml"
    if island_file.exists():
        gm_env = os.environ.copy()
        gm_env["QT_QUICK_BACKEND"] = "software"
        gm_env["MALLOC_TRIM_THRESHOLD_"] = "65536"
        subprocess.Popen(
            ["quickshell", "-p", str(island_file)],
            env=gm_env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
        time.sleep(0.35)

    # Step 5: Terminate heavy cool-shell instances to reclaim ~400MB RAM
    for pid, info in all_procs.items():
        if info.get("uid") == uid and "quickshell" in info.get("name", ""):
            try:
                with open(f"/proc/{pid}/cmdline", "r") as f:
                    cmd = f.read()
                    if "cool-shell" in cmd and "GameModeIsland" not in cmd:
                        os.kill(pid, signal.SIGTERM)
            except Exception:
                pass

    state = {
        "gameMode": True,
        "killedCount": len(killed_names),
        "killedNames": killed_names[:15],
        "timestamp": int(time.time())
    }
    write_state(state)
    return state

def disable_game_mode():
    state = {
        "gameMode": False,
        "killedCount": 0,
        "killedNames": [],
        "timestamp": int(time.time())
    }
    write_state(state)

    try:
        subprocess.run(["hyprctl", "keyword", "animations:enabled", "1"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["hyprctl", "keyword", "decoration:blur:enabled", "1"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    # Step 1: Relaunch full GPU-accelerated cool-shell with clean environment
    try:
        clean_env = os.environ.copy()
        clean_env.pop("QT_QUICK_BACKEND", None)
        clean_env.pop("MALLOC_TRIM_THRESHOLD_", None)
        subprocess.Popen(
            ["quickshell", "-c", "cool-shell"],
            env=clean_env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
        time.sleep(0.4)
    except Exception:
        pass

    # Step 2: Terminate any running GameModeIsland processes
    my_uid = os.getuid()
    for entry in os.scandir("/proc"):
        if entry.is_dir() and entry.name.isdigit():
            pid = int(entry.name)
            try:
                with open(f"/proc/{pid}/cmdline", "r") as f:
                    cmd = f.read()
                    if "GameModeIsland" in cmd:
                        os.kill(pid, signal.SIGTERM)
            except Exception:
                pass

    # Step 3: Restore wallpaper daemon
    try:
        subprocess.Popen(["awww-daemon"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except Exception:
        pass

    return state

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "enable":
        result = enable_game_mode()
        print(json.dumps(result))
    elif cmd == "disable":
        result = disable_game_mode()
        print(json.dumps(result))
    elif cmd == "toggle":
        curr = read_state()
        if curr.get("gameMode", False):
            result = disable_game_mode()
        else:
            result = enable_game_mode()
        print(json.dumps(result))
    elif cmd == "status":
        curr = read_state()
        print(json.dumps(curr))
    elif cmd == "list-exceptions":
        print(json.dumps(read_exceptions()))
    elif cmd == "add-exception":
        if len(sys.argv) > 2:
            app = sys.argv[2].strip().lower()
            excs = read_exceptions()
            if app not in excs:
                excs.append(app)
            print(json.dumps(write_exceptions(excs)))
        else:
            print(json.dumps({"error": "Missing application name"}))
    elif cmd == "remove-exception":
        if len(sys.argv) > 2:
            app = sys.argv[2].strip().lower()
            excs = read_exceptions()
            excs = [x for x in excs if x != app]
            print(json.dumps(write_exceptions(excs)))
        else:
            print(json.dumps({"error": "Missing application name"}))
    elif cmd == "dry-run":
        my_pid = os.getpid()
        uid = os.getuid()
        all_procs = get_all_processes()
        protected = build_protected_pids(all_procs, my_pid)
        candidates = {pid: info['name'] for pid, info in all_procs.items() if info.get('uid') == uid and pid not in protected}
        print(json.dumps({
            "exceptions": read_exceptions(),
            "protectedCount": len(protected),
            "candidateCount": len(candidates),
            "candidates": candidates
        }, indent=2))
    else:
        print(json.dumps({"error": f"Unknown command {cmd}"}))
        sys.exit(1)

if __name__ == "__main__":
    main()
