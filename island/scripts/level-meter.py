#!/usr/bin/env python3
"""Island level meter: taps the default sink's monitor ports via pw-record and
writes 4 real amplitude values (0.0-1.0) at ~12Hz to
$XDG_RUNTIME_DIR/cool-shell-levels as a single line: "v0 v1 v2 v3".

Why manual wiring: on this system `pw-record --target <monitor-name>` never
links (stays "connecting"), so we spawn pw-record unlinked (--target=0),
discover ports via pw-dump, and pw-link sink monitor_FL/FR to our inputs.
stdlib only."""

import atexit
import json
import math
import os
import signal
import struct
import subprocess
import sys
import time

RATE = 48000
CHUNK = 8192  # bytes per read (1024 stereo f32 frames)


def sh(args, timeout=8):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return r.stdout
    except Exception:
        return ""


def default_sink_name():
    sink = sh(["pactl", "get-default-sink"]).strip()
    return sink or None


def dump():
    try:
        return json.loads(sh(["pw-dump"]))
    except Exception:
        return []


def find_sink_monitors(objects, sink_name):
    node_id = None
    for o in objects:
        if o.get("type") == "PipeWire:Interface:Node":
            p = o.get("info", {}).get("props", {})
            if p.get("node.name") == sink_name:
                node_id = o.get("id")
                break
    if node_id is None:
        return []
    mons = {}
    for o in objects:
        if o.get("type") == "PipeWire:Interface:Port":
            p = o.get("info", {}).get("props", {})
            if p.get("node.id") == node_id:
                n = p.get("port.name", "")
                if n == "monitor_FL":
                    mons["fl"] = o.get("id")
                elif n == "monitor_FR":
                    mons["fr"] = o.get("id")
    return [mons.get("fl"), mons.get("fr")]


def find_rec_inputs(objects, tag):
    node_id = None
    for o in objects:
        if o.get("type") == "PipeWire:Interface:Node":
            p = o.get("info", {}).get("props", {})
            if p.get("media.name") == tag:
                node_id = o.get("id")
                break
    if node_id is None:
        return []
    ins = {}
    for o in objects:
        if o.get("type") == "PipeWire:Interface:Port":
            p = o.get("info", {}).get("props", {})
            if p.get("node.id") == node_id and p.get("port.name") in ("input_FL", "input_FR"):
                ins[p.get("port.name")] = o.get("id")
    return [ins.get("input_FL"), ins.get("input_FR")]


def stream_levels(proc, out_path):
    smooth = [0.0, 0.0, 0.0, 0.0]
    last_write = 0.0
    buf = b""
    while True:
        data = proc.stdout.read(CHUNK)
        if not data:
            break
        buf += data
        while len(buf) >= CHUNK:
            chunk, buf = buf[:CHUNK], buf[CHUNK:]
            n = len(chunk) // 4
            vals = struct.unpack("<%df" % n, chunk)
            q = n // 4
            bars = []
            for s in range(4):
                seg = vals[s * q:(s + 1) * q]
                rms = math.sqrt(sum(v * v for v in seg) / max(1, len(seg)))
                bars.append(min(1.0, rms * 2.5))
            now = time.monotonic()
            for i in range(4):
                if bars[i] > smooth[i]:
                    smooth[i] = bars[i]
                else:
                    smooth[i] += (bars[i] - smooth[i]) * 0.35
            if now - last_write >= 0.08:
                last_write = now
                write_levels(out_path, smooth)


def write_levels(out_path, vals):
    tmp = out_path + ".tmp"
    with open(tmp, "w") as f:
        f.write("%.3f %.3f %.3f %.3f\n" % tuple(vals))
    os.replace(tmp, out_path)


_CHILD = None


def _kill_child():
    global _CHILD
    if _CHILD is not None:
        try:
            # Own process group (start_new_session below) so stray links die too.
            os.killpg(os.getpgid(_CHILD.pid), signal.SIGTERM)
        except Exception:
            try:
                _CHILD.terminate()
            except Exception:
                pass
        _CHILD = None


def _handle_exit(signum, frame):
    _kill_child()
    sys.exit(0)


def capture_session(out_path, tag):
    global _CHILD
    sink = default_sink_name()
    if not sink:
        return False
    try:
        proc = subprocess.Popen(
            ["pw-record", "--target=0", "--channels=2",
             "--rate=%d" % RATE, "--format=f32",
             "-P", "{media.name=%s}" % tag, "-"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            start_new_session=True)
    except Exception:
        return False
    _CHILD = proc
    try:
        # Wait for our ports, then wire monitor -> us.
        deadline = time.monotonic() + 4.0
        linked = False
        while time.monotonic() < deadline:
            objs = dump()
            rec = find_rec_inputs(objs, tag)
            if rec[0] is not None and rec[1] is not None:
                mons = find_sink_monitors(objs, sink)
                if mons[0] is not None and mons[1] is not None:
                    subprocess.run(["pw-link", str(mons[0]), str(rec[0])],
                                   capture_output=True, timeout=5)
                    subprocess.run(["pw-link", str(mons[1]), str(rec[1])],
                                   capture_output=True, timeout=5)
                    linked = True
                    break
            time.sleep(0.2)
        if not linked:
            write_levels(out_path, [0.0, 0.0, 0.0, 0.0])
            return False
        stream_levels(proc, out_path)
    finally:
        _kill_child()
    return True


def main():
    signal.signal(signal.SIGTERM, _handle_exit)
    signal.signal(signal.SIGINT, _handle_exit)
    atexit.register(_kill_child)
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    out_path = os.path.join(runtime, "cool-shell-levels")
    tag = "cool-shell-levels-%d" % os.getpid()
    last_sink = None
    sink_since = time.monotonic()
    while True:
        sink = default_sink_name()
        if sink != last_sink:
            last_sink = sink
            sink_since = time.monotonic()
        # Re-resolve the sink every 30s (e.g. BT connect moves default).
        if time.monotonic() - sink_since > 30:
            sink_since = time.monotonic()
            last_sink = None
            continue
        ok = capture_session(out_path, tag)
        if not ok:
            time.sleep(2)


if __name__ == "__main__":
    sys.exit(main())
