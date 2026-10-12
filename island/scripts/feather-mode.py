#!/usr/bin/env python3
"""
The Feather - Absolute Battery Mode for cool-shell / Hyprland
Resource Limits & Maximum Power Preservation:
- CFS cgroup Bandwidth Quota (CPU limit: 20% / 240% quota or 35% / 420% quota on app.slice)
- Hyprland Lua Shader & Animation Stripping (0 blur passes, 0 drop-shadow passes, 0 animations)
- Display Refresh Throttling (30Hz cap for 20% mode; 60Hz balanced for 35% mode)
- Display Brightness Preservation (15% for 20% mode; 30% for 35% mode)
- NVIDIA dGPU RTD3 Sleep Enforcement (prunes non-essential GPU clients like swaync so GTX 1650 drops to deep idle/sleep)
- Wallpaper daemon and video decoding halted (awww-daemon terminated)
- Prunes non-essential user applications (browsers, discord, spotify, steam, media bloat)
- Preserves systemd, D-Bus, Polkit, Hyprland, quickshell, PipeWire, terminals, portals, and AGY pair-programming
- Turning off cleanly restores normal Hyprland visuals, 60Hz display, brightness, CPU quota, and wallpaper
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
    # Polkit, Auth & Accessibility
    "polkitd", "polkit-kde-authentication-agent-1", "polkit-gnome-authentication-agent-1", "hyprpolkitagent", "dconf-service",
    "gpg-agent", "scdaemon", "at-spi2-registr", "at-spi-bus-laun", "at-spi2-registryd",
    "fusermount", "fusermount3",
    # Distro login managers, TTYs, login shells
    "-fish", "-bash", "-zsh", "-sh",
    "login", "agetty", "getty", "greetd", "tuigreet", "sddm", "gdm", "lightdm",
    # Compositor & Display (Kept alive at bare minimum so apps can start)
    "Hyprland", "hyprland", "start-hyprland", "Xwayland", "hypridle", "hyprlock", "hyprpm",
    # Desktop Shell (keeps Left Sidebar operable for clean restoration)
    "quickshell",
    # Terminal Emulators (preserve user shells and terminal tasks)
    "kitty", "kitten", "alacritty", "foot", "ghostty", "wezterm", "konsole", "tmux",
    # Portals & standard UI helpers
    "xdg-desktop-por", "xdg-desktop-portal", "xdg-desktop-portal-gtk", "xdg-permission-", "xdg-document-po",
    "zenity", "rofi",
    # Distro hardware, power & networking
    "upowerd", "NetworkManager", "wpa_supplicant", "iwd", "bluetoothd", "rtkit-daemon",
    "brightnessctl",
    # Distro audio stack (PipeWire / WirePlumber)
    "pipewire", "wireplumber", "pipewire-pulse", "pipewire-media-session",
    # Agent & Coding Environment (keeps pair-programming alive)
    "antigravity", "agy", "python3"
}

ESSENTIAL_SUBSTRINGS = [
    "hypr", "quickshell", "systemd", "dbus", "polkit", "antigravity", "agy", "wireplumber", "pipewire", "portal"
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
    return {
        "featherMode": False,
        "limit": 20,
        "cpuQuotaPercent": 0,
        "targetRefreshRate": 60,
        "killedCount": 0,
        "killedNames": [],
        "savedBrightness": None,
        "savedMonitors": {}
    }

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

def get_active_monitors():
    try:
        res = subprocess.run(["hyprctl", "-j", "monitors"], capture_output=True, text=True, check=True)
        mons = json.loads(res.stdout)
        return [m for m in mons if not m.get("disabled", False)]
    except Exception:
        return []

def apply_monitor_refresh(target_hz: float, saved_monitors: dict = None) -> dict:
    """
    If target_hz <= 30, sets active monitors to 30Hz if supported.
    If target_hz >= 60, restores original modes or 60Hz.
    Returns the dictionary of original monitor configurations.
    """
    current_saved = dict(saved_monitors or {})
    monitors = get_active_monitors()

    for m in monitors:
        name = m.get("name")
        w = m.get("width")
        h = m.get("height")
        current_rr = float(m.get("refreshRate", 60.0))
        x = m.get("x", 0)
        y = m.get("y", 0)
        scale = m.get("scale", 1)
        modes = m.get("availableModes", [])

        if name not in current_saved:
            current_saved[name] = {
                "width": w,
                "height": h,
                "refreshRate": current_rr,
                "x": x,
                "y": y,
                "scale": scale
            }

        if target_hz <= 30.0:
            has_30 = any(f"{w}x{h}" in mode and ("30.00Hz" in mode or "@30" in mode) for mode in modes)
            if has_30:
                lua_cmd = f'hl.monitor({{ output = "{name}", mode = "{w}x{h}@30.0", position = "{x}x{y}", scale = {scale}, disabled = false, vrr = 0 }})'
                subprocess.run(["hyprctl", "eval", lua_cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            orig = current_saved.get(name, {})
            orig_w = orig.get("width", w)
            orig_h = orig.get("height", h)
            orig_rr = orig.get("refreshRate", 60.0)
            lua_cmd = f'hl.monitor({{ output = "{name}", mode = "{orig_w}x{orig_h}@{orig_rr:.1f}", position = "{x}x{y}", scale = {scale}, disabled = false, vrr = 0 }})'
            subprocess.run(["hyprctl", "eval", lua_cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    return current_saved

def set_compositor_eco(enabled: bool):
    """Uses Hyprland Lua engine to toggle animations, blur passes, and window drop-shadows."""
    if enabled:
        subprocess.run(["hyprctl", "eval", "hl.config({ animations = { enabled = false } })"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["hyprctl", "eval", "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } } })"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        subprocess.run(["hyprctl", "eval", "hl.config({ animations = { enabled = true } })"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["hyprctl", "eval", "hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true } } })"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def set_cpu_quota(limit_percent: int) -> int:
    """Sets CFS bandwidth quota on user app.slice without root privileges."""
    try:
        cpus = os.cpu_count() or 4
        quota = int(cpus * limit_percent)
        subprocess.run(["systemctl", "--user", "set-property", "app.slice", f"CPUQuota={quota}%"],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return quota
    except Exception:
        return 0

def reset_cpu_quota():
    try:
        subprocess.run(["systemctl", "--user", "set-property", "app.slice", "CPUQuota="],
                       check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def optimize_gpu_sleep():
    """Stops non-essential processes attached to dGPU so NVIDIA can drop to deep sleep/P8 idle."""
    try:
        subprocess.run(["systemctl", "--user", "stop", "swaync.service"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        res = subprocess.run(["nvidia-smi", "--query-compute-apps=pid,process_name", "--format=csv,noheader,nounits"],
                             capture_output=True, text=True, check=False)
        for line in res.stdout.splitlines():
            parts = [p.strip() for p in line.split(",") if p.strip()]
            if parts and parts[0].isdigit():
                gpid = int(parts[0])
                try:
                    os.kill(gpid, signal.SIGTERM)
                except Exception:
                    pass
    except Exception:
        pass

def apply_resource_limits(limit_percent: int, state: dict) -> dict:
    """Applies CPU and GPU caps based on the requested limit percentage (e.g. 20% or 35%)."""
    limit = max(10, min(100, int(limit_percent)))
    state["limit"] = limit

    # 1. CPU CFS Quota
    quota = set_cpu_quota(limit)
    state["cpuQuotaPercent"] = quota

    # 2. Display Refresh Rate & GPU VBlank Throttling
    target_hz = 30.0 if limit <= 25 else 60.0
    saved_mons = state.get("savedMonitors", {})
    updated_saved = apply_monitor_refresh(target_hz, saved_mons)
    state["savedMonitors"] = updated_saved
    state["targetRefreshRate"] = 30 if limit <= 25 else 60

    # 3. Display Brightness Level
    target_bright = "15%" if limit <= 25 else "30%"
    set_brightness(target_bright)

    return state

def enable_feather_mode(limit: int = 20):
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

    # Step 3: Optimize NVIDIA GPU sleep
    optimize_gpu_sleep()

    # Step 4: Strip Hyprland to absolute bare minimum (0 animations, 0 blur, 0 shadows)
    set_compositor_eco(True)

    # Step 5: Halt wallpaper daemon to stop GPU decoding
    try:
        subprocess.run(["pkill", "-TERM", "awww-daemon"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    # Step 6: Save current display brightness before dimming
    saved_bright = get_current_brightness()

    # Step 7: Build initial state and apply CPU & GPU resource limits
    curr = read_state()
    saved_mons = curr.get("savedMonitors", {})
    state = {
        "featherMode": True,
        "limit": limit,
        "killedCount": len(killed_names),
        "killedNames": killed_names[:25],
        "savedBrightness": saved_bright,
        "savedMonitors": saved_mons,
        "timestamp": int(time.time())
    }
    state = apply_resource_limits(limit, state)
    write_state(state)
    return state

def disable_feather_mode():
    curr = read_state()
    saved_bright = curr.get("savedBrightness")
    saved_mons = curr.get("savedMonitors", {})
    saved_limit = curr.get("limit", 20)

    # Step 1: Unconstrain CPU CFS quota on app.slice
    reset_cpu_quota()

    # Step 2: Restore full Hyprland visual fidelity (animations, blur, shadows)
    set_compositor_eco(False)

    # Step 3: Restore display refresh rate (60Hz / native)
    apply_monitor_refresh(60.0, saved_mons)

    # Step 4: Restore display brightness
    if saved_bright is not None:
        set_brightness(saved_bright)

    # Step 5: Relaunch wallpaper daemon and restore normal wallpaper
    try:
        subprocess.Popen(["awww-daemon"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        time.sleep(0.2)
        theme_script = Path(__file__).resolve().parent / "theme-system.sh"
        if theme_script.exists():
            subprocess.Popen([str(theme_script), "restore-wallpaper"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except Exception:
        pass

    state = {
        "featherMode": False,
        "limit": saved_limit,
        "cpuQuotaPercent": 0,
        "targetRefreshRate": 60,
        "killedCount": 0,
        "killedNames": [],
        "savedBrightness": None,
        "savedMonitors": {},
        "timestamp": int(time.time())
    }
    write_state(state)
    return state

def set_limit(new_limit: int):
    curr = read_state()
    limit = max(10, min(100, int(new_limit)))
    if curr.get("featherMode", False):
        curr = apply_resource_limits(limit, curr)
    else:
        curr["limit"] = limit
    write_state(curr)
    return curr

def parse_limit_arg(args, default=20):
    for i, a in enumerate(args):
        if a.startswith("--limit="):
            try:
                return int(a.split("=")[1])
            except ValueError:
                pass
        elif a in ("--limit", "-l") and i + 1 < len(args):
            try:
                return int(args[i + 1])
            except ValueError:
                pass
        elif a.isdigit():
            return int(a)
    return default

def main():
    args = sys.argv[1:]
    cmd = args[0] if len(args) > 0 else "status"

    if cmd in ("enable", "on"):
        limit = parse_limit_arg(args[1:], default=20)
        result = enable_feather_mode(limit=limit)
        print(json.dumps(result))
    elif cmd in ("disable", "off"):
        result = disable_feather_mode()
        print(json.dumps(result))
    elif cmd == "toggle":
        curr = read_state()
        if curr.get("featherMode", False):
            result = disable_feather_mode()
        else:
            limit = parse_limit_arg(args[1:], default=curr.get("limit", 20))
            result = enable_feather_mode(limit=limit)
        print(json.dumps(result))
    elif cmd in ("set-limit", "limit"):
        limit = parse_limit_arg(args[1:], default=20)
        result = set_limit(limit)
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
            "mode": "dry-run (The Feather Mode)",
            "protectedCount": len(protected),
            "candidatesCount": len(candidates),
            "candidates": candidates
        }, indent=2))
    else:
        print(json.dumps({
            "error": f"Unknown command {cmd}",
            "usage": "feather-mode.py [status|enable [limit]|disable|toggle [limit]|set-limit <limit>|dry-run]"
        }))
        sys.exit(1)

if __name__ == "__main__":
    main()
