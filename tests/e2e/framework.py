"""
E2E Test Framework for cool-shell Optimization & Capability Enhancement.
Provides opaque test utilities, process inspection, system metrics, IPC callers,
isolated temporary environments, and test case registration.
"""

import os
import sys
import re
import json
import time
import shutil
import tempfile
import subprocess
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple, Union

BASE_DIR = Path("/home/pranc/.config/quickshell/cool-shell").resolve()
HYPR_CONFIG_DIR = Path.home() / ".config" / "hypr"
HYPRLAND_LUA = HYPR_CONFIG_DIR / "hyprland.lua"
SHORTCUTS_CUSTOM_LUA = HYPR_CONFIG_DIR / "shortcuts_custom.lua"
FIXTURES_DIR = BASE_DIR / "tests" / "e2e" / "fixtures"


# ==============================================================================
# Assertion Helpers
# ==============================================================================

def assert_true(condition: bool, msg: Optional[str] = None) -> None:
    if not condition:
        raise AssertionError(msg or "Expected condition to be True, but was False.")


def assert_false(condition: bool, msg: Optional[str] = None) -> None:
    if condition:
        raise AssertionError(msg or "Expected condition to be False, but was True.")


def assert_equal(actual: Any, expected: Any, msg: Optional[str] = None) -> None:
    if actual != expected:
        raise AssertionError(msg or f"Expected {expected!r}, but got {actual!r}.")


def assert_not_equal(actual: Any, expected: Any, msg: Optional[str] = None) -> None:
    if actual == expected:
        raise AssertionError(msg or f"Expected value different from {expected!r}.")


def assert_in(member: Any, container: Any, msg: Optional[str] = None) -> None:
    if member not in container:
        raise AssertionError(msg or f"Expected {member!r} in {container!r}.")


def assert_not_in(member: Any, container: Any, msg: Optional[str] = None) -> None:
    if member in container:
        raise AssertionError(msg or f"Did not expect {member!r} in {container!r}.")


def assert_regex(pattern: str, text: str, msg: Optional[str] = None) -> None:
    if not re.search(pattern, text):
        raise AssertionError(msg or f"Regex {pattern!r} did not match text {text[:200]!r}.")


def assert_not_regex(pattern: str, text: str, msg: Optional[str] = None) -> None:
    if re.search(pattern, text):
        raise AssertionError(msg or f"Regex {pattern!r} matched text unexpectedly.")


def assert_less(a: Union[int, float], b: Union[int, float], msg: Optional[str] = None) -> None:
    if not (a < b):
        raise AssertionError(msg or f"Expected {a} < {b}.")


def assert_less_equal(a: Union[int, float], b: Union[int, float], msg: Optional[str] = None) -> None:
    if not (a <= b):
        raise AssertionError(msg or f"Expected {a} <= {b}.")


def assert_greater(a: Union[int, float], b: Union[int, float], msg: Optional[str] = None) -> None:
    if not (a > b):
        raise AssertionError(msg or f"Expected {a} > {b}.")


def assert_greater_equal(a: Union[int, float], b: Union[int, float], msg: Optional[str] = None) -> None:
    if not (a >= b):
        raise AssertionError(msg or f"Expected {a} >= {b}.")


def strip_qml_comments(code: str) -> str:
    """Strip single-line (//...) and multi-line (/*...*/) comments from QML code."""
    code = re.sub(r'/\*.*?\*/', '', code, flags=re.DOTALL)
    code = re.sub(r'//.*', '', code)
    return code


# ==============================================================================
# Test Model & Registry
# ==============================================================================

class TestResult:
    def __init__(
        self,
        test_id: str,
        tier: int,
        feature: str,
        description: str,
        status: str,
        duration: float = 0.0,
        message: str = "",
        details: Optional[Dict[str, Any]] = None,
    ):
        self.test_id = test_id
        self.tier = tier
        self.feature = feature
        self.description = description
        self.status = status  # "PASS", "FAIL", "SKIP", "ERROR"
        self.duration = duration
        self.message = message
        self.details = details or {}

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.test_id,
            "tier": self.tier,
            "feature": self.feature,
            "description": self.description,
            "status": self.status,
            "duration": round(self.duration, 4),
            "message": self.message,
            "details": self.details,
        }


class TestCase:
    def __init__(
        self,
        test_id: str,
        tier: int,
        feature: str,
        description: str,
        fn: Callable[..., Any],
        tags: Optional[List[str]] = None,
    ):
        self.test_id = test_id
        self.tier = tier
        self.feature = feature
        self.description = description
        self.fn = fn
        self.tags = tags or []

    def run(self) -> TestResult:
        start_time = time.perf_counter()
        try:
            self.fn()
            duration = time.perf_counter() - start_time
            return TestResult(
                test_id=self.test_id,
                tier=self.tier,
                feature=self.feature,
                description=self.description,
                status="PASS",
                duration=duration,
                message="OK",
            )
        except AssertionError as e:
            duration = time.perf_counter() - start_time
            return TestResult(
                test_id=self.test_id,
                tier=self.tier,
                feature=self.feature,
                description=self.description,
                status="FAIL",
                duration=duration,
                message=str(e),
            )
        except Exception as e:
            duration = time.perf_counter() - start_time
            return TestResult(
                test_id=self.test_id,
                tier=self.tier,
                feature=self.feature,
                description=self.description,
                status="ERROR",
                duration=duration,
                message=f"Unhandled {type(e).__name__}: {e}",
            )


class TestRegistry:
    def __init__(self):
        self._tests: Dict[str, TestCase] = {}

    def register(
        self,
        test_id: str,
        tier: int,
        description: str,
        feature: str = "",
        tags: Optional[List[str]] = None,
    ):
        def decorator(fn: Callable[..., Any]):
            feat = feature
            if not feat:
                # Infer feature from test_id: T1_R1_1_01 -> R1.1
                m = re.match(r"^T\d+_(R\d+)_(\d+)", test_id)
                if m:
                    feat = f"{m.group(1)}.{m.group(2)}"
                elif "PAIR" in test_id:
                    feat = "T3_PAIR"
                elif "SCEN" in test_id:
                    feat = "T4_SCEN"
            self._tests[test_id] = TestCase(
                test_id=test_id,
                tier=tier,
                feature=feat,
                description=description,
                fn=fn,
                tags=tags or [],
            )
            return fn

        return decorator

    def get_test(self, test_id: str) -> Optional[TestCase]:
        return self._tests.get(test_id)

    def get_tests(
        self,
        tier: Optional[int] = None,
        filter_pattern: Optional[str] = None,
    ) -> List[TestCase]:
        tests = list(self._tests.values())
        # Sort naturally by test_id
        def sort_key(t: TestCase):
            parts = re.split(r"(\d+)", t.test_id)
            return [int(p) if p.isdigit() else p for p in parts]

        tests.sort(key=sort_key)

        if tier is not None:
            tests = [t for t in tests if t.tier == tier]

        if filter_pattern:
            try:
                pat = re.compile(filter_pattern, re.IGNORECASE)
            except re.error as e:
                raise ValueError(f"malformed regular expression: {e}") from e
            tests = [
                t
                for t in tests
                if pat.search(t.test_id)
                or pat.search(t.feature)
                or pat.search(t.description)
            ]

        return tests

    @property
    def count(self) -> int:
        return len(self._tests)


registry = TestRegistry()
register_test = registry.register


# ==============================================================================
# System & Process Inspection Utilities
# ==============================================================================

def find_process_pids(name_pattern: str) -> List[int]:
    """Find process IDs matching name_pattern via pgrep or /proc scan."""
    try:
        res = subprocess.run(
            ["pgrep", "-f", name_pattern],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=2.0,
        )
        if res.returncode == 0:
            pids = []
            for line in res.stdout.strip().splitlines():
                line = line.strip()
                if line.isdigit():
                    pids.append(int(line))
            return pids
    except Exception:
        pass

    # Fallback to /proc scan
    pids = []
    proc = Path("/proc")
    if proc.exists():
        for p in proc.iterdir():
            if p.is_dir() and p.name.isdigit():
                cmdline = p / "cmdline"
                if cmdline.exists():
                    try:
                        content = cmdline.read_bytes().replace(b"\0", b" ").decode(
                            "utf-8", errors="ignore"
                        )
                        if name_pattern in content:
                            pids.append(int(p.name))
                    except (OSError, PermissionError):
                        continue
    return pids


def get_quickshell_pids() -> List[int]:
    """Get active Quickshell process IDs for cool-shell."""
    pids = find_process_pids("quickshell.*cool-shell")
    if not pids:
        pids = find_process_pids("quickshell")
    return pids


def sample_process_cpu_percent(pid: int, interval: float = 0.5) -> float:
    """
    Calculate instantaneous CPU usage % for a process over interval seconds
    using delta ticks from /proc/[pid]/stat and /proc/stat.
    """
    stat_file = Path(f"/proc/{pid}/stat")
    sys_stat = Path("/proc/stat")

    if not stat_file.exists() or not sys_stat.exists():
        return 0.0

    def read_ticks():
        try:
            with open(stat_file, "r") as f:
                parts = f.read().split()
                # utime is field 14, stime is field 15 (0-indexed: 13, 14)
                proc_ticks = int(parts[13]) + int(parts[14])
            with open(sys_stat, "r") as f:
                cpu_line = f.readline().split()[1:]
                sys_ticks = sum(int(x) for x in cpu_line)
            return proc_ticks, sys_ticks
        except (IndexError, ValueError, OSError):
            return 0, 0

    p1, s1 = read_ticks()
    time.sleep(interval)
    p2, s2 = read_ticks()

    delta_proc = p2 - p1
    delta_sys = s2 - s1

    if delta_sys <= 0:
        return 0.0

    cpu_count = os.cpu_count() or 1
    # Percentage of a single core: (delta_proc / delta_sys) * cpu_count * 100.0
    usage = (delta_proc / delta_sys) * cpu_count * 100.0
    return max(0.0, usage)


def read_gpu_busy_percent() -> float:
    """Read GPU busy percentage from /sys/class/drm/card*/device/gpu_busy_percent."""
    drm = Path("/sys/class/drm")
    if not drm.exists():
        return 0.0

    for card in sorted(drm.glob("card*")):
        busy_file = card / "device" / "gpu_busy_percent"
        if busy_file.exists():
            try:
                content = busy_file.read_text().strip()
                return float(content)
            except (OSError, ValueError):
                continue
    return 0.0


def get_process_thread_comms(pid: int) -> List[str]:
    """Retrieve thread comm names for a process from /proc/[pid]/task/*/comm."""
    task_dir = Path(f"/proc/{pid}/task")
    comms = []
    if task_dir.exists():
        for task in task_dir.iterdir():
            comm_file = task / "comm"
            if comm_file.exists():
                try:
                    comms.append(comm_file.read_text().strip())
                except OSError:
                    continue
    return comms


def count_threads_matching(pid: int, pattern: str) -> int:
    """Count threads whose comm name matches regex pattern."""
    regex = re.compile(pattern, re.IGNORECASE)
    comms = get_process_thread_comms(pid)
    return sum(1 for c in comms if regex.search(c))


def is_awww_running() -> bool:
    """Check if awww-daemon is running."""
    pids = find_process_pids("awww-daemon")
    return len(pids) > 0


# ==============================================================================
# IPC Utilities (Quickshell & Hyprland)
# ==============================================================================

def quickshell_ipc_call(target: str, method: str, *args: Any, timeout: float = 3.0) -> Dict[str, Any]:
    """
    Call a Quickshell IPC method: qs -c cool-shell ipc call <target> <method> [args...]
    Returns dict parsed from JSON stdout, or error dict.
    """
    cmd = ["qs", "-c", "cool-shell", "ipc", "call", target, method]
    for arg in args:
        cmd.append(str(arg))

    try:
        res = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
        )
        out = res.stdout.strip()
        if not out:
            return {"success": res.returncode == 0, "error": res.stderr.strip()}
        try:
            return json.loads(out)
        except json.JSONDecodeError:
            return {"success": res.returncode == 0, "raw": out}
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "IPC call timed out"}
    except FileNotFoundError:
        return {"success": False, "error": "qs binary not found in PATH"}


def quickshell_ipc_prop(target: str, prop: str, timeout: float = 3.0) -> Dict[str, Any]:
    """Get property via quickshell IPC: qs -c cool-shell ipc prop <target> <prop>."""
    cmd = ["qs", "-c", "cool-shell", "ipc", "prop", target, prop]
    try:
        res = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
        )
        out = res.stdout.strip()
        try:
            return {"success": True, "value": json.loads(out)}
        except json.JSONDecodeError:
            return {"success": True, "value": out}
    except Exception as e:
        return {"success": False, "error": str(e)}


def hyprctl_cmd(subcmd: str, *args: Any, json_output: bool = False, timeout: float = 3.0) -> Tuple[int, str]:
    """Execute hyprctl command, optionally with -j flag."""
    cmd = ["hyprctl"]
    if json_output:
        cmd.append("-j")
    cmd.append(subcmd)
    for arg in args:
        cmd.append(str(arg))

    try:
        res = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
        )
        return res.returncode, res.stdout.strip()
    except Exception as e:
        return -1, str(e)


def hyprctl_reload() -> bool:
    """Execute hyprctl reload and return True if successful."""
    code, out = hyprctl_cmd("reload")
    return code == 0 and ("ok" in out.lower() or out == "")


# ==============================================================================
# Lua Syntax & Drop-In Helpers
# ==============================================================================

def validate_lua_syntax(lua_code_or_path: Union[str, Path]) -> Tuple[bool, str]:
    """Check Lua code or file syntax with luac -p. Returns (is_valid, error_msg)."""
    p = Path(str(lua_code_or_path))
    if p.exists() and p.is_file():
        cmd = ["luac", "-p", str(p)]
        input_data = None
    else:
        cmd = ["luac", "-p", "-"]
        input_data = str(lua_code_or_path)

    try:
        res = subprocess.run(
            cmd,
            input=input_data,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=2.0,
        )
        if res.returncode == 0:
            return True, ""
        return False, res.stderr.strip()
    except Exception as e:
        return False, f"Lua syntax check error: {e}"


# ==============================================================================
# Isolated Temp Environment Context Manager
# ==============================================================================

class TempEnvironment:
    """
    Provides an isolated filesystem environment for executing installer flags
    and testing mock Hyprland / Quickshell setups safely without side effects.
    """

    def __init__(self, prefix: str = "cool_shell_test_"):
        self.temp_dir = tempfile.TemporaryDirectory(prefix=prefix)
        self.root = Path(self.temp_dir.name)
        self.home = self.root / "home" / "testuser"
        self.config_dir = self.home / ".config"
        self.cool_shell_dir = self.config_dir / "quickshell" / "cool-shell"
        self.hypr_dir = self.config_dir / "hypr"
        self.local_share = self.home / ".local" / "share"
        self.pictures_wallpapers = self.home / "Pictures" / "Wallpapers"
        self.bin_dir = self.root / "bin"
        self._orig_env: Dict[str, Optional[str]] = {}

    def __enter__(self):
        # Create standard directory layout
        for d in [self.hypr_dir, self.cool_shell_dir, self.local_share, self.pictures_wallpapers, self.bin_dir]:
            d.mkdir(parents=True, exist_ok=True)

        # Copy cool-shell installer and requirements to temp cool_shell_dir
        for item in ["install.sh", "requirements.txt", "Other-stuff"]:
            src = BASE_DIR / item
            dst = self.cool_shell_dir / item
            if src.is_file():
                shutil.copy2(src, dst)
            elif src.is_dir():
                shutil.copytree(src, dst)

        # Set up mock hyprland.lua
        shutil.copy2(FIXTURES_DIR / "mock_hyprland.lua", self.hypr_dir / "hyprland.lua")

        # Snapshot and override environment (including PATH to prioritize bin_dir)
        self._orig_env = {
            "HOME": os.environ.get("HOME"),
            "XDG_CONFIG_HOME": os.environ.get("XDG_CONFIG_HOME"),
            "XDG_DATA_HOME": os.environ.get("XDG_DATA_HOME"),
            "PATH": os.environ.get("PATH"),
        }
        os.environ["HOME"] = str(self.home)
        os.environ["XDG_CONFIG_HOME"] = str(self.config_dir)
        os.environ["XDG_DATA_HOME"] = str(self.local_share)
        os.environ["PATH"] = f"{self.bin_dir}:{os.environ.get('PATH', '')}"
        return self

    def _make_all_writable(self) -> None:
        """Recursively ensure all temp files and dirs are writable so cleanup succeeds."""
        for root, dirs, files in os.walk(self.root, followlinks=False):
            for d in dirs:
                p = os.path.join(root, d)
                if not os.path.islink(p):
                    try:
                        os.chmod(p, 0o755)
                    except OSError:
                        pass
            for f in files:
                p = os.path.join(root, f)
                if not os.path.islink(p):
                    try:
                        os.chmod(p, 0o644)
                    except OSError:
                        pass

    def __exit__(self, exc_type, exc_val, exc_tb):
        # Restore environment variables
        for k, v in self._orig_env.items():
            if v is not None:
                os.environ[k] = v
            else:
                os.environ.pop(k, None)
        # Fix permissions before tempdir cleanup to avoid PermissionError on read-only trees
        self._make_all_writable()
        self.temp_dir.cleanup()

    # --- Permission Simulation APIs ---
    def set_read_only(self, target: Union[str, Path]) -> Path:
        """Set read-only permissions (0o555 for directory, 0o444 for file)."""
        p = Path(target)
        if p.is_dir():
            os.chmod(p, 0o555)
        else:
            os.chmod(p, 0o444)
        return p

    def set_writable(self, target: Union[str, Path]) -> Path:
        """Restore write permissions (0o755 for directory, 0o644 for file)."""
        p = Path(target)
        if p.is_dir():
            os.chmod(p, 0o755)
        else:
            os.chmod(p, 0o644)
        return p

    # --- Symlink Simulation APIs ---
    def create_symlink(self, link_path: Union[str, Path], target_path: Union[str, Path]) -> Path:
        """Create a symlink with automatic parent directory creation."""
        lp = Path(link_path)
        lp.parent.mkdir(parents=True, exist_ok=True)
        lp.symlink_to(Path(target_path))
        return lp

    def create_symlink_loop(self, directory: Union[str, Path], link_name: str = "loop") -> Path:
        """Create a self-referential symlink loop inside directory pointing to itself."""
        d = Path(directory)
        d.mkdir(parents=True, exist_ok=True)
        link = d / link_name
        link.symlink_to(d)
        return link

    def create_broken_symlink(self, link_path: Union[str, Path], target_path: str = "/nonexistent/target") -> Path:
        """Create a broken/dangling symlink pointing to a non-existent path."""
        lp = Path(link_path)
        lp.parent.mkdir(parents=True, exist_ok=True)
        lp.symlink_to(Path(target_path))
        return lp

    # --- Mock Binary & PATH Interception APIs ---
    def mock_command(
        self,
        cmd_name: str,
        exit_code: int = 0,
        stdout: str = "",
        stderr: str = "",
        record_calls: bool = True,
    ) -> Path:
        """
        Creates an executable shell script in self.bin_dir (which is in PATH)
        to mock system binaries (e.g. paru, yay, pacman, fc-list).
        """
        mock_file = self.bin_dir / cmd_name
        log_file = self.bin_dir / f"{cmd_name}.calls"
        rec_line = f'echo "$@" >> "{log_file}"' if record_calls else ""
        script = f"""#!/usr/bin/env bash
{rec_line}
if [ -n "{stderr}" ]; then echo "{stderr}" >&2; fi
if [ -n "{stdout}" ]; then echo "{stdout}"; fi
exit {exit_code}
"""
        mock_file.write_text(script, encoding="utf-8")
        mock_file.chmod(0o755)
        return mock_file

    def get_command_calls(self, cmd_name: str) -> List[str]:
        """Retrieve logged argument invocations for a mocked command."""
        log_file = self.bin_dir / f"{cmd_name}.calls"
        if not log_file.exists():
            return []
        return [line.strip() for line in log_file.read_text(encoding="utf-8").splitlines() if line.strip()]

    def remove_mock(self, cmd_name: str) -> None:
        """Remove a mock command and its call log."""
        for f in [self.bin_dir / cmd_name, self.bin_dir / f"{cmd_name}.calls"]:
            if f.exists():
                f.unlink()

    # --- Subprocess Execution Helper ---
    def run_installer(
        self,
        *flags: str,
        input_text: str = "",
        env_override: Optional[Dict[str, str]] = None,
        timeout: float = 10.0,
        cwd: Optional[Path] = None,
    ) -> Tuple[int, str, str]:
        """Execute install.sh within the isolated temp environment."""
        installer = self.cool_shell_dir / "install.sh"
        bash_bin = shutil.which("bash") or "/usr/bin/bash"
        cmd = [bash_bin, str(installer)] + list(flags)

        proc_env = dict(os.environ)
        if env_override:
            proc_env.update(env_override)

        try:
            res = subprocess.run(
                cmd,
                input=input_text,
                cwd=str(cwd or self.cool_shell_dir),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=proc_env,
                timeout=timeout,
            )
            return res.returncode, res.stdout, res.stderr
        except subprocess.TimeoutExpired:
            return -1, "", "Execution timed out"
        except Exception as e:
            return -1, "", str(e)


# ==============================================================================
# Surface & JS Evaluation Helpers
# ==============================================================================

class ShellSurfaceClassifier:
    """
    Evaluates window see-through classification by executing the exact logic
    defined in shell.qml.
    """
    _exact_patterns: Optional[List[str]] = None
    _prefix_patterns: Optional[List[str]] = None
    _js_func_body: Optional[str] = None
    _has_node: Optional[bool] = None

    @classmethod
    def load(cls, shell_qml_path: Path = BASE_DIR / "shell.qml") -> None:
        if cls._exact_patterns is not None:
            return
        content = shell_qml_path.read_text(encoding="utf-8")

        # 1. Extract seeThroughExactPatterns from shell.qml
        m_exact = re.search(r'readonly\s+property\s+var\s+seeThroughExactPatterns\s*:\s*(\[[^\]]+\])', content)
        if m_exact:
            raw = m_exact.group(1).replace("'", '"')
            cls._exact_patterns = json.loads(raw)
        else:
            cls._exact_patterns = []

        # 2. Extract seeThroughPrefixPatterns from shell.qml
        m_prefix = re.search(r'readonly\s+property\s+var\s+seeThroughPrefixPatterns\s*:\s*(\[[^\]]+\])', content)
        if m_prefix:
            raw = m_prefix.group(1).replace("'", '"')
            cls._prefix_patterns = json.loads(raw)
        else:
            cls._prefix_patterns = []

        # 3. Extract isSurfaceSeeThrough function body via brace matching
        start = content.find("function isSurfaceSeeThrough")
        if start != -1:
            brace_count = 0
            in_func = False
            end = start
            for i in range(start, len(content)):
                if content[i] == '{':
                    brace_count += 1
                    in_func = True
                elif content[i] == '}':
                    brace_count -= 1
                    if in_func and brace_count == 0:
                        end = i + 1
                        break
            raw_func = content[start:end]
            # Strip QML type annotation ': bool'
            cls._js_func_body = re.sub(r'function\s+isSurfaceSeeThrough\s*\(([^)]*)\)\s*:\s*\w+', r'function isSurfaceSeeThrough(\1)', raw_func)
        else:
            cls._js_func_body = ""

        cls._has_node = bool(shutil.which("node"))

    @classmethod
    def evaluate(cls, surface: Optional[Dict[str, Any]]) -> bool:
        cls.load()
        if not surface or not isinstance(surface, dict):
            return False

        # Normalize dictionary keys so surface mirrors Quickshell Wayland surface structure
        s: Dict[str, Any] = {}
        for k, v in surface.items():
            s[k] = "" if v is None else v

        if "class" in s and "windowClass" not in s:
            s["windowClass"] = s["class"]
        if "class" in s and "lastIpcObject" not in s:
            s["lastIpcObject"] = {
                "class": s["class"],
                "initialClass": s.get("initialClass", ""),
            }

        # Primary path: Execute exact JavaScript extracted from shell.qml via Node.js
        if cls._has_node and cls._js_func_body:
            js_script = f"""
const shellRoot = {{
    seeThroughExactPatterns: {json.dumps(cls._exact_patterns)},
    seeThroughPrefixPatterns: {json.dumps(cls._prefix_patterns)}
}};
{cls._js_func_body}
const surf = {json.dumps(s)};
try {{
    const res = isSurfaceSeeThrough(surf);
    process.stdout.write(res ? '1' : '0');
}} catch (e) {{
    process.stdout.write('0');
}}
"""
            try:
                res = subprocess.run(
                    ["node", "-e", js_script],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    timeout=1.0,
                )
                if res.returncode == 0:
                    return res.stdout.strip() == "1"
            except Exception:
                pass

        # Portable fallback: execute identical 2-phase logic using patterns extracted from shell.qml
        cls_val = str(s.get("windowClass") or (s.get("lastIpcObject", {}) or {}).get("class", "")).lower()
        init_cls = str(s.get("initialClass") or (s.get("lastIpcObject", {}) or {}).get("initialClass", "")).lower()
        app_id = str(s.get("appId", "")).lower()
        if app_id and not cls_val:
            cls_val = app_id

        # Phase 1: Exact match against shell.qml's seeThroughExactPatterns
        for pat in (cls._exact_patterns or []):
            if cls_val == pat or init_cls == pat or app_id == pat:
                return True

        # Phase 2: Safe substring match against shell.qml's seeThroughPrefixPatterns
        # (NEVER matches against title per shell.qml design)
        for pat in (cls._prefix_patterns or []):
            if (pat in cls_val) or (pat in init_cls) or (pat in app_id):
                return True

        return False


def evaluate_surface_seethrough(surface: Dict[str, Any], custom_patterns: Optional[List[str]] = None) -> bool:
    """Public test framework entry point linking directly to shell.qml."""
    return ShellSurfaceClassifier.evaluate(surface)


def get_shell_seethrough_patterns() -> Tuple[List[str], List[str]]:
    """Returns (exact_patterns, prefix_patterns) parsed from shell.qml."""
    ShellSurfaceClassifier.load()
    return list(ShellSurfaceClassifier._exact_patterns or []), list(ShellSurfaceClassifier._prefix_patterns or [])
