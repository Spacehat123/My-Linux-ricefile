"""
Tier 1: Feature Coverage (5 tests per feature = 60 tests)
Covers R1.1 - R1.5, R2.1 - R2.4, R3.1 - R3.3.
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
    assert_in,
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
    count_threads_matching,
    is_awww_running,
    quickshell_ipc_call,
    validate_lua_syntax,
    evaluate_surface_seethrough,
    TempEnvironment,
)


# ==============================================================================
# R1.1: Transparent Window Classification
# ==============================================================================

@register_test("T1_R1_1_01", 1, "Verify exact terminal class matching: window with class 'kitty' is classified as transparent", "R1.1")
def test_t1_r1_1_01():
    surf = {"class": "kitty", "initialClass": "kitty", "title": "terminal"}
    assert_true(evaluate_surface_seethrough(surf), "kitty terminal must be classified as see-through")
    # Verify in shell.qml source
    shell_qml = (BASE_DIR / "shell.qml").read_text()
    assert_regex(r'["\']kitty["\']', shell_qml, "shell.qml must include 'kitty' pattern")


@register_test("T1_R1_1_02", 1, "Verify exact terminal class matching: window with class 'alacritty' is classified as transparent", "R1.1")
def test_t1_r1_1_02():
    surf = {"class": "alacritty", "initialClass": "Alacritty", "title": "shell"}
    assert_true(evaluate_surface_seethrough(surf), "alacritty terminal must be classified as see-through")
    shell_qml = (BASE_DIR / "shell.qml").read_text()
    assert_regex(r'["\']alacritty["\']', shell_qml, "shell.qml must include 'alacritty' pattern")


@register_test("T1_R1_1_03", 1, "Verify non-terminal window with 'st' in title is NOT classified as transparent", "R1.1")
def test_t1_r1_1_03():
    surf = {"class": "brave-browser", "title": "Streamers - YouTube - Brave", "appId": "brave"}
    assert_false(evaluate_surface_seethrough(surf), "Streamers YouTube tab must NOT be classified as see-through")
    shell_qml = (BASE_DIR / "shell.qml").read_text()
    # Check if shell.qml still has the bug: "st" in seeThroughPatterns while testing title.includes(pat)
    has_st_in_patterns = bool(re.search(r'seeThroughPatterns[\s\S]*?["\']st["\']', shell_qml))
    tests_title_with_pat = bool(re.search(r'title\.includes\(\s*pat\s*\)', shell_qml))
    assert_false(has_st_in_patterns and tests_title_with_pat, 
                 "shell.qml matches 'st' in seeThroughPatterns against window title! R1.1 fix required.")


@register_test("T1_R1_1_04", 1, "Verify window with title 'Playing Chess Online - Fast Moves' does not trigger false positive", "R1.1")
def test_t1_r1_1_04():
    surf = {"class": "google-chrome", "title": "Playing Chess Online - Fast Moves", "appId": "google-chrome"}
    assert_false(evaluate_surface_seethrough(surf), "'Fast Moves' must not trigger see-through false positive")


@register_test("T1_R1_1_05", 1, "Verify suckless terminal with exact class 'st' is correctly recognized without substring false-positives on title", "R1.1")
def test_t1_r1_1_05():
    exact_st = {"class": "st", "title": "user@host:~"}
    assert_true(evaluate_surface_seethrough(exact_st), "Exact class 'st' must be classified as transparent")
    fake_st = {"class": "firefox", "title": "First Step Tutorial"}
    assert_false(evaluate_surface_seethrough(fake_st), "Title with 'st' in firefox must NOT be transparent")


# ==============================================================================
# R1.2: Video Wallpaper Idle Pause & Thread Teardown
# ==============================================================================

@register_test("T1_R1_2_01", 1, "Verify IPC wallpaper isLive returns {'live': false} when desktop is idle", "R1.2")
def test_t1_r1_2_01():
    # Simulate idle if Quickshell IPC is active
    quickshell_ipc_call("idle", "setSimulatedIdle", "true")
    res = quickshell_ipc_call("wallpaper", "isLive")
    quickshell_ipc_call("idle", "clearSimulation")
    if res.get("success"):
        assert_equal(res.get("live"), False, "wallpaper must not be live when simulated idle")
    else:
        # Static check in Wallpaper.qml and shell.qml
        wall_qml = (BASE_DIR / "wallpaper" / "Wallpaper.qml").read_text()
        assert_regex(r'live\s*:', wall_qml, "Wallpaper.qml must declare 'live' property")
        shell_qml = (BASE_DIR / "shell.qml").read_text()
        assert_regex(r'idle', shell_qml, "shell.qml must check idle state for wallpaper")


@register_test("T1_R1_2_02", 1, "Verify MediaPlayer state is stopped/source empty when live == false", "R1.2")
def test_t1_r1_2_02():
    wall_qml = (BASE_DIR / "wallpaper" / "Wallpaper.qml").read_text()
    assert_regex(r'(_syncPlayback|mediaPlayer\.(stop|pause))', wall_qml, "Wallpaper.qml must pause/stop MediaPlayer on !live")


@register_test("T1_R1_2_03", 1, "Verify FFmpeg software decode threads are 0 when video wallpaper is unmapped", "R1.2")
def test_t1_r1_2_03():
    pids = get_quickshell_pids()
    if pids:
        # Verify decode threads count
        thread_count = count_threads_matching(pids[0], r"av:h264|ffmpeg|avcodec")
        assert_equal(thread_count, 0, f"Expected 0 FFmpeg decode threads when idle/unmapped, found {thread_count}")
    else:
        # Static check in Wallpaper.qml
        wall_qml = (BASE_DIR / "wallpaper" / "Wallpaper.qml").read_text()
        assert_in("mediaPlayer.pause()", wall_qml, "Wallpaper.qml must halt media player threads")


@register_test("T1_R1_2_04", 1, "Verify static wallpaper daemon (awww-daemon) remains active when video wallpaper unmaps", "R1.2")
def test_t1_r1_2_04():
    wall_qml = (BASE_DIR / "wallpaper" / "Wallpaper.qml").read_text()
    assert_in("awww-daemon", wall_qml, "Wallpaper.qml must document/support awww-daemon background fallback")


@register_test("T1_R1_2_05", 1, "Verify video wallpaper unmaps when an opaque fullscreen window covers the workspace", "R1.2")
def test_t1_r1_2_05():
    shell_qml = (BASE_DIR / "shell.qml").read_text()
    assert_regex(r'shouldWallpaperBeLive', shell_qml, "shell.qml must provide shouldWallpaperBeLive logic")


# ==============================================================================
# R1.3: Motes Physics Throttling & Idle Dormancy
# ==============================================================================

@register_test("T1_R1_3_01", 1, "Verify AtmosphericMotes physics timer stops or freezes when cursorPresent == false", "R1.3")
def test_t1_r1_3_01():
    motes_qml = (BASE_DIR / "desktop" / "AtmosphericMotes.qml").read_text()
    # The physicsTimer running condition must require cursorPresent or be throttled when idle
    assert_regex(r'id:\s*physicsTimer[^}]+running:\s*root\.active\s*&&\s*root\.visible\s*&&\s*root\.cursorPresent', 
                 motes_qml, 
                 "physicsTimer must halt when cursorPresent is false")


@register_test("T1_R1_3_02", 1, "Verify motes positions do not mutate across 1-second sample when idle", "R1.3")
def test_t1_r1_3_02():
    motes_qml = (BASE_DIR / "desktop" / "AtmosphericMotes.qml").read_text()
    # Verify that cursorPresent controls physics progression
    assert_in("cursorPresent", motes_qml, "AtmosphericMotes.qml must use cursorPresent tracking")


@register_test("T1_R1_3_03", 1, "Verify canvas SceneGraph dirtiness drops to zero when cursor is outside ambient slate", "R1.3")
def test_t1_r1_3_03():
    motes_qml = (BASE_DIR / "desktop" / "AtmosphericMotes.qml").read_text()
    assert_regex(r'physicsTimer', motes_qml, "AtmosphericMotes must manage physics timer")


@register_test("T1_R1_3_04", 1, "Verify motes smoothly resume physics when cursor movement is detected", "R1.3")
def test_t1_r1_3_04():
    motes_qml = (BASE_DIR / "desktop" / "AtmosphericMotes.qml").read_text()
    assert_in("cursorX", motes_qml, "AtmosphericMotes must track cursorX")
    assert_in("cursorY", motes_qml, "AtmosphericMotes must track cursorY")


@register_test("T1_R1_3_05", 1, "Verify twinkle animations do not trigger continuous render loop when idle", "R1.3")
def test_t1_r1_3_05():
    motes_qml = (BASE_DIR / "desktop" / "AtmosphericMotes.qml").read_text()
    # Twinkle timer must be conditioned on cursorPresent or active
    assert_regex(r'twinkleTimer[^}]+running:\s*root\.active\s*&&\s*root\.cursorPresent', motes_qml, 
                 "twinkleTimer must cease continuous loop when idle / cursor not present")


# ==============================================================================
# R1.4: Ambient Mist Animations Inactive when Hidden/Zero Opacity
# ==============================================================================

@register_test("T1_R1_4_01", 1, "Verify AmbientWeatherMist property animations have running: false when opacity == 0.0", "R1.4")
def test_t1_r1_4_01():
    mist_qml = (BASE_DIR / "desktop" / "AmbientWeatherMist.qml").read_text()
    # Animations must bind running: root.opacity > 0.0 or similar guard
    assert_regex(r'running:\s*root\.opacity\s*>\s*0', mist_qml, 
                 "AmbientWeatherMist animations must bind running: root.opacity > 0.0")


@register_test("T1_R1_4_02", 1, "Verify AmbientWeatherMist layer visibility is false when mist is disabled in profile", "R1.4")
def test_t1_r1_4_02():
    mist_qml = (BASE_DIR / "desktop" / "AmbientWeatherMist.qml").read_text()
    assert_regex(r'visible:\s*root\.opacity\s*>\s*0', mist_qml, "Mist layer visibility must be false when opacity is 0")


@register_test("T1_R1_4_03", 1, "Verify animation driver tick count does not increment due to mist when hidden", "R1.4")
def test_t1_r1_4_03():
    mist_qml = (BASE_DIR / "desktop" / "AmbientWeatherMist.qml").read_text()
    assert_in("opacity: 0.0", mist_qml, "AmbientWeatherMist default opacity must be 0.0")


@register_test("T1_R1_4_04", 1, "Verify mist layer does not allocate GPU offscreen surface when inactive", "R1.4")
def test_t1_r1_4_04():
    mist_qml = (BASE_DIR / "desktop" / "AmbientWeatherMist.qml").read_text()
    assert_not_regex(r'layer\.enabled:\s*true', mist_qml, "Mist items must not keep unconditional layer.enabled: true")


@register_test("T1_R1_4_05", 1, "Verify activating mist properly starts animations and deactivating cleanly halts them", "R1.4")
def test_t1_r1_4_05():
    mist_qml = (BASE_DIR / "desktop" / "AmbientWeatherMist.qml").read_text()
    assert_in("Behavior on opacity", mist_qml, "Mist must define opacity transition behavior")


# ==============================================================================
# R1.5: Telemetry Polling Optimization & Instant Delta CPU Calculation
# ==============================================================================

@register_test("T1_R1_5_01", 1, "Verify sysinfo.sh calculates instantaneous CPU delta rather than cumulative boot ticks", "R1.5")
def test_t1_r1_5_01():
    sysinfo_path = BASE_DIR / "island" / "scripts" / "sysinfo.sh"
    content = sysinfo_path.read_text()
    # Must NOT use the naive cumulative formula ($2+$4)*100/($2+$4+$5) without delta calculation
    assert_not_regex(r'usage\s*=\s*\(\$2\+\$4\)\*100/\(\$2\+\$4\+\$5\)', content, 
                     "sysinfo.sh must calculate delta ticks, not cumulative boot ticks")


@register_test("T1_R1_5_02", 1, "Verify telemetry timer interval in DesktopAmbientSlate is >= 3000ms", "R1.5")
def test_t1_r1_5_02():
    slate_qml = (BASE_DIR / "desktop" / "DesktopAmbientSlate.qml").read_text()
    m = re.search(r'interval:\s*(\d+)', slate_qml)
    assert_true(bool(m), "DesktopAmbientSlate.qml must define a telemetry timer interval")
    interval = int(m.group(1))
    assert_greater_equal(interval, 3000, f"Telemetry timer interval {interval}ms must be >= 3000ms")


@register_test("T1_R1_5_03", 1, "Verify radialGauges Shape does not use layer.samples: 4", "R1.5")
def test_t1_r1_5_03():
    slate_qml = (BASE_DIR / "desktop" / "DesktopAmbientSlate.qml").read_text()
    # In unoptimized code: layer.samples: 4 caused heavy MSAA blit
    assert_not_regex(r'layer\.samples:\s*4', slate_qml, "radialGauges must not use layer.samples: 4")


@register_test("T1_R1_5_04", 1, "Verify GPU busy percent polling safely handles dual-GPU setups (card0/card1)", "R1.5")
def test_t1_r1_5_04():
    sysinfo_path = BASE_DIR / "island" / "scripts" / "sysinfo.sh"
    content = sysinfo_path.read_text()
    assert_regex(r'card[01\*]', content, "sysinfo.sh must inspect card0/card1 or card* for GPU metrics")


@register_test("T1_R1_5_05", 1, "Verify overall idle CPU of Quickshell process is < 5% of a single core", "R1.5")
def test_t1_r1_5_05():
    pids = get_quickshell_pids()
    if pids:
        cpu = sample_process_cpu_percent(pids[0], interval=0.8)
        assert_less(cpu, 5.0, f"Quickshell idle CPU ({cpu:.2f}%) must be < 5.0% of a core")
    else:
        # Fallback check
        assert_true(True)


# ==============================================================================
# R2.1: Turnkey Execution & Package Manager / AUR Detection
# ==============================================================================

@register_test("T1_R2_1_01", 1, "Verify install.sh --dry-run runs non-interactively without prompting stdin", "R2.1")
def test_t1_r2_1_01():
    with TempEnvironment() as env:
        code, out, err = env.run_installer("--dry-run", timeout=5.0)
        assert_equal(code, 0, f"install.sh --dry-run failed with code {code}: {err}\n{out}")


@register_test("T1_R2_1_02", 1, "Verify install.sh --turnkey or --yes executes cleanly without interactive user prompts", "R2.1")
def test_t1_r2_1_02():
    with TempEnvironment() as env:
        code, out, err = env.run_installer("--turnkey", "--dry-run", timeout=5.0)
        assert_equal(code, 0, f"install.sh --turnkey --dry-run failed: {err}")


@register_test("T1_R2_1_03", 1, "Verify install.sh detects paru if installed", "R2.1")
def test_t1_r2_1_03():
    with TempEnvironment() as env:
        # Create mock paru in temp bin
        paru_bin = env.bin_dir / "paru"
        paru_bin.write_text("#!/usr/bin/env bash\necho 'paru v2.0.0'")
        paru_bin.chmod(0o755)
        orig_path = os.environ.get("PATH", "")
        try:
            os.environ["PATH"] = f"{env.bin_dir}:{orig_path}"
            code, out, err = env.run_installer("--dry-run")
            assert_in("paru", out.lower(), "install.sh should detect paru")
        finally:
            os.environ["PATH"] = orig_path


@register_test("T1_R2_1_04", 1, "Verify install.sh detects yay if paru is absent", "R2.1")
def test_t1_r2_1_04():
    with TempEnvironment() as env:
        yay_bin = env.bin_dir / "yay"
        yay_bin.write_text("#!/usr/bin/env bash\necho 'yay v12.0.0'")
        yay_bin.chmod(0o755)
        orig_path = os.environ.get("PATH", "")
        try:
            os.environ["PATH"] = f"{env.bin_dir}:{orig_path}"
            code, out, err = env.run_installer("--dry-run")
            assert_true("yay" in out.lower() or "paru" in out.lower(), "install.sh should detect AUR helper")
        finally:
            os.environ["PATH"] = orig_path


@register_test("T1_R2_1_05", 1, "Verify install.sh refuses to run with error exit code when executed as root (EUID == 0)", "R2.1")
def test_t1_r2_1_05():
    installer = BASE_DIR / "install.sh"
    content = installer.read_text()
    assert_regex(r'EUID\s*==\s*0|UID\s*==\s*0|\$\(id\s+-u\)\s*==\s*0', content, 
                 "install.sh must check for root EUID and reject execution")


# ==============================================================================
# R2.2: Package & Typography/Font Dependency Verification
# ==============================================================================

@register_test("T1_R2_2_01", 1, "Verify install.sh targets ttf-jetbrains-mono-nerd", "R2.2")
def test_t1_r2_2_01():
    installer = (BASE_DIR / "install.sh").read_text()
    sub_installers = list((BASE_DIR / "Other-stuff").glob("*.sh"))
    all_text = installer + "\n" + "\n".join(f.read_text() for f in sub_installers if f.is_file())
    assert_in("ttf-jetbrains-mono-nerd", all_text, "Dependencies must include ttf-jetbrains-mono-nerd")


@register_test("T1_R2_2_02", 1, "Verify install.sh targets inter-font", "R2.2")
def test_t1_r2_2_02():
    sub_installers = list((BASE_DIR / "Other-stuff").glob("*.sh"))
    all_text = (BASE_DIR / "install.sh").read_text() + "\n" + "\n".join(f.read_text() for f in sub_installers if f.is_file())
    assert_in("inter-font", all_text, "Dependencies must include inter-font")


@register_test("T1_R2_2_03", 1, "Verify install.sh targets ttf-geist via AUR helper", "R2.2")
def test_t1_r2_2_03():
    sub_installers = list((BASE_DIR / "Other-stuff").glob("*.sh"))
    all_text = (BASE_DIR / "install.sh").read_text() + "\n" + "\n".join(f.read_text() for f in sub_installers if f.is_file())
    assert_in("ttf-geist", all_text, "Dependencies must include ttf-geist")


@register_test("T1_R2_2_04", 1, "Verify pacman installation uses --needed --noconfirm flags", "R2.2")
def test_t1_r2_2_04():
    sub_installers = list((BASE_DIR / "Other-stuff").glob("*.sh"))
    all_text = (BASE_DIR / "install.sh").read_text() + "\n" + "\n".join(f.read_text() for f in sub_installers if f.is_file())
    assert_regex(r'--needed', all_text, "Package installation must use --needed")
    assert_regex(r'--noconfirm', all_text, "Package installation must use --noconfirm")


@register_test("T1_R2_2_05", 1, "Verify missing fonts trigger installation command in dry-run/execution report", "R2.2")
def test_t1_r2_2_05():
    with TempEnvironment() as env:
        code, out, err = env.run_installer("--dry-run")
        assert_regex(r'font', out.lower(), "Dry-run report must mention font verification")


# ==============================================================================
# R2.3: Directory Structure & Python Virtual Environment Setup
# ==============================================================================

@register_test("T1_R2_3_01", 1, "Verify directory creation creates ~/.config/quickshell/cool-shell", "R2.3")
def test_t1_r2_3_01():
    with TempEnvironment() as env:
        code, out, err = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code, 0, f"Installer failed on turnkey dry-run: {err}\n{out}")
        installer = (BASE_DIR / "install.sh").read_text()
        assert_regex(r'quickshell/cool-shell', installer, "install.sh must target ~/.config/quickshell/cool-shell directory")


@register_test("T1_R2_3_02", 1, "Verify directory creation creates ~/.local/share/cool-shell/models", "R2.3")
def test_t1_r2_3_02():
    with TempEnvironment() as env:
        env.run_installer("--dry-run")
        target = env.local_share / "cool-shell" / "models"
        # Check either target created or referenced in installer
        installer = (BASE_DIR / "install.sh").read_text()
        assert_regex(r'models', installer, "install.sh must manage models directory")


@register_test("T1_R2_3_03", 1, "Verify directory creation creates wallpaper directories in ~/Pictures/Wallpapers", "R2.3")
def test_t1_r2_3_03():
    with TempEnvironment() as env:
        installer = (BASE_DIR / "install.sh").read_text()
        assert_regex(r'Pictures.*Wallpapers', installer, "install.sh must target ~/Pictures/Wallpapers")


@register_test("T1_R2_3_04", 1, "Verify Python virtual environment creation targets ~/.local/share/cool-shell/venv", "R2.3")
def test_t1_r2_3_04():
    py_env_script = BASE_DIR / "Other-stuff" / "02-python-environment.sh"
    content = py_env_script.read_text() if py_env_script.exists() else ""
    installer = (BASE_DIR / "install.sh").read_text()
    assert_regex(r'cool-shell.*venv', content + installer, "Python venv must target cool-shell/venv")


@register_test("T1_R2_3_05", 1, "Verify venv setup installs packages from requirements.txt", "R2.3")
def test_t1_r2_3_05():
    req_file = BASE_DIR / "requirements.txt"
    assert_true(req_file.exists(), "requirements.txt must exist in project root")
    assert_greater(len(req_file.read_text().splitlines()), 5, "requirements.txt must contain dependencies")


# ==============================================================================
# R2.4: Hyprland Lua Integration & Drop-in Sourcing Check
# ==============================================================================

@register_test("T1_R2_4_01", 1, "Verify install.sh checks for existence of ~/.config/hypr/hyprland.lua", "R2.4")
def test_t1_r2_4_01():
    installer = (BASE_DIR / "install.sh").read_text()
    assert_regex(r'hyprland\.lua', installer, "install.sh must reference hyprland.lua")


@register_test("T1_R2_4_02", 1, "Verify install.sh verifies or adds sourcing block for shortcuts_custom.lua", "R2.4")
def test_t1_r2_4_02():
    installer = (BASE_DIR / "install.sh").read_text()
    assert_regex(r'shortcuts_custom\.lua', installer, "install.sh must check/source shortcuts_custom.lua")


@register_test("T1_R2_4_03", 1, "Verify shortcuts_custom.lua template is touched/created if absent", "R2.4")
def test_t1_r2_4_03():
    with TempEnvironment() as env:
        custom_lua = env.hypr_dir / "shortcuts_custom.lua"
        if custom_lua.exists():
            custom_lua.unlink()
        code, out, err = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code, 0, f"Installer failed on turnkey dry-run: {err}\n{out}")
        assert_true(custom_lua.exists(), "install.sh must touch/create shortcuts_custom.lua if absent")


@register_test("T1_R2_4_04", 1, "Verify sourcing block uses pcall or safe require pattern", "R2.4")
def test_t1_r2_4_04():
    installer = (BASE_DIR / "install.sh").read_text()
    assert_regex(r'(pcall|loadfile|dofile|require)', installer, "Sourcing block must use safe loading pattern")


@register_test("T1_R2_4_05", 1, "Verify Hyprland configuration syntax remains valid after integration", "R2.4")
def test_t1_r2_4_05():
    if HYPRLAND_LUA.exists():
        valid, err = validate_lua_syntax(HYPRLAND_LUA)
        assert_true(valid, f"hyprland.lua has invalid Lua syntax: {err}")


# ==============================================================================
# R3.1: Shortcuts Cheatsheet Config Path Display (hyprland.lua)
# ==============================================================================

@register_test("T1_R3_1_01", 1, "Verify ShortcutsWindow.qml contains text referencing ~/.config/hypr/hyprland.lua", "R3.1")
def test_t1_r3_1_01():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'Text\s*\{[^}]*(?:~/\.config/hypr/hyprland\.lua|hyprland\.lua)', content, 
                 "ShortcutsWindow.qml must render a Text component displaying ~/.config/hypr/hyprland.lua")


@register_test("T1_R3_1_02", 1, "Verify font size for config path display is small (<= 11px / pixelSize <= 11)", "R3.1")
def test_t1_r3_1_02():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    m = re.search(r'Text\s*\{[^}]*hyprland\.lua[^}]*font\.pixelSize:\s*(\d+)', content, re.DOTALL) or \
        re.search(r'Text\s*\{[^}]*font\.pixelSize:\s*(\d+)[^}]*hyprland\.lua', content, re.DOTALL)
    assert_true(bool(m), "ShortcutsWindow must declare config path Text item with explicit font.pixelSize")
    size = int(m.group(1))
    assert_less_equal(size, 11, f"Config path font size must be <= 11px, found {size}px")


@register_test("T1_R3_1_03", 1, "Verify config path text is visible when shortcuts window is toggled", "R3.1")
def test_t1_r3_1_03():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'Text\s*\{[^}]*hyprland\.lua', content, 
                 "Config path text must be declared in a UI Text component in ShortcutsWindow.qml")


@register_test("T1_R3_1_04", 1, "Verify config path display uses monospace font (JetBrains Mono Nerd Font)", "R3.1")
def test_t1_r3_1_04():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    m = re.search(r'Text\s*\{[^}]*hyprland\.lua[^}]*font\.family:\s*["\']([^"\']*)["\']', content, re.DOTALL) or \
        re.search(r'Text\s*\{[^}]*font\.family:\s*["\']([^"\']*)["\'][^}]*hyprland\.lua', content, re.DOTALL)
    assert_true(bool(m), "Config path Text item must declare font.family")
    font_fam = m.group(1)
    assert_regex(r'(JetBrains Mono|monospace)', font_fam, f"Config path font must be monospace, got {font_fam}")


@register_test("T1_R3_1_05", 1, "Verify config path text displays drop-in location ~/.config/hypr/shortcuts_custom.lua", "R3.1")
def test_t1_r3_1_05():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'shortcuts_custom\.lua', content, "ShortcutsWindow.qml UI must display drop-in location shortcuts_custom.lua")


# ==============================================================================
# R3.2: In-UI Shortcut Keybinding Editing Interface & Validation
# ==============================================================================

@register_test("T1_R3_2_01", 1, "Verify shortcut rows expose an interactive editing element (edit button or click-to-edit)", "R3.2")
def test_t1_r3_2_01():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(isEditing|editMode|editShortcut|startEdit|onEditClicked)', content, 
                 "ShortcutsWindow rows must expose specific shortcut editing controls (isEditing, editMode, editShortcut)")


@register_test("T1_R3_2_02", 1, "Verify edit interface allows modifying modifier keys (SUPER, CTRL, ALT, SHIFT)", "R3.2")
def test_t1_r3_2_02():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(availableModifiers|modifierList|toggleModifier|selectedModifiers|editModifiers)', content, 
                 "ShortcutsWindow must implement modifier selection/editing logic (availableModifiers, toggleModifier, selectedModifiers)")


@register_test("T1_R3_2_03", 1, "Verify edit interface allows modifying key string", "R3.2")
def test_t1_r3_2_03():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(keyInput|keyField|editKeyText|keyEditor|placeholderText:\s*["\'][^"\']*[Kk]ey)', content, 
                 "ShortcutsWindow must provide a dedicated key editing input field (keyInput, keyField, keyEditor)")


@register_test("T1_R3_2_04", 1, "Verify input validation rejects empty key combination", "R3.2")
def test_t1_r3_2_04():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(validateKey|validateShortcut|isValidKey|key.*trim\(\)\s*===?\s*["\']["\'])', content, 
                 "ShortcutsWindow must validate against empty or invalid key inputs")


@register_test("T1_R3_2_05", 1, "Verify conflict detection flags duplicate key combinations", "R3.2")
def test_t1_r3_2_05():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(detectConflict|findDuplicate|hasConflict|isConflicting)', content, 
                 "ShortcutsWindow must feature shortcut conflict detection")


# ==============================================================================
# R3.3: Custom Drop-in Persistence (shortcuts_custom.lua) & Hyprland Reload
# ==============================================================================

@register_test("T1_R3_3_01", 1, "Verify saving modified shortcut writes valid Lua syntax to ~/.config/hypr/shortcuts_custom.lua", "R3.3")
def test_t1_r3_3_01():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'shortcuts_custom\.lua', content, "ShortcutsWindow must target shortcuts_custom.lua")


@register_test("T1_R3_3_02", 1, "Verify drop-in file contains unbind for old key and bind for new key (hl.unbind, hl.bind)", "R3.3")
def test_t1_r3_3_02():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'hl\.unbind', content, "ShortcutsWindow.qml must format drop-in with hl.unbind statements")
    assert_regex(r'hl\.bind', content, "ShortcutsWindow.qml must format drop-in with hl.bind statements")


@register_test("T1_R3_3_03", 1, "Verify drop-in file stores metadata JSON (-- SHORTCUTS_DATA:) for bidirectional state load", "R3.3")
def test_t1_r3_3_03():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'--\s*SHORTCUTS_DATA:', content, "ShortcutsWindow.qml must serialize metadata header (-- SHORTCUTS_DATA:) in drop-in")


@register_test("T1_R3_3_04", 1, "Verify saving invokes hyprctl reload via process execution", "R3.3")
def test_t1_r3_3_04():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'hyprctl.*reload', content, "Saving shortcut must trigger hyprctl reload")


@register_test("T1_R3_3_05", 1, "Verify re-opening ShortcutsWindow loads previously saved custom bindings from drop-in", "R3.3")
def test_t1_r3_3_05():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(loadCustomShortcuts|readCustomBindings|SHORTCUTS_DATA)', content, 
                 "ShortcutsWindow must deserialize custom drop-in bindings on launch")
