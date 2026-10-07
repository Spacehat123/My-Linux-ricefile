#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

THUMB_DIR = "/tmp/cool-shell-thumbs"

def capture_all():
    t0 = time.time()
    os.makedirs(THUMB_DIR, exist_ok=True)
    try:
        raw = subprocess.check_output(["hyprctl", "clients", "-j"], timeout=1.0)
        clients = json.loads(raw.decode("utf-8", errors="ignore"))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        return

    active_sids = set()
    to_capture = []
    for c in clients:
        sid = c.get("stableId")
        if sid and c.get("mapped", False):
            sid_str = str(sid)
            active_sids.add(sid_str)
            to_capture.append(sid_str)

    def _worker(sid_str):
        out_path = os.path.join(THUMB_DIR, f"{sid_str}.jpg")
        try:
            # -t jpeg -q 70 produces high quality crisp miniature at low byte size
            subprocess.run(
                ["grim", "-T", sid_str, "-t", "jpeg", "-q", "70", out_path],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=0.8
            )
            return sid_str
        except Exception:
            return None

    captured = []
    with ThreadPoolExecutor(max_workers=6) as executor:
        for res in executor.map(_worker, to_capture):
            if res:
                captured.append(res)

    elapsed_ms = round((time.time() - t0) * 1000, 1)
    print(json.dumps({
        "success": True,
        "captured": captured,
        "count": len(captured),
        "timeMs": elapsed_ms
    }))

if __name__ == "__main__":
    capture_all()
