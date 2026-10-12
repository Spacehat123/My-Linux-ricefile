#!/usr/bin/env python3
"""
Cool-Shell Phone Bridge Daemon
Handles:
1. Battery and charging status telemetry synchronization over ADB to Quickshell.
2. Reverse file ingestion: watches /sdcard/SendToPC/ on Android, pulls to ~/Downloads/Phone/,
   registers files into Stash Shelf, and triggers Dynamic Island notifications.
3. Wireless ADB auto-reconnect and device state management.
"""
import sys
import os
import time
import subprocess
import json
import signal
import re

PID_FILE = "/tmp/coolphone-bridge.pid"
CONFIG_FILE = os.path.expanduser("~/.config/cool-shell/phone.conf")
DOWNLOAD_DIR = os.path.expanduser("~/Downloads/Phone")
os.makedirs(DOWNLOAD_DIR, exist_ok=True)
os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)

ALLOWED_EXTENSIONS = {
    # Images
    "jpg", "jpeg", "png", "webp", "gif", "svg", "avif", "heic", "heif",
    # Audio
    "mp3", "flac", "ogg", "wav", "m4a", "aac", "opus",
    # Video
    "mp4", "webm", "mkv", "mov", "avi",
    # Documents
    "pdf", "txt", "md", "csv", "epub", "docx", "xlsx", "pptx",
    # Android Packages
    "apk"
}

def notify_island(text: str, duration: int = 3500):
    try:
        subprocess.run(
            ["qs", "-c", "cool-shell", "ipc", "call", "island", "showTransient", text, str(duration)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2
        )
    except Exception:
        pass

def update_shell_phone_state(connected: bool, battery: int, charging: bool):
    """Sends authoritative phone status to Quickshell via IPC."""
    conn_str = "true" if connected else "false"
    charg_str = "true" if charging else "false"
    try:
        subprocess.run(
            ["qs", "-c", "cool-shell", "ipc", "call", "phone", "setBattery", str(battery), charg_str, conn_str],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2
        )
    except Exception:
        pass

def get_adb_devices():
    try:
        res = subprocess.run(["adb", "devices"], capture_output=True, text=True, timeout=3)
        devices = []
        for line in res.stdout.strip().split("\n")[1:]:
            parts = line.split()
            if len(parts) >= 2 and parts[1] == "device":
                devices.append(parts[0])
        return devices
    except Exception:
        return []

def get_battery_info():
    try:
        res = subprocess.run(["adb", "shell", "dumpsys", "battery"], capture_output=True, text=True, timeout=3)
        level = -1
        charging = False
        for line in res.stdout.split("\n"):
            line = line.strip()
            if line.startswith("level:"):
                level = int(line.split(":")[1].strip())
            elif line.startswith("status:"):
                status_code = int(line.split(":")[1].strip())
                charging = (status_code == 2)  # 2 = CHARGING
            elif line.startswith("AC powered:") or line.startswith("USB powered:") or line.startswith("Wireless powered:"):
                if "true" in line:
                    charging = True
        return level, charging
    except Exception:
        return -1, False

def check_and_pull_inbox():
    """Checks /sdcard/SendToPC/ on Android, pulls new files to PC, and notifies."""
    try:
        # Ensure remote directory exists
        subprocess.run(
            ["adb", "shell", "mkdir", "-p", "/sdcard/SendToPC"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3
        )
        # List files in remote inbox
        res = subprocess.run(
            ["adb", "shell", "ls", "-1", "/sdcard/SendToPC"],
            capture_output=True, text=True, timeout=3
        )
        remote_files = [f.strip() for f in res.stdout.strip().split("\n") if f.strip() and not f.startswith("ls:")]
        
        for rf in remote_files:
            ext = rf.split(".")[-1].lower() if "." in rf else ""
            if ext not in ALLOWED_EXTENSIONS:
                print(f"[-] Disallowed file in outbox: {rf}, skipping.")
                continue

            local_dest = os.path.join(DOWNLOAD_DIR, rf)
            remote_path = f"/sdcard/SendToPC/{rf}"
            
            # Pull file
            pull_res = subprocess.run(["adb", "pull", remote_path, local_dest], timeout=20)
            if pull_res.returncode == 0:
                # Remove from phone outbox
                subprocess.run(["adb", "shell", "rm", "-f", f'"{remote_path}"'], timeout=5)
                print(f"[+] Received: {rf} -> {local_dest}")
                notify_island(f"📥 Received {rf} from Phone", 4000)
                
                # Register in Cool-Shell Shelf if available
                register_in_shelf(local_dest)
    except Exception as e:
        pass

def register_in_shelf(filepath: str):
    try:
        subprocess.run(
            ["qs", "-c", "cool-shell", "ipc", "call", "island", "shelfAdd", filepath],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2
        )
    except Exception:
        pass

def connect_wireless(ip: str):
    """Enables wireless ADB on port 5555 and connects to target IP."""
    print(f"[*] Setting ADB to TCP mode 5555...")
    subprocess.run(["adb", "tcpip", "5555"], timeout=5)
    time.sleep(1)
    print(f"[*] Connecting to {ip}:5555...")
    res = subprocess.run(["adb", "connect", f"{ip}:5555"], capture_output=True, text=True, timeout=5)
    print(res.stdout)
    with open(CONFIG_FILE, "w") as f:
        f.write(f'WIRELESS_IP="{ip}"\n')
    print(f"[+] Saved wireless IP {ip} to {CONFIG_FILE}")

def run_loop():
    print("[*] Phone Bridge Daemon started.")
    last_conn_state = False
    last_battery = -1
    last_charging = False
    poll_counter = 0

    while True:
        devices = get_adb_devices()
        connected = len(devices) > 0

        if connected:
            battery, charging = get_battery_info()
            if (connected != last_conn_state) or (battery != last_battery) or (charging != last_charging):
                update_shell_phone_state(True, battery, charging)
                last_conn_state = True
                last_battery = battery
                last_charging = charging

            # Check incoming files every ~2 seconds (every 2nd tick)
            if poll_counter % 2 == 0:
                check_and_pull_inbox()
        else:
            if last_conn_state:
                update_shell_phone_state(False, -1, False)
                last_conn_state = False
                last_battery = -1
                last_charging = False

        poll_counter += 1
        time.sleep(1.0)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "--pair" and len(sys.argv) > 2:
            connect_wireless(sys.argv[2])
            sys.exit(0)
        elif cmd == "--status":
            devs = get_adb_devices()
            lvl, chg = get_battery_info() if devs else (-1, False)
            print(json.dumps({
                "connected": len(devs) > 0,
                "devices": devs,
                "battery": lvl,
                "charging": chg
            }))
            sys.exit(0)

    # Save PID and run daemon loop
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    def handle_exit(sig, frame):
        try:
            os.remove(PID_FILE)
        except Exception:
            pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_exit)
    signal.signal(signal.SIGINT, handle_exit)

    run_loop()
