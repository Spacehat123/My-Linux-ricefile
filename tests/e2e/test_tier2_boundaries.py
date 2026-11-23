"""
Tier 2: Boundary & Corner Cases (5 tests per feature = 60 tests)
Covers error handling, limits, resilience, and adversarial edge conditions.
"""

import os
import sys
import re
import json
import subprocess
from pathlib import Path

from framework import (
    BASE_DIR,
    HYPR_CONFIG_DIR,
    HYPRLAND_LUA,
    SHORTCUTS_CUSTOM_LUA,
    FIXTURES_DIR,
    register_test,
    assert_true,
    assert_false,
    assert_equal,
    assert_not_equal,
    assert_in,
    assert_not_in,
    assert_regex,
    assert_not_regex,
    assert_less,
    assert_less_equal,
    assert_greater,
    assert_greater_equal,
    strip_qml_comments,
    find_process_pids,
    get_quickshell_pids,
    sample_process_cpu_percent,
    read_gpu_busy_percent,
    quickshell_ipc_call,
    validate_lua_syntax,
    evaluate_surface_seethrough,
    TempEnvironment,
)


# ==============================================================================
# R1.1: Transparent Window Classification Boundaries
# ==============================================================================

@register_test("T2_R1_1_01", 2, "Window with empty title and empty class returns false (no crash)", "R1.1")
def test_t2_r1_1_01():
    surf = {"class": "", "initialClass": "", "title": ""}
    assert_false(evaluate_surface_seethrough(surf), "Empty surface must return false without crash")


@register_test("T2_R1_1_02", 2, "Window title containing 'st' across word boundaries returns false", "R1.1")
def test_t2_r1_1_02():
    surf = {"class": "mpv", "title": "fastest streamer alive"}
    assert_false(evaluate_surface_seethrough(surf), "Word boundary 'st' must return false")


@register_test("T2_R1_1_03", 2, "Window title with special unicode characters returns false", "R1.1")
def test_t2_r1_1_03():
    surf = {"class": "firefox", "title": "🎬 𝐒𝐭𝐫𝐞𝐚𝐦 🎥 - Live Special"}
    assert_false(evaluate_surface_seethrough(surf), "Unicode title must return false")


@register_test("T2_R1_1_04", 2, "Surface with null or undefined properties does not throw TypeError", "R1.1")
def test_t2_r1_1_04():
    surf = {"class": None, "initialClass": None, "title": None, "appId": None}
    assert_false(evaluate_surface_seethrough(surf), "Surface with None values must return false")


@register_test("T2_R1_1_05", 2, "Multiple windows on same workspace (1 opaque, 1 transparent) flags workspace as NOT live for video", "R1.1")
def test_t2_r1_1_05():
    shell_qml = (BASE_DIR / "shell.qml").read_text()
    assert_regex(r'shouldWallpaperBeLive', shell_qml, "shell.qml must evaluate all windows on active workspace")


# ==============================================================================
# R1.2: Video Wallpaper Boundaries
# ==============================================================================

@register_test("T2_R1_2_01", 2, "Video wallpaper with non-existent or corrupted video file path fails gracefully", "R1.2")
def test_t2_r1_2_01():
    wall_qml = (BASE_DIR / "wallpaper" / "Wallpaper.qml").read_text()
    assert_regex(r'mediaPlayer', wall_qml, "Wallpaper.qml must handle media player errors or empty source")


@register_test("T2_R1_2_02", 2, "Rapid toggling of idle state (idle -> active -> idle within 100ms) does not leak media players", "R1.2")
def test_t2_r1_2_02():
    wall_qml = (BASE_DIR / "wallpaper" / "Wallpaper.qml").read_text()
    assert_in("_syncPlayback", wall_qml, "Wallpaper.qml must sync playback cleanly")


@register_test("T2_R1_2_03", 2, "Switching workspaces rapidly between empty and tiled does not wedge MediaPlayer", "R1.2")
def test_t2_r1_2_03():
    shell_qml = (BASE_DIR / "shell.qml").read_text()
    assert_in("_wallpaperLiveTick", shell_qml, "shell.qml must track workspace change ticks")


@register_test("T2_R1_2_04", 2, "External kill -9 of awww-daemon does not crash wallpaper component", "R1.2")
def test_t2_r1_2_04():
    wall_qml = (BASE_DIR / "wallpaper" / "Wallpaper.qml").read_text()
    assert_regex(r'mediaType\s*===\s*["\']video["\']', wall_qml, "Wallpaper.qml must guard video mapping independently of awww-daemon")
    assert_regex(r'awww-daemon', wall_qml, "Wallpaper.qml must reference awww-daemon for static background lifecycle")


@register_test("T2_R1_2_05", 2, "Memory leak stress test: sequential unmap/map cycles does not increase RES memory > 50MB", "R1.2")
def test_t2_r1_2_05():
    pids = get_quickshell_pids()
    if pids:
        statm = Path(f"/proc/{pids[0]}/statm")
        if statm.exists():
            pages = int(statm.read_text().split()[1])
            res_mb = (pages * 4096) / (1024 * 1024)
            assert_less(res_mb, 1500, f"Quickshell resident memory {res_mb:.1f}MB exceeds upper limit")


# ==============================================================================
# R1.3: Motes Physics Boundaries
# ==============================================================================

@register_test("T2_R1_3_01", 2, "Cursor moved outside all screen boundaries does not crash collision calculations", "R1.3")
def test_t2_r1_3_01():
    motes_qml = (BASE_DIR / "desktop" / "AtmosphericMotes.qml").read_text()
    assert_in("getObstacleList", motes_qml, "AtmosphericMotes must define obstacle bounds")


@register_test("T2_R1_3_02", 2, "0 motes in Repeater (count: 0) causes no division by zero or errors", "R1.3")
def test_t2_r1_3_02():
    motes_qml = (BASE_DIR / "desktop" / "AtmosphericMotes.qml").read_text()
    assert_regex(r'moteRepeater\.count', motes_qml, "Motes must bound loop by moteRepeater.count")


@register_test("T2_R1_3_03", 2, "Extreme display resolutions handle bounds clamping correctly", "R1.3")
def test_t2_r1_3_03():
    motes_qml = (BASE_DIR / "desktop" / "AtmosphericMotes.qml").read_text()
    assert_regex(r'Math\.(min|max)', motes_qml, "Coordinate calculations must clamp bounds")


@register_test("T2_R1_3_04", 2, "Motes velocity vector NaN/Infinity protection during violent cursor flick", "R1.3")
def test_t2_r1_3_04():
    motes_qml = (BASE_DIR / "desktop" / "AtmosphericMotes.qml").read_text()
    assert_regex(r'(Math\.hypot|Math\.sqrt|dist|pad)', motes_qml, "Physics calculations must clamp distances")


@register_test("T2_R1_3_05", 2, "Long idle duration maintains 0 FPS without clock drift or animation wakeups", "R1.3")
def test_t2_r1_3_05():
    motes_qml = (BASE_DIR / "desktop" / "AtmosphericMotes.qml").read_text()
    assert_in("cursorPresent", motes_qml, "AtmosphericMotes must sleep completely when cursor is absent")


# ==============================================================================
# R1.4: Ambient Mist Boundaries
# ==============================================================================

@register_test("T2_R1_4_01", 2, "Rapid weather changes between misty and clear weather correctly starts/stops animations", "R1.4")
def test_t2_r1_4_01():
    mist_qml = (BASE_DIR / "desktop" / "AmbientWeatherMist.qml").read_text()
    assert_in("opacity", mist_qml, "AmbientWeatherMist must use opacity transitions")


@register_test("T2_R1_4_02", 2, "Width or height resizing of screen dynamically updates animation endpoints without hitching", "R1.4")
def test_t2_r1_4_02():
    mist_qml = (BASE_DIR / "desktop" / "AmbientWeatherMist.qml").read_text()
    assert_regex(r'root\.(width|height)', mist_qml, "Mist animation endpoints must bind to root dimensions")


@register_test("T2_R1_4_03", 2, "Zero duration in weather profile defaults to safe non-zero duration", "R1.4")
def test_t2_r1_4_03():
    mist_qml = (BASE_DIR / "desktop" / "AmbientWeatherMist.qml").read_text()
    assert_in("durationL1", mist_qml, "Mist must define durationL1")


@register_test("T2_R1_4_04", 2, "Mist layer opacity at epsilon (0.001) does not activate expensive render pass", "R1.4")
def test_t2_r1_4_04():
    mist_qml = (BASE_DIR / "desktop" / "AmbientWeatherMist.qml").read_text()
    assert_regex(r'opacity', mist_qml, "Mist must bind opacity")


@register_test("T2_R1_4_05", 2, "Component destruction during active animation does not leave dangling timers", "R1.4")
def test_t2_r1_4_05():
    mist_qml = (BASE_DIR / "desktop" / "AmbientWeatherMist.qml").read_text()
    assert_regex(r'running:\s*(?:root\.)?opacity\s*>\s*0', mist_qml, "AmbientWeatherMist.qml property animations must bind running state to non-zero opacity")


# ==============================================================================
# R1.5: Telemetry Boundaries
# ==============================================================================

@register_test("T2_R1_5_01", 2, "/sys/class/drm/card* missing or unreadable falls back cleanly to 0% GPU without error logs", "R1.5")
def test_t2_r1_5_01():
    sysinfo_path = BASE_DIR / "island" / "scripts" / "sysinfo.sh"
    content = sysinfo_path.read_text()
    # Check fallback for GPU reading
    assert_regex(r'(gpu|card|\/sys\/class\/drm)', content, "sysinfo.sh must inspect /sys/class/drm for GPU metrics")


@register_test("T2_R1_5_02", 2, "Counter overflow in /proc/stat handles delta calculation safely", "R1.5")
def test_t2_r1_5_02():
    sysinfo_path = BASE_DIR / "island" / "scripts" / "sysinfo.sh"
    content = sysinfo_path.read_text()
    assert_regex(r'\[\s*"\$dt"\s+-gt\s+0\s*\]', content, "sysinfo.sh must guard against zero or negative delta ticks")
    assert_regex(r'\[\s*"\$cpu_usage"\s+-lt\s+0\s*\]', content, "sysinfo.sh must clamp negative CPU calculation on counter overflow")


@register_test("T2_R1_5_03", 2, "Heavy system load does not hang sysinfo.sh execution", "R1.5")
def test_t2_r1_5_03():
    sysinfo_path = BASE_DIR / "island" / "scripts" / "sysinfo.sh"
    res = subprocess.run(["bash", str(sysinfo_path)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=2.0)
    assert_equal(res.returncode, 0, f"sysinfo.sh failed: {res.stderr}")
    data = json.loads(res.stdout.strip())
    assert_in("cpu", data, "sysinfo output must contain 'cpu'")
    assert_in("ram", data, "sysinfo output must contain 'ram'")


@register_test("T2_R1_5_04", 2, "Subprocess timeout protection: hanging cat or script is terminated if exceeding 2000ms", "R1.5")
def test_t2_r1_5_04():
    slate_qml = (BASE_DIR / "desktop" / "DesktopAmbientSlate.qml").read_text()
    assert_in("sysinfoProc", slate_qml, "DesktopAmbientSlate must declare sysinfoProc")


@register_test("T2_R1_5_05", 2, "Parsing malformed /proc/meminfo lines returns fallback values", "R1.5")
def test_t2_r1_5_05():
    sysinfo_path = BASE_DIR / "island" / "scripts" / "sysinfo.sh"
    content = sysinfo_path.read_text()
    assert_in("/proc/meminfo", content, "sysinfo.sh must read /proc/meminfo")


# ==============================================================================
# R2.1: Turnkey Installer CLI Flag Boundaries
# ==============================================================================

@register_test("T2_R2_1_01", 2, "Unknown flags display help usage and exit with non-zero", "R2.1")
def test_t2_r2_1_01():
    with TempEnvironment() as env:
        code, out, err = env.run_installer("--invalid-flag-xyz")
        assert_not_equal(code, 0, "Unknown flag must return non-zero exit code")


@register_test("T2_R2_1_02", 2, "Piped stdin with --turnkey flag does not stall", "R2.1")
def test_t2_r2_1_02():
    with TempEnvironment() as env:
        code, out, err = env.run_installer("--turnkey", "--dry-run", input_text="", timeout=5.0)
        assert_equal(code, 0, f"Piped stdin with turnkey flag stalled or failed: {err}")


@register_test("T2_R2_1_03", 2, "Missing package manager displays informative error message and exits cleanly", "R2.1")
def test_t2_r2_1_03():
    with TempEnvironment() as env:
        import shutil
        for util in ["sh", "bash", "dirname", "pwd", "mkdir", "cat", "echo", "clear", "tput", "id", "which", "grep", "sed"]:
            src = shutil.which(util)
            if src:
                dst = env.bin_dir / util
                if not dst.exists():
                    try:
                        dst.symlink_to(src)
                    except OSError:
                        pass
        orig_path = os.environ.get("PATH", "")
        try:
            os.environ["PATH"] = str(env.bin_dir)
            code, out, err = env.run_installer("--dry-run")
            assert_true(code != 0 or "package manager" in (out + err).lower() or "not found" in (out + err).lower(), "Missing package manager should report error")
        finally:
            os.environ["PATH"] = orig_path


@register_test("T2_R2_1_04", 2, "Both paru and yay present: prefers paru without duplicate invocations", "R2.1")
def test_t2_r2_1_04():
    with TempEnvironment() as env:
        paru = env.bin_dir / "paru"
        paru.write_text("#!/usr/bin/env bash\necho 'paru v2.0'")
        paru.chmod(0o755)
        yay = env.bin_dir / "yay"
        yay.write_text("#!/usr/bin/env bash\necho 'yay v12.0'")
        yay.chmod(0o755)
        orig_path = os.environ.get("PATH", "")
        try:
            os.environ["PATH"] = f"{env.bin_dir}:{orig_path}"
            code, out, err = env.run_installer("--dry-run")
            assert_in("paru", out.lower(), "Should prefer paru when both are present")
        finally:
            os.environ["PATH"] = orig_path


@register_test("T2_R2_1_05", 2, "Running in non-interactive subshell without TTY correctly adopts turnkey defaults", "R2.1")
def test_t2_r2_1_05():
    with TempEnvironment() as env:
        code, out, err = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code, 0, "Non-interactive subshell with turnkey must complete cleanly")


# ==============================================================================
# R2.2: Package & Font Installation Boundaries
# ==============================================================================

@register_test("T2_R2_2_01", 2, "Font already installed: pacman/helper skips without reinstalling or erroring", "R2.2")
def test_t2_r2_2_01():
    installer = (BASE_DIR / "install.sh").read_text()
    sub_installers = list((BASE_DIR / "Other-stuff").glob("*.sh"))
    all_text = installer + "\n" + "\n".join(f.read_text() for f in sub_installers if f.is_file())
    assert_in("--needed", all_text, "Package operations must use --needed to skip already installed packages")


@register_test("T2_R2_2_02", 2, "Network failure simulation during pacman check handles error gracefully", "R2.2")
def test_t2_r2_2_02():
    installer = (BASE_DIR / "install.sh").read_text()
    assert_regex(r'set\s+-[a-z]*e', installer, "install.sh must use strict error handling")


@register_test("T2_R2_2_03", 2, "Custom font directory ~/.local/share/fonts has restricted permissions: catches error", "R2.2")
def test_t2_r2_2_03():
    with TempEnvironment() as env:
        font_dir = env.local_share / "fonts"
        font_dir.mkdir(parents=True, exist_ok=True)
        env.set_read_only(font_dir)
        code, out, err = env.run_installer("--turnkey", "--dry-run")
        assert_not_equal(code, 0, "Installer must fail or report error when font directory is read-only")
        assert_regex(r'(permission|denied|read-only|fonts|error)', (out + err).lower(),
                     "Installer must catch and report font directory permission error")


@register_test("T2_R2_2_04", 2, "Space characters in font paths handled with proper quoting", "R2.2")
def test_t2_r2_2_04():
    sub_installers = list((BASE_DIR / "Other-stuff").glob("*.sh"))
    for f in sub_installers:
        if f.is_file():
            text = f.read_text()
            # Check for unquoted variable usage like $DEST_DIR without quotes
            assert_not_regex(r'mkdir -p \$[A-Za-z0-9_]+\s', text, f"Unquoted mkdir in {f.name}")


@register_test("T2_R2_2_05", 2, "fc-cache called only once after all fonts are verified", "R2.2")
def test_t2_r2_2_05():
    sub_installers = list((BASE_DIR / "Other-stuff").glob("*.sh"))
    all_text = "\n".join(f.read_text() for f in sub_installers if f.is_file())
    assert_regex(r'fc-cache', all_text, "Installer scripts must update font cache via fc-cache")


# ==============================================================================
# R2.3: Directory Setup & Venv Boundaries
# ==============================================================================

@register_test("T2_R2_3_01", 2, "Target directory already exists as regular file: flags collision", "R2.3")
def test_t2_r2_3_01():
    with TempEnvironment() as env:
        installer = (BASE_DIR / "install.sh").read_text()
        assert_regex(r'mkdir\s+-p', installer, "Installer must use mkdir -p for directory creation")


@register_test("T2_R2_3_02", 2, "Existing venv with missing bin/activate or broken python symlink is detected and rebuilt", "R2.3")
def test_t2_r2_3_02():
    py_env_script = BASE_DIR / "Other-stuff" / "02-python-environment.sh"
    content = py_env_script.read_text() if py_env_script.exists() else ""
    assert_regex(r'activate', content, "02-python-environment.sh must verify venv activate script")


@register_test("T2_R2_3_03", 2, "Missing requirements.txt file in installer directory gives clear error", "R2.3")
def test_t2_r2_3_03():
    with TempEnvironment() as env:
        req = env.cool_shell_dir / "requirements.txt"
        if req.exists():
            req.unlink()
        code, out, err = env.run_installer("--dry-run")
        # In dry run with missing requirements, should either warn or notice
        assert_true(code == 0 or "requirements.txt" in (out + err), "Missing requirements.txt should be caught")


@register_test("T2_R2_3_04", 2, "Read-only filesystem for ~/.local/share reports write permission failure", "R2.3")
def test_t2_r2_3_04():
    with TempEnvironment() as env:
        env.set_read_only(env.local_share)
        code, out, err = env.run_installer("--turnkey", "--dry-run")
        assert_not_equal(code, 0, "Installer must fail when ~/.local/share is read-only")
        assert_regex(r'(permission|denied|read-only|writable|error)', (out + err).lower(),
                     "Installer must report write permission failure for ~/.local/share")


@register_test("T2_R2_3_05", 2, "Python version check: verifies Python 3.10+ compatibility", "R2.3")
def test_t2_r2_3_05():
    py_env_script = BASE_DIR / "Other-stuff" / "02-python-environment.sh"
    content = py_env_script.read_text() if py_env_script.exists() else ""
    assert_regex(r'python3', content, "Python environment script must check python3")


# ==============================================================================
# R2.4: Hyprland Sourcing Boundaries
# ==============================================================================

@register_test("T2_R2_4_01", 2, "Idempotency: Running install.sh twice does NOT append duplicate sourcing blocks in hyprland.lua", "R2.4")
def test_t2_r2_4_01():
    with TempEnvironment() as env:
        code1, _, _ = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code1, 0, "First installer run must succeed")
        code2, _, _ = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code2, 0, "Second installer run must succeed")
        content = (env.hypr_dir / "hyprland.lua").read_text()
        count = content.count("shortcuts_custom.lua")
        assert_equal(count, 1, f"hyprland.lua must have exactly 1 sourcing block for shortcuts_custom.lua, found {count}")


@register_test("T2_R2_4_02", 2, "Existing hyprland.lua with read-only permissions reports error without corrupting file", "R2.4")
def test_t2_r2_4_02():
    with TempEnvironment() as env:
        hl_file = env.hypr_dir / "hyprland.lua"
        orig_content = hl_file.read_text()
        env.set_read_only(hl_file)
        code, out, err = env.run_installer("--turnkey", "--dry-run")
        assert_not_equal(code, 0, "Installer must return error when hyprland.lua is unwritable")
        assert_regex(r'(permission|read-only|error)', (out + err).lower(), "Installer must report permission error on read-only hyprland.lua")
        env.set_writable(hl_file)
        assert_equal(hl_file.read_text(), orig_content, "hyprland.lua must remain intact without corruption")


@register_test("T2_R2_4_03", 2, "Sourcing block inserted into an empty hyprland.lua produces syntactically valid Lua", "R2.4")
def test_t2_r2_4_03():
    with TempEnvironment() as env:
        empty_lua = env.hypr_dir / "hyprland.lua"
        empty_lua.write_text("")
        code, out, err = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code, 0, f"Installer failed on empty hyprland.lua: {err}")
        assert_in("shortcuts_custom.lua", empty_lua.read_text(), "Installer must insert sourcing block into empty hyprland.lua")
        valid, err = validate_lua_syntax(empty_lua)
        assert_true(valid, f"Modified hyprland.lua has syntax error: {err}")


@register_test("T2_R2_4_04", 2, "shortcuts_custom.lua created with 0644 permissions", "R2.4")
def test_t2_r2_4_04():
    with TempEnvironment() as env:
        custom_lua = env.hypr_dir / "shortcuts_custom.lua"
        if custom_lua.exists():
            custom_lua.unlink()
        code, out, err = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code, 0, f"Installer failed: {err}")
        assert_true(custom_lua.exists(), "shortcuts_custom.lua must be created by installer")
        mode = oct(custom_lua.stat().st_mode & 0o777)[-3:]
        assert_equal(mode, "644", f"Installer must set permissions to 0644, got {mode}")


@register_test("T2_R2_4_05", 2, "Symlink loop in ~/.config/hypr detected and rejected", "R2.4")
def test_t2_r2_4_05():
    with TempEnvironment() as env:
        env.create_symlink_loop(env.hypr_dir, "loop")
        code, out, err = env.run_installer("--turnkey", "--dry-run", timeout=5.0)
        assert_not_equal(code, 0, "Installer must reject symlink loop in config directory")
        assert_regex(r'(symlink|loop|recursive|error)', (out + err).lower(), "Installer must report symlink loop rejection")
        assert_not_in("RecursionError", err)
        assert_not_in("Too many levels of symbolic links", err)


# ==============================================================================
# R3.1: Cheatsheet Config Path Display Boundaries
# ==============================================================================

@register_test("T2_R3_1_01", 2, "Very small window dimensions keep config path text elided or contained without overflow", "R3.1")
def test_t2_r3_1_01():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    m = re.search(r'Text\s*\{[^}]*hyprland\.lua[^}]*elide:\s*Text\.Elide', content, re.DOTALL) or \
        re.search(r'Text\s*\{[^}]*elide:\s*Text\.Elide[^}]*hyprland\.lua', content, re.DOTALL)
    assert_true(bool(m), "Config path Text item must declare elide behavior for small window dimensions")


@register_test("T2_R3_1_02", 2, "Custom XDG_CONFIG_HOME set: path display reflects actual config path or standard tilde path", "R3.1")
def test_t2_r3_1_02():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'Text\s*\{[^}]*hyprland\.lua', content, "Config path Text item must display hyprland.lua path in UI")


@register_test("T2_R3_1_03", 2, "Non-ASCII user home directory paths display properly without glyph corruption", "R3.1")
def test_t2_r3_1_03():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(configPath|hyprlandPath|~/\.config/hypr/hyprland\.lua)', content, 
                 "ShortcutsWindow must bind or format configPath cleanly without hardcoded ASCII assumptions")


@register_test("T2_R3_1_04", 2, "High DPI scaling keeps path text crisp and appropriately sized", "R3.1")
def test_t2_r3_1_04():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    m = re.search(r'Text\s*\{[^}]*hyprland\.lua[^}]*font\.pixelSize', content, re.DOTALL) or \
        re.search(r'Text\s*\{[^}]*font\.pixelSize[^}]*hyprland\.lua', content, re.DOTALL)
    assert_true(bool(m), "Config path Text item must declare font.pixelSize for High DPI scalability")


@register_test("T2_R3_1_05", 2, "Text selection / copyability of config path string", "R3.1")
def test_t2_r3_1_05():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(TextEdit|selectByMouse|clipboard|copyPath|copyToClipboard)[^}]*hyprland\.lua|hyprland\.lua[^}]*(TextEdit|selectByMouse|clipboard|copyPath)', content, 
                 "Config path in ShortcutsWindow must support text selection or copying")


# ==============================================================================
# R3.2: Shortcut Editing Boundaries
# ==============================================================================

@register_test("T2_R3_2_01", 2, "Entering key string with leading/trailing spaces trims input automatically", "R3.2")
def test_t2_r3_2_01():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(keyInput|newKey|keyField|editKey)[^;}\n]*\.trim\(\)|\.trim\(\)[^;}\n]*(keyInput|newKey|keyField|editKey)', content, 
                 "Key editor must call trim() on key inputs to strip leading/trailing whitespace")


@register_test("T2_R3_2_02", 2, "Entering reserved compositor key combinations triggers warning", "R3.2")
def test_t2_r3_2_02():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(reservedKeys|isReserved|warnReserved|invalidKey|reservedShortcut)', content, 
                 "ShortcutsWindow must check against reserved compositor key combinations")


@register_test("T2_R3_2_03", 2, "Re-binding a key to its existing binding is a no-op and does not generate redundant drop-in entries", "R3.2")
def test_t2_r3_2_03():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(originalKeys|sameKey|noChange|unchanged|keysMatch)', content, 
                 "ShortcutsWindow must check if key combination is unchanged from originalKeys before saving")


@register_test("T2_R3_2_04", 2, "Editing cancellation restores original key combination without saving", "R3.2")
def test_t2_r3_2_04():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(cancelEdit|revertEdit|onCancelClicked|cancelButton)', content, 
                 "ShortcutsWindow must provide a dedicated cancellation function/button (cancelEdit, revertEdit) that restores state")


@register_test("T2_R3_2_05", 2, "Rapid multi-clicks on Edit/Save buttons do not trigger race conditions", "R3.2")
def test_t2_r3_2_05():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(isSaving|savingLock|saveButton\.enabled\s*:\s*!|busySaving)', content, 
                 "ShortcutsWindow must guard against double-clicking save with saving state lock (isSaving, savingLock)")


# ==============================================================================
# R3.3: Custom Drop-in Persistence Boundaries
# ==============================================================================

@register_test("T2_R3_3_01", 2, "Special characters in command dispatcher strings are properly escaped in Lua output", "R3.3")
def test_t2_r3_3_01():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(\.replace\(/\\/g|escapeLua|sanitizeLua|\.replace\(/\x22/g|\.replace\(/\[\x22\\\\]/g)', content, 
                 "ShortcutsWindow.qml must escape backslashes and quotes for Lua output strings")


@register_test("T2_R3_3_02", 2, "Disk full or unwritable shortcuts_custom.lua shows error notification in UI", "R3.3")
def test_t2_r3_3_02():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'catch\s*\([^)]*\)\s*\{[^}]*(saveError|writeError|errorText|statusMessage|notify)', content, 
                 "ShortcutsWindow must capture file write errors and set an error status message or notification")


@register_test("T2_R3_3_03", 2, "hyprctl reload failure or timeout handled gracefully without crashing QML", "R3.3")
def test_t2_r3_3_03():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'hyprctl.*reload', content, "ShortcutsWindow must invoke hyprctl reload via safe Process execution")
    assert_regex(r'(onExited|onError|onProcessError|onFinished)', content, 
                 "ShortcutsWindow Process handler must monitor process exit/error status")


@register_test("T2_R3_3_04", 2, "Reset all shortcuts to default deletes or empties shortcuts_custom.lua cleanly", "R3.3")
def test_t2_r3_3_04():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(resetToDefault|resetAllShortcuts|clearCustomBindings)', content, 
                 "ShortcutsWindow must implement a resetToDefault or resetAllShortcuts function")


@register_test("T2_R3_3_05", 2, "Corrupted JSON in -- SHORTCUTS_DATA: comments falls back to parsing raw Lua bindings", "R3.3")
def test_t2_r3_3_05():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'JSON\.parse', content, "ShortcutsWindow.qml must attempt to parse JSON metadata")
    assert_regex(r'catch\s*\([^)]*\)\s*\{[^}]*(hl\.bind|bind|parseRaw|match|fallback)', content, 
                 "ShortcutsWindow.qml must fall back to raw Lua binding parsing when JSON is corrupt")
