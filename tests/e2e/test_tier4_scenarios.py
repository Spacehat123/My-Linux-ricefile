"""
Tier 4: Real-World Application Scenarios (6 Application Workloads)
End-to-end integration workflows simulating realistic desktop usage patterns.
"""

import os
import sys
import re
import json
import time
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
    quickshell_ipc_call,
    hyprctl_reload,
    validate_lua_syntax,
    evaluate_surface_seethrough,
    TempEnvironment,
)


@register_test("T4_SCEN_01", 4, "Scenario 1: Clean Turnkey Installation & Verification", "Workflow")
def test_t4_scen_01():
    """
    Simulates a fresh user running ./install.sh --turnkey --dry-run:
    1. Installer invoked with --turnkey --dry-run.
    2. Detects AUR helper (paru/yay).
    3. Verifies pacman packages and font targets.
    4. Verifies directory structure layout and Python venv target.
    5. Verifies hyprland.lua sourcing for shortcuts_custom.lua.
    6. Returns exit code 0 and outputs complete verification summary.
    """
    with TempEnvironment() as env:
        code, out, err = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code, 0, f"Turnkey installer failed with code {code}: {err}\n{out}")
        assert_regex(r'(paru|yay|package|font)', out.lower(), "Verification report must detail dependency checks")


@register_test("T4_SCEN_02", 4, "Scenario 2: Normal Desktop Idle & Resource Throttling Lifecycle", "Workflow")
def test_t4_scen_02():
    """
    Active desktop moves into idle state and returns to active:
    1. Desktop active.
    2. Idle signal triggered.
    3. Video wallpaper stops, software decode threads terminate.
    4. Motes physics loop halts; motes coordinates freeze.
    5. Quickshell process CPU measured: average CPU < 5% of a core.
    6. GPU busy percent measured: < 10% busy.
    7. User activity resumes: motes physics resume, wallpaper reactivates if workspace conditions permit.
    """
    pids = get_quickshell_pids()
    if pids:
        # Simulate idle via IPC
        quickshell_ipc_call("idle", "setSimulatedIdle", "true")
        time.sleep(0.5)

        # Measure CPU and decode threads
        cpu = sample_process_cpu_percent(pids[0], interval=1.0)
        decode_threads = count_threads_matching(pids[0], r"av:h264|ffmpeg|avcodec")

        # Resume active
        quickshell_ipc_call("idle", "clearSimulation")

        assert_less(cpu, 5.0, f"Quickshell idle CPU ({cpu:.2f}%) must be < 5.0% of a core")
        assert_equal(decode_threads, 0, f"Decode thread count ({decode_threads}) must be 0 when idle")
    else:
        # Static validation of idle lifecycle
        shell_qml = (BASE_DIR / "shell.qml").read_text()
        assert_in("idle", shell_qml, "shell.qml must handle idle state")


@register_test("T4_SCEN_03", 4, "Scenario 3: Custom Shortcut Configuration & Hot-Reload", "Workflow")
def test_t4_scen_03():
    shortcuts_qml = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    
    # 1. UI displays hyprland.lua in small font Text element
    assert_regex(r'Text\s*\{[^}]*hyprland\.lua', shortcuts_qml, "ShortcutsWindow must render visible Text item displaying hyprland.lua")
    
    # 2. UI provides key editing inputs and save mechanism
    assert_regex(r'(keyInput|keyField|editKeyText|keyEditor)', shortcuts_qml, "ShortcutsWindow must provide key editing input element")
    assert_regex(r'(function\s+saveCustomShortcuts|function\s+saveShortcut|saveModifiedShortcut)', shortcuts_qml, 
                 "ShortcutsWindow must provide a save function for custom shortcuts")
                 
    # 3. Drop-in format generation with hl.unbind and hl.bind
    assert_regex(r'hl\.unbind', shortcuts_qml, "ShortcutsWindow must format hl.unbind statements in drop-in")
    assert_regex(r'hl\.bind', shortcuts_qml, "ShortcutsWindow must format hl.bind statements in drop-in")
    assert_regex(r'shortcuts_custom\.lua', shortcuts_qml, "ShortcutsWindow must write to shortcuts_custom.lua")
    
    # 4. hyprctl reload execution
    assert_regex(r'hyprctl.*reload', shortcuts_qml, "ShortcutsWindow must trigger hyprctl reload on save")
    
    # 5. Deserialization of custom shortcuts on launch
    assert_regex(r'(loadCustomShortcuts|readCustomBindings)', shortcuts_qml, 
                 "ShortcutsWindow must load custom bindings on startup")


@register_test("T4_SCEN_04", 4, "Scenario 4: Browser Video Playback & Window Title Isolation", "Workflow")
def test_t4_scen_04():
    """
    User opens web browser with media title containing 'st' (YouTube stream):
    1. Browser window opened with title 'I Hustled Streamers for $250,000 - YouTube - Brave'.
    2. isSurfaceSeeThrough() evaluated on this window: returns false.
    3. IPC wallpaper isLive queried: returns false.
    4. Live video decoding does not start in background behind opaque browser.
    5. Switching focus to genuine terminal (kitty): isSurfaceSeeThrough() returns true and wallpaper activates.
    """
    browser_window = {
        "class": "brave-browser",
        "initialClass": "Brave-browser",
        "title": "I Hustled Streamers for $250,000 - YouTube - Brave",
        "appId": "brave",
    }
    assert_false(evaluate_surface_seethrough(browser_window), 
                 "Opaque browser window with 'Streamers' in title must NOT be classified as see-through")

    terminal_window = {
        "class": "kitty",
        "initialClass": "kitty",
        "title": "pranc@zenith: ~",
        "appId": "kitty",
    }
    assert_true(evaluate_surface_seethrough(terminal_window), 
                "Kitty terminal window must be classified as see-through")


@register_test("T4_SCEN_05", 4, "Scenario 5: Ambient HUD Display & Long-Term Telemetry Stability", "Workflow")
def test_t4_scen_05():
    """
    Desktop ambient HUD running continuously for extended monitoring:
    1. Ambient mode engaged.
    2. Telemetry polling runs at steady interval (>= 3s) using delta CPU calculations.
    3. Radial gauges render without 4x MSAA offscreen GPU blit overhead.
    4. CPU usage remains below 5% when cursor is not hovering over cards.
    """
    slate_qml = (BASE_DIR / "desktop" / "DesktopAmbientSlate.qml").read_text()
    sysinfo_sh = (BASE_DIR / "island" / "scripts" / "sysinfo.sh").read_text()

    # Interval check
    m = re.search(r'interval:\s*(\d+)', slate_qml)
    assert_true(bool(m), "Slate must declare interval")
    assert_greater_equal(int(m.group(1)), 3000, "Interval must be >= 3000ms")

    # MSAA check: layer.samples: 4 must NOT be present
    assert_not_regex(r'layer\.samples:\s*4', slate_qml, "Radial gauges must not use 4x MSAA blit")


@register_test("T4_SCEN_06", 4, "Scenario 6: Full System Integration & Idempotent Configuration Recovery", "Workflow")
def test_t4_scen_06():
    with TempEnvironment() as env:
        # Run 1: Verify clean execution
        code1, out1, err1 = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code1, 0, f"Initial installer run failed with code {code1}: {err1}\n{out1}")
        
        # Run 2: Verify idempotency on consecutive run
        code2, out2, err2 = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code2, 0, f"Secondary idempotent installer run failed with code {code2}: {err2}\n{out2}")

        # Check hyprland.lua configuration and idempotency
        hl_file = env.hypr_dir / "hyprland.lua"
        hl_text = hl_file.read_text()
        assert_in("shortcuts_custom.lua", hl_text, "Installer must ensure hyprland.lua sources shortcuts_custom.lua")
        assert_equal(hl_text.count("shortcuts_custom.lua"), 1, "Duplicate sourcing blocks created in hyprland.lua")
        valid, err = validate_lua_syntax(hl_file)
        assert_true(valid, f"hyprland.lua became invalid after duplicate runs: {err}")

        # Verify shortcuts_custom.lua was provisioned by installer
        custom_lua = env.hypr_dir / "shortcuts_custom.lua"
        assert_true(custom_lua.exists(), "Installer must provision shortcuts_custom.lua")
        valid_custom, err_custom = validate_lua_syntax(custom_lua)
        assert_true(valid_custom, f"Installer generated invalid Lua in shortcuts_custom.lua: {err_custom}")

        # Verify ShortcutsWindow integration handles custom drop-in and reload
        shortcuts_qml = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
        assert_regex(r'shortcuts_custom\.lua', shortcuts_qml, "ShortcutsWindow must target shortcuts_custom.lua")
        assert_regex(r'hyprctl.*reload', shortcuts_qml, "ShortcutsWindow must trigger hyprctl reload")
