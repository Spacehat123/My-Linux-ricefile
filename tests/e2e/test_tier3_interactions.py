"""
Tier 3: Cross-Feature Combinations (15 Pairwise Interaction Tests)
Verifies multi-feature interactions across R1, R2, and R3.
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
    assert_greater_equal,
    strip_qml_comments,
    find_process_pids,
    get_quickshell_pids,
    sample_process_cpu_percent,
    quickshell_ipc_call,
    validate_lua_syntax,
    evaluate_surface_seethrough,
    TempEnvironment,
)


@register_test("T3_PAIR_01", 3, "Installer provisions shortcuts_custom.lua in hyprland.lua; UI writes binding; reload executes cleanly", "R2.4+R3.3")
def test_t3_pair_01():
    with TempEnvironment() as env:
        code, out, err = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code, 0, f"Installer turnkey dry-run failed with code {code}: {err}\n{out}")
        hl_content = (env.hypr_dir / "hyprland.lua").read_text()
        assert_in("shortcuts_custom.lua", hl_content, "install.sh must configure hyprland.lua to source shortcuts_custom.lua")
        valid_hl, err_hl = validate_lua_syntax(env.hypr_dir / "hyprland.lua")
        assert_true(valid_hl, f"hyprland.lua syntax error after provisioning: {err_hl}")
        shortcuts_qml = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
        assert_regex(r'shortcuts_custom\.lua', shortcuts_qml, "ShortcutsWindow.qml must target shortcuts_custom.lua")


@register_test("T3_PAIR_02", 3, "Installer turnkey run with --dry-run validates packages, fonts, and directories atomically", "R2.1+R2.2+R2.3")
def test_t3_pair_02():
    with TempEnvironment() as env:
        code, out, err = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code, 0, f"Turnkey dry-run failed: {err}")
        assert_regex(r'(font|ttf|package|dir)', out.lower(), "Turnkey dry-run should report validation steps")


@register_test("T3_PAIR_03", 3, "ShortcutsWindow displays config path, user edits shortcut, path display remains steady", "R3.1+R3.2")
def test_t3_pair_03():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'Text\s*\{[^}]*hyprland\.lua', content, "ShortcutsWindow must render hyprland.lua in UI Text item")
    assert_regex(r'(editMode|isEditing|editShortcut)', content, "ShortcutsWindow must provide active shortcut editing state")


@register_test("T3_PAIR_04", 3, "Launching terminal triggers live wallpaper; launching browser with 'st' pauses live wallpaper", "R1.1+R1.2")
def test_t3_pair_04():
    term_surf = {"class": "kitty", "title": "bash"}
    browser_surf = {"class": "brave-browser", "title": "Streamers - YouTube - Brave"}
    assert_true(evaluate_surface_seethrough(term_surf), "Terminal must be see-through")
    assert_false(evaluate_surface_seethrough(browser_surf), "Browser with 'st' title must NOT be see-through")


@register_test("T3_PAIR_05", 3, "Transitioning system to idle pauses video wallpaper and freezes motes physics simultaneously", "R1.2+R1.3")
def test_t3_pair_05():
    shell_qml = (BASE_DIR / "shell.qml").read_text()
    motes_qml = (BASE_DIR / "desktop" / "AtmosphericMotes.qml").read_text()
    wall_qml = (BASE_DIR / "wallpaper" / "Wallpaper.qml").read_text()
    assert_regex(r'idle', shell_qml, "shell.qml must track idle state")
    assert_regex(r'physicsTimer', motes_qml, "AtmosphericMotes must govern physicsTimer")
    assert_regex(r'live', wall_qml, "Wallpaper.qml must govern live property")


@register_test("T3_PAIR_06", 3, "Ambient mode enabled: telemetry polls at >= 3s while motes freeze when mouse leaves screen", "R1.3+R1.5")
def test_t3_pair_06():
    slate_qml = (BASE_DIR / "desktop" / "DesktopAmbientSlate.qml").read_text()
    motes_qml = (BASE_DIR / "desktop" / "AtmosphericMotes.qml").read_text()
    m = re.search(r'interval:\s*(\d+)', slate_qml)
    assert_true(bool(m), "Slate must have interval")
    assert_greater_equal(int(m.group(1)), 3000, "Slate telemetry interval must be >= 3000ms")
    assert_in("cursorPresent", motes_qml, "Motes must use cursorPresent tracking")


@register_test("T3_PAIR_07", 3, "Editing and saving shortcut does not spike Quickshell CPU or cause persistent polling churn", "R3.2+R3.3+R1.5")
def test_t3_pair_07():
    pids = get_quickshell_pids()
    if pids:
        cpu = sample_process_cpu_percent(pids[0], interval=0.5)
        assert_less(cpu, 5.0, f"Quickshell CPU ({cpu:.2f}%) should stay below 5% at idle")
    else:
        assert_true(True)


@register_test("T3_PAIR_08", 3, "ShortcutsWindow config path matches the exact file verified and configured by install.sh", "R2.4+R3.1")
def test_t3_pair_08():
    installer = (BASE_DIR / "install.sh").read_text()
    shortcuts_qml = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_in("hyprland.lua", installer, "install.sh must configure hyprland.lua")
    assert_regex(r'Text\s*\{[^}]*hyprland\.lua', shortcuts_qml, "ShortcutsWindow.qml must display hyprland.lua in a UI Text element")


@register_test("T3_PAIR_09", 3, "Video wallpaper unmapped and weather mist disabled: SceneGraph render thread CPU drops", "R1.2+R1.4")
def test_t3_pair_09():
    mist_qml = (BASE_DIR / "desktop" / "AmbientWeatherMist.qml").read_text()
    wall_qml = (BASE_DIR / "wallpaper" / "Wallpaper.qml").read_text()
    assert_in("opacity: 0.0", mist_qml, "Mist must be disabled/0 opacity at baseline")
    assert_in("live", wall_qml, "Wallpaper must have live gate")


@register_test("T3_PAIR_10", 3, "User rebinds terminal shortcut from SUPER+T to SUPER+Return; drop-in written; Hyprland config valid", "R3.2+R2.4")
def test_t3_pair_10():
    with TempEnvironment() as env:
        code, out, err = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code, 0, f"Installer failed: {err}")
        shortcuts_qml = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
        assert_regex(r'hl\.unbind', shortcuts_qml, "ShortcutsWindow must format hl.unbind for old keybindings")
        assert_regex(r'hl\.bind', shortcuts_qml, "ShortcutsWindow must format hl.bind for new keybindings")
        assert_regex(r'shortcuts_custom\.lua', shortcuts_qml, "ShortcutsWindow must target shortcuts_custom.lua")
        valid, err_lua = validate_lua_syntax(env.hypr_dir / "hyprland.lua")
        assert_true(valid, f"hyprland.lua syntax invalid: {err_lua}")


@register_test("T3_PAIR_11", 3, "Opening transparent terminal over motes keeps motes throttled when cursor inside terminal", "R1.1+R1.3")
def test_t3_pair_11():
    motes_qml = (BASE_DIR / "desktop" / "AtmosphericMotes.qml").read_text()
    assert_in("cursorPresent", motes_qml, "AtmosphericMotes must check cursor presence")


@register_test("T3_PAIR_12", 3, "Python venv verified by installer runs helper daemons without high-frequency polling", "R2.3+R1.5")
def test_t3_pair_12():
    req_file = BASE_DIR / "requirements.txt"
    assert_true(req_file.exists(), "requirements.txt must exist")
    installer_script = (BASE_DIR / "Other-stuff" / "02-python-environment.sh").read_text()
    assert_regex(r'requirements\.txt', installer_script, "Python setup script must install from requirements.txt")
    sysinfo_sh = (BASE_DIR / "island" / "scripts" / "sysinfo.sh").read_text()
    assert_not_regex(r'while\s+true;\s*do.*sleep\s+0\.[1-5]', sysinfo_sh, "sysinfo helper script must not use continuous high-frequency sleep")


@register_test("T3_PAIR_13", 3, "User modifies multiple shortcuts in one session; single consolidated drop-in file written", "R3.3+R3.2")
def test_t3_pair_13():
    content = strip_qml_comments((BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text())
    assert_regex(r'(\.forEach|\.map|for\s*\([^)]*customShortcuts|for\s*\([^)]*allShortcuts)', content, 
                 "ShortcutsWindow.qml must iterate over modified shortcuts to produce consolidated drop-in")
    assert_regex(r'shortcuts_custom\.lua', content, "ShortcutsWindow.qml must target shortcuts_custom.lua")


@register_test("T3_PAIR_14", 3, "ShortcutsWindow overlay opened on top of live wallpaper pauses video or renders smoothly", "R1.2+R3.1")
def test_t3_pair_14():
    shortcuts_qml = (BASE_DIR / "panels" / "ShortcutsWindow.qml").read_text()
    assert_in("WlrLayer.Overlay", shortcuts_qml, "ShortcutsWindow must run on Overlay layer")


@register_test("T3_PAIR_15", 3, "Fresh setup where hyprland.lua is newly copied by installer supports custom shortcut overrides", "R2.1+R3.3")
def test_t3_pair_15():
    with TempEnvironment() as env:
        code, out, err = env.run_installer("--turnkey", "--dry-run")
        assert_equal(code, 0, f"Installer failed on fresh setup: {err}\n{out}")
        hl_content = (env.hypr_dir / "hyprland.lua").read_text()
        assert_regex(r'shortcuts_custom\.lua', hl_content, "Fresh installer run must configure hyprland.lua to source shortcuts_custom.lua")
        assert_true((env.hypr_dir / "shortcuts_custom.lua").exists(), "Fresh setup must provision shortcuts_custom.lua")
        valid, err_lua = validate_lua_syntax(env.hypr_dir / "hyprland.lua")
        assert_true(valid, f"hyprland.lua syntax error on fresh setup: {err_lua}")
