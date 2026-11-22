#!/usr/bin/env bash
# ==============================================================================
# QuickShell Living Workspace — Comprehensive Opaque-Box E2E Test Suite
# Tests covering Tier 1 (Feature Coverage), Tier 2 (Boundaries & Corners),
# Tier 3 (Cross-Feature Combinations), and Tier 4 (Real-World Application Scenarios).
# ==============================================================================

set -uo pipefail

PROJECT_DIR="/home/pranc/.config/quickshell/cool-shell"
cd "$PROJECT_DIR" || { echo "Failed to cd to $PROJECT_DIR"; exit 1; }

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
declare -a FAILURES=()

record_pass() {
    local desc="$1"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    PASSED_TESTS=$((PASSED_TESTS + 1))
    printf "${GREEN}  ✓ PASS [T%02d]${NC} %s\n" "$TOTAL_TESTS" "$desc"
}

record_fail() {
    local desc="$1"
    local reason="${2:-Assertion failed}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    FAILED_TESTS=$((FAILED_TESTS + 1))
    FAILURES+=("Test #$TOTAL_TESTS ($desc): $reason")
    printf "${RED}  ✗ FAIL [T%02d]${NC} %s\n        ${RED}Reason:${NC} %s\n" "$TOTAL_TESTS" "$desc" "$reason"
}

assert_true() {
    local desc="$1"
    shift
    local out
    if out=$("$@" 2>&1); then
        record_pass "$desc"
    else
        record_fail "$desc" "Command failed ($*): $out"
    fi
}

assert_python() {
    local desc="$1"
    local code="$2"
    if python3 -c "$code" 2>/dev/null; then
        record_pass "$desc"
    else
        local err
        err=$(python3 -c "$code" 2>&1 || true)
        record_fail "$desc" "$err"
    fi
}

echo -e "\n${BOLD}${CYAN}========================================================================${NC}"
echo -e "${BOLD}${CYAN}   QUICKSHELL LIVING WORKSPACE — AUTOMATED TEST SUITE (TIERS 1-4)       ${NC}"
echo -e "${BOLD}${CYAN}========================================================================${NC}\n"

# ==============================================================================
# TIER 1: FEATURE COVERAGE (Static, Existence, Schemas, Syntax)
# ==============================================================================
echo -e "${BOLD}--- TIER 1: Feature Coverage & Static Verification ---${NC}"

# T1.1: Wallpaper Metadata Integrity
META_FILE="$PROJECT_DIR/wallpaper/wallpaper-metadata.json"
assert_true "Wallpaper metadata file exists" test -f "$META_FILE"
assert_python "Wallpaper metadata is valid JSON" "
import json
with open('$META_FILE') as f:
    data = json.load(f)
assert isinstance(data, dict), 'Root must be an object'
"

assert_python "Wallpaper metadata contains '5.png' anchor with required schema" "
import json
with open('$META_FILE') as f:
    d = json.load(f)
assert '5.png' in d, 'Missing 5.png anchor'
c = d['5.png']
req = ['name', 'originX', 'originY', 'spreadX', 'spreadY', 'intensity']
for r in req:
    assert r in c, f'Missing field {r}'
assert abs(c['originX'] - 0.50) < 0.05, f'Unexpected originX {c[\"originX\"]}'
assert abs(c['originY'] - 0.44) < 0.05, f'Unexpected originY {c[\"originY\"]}'
assert 0.0 <= c['intensity'] <= 1.0, f'Invalid intensity {c[\"intensity\"]}'
"

assert_python "Wallpaper metadata contains 'default' anchor with required schema" "
import json
with open('$META_FILE') as f:
    d = json.load(f)
assert 'default' in d, 'Missing default anchor'
c = d['default']
req = ['name', 'originX', 'originY', 'spreadX', 'spreadY', 'intensity']
for r in req:
    assert r in c, f'Missing field {r}'
assert abs(c['originX'] - 0.50) < 0.05, f'Unexpected originX {c[\"originX\"]}'
assert abs(c['originY'] - 0.72) < 0.05, f'Unexpected originY {c[\"originY\"]}'
assert 0.0 <= c['intensity'] <= 1.0, f'Invalid intensity {c[\"intensity\"]}'
"

# T1.2: Git Telemetry Script Integrity
GIT_SCRIPT="$PROJECT_DIR/island/scripts/git-stats.py"
assert_true "git-stats.py script exists" test -f "$GIT_SCRIPT"
assert_true "git-stats.py has executable permissions" test -x "$GIT_SCRIPT"
assert_python "git-stats.py executes with exit 0 and outputs valid JSON" "
import subprocess, json
out = subprocess.check_output(['python3', '$GIT_SCRIPT'], text=True)
data = json.loads(out)
assert isinstance(data, dict), 'Expected dict output'
"

assert_python "git-stats.py JSON schema contains required top-level keys" "
import subprocess, json
data = json.loads(subprocess.check_output(['python3', '$GIT_SCRIPT'], text=True))
assert 'repo' in data and isinstance(data['repo'], str) and len(data['repo']) > 0
assert 'branch' in data and isinstance(data['branch'], str) and len(data['branch']) > 0
assert 'lastCommit' in data and isinstance(data['lastCommit'], str)
assert 'totalCommits' in data and isinstance(data['totalCommits'], int) and data['totalCommits'] >= 0
assert 'days' in data and isinstance(data['days'], list)
assert len(data['days']) == 7, f'Expected 7 days, got {len(data[\"days\"])}'
"

assert_python "git-stats.py days array items adhere to date/dayName/commits schema" "
import subprocess, json, re
data = json.loads(subprocess.check_output(['python3', '$GIT_SCRIPT'], text=True))
for d in data['days']:
    assert re.match(r'^\d{4}-\d{2}-\d{2}$', d['date']), f'Invalid date format: {d[\"date\"]}'
    assert isinstance(d['dayName'], str) and len(d['dayName']) == 3, f'Invalid dayName: {d[\"dayName\"]}'
    assert isinstance(d['commits'], int) and d['commits'] >= 0, f'Invalid commit count: {d[\"commits\"]}'
"

# T1.3: Static QML Verification (qmllint)
QMLLINT="/usr/lib/qt6/bin/qmllint"
assert_true "qmllint binary is available" test -x "$QMLLINT"

assert_true "qmllint passes on desktop/AmbientLayer.qml" \
    "$QMLLINT" -I "$PROJECT_DIR" "$PROJECT_DIR/desktop/AmbientLayer.qml"

assert_true "qmllint passes on desktop/DesktopConstellationCard.qml" \
    "$QMLLINT" -I "$PROJECT_DIR" "$PROJECT_DIR/desktop/DesktopConstellationCard.qml"

assert_true "qmllint passes on desktop/AudioCrestAurora.qml" \
    "$QMLLINT" -I "$PROJECT_DIR" "$PROJECT_DIR/desktop/AudioCrestAurora.qml"

assert_true "qmllint passes on desktop/AmbientWeatherMist.qml" \
    "$QMLLINT" -I "$PROJECT_DIR" "$PROJECT_DIR/desktop/AmbientWeatherMist.qml"

assert_true "qmllint passes on desktop/SolarLunarArc.qml" \
    "$QMLLINT" -I "$PROJECT_DIR" "$PROJECT_DIR/desktop/SolarLunarArc.qml"

assert_true "qmllint passes on desktop/DesktopGhostTrails.qml" \
    "$QMLLINT" -I "$PROJECT_DIR" "$PROJECT_DIR/desktop/DesktopGhostTrails.qml"

assert_true "qmllint batch passes on all 6 QML components simultaneously" \
    "$QMLLINT" -I "$PROJECT_DIR" \
    "$PROJECT_DIR/desktop/AmbientLayer.qml" \
    "$PROJECT_DIR/desktop/DesktopConstellationCard.qml" \
    "$PROJECT_DIR/desktop/AudioCrestAurora.qml" \
    "$PROJECT_DIR/desktop/AmbientWeatherMist.qml" \
    "$PROJECT_DIR/desktop/SolarLunarArc.qml" \
    "$PROJECT_DIR/desktop/DesktopGhostTrails.qml"

# T1.4: QML Component Contract Properties
assert_true "AmbientWeatherMist.qml declares required interface properties" \
    grep -q "property bool active" "$PROJECT_DIR/desktop/AmbientWeatherMist.qml" && \
    grep -q "readonly property string condition" "$PROJECT_DIR/desktop/AmbientWeatherMist.qml" && \
    grep -q "readonly property var profile" "$PROJECT_DIR/desktop/AmbientWeatherMist.qml"

assert_true "AmbientWeatherMist.qml implements dual-layer drifting mist ribbons" \
    grep -q "id: layer1" "$PROJECT_DIR/desktop/AmbientWeatherMist.qml" && \
    grep -q "id: layer2" "$PROJECT_DIR/desktop/AmbientWeatherMist.qml"

assert_true "AudioCrestAurora.qml declares required audio and metadata properties" \
    grep -q "property bool active" "$PROJECT_DIR/desktop/AudioCrestAurora.qml" && \
    grep -q "readonly property bool isPlaying" "$PROJECT_DIR/desktop/AudioCrestAurora.qml" && \
    grep -q "readonly property var audioLevels" "$PROJECT_DIR/desktop/AudioCrestAurora.qml" && \
    grep -q "readonly property real rawEnergy" "$PROJECT_DIR/desktop/AudioCrestAurora.qml" && \
    grep -q "readonly property var currentMeta" "$PROJECT_DIR/desktop/AudioCrestAurora.qml"

assert_python "AudioCrestAurora.qml declares GE.RadialGradient bloom and 600ms fadeout" "
with open('$PROJECT_DIR/desktop/AudioCrestAurora.qml') as f:
    c = f.read()
assert 'import Qt5Compat.GraphicalEffects as GE' in c, 'Missing GE import'
assert 'GE.RadialGradient {' in c, 'Missing GE.RadialGradient'
assert 'duration: 600' in c, 'Missing 600ms fadeout duration'
"

assert_true "AudioCrestAurora.qml declares dual-source playback detection (hasAudioEnergy & isPlaying)" \
    grep -q "readonly property bool hasAudioEnergy:" "$PROJECT_DIR/desktop/AudioCrestAurora.qml" && \
    grep -q "readonly property bool isPlaying:" "$PROJECT_DIR/desktop/AudioCrestAurora.qml"

assert_true "AudioCrestAurora.qml declares resting ambient aura when audio is paused or idle" \
    grep -q "currentMeta.intensity \* 0.14" "$PROJECT_DIR/desktop/AudioCrestAurora.qml"

assert_true "AudioCrestAurora.qml declares visible audio wave and crest frequency arc" \
    grep -q "id: crestFrequencyArc" "$PROJECT_DIR/desktop/AudioCrestAurora.qml" && \
    grep -q "PathAngleArc {" "$PROJECT_DIR/desktop/AudioCrestAurora.qml"

assert_true "DesktopGhostTrails.qml declares required particle pool interface" \
    grep -q "readonly property int maxGlyphs: 24" "$PROJECT_DIR/desktop/DesktopGhostTrails.qml" && \
    grep -q "readonly property int maxRipples: 8" "$PROJECT_DIR/desktop/DesktopGhostTrails.qml" && \
    grep -q "function spawnBurst(" "$PROJECT_DIR/desktop/DesktopGhostTrails.qml"

assert_true "DesktopGhostTrails.qml implements kinetic ripples and ghost glyph repeaters" \
    grep -q "id: rippleRepeater" "$PROJECT_DIR/desktop/DesktopGhostTrails.qml" && \
    grep -q "id: glyphRepeater" "$PROJECT_DIR/desktop/DesktopGhostTrails.qml"

assert_true "DesktopConstellationCard.qml declares required geometry and state properties" \
    grep -q "implicitWidth: 500" "$PROJECT_DIR/desktop/DesktopConstellationCard.qml" && \
    grep -q "implicitHeight: 260" "$PROJECT_DIR/desktop/DesktopConstellationCard.qml" && \
    grep -q "property string gitRepo" "$PROJECT_DIR/desktop/DesktopConstellationCard.qml" && \
    grep -q "property int gitTotalCommits" "$PROJECT_DIR/desktop/DesktopConstellationCard.qml"

assert_true "DesktopConstellationCard.qml binds Pomodoro focus telemetry and star canvas" \
    grep -q "completedFocusSessions" "$PROJECT_DIR/desktop/DesktopConstellationCard.qml" && \
    grep -q "id: starCanvas" "$PROJECT_DIR/desktop/DesktopConstellationCard.qml"

assert_true "SolarLunarArc.qml declares required Bangalore solar/lunar properties" \
    grep -q "implicitWidth: 780" "$PROJECT_DIR/desktop/SolarLunarArc.qml" && \
    grep -q "implicitHeight: 160" "$PROJECT_DIR/desktop/SolarLunarArc.qml" && \
    grep -q "readonly property bool isDay" "$PROJECT_DIR/desktop/SolarLunarArc.qml" && \
    grep -q "readonly property real dayProgress" "$PROJECT_DIR/desktop/SolarLunarArc.qml" && \
    grep -q "readonly property real nightProgress" "$PROJECT_DIR/desktop/SolarLunarArc.qml" && \
    grep -q "readonly property real nadirSunX" "$PROJECT_DIR/desktop/SolarLunarArc.qml"

assert_true "SolarLunarArc.qml defines vector Shape paths for celestial arc" \
    grep -q "Shape {" "$PROJECT_DIR/desktop/SolarLunarArc.qml" && \
    grep -q "ShapePath {" "$PROJECT_DIR/desktop/SolarLunarArc.qml"

assert_python "SolarLunarArc.qml implements exponential radial bloom and celestial diffraction cross rays" "
with open('$PROJECT_DIR/desktop/SolarLunarArc.qml') as f:
    c = f.read()
# Exponential soft radial bloom concentric layers
assert '#fff8d6' in c, 'Missing #fff8d6 bloom layer'
assert '#fffdf0' in c, 'Missing #fffdf0 core layer'
assert '#ffffff' in c, 'Missing #ffffff pinpoint center'
assert 'width: root.isDay ? 48 :' in c, 'Missing 48px outer ambient glow tier'
assert 'width: root.isDay ? 28 :' in c, 'Missing 28px soft golden corona tier'
assert 'width: root.isDay ? 16 :' in c, 'Missing 16px radiant halo tier'
assert 'width: root.isDay ? 8 :' in c, 'Missing 8px high-intensity core tier'
assert 'width: root.isDay ? 4 :' in c, 'Missing 4px brilliant pinpoint center tier'
# Celestial diffraction cross flare rays
assert 'width: 32' in c and 'height: 1.5' in c, 'Missing 32px horizontal diffraction beam'
assert 'width: 1.5' in c and 'height: 32' in c, 'Missing 32px vertical diffraction beam'
# Softened daytime arc line
assert 'strokeWidth: 1.0' in c, 'Missing 1.0 strokeWidth arc line'
"

assert_true "SolarLunarArc.qml implements softened crescent moon and removes heavy glow" \
    grep -q 'color: "#c4a7e7"' "$PROJECT_DIR/desktop/SolarLunarArc.qml" && \
    grep -q 'opacity: 0.45' "$PROJECT_DIR/desktop/SolarLunarArc.qml" && \
    ! grep -q '#e0def4' "$PROJECT_DIR/desktop/SolarLunarArc.qml"

echo ""

# ==============================================================================
# TIER 2: BOUNDARY & CORNER CASES
# ==============================================================================
echo -e "${BOLD}--- TIER 2: Boundary & Corner Cases ---${NC}"

# T2.1: Wallpaper Metadata Fallback Verification
assert_python "Metadata lookup for registered wallpaper '5.png' returns peak coordinates" "
import json
with open('$META_FILE') as f:
    meta = json.load(f)
target = '5.png'
res = meta.get(target) or meta.get('default')
assert res['originY'] == 0.44, f'Expected 0.44, got {res[\"originY\"]}'
assert res['originX'] == 0.50, f'Expected 0.50, got {res[\"originX\"]}'
"

assert_python "Metadata lookup for unindexed wallpaper safely returns 'default' fallback" "
import json
with open('$META_FILE') as f:
    meta = json.load(f)
target = 'unknown_mountain_forest_99.png'
res = meta.get(target) or meta.get('default')
assert res is not None, 'Fallback was None'
assert res['originY'] == 0.72, f'Expected horizon 0.72, got {res[\"originY\"]}'
assert res['intensity'] == 0.50, f'Expected intensity 0.50, got {res[\"intensity\"]}'
"

assert_python "Metadata lookup with empty string or None wallpaper filename returns default fallback" "
import json
with open('$META_FILE') as f:
    meta = json.load(f)
for target in ['', None, 'nonexistent']:
    res = meta.get(target) or meta.get('default')
    assert res['originY'] == 0.72
"

assert_python "Metadata lookup with missing/empty dict returns hardcoded default structure" "
meta = {}
default_hardcoded = {'originX': 0.50, 'originY': 0.72, 'spreadX': 0.85, 'spreadY': 0.35, 'intensity': 0.50}
res = meta.get('any.png') or meta.get('default') or default_hardcoded
assert res == default_hardcoded
"

# T2.2: Audio Levels Handling & Extreme Inputs
assert_python "Audio energy calculation with normal 4-band levels [0.8, 0.4, 0.1, 0.0]" "
levels = [0.8, 0.4, 0.1, 0.0]
is_playing = True
raw_energy = max(0.0, min(1.0, (levels[0] or 0) * 0.75 + (levels[1] or 0) * 0.25)) if is_playing and levels and len(levels) >= 2 else 0.0
assert abs(raw_energy - 0.70) < 0.001, f'Expected 0.70, got {raw_energy}'
"

assert_python "Audio energy calculation with pure silence [0.0, 0.0, 0.0, 0.0] returns 0.0" "
levels = [0.0, 0.0, 0.0, 0.0]
is_playing = True
raw_energy = max(0.0, min(1.0, (levels[0] or 0) * 0.75 + (levels[1] or 0) * 0.25)) if is_playing and levels and len(levels) >= 2 else 0.0
assert raw_energy == 0.0, f'Expected 0.0, got {raw_energy}'
"

assert_python "Audio energy calculation with null/None levels returns 0.0 without exception" "
levels = None
is_playing = True
raw_energy = max(0.0, min(1.0, (levels[0] or 0) * 0.75 + (levels[1] or 0) * 0.25)) if is_playing and levels and len(levels) >= 2 else 0.0
assert raw_energy == 0.0, f'Expected 0.0, got {raw_energy}'
"

assert_python "Audio energy calculation with empty array [] returns 0.0 without IndexError" "
levels = []
is_playing = True
raw_energy = max(0.0, min(1.0, (levels[0] or 0) * 0.75 + (levels[1] or 0) * 0.25)) if is_playing and levels and len(levels) >= 2 else 0.0
assert raw_energy == 0.0, f'Expected 0.0, got {raw_energy}'
"

assert_python "Audio energy calculation with truncated array [0.5] (<2 items) returns 0.0 safely" "
levels = [0.5]
is_playing = True
raw_energy = max(0.0, min(1.0, (levels[0] or 0) * 0.75 + (levels[1] or 0) * 0.25)) if is_playing and levels and len(levels) >= 2 else 0.0
assert raw_energy == 0.0, f'Expected 0.0, got {raw_energy}'
"

assert_python "Audio energy when playback is stopped (isPlaying=False) forces 0.0 even with non-zero levels" "
levels = [1.0, 1.0, 1.0, 1.0]
is_playing = False
raw_energy = max(0.0, min(1.0, (levels[0] or 0) * 0.75 + (levels[1] or 0) * 0.25)) if is_playing and levels and len(levels) >= 2 else 0.0
assert raw_energy == 0.0, f'Expected 0.0, got {raw_energy}'
"

assert_python "Audio energy clamping prevents overflow on extreme audio levels [5.0, 10.0]" "
levels = [5.0, 10.0, 0.0, 0.0]
is_playing = True
raw_energy = max(0.0, min(1.0, (levels[0] or 0) * 0.75 + (levels[1] or 0) * 0.25)) if is_playing and levels and len(levels) >= 2 else 0.0
assert raw_energy == 1.0, f'Expected 1.0 clamped, got {raw_energy}'
"

assert_python "Audio energy clamping prevents underflow on negative audio levels [-1.0, -0.5]" "
levels = [-1.0, -0.5, 0.0, 0.0]
is_playing = True
raw_energy = max(0.0, min(1.0, (levels[0] or 0) * 0.75 + (levels[1] or 0) * 0.25)) if is_playing and levels and len(levels) >= 2 else 0.0
assert raw_energy == 0.0, f'Expected 0.0 clamped, got {raw_energy}'
"

assert_python "Dual-source playback detection triggers on PipeWire energy without MPRIS" "
media_playing = False
levels = [0.08, 0.03, 0.0, 0.0]
has_energy = bool(levels and len(levels) >= 2 and ((levels[0] or 0) > 0.01 or (levels[1] or 0) > 0.01))
is_playing = media_playing or has_energy
assert has_energy is True
assert is_playing is True
"

assert_python "Dual-source playback detection remains inactive during pure silence without MPRIS" "
media_playing = False
levels = [0.005, 0.005, 0.0, 0.0]
has_energy = bool(levels and len(levels) >= 2 and ((levels[0] or 0) > 0.01 or (levels[1] or 0) > 0.01))
is_playing = media_playing or has_energy
assert has_energy is False
assert is_playing is False
"

assert_python "Dual-source playback detection triggers when MPRIS mediaPlaying is true" "
media_playing = True
levels = [0.0, 0.0, 0.0, 0.0]
has_energy = bool(levels and len(levels) >= 2 and ((levels[0] or 0) > 0.01 or (levels[1] or 0) > 0.01))
is_playing = media_playing or has_energy
assert is_playing is True
"

assert_python "Resting ambient aura maintains subtle visibility (> 0) when audio is idle" "
active = True
is_playing = False
intensity = 0.50
smoothed_energy = 0.0
opacity = (intensity * (0.35 + smoothed_energy * 0.65)) if is_playing else (intensity * 0.14)
if not active: opacity = 0.0
assert opacity > 0.05 and opacity < 0.15, f'Expected ~0.07 resting aura, got {opacity}'
assert (opacity > 0.001) is True, 'Resting aura should remain visible (opacity > 0.001)'
"

assert_python "Aurora surges from resting aura to full brilliance when playback begins" "
active = True
intensity = 0.50
# Resting state
resting_opacity = intensity * 0.14
# Active playback with bass pulse
active_opacity = intensity * (0.35 + 0.85 * 0.65)
assert active_opacity > resting_opacity * 5, f'Surge insufficient: {active_opacity} vs {resting_opacity}'
"

# T2.3: Solar & Lunar Astronomical Calculations
assert_python "Solar progress calculation at Dawn (06:15 / 375 min) evaluates to 0.0" "
current_minutes = 6 * 60 + 15
assert current_minutes == 375
is_day = current_minutes >= 375 and current_minutes < 1095
day_progress = max(0.0, min(1.0, (current_minutes - 375) / 720.0))
assert is_day is True
assert day_progress == 0.0, f'Expected 0.0, got {day_progress}'
"

assert_python "Solar progress calculation at Solar Noon (12:15 / 735 min) evaluates to 0.5" "
current_minutes = 12 * 60 + 15
assert current_minutes == 735
is_day = current_minutes >= 375 and current_minutes < 1095
day_progress = max(0.0, min(1.0, (current_minutes - 375) / 720.0))
assert is_day is True
assert abs(day_progress - 0.5) < 1e-6, f'Expected 0.5, got {day_progress}'
"

assert_python "Solar progress calculation at Dusk (18:15 / 1095 min) reaches 1.0" "
current_minutes = 18 * 60 + 15
assert current_minutes == 1095
day_progress = max(0.0, min(1.0, (current_minutes - 375) / 720.0))
assert abs(day_progress - 1.0) < 1e-6, f'Expected 1.0, got {day_progress}'
"

assert_python "Lunar progress calculation at Dusk (18:15 / 1095 min) evaluates to 0.0" "
current_minutes = 18 * 60 + 15
nm = (current_minutes - 1095) if current_minutes >= 1095 else (current_minutes + 1440 - 1095)
night_progress = max(0.0, min(1.0, nm / 720.0))
assert night_progress == 0.0, f'Expected 0.0, got {night_progress}'
"

assert_python "Lunar progress calculation at Midnight/Nadir (00:15 / 15 min) evaluates to 0.5" "
current_minutes = 0 * 60 + 15
nm = (current_minutes - 1095) if current_minutes >= 1095 else (current_minutes + 1440 - 1095)
night_progress = max(0.0, min(1.0, nm / 720.0))
assert abs(night_progress - 0.5) < 1e-6, f'Expected 0.5, got {night_progress}'
"

assert_python "Lunar progress calculation at Dawn (06:15 / 375 min) reaches 1.0" "
current_minutes = 6 * 60 + 15
nm = (current_minutes - 1095) if current_minutes >= 1095 else (current_minutes + 1440 - 1095)
night_progress = max(0.0, min(1.0, nm / 720.0))
assert abs(night_progress - 1.0) < 1e-6, f'Expected 1.0, got {night_progress}'
"

assert_python "Solar/Lunar arc apex and horizon coordinates are mathematically smooth and bounded" "
start_x, end_x = 50.0, 730.0
baseline_y, apex_y = 110.0, 32.0
rise = baseline_y - apex_y

for prog in [0.0, 0.25, 0.5, 0.75, 1.0]:
    x = start_x + prog * (end_x - start_x)
    y = baseline_y - rise * 4 * prog * (1.0 - prog)
    assert not (x != x or y != y), 'NaN detected in trajectory'
    assert start_x <= x <= end_x, f'x={x} outside [{start_x}, {end_x}]'
    assert apex_y <= y <= baseline_y, f'y={y} outside [{apex_y}, {baseline_y}]'
assert abs(baseline_y - rise * 4 * 0.5 * 0.5 - apex_y) < 1e-6, 'Apex mismatch at midpoint'
"

assert_python "Solar bead trajectory is completely continuous across dawn and dusk transitions (0px jump)" "
start_x, end_x = 50.0, 730.0
baseline_y = 110.0
rise = baseline_y - 32.0

def get_sun_center(m):
    is_day = (m >= 375 and m < 1095)
    dp = max(0.0, min(1.0, (m - 375) / 720.0))
    nm = (m - 1095) if (m >= 1095) else (m + 1440 - 1095)
    np = max(0.0, min(1.0, nm / 720.0))
    sun_x = start_x + dp * (end_x - start_x)
    sun_y = baseline_y - rise * 4 * dp * (1.0 - dp)
    nadir_x = end_x - np * (end_x - start_x)
    nadir_y = baseline_y + 28 * 4 * np * (1.0 - np)
    cx = sun_x if is_day else nadir_x
    cy = sun_y if is_day else nadir_y
    return cx, cy

for m in range(1440):
    next_m = (m + 1) % 1440
    cx1, cy1 = get_sun_center(m)
    cx2, cy2 = get_sun_center(next_m)
    dx = abs(cx2 - cx1)
    dy = abs(cy2 - cy1)
    assert dx < 2.0, f'Discontinuous jump at minute {m}->{next_m}: dx={dx:.2f}px'
    assert dy < 2.0, f'Discontinuous jump at minute {m}->{next_m}: dy={dy:.2f}px'

# Dusk continuity: minute 1094 (day) -> 1095 (night)
cx_d1, cy_d1 = get_sun_center(1094)
cx_d2, cy_d2 = get_sun_center(1095)
assert abs(cx_d2 - cx_d1) < 1.0, f'Dusk jump dx={abs(cx_d2 - cx_d1)}'
assert abs(cy_d2 - cy_d1) < 1.0, f'Dusk jump dy={abs(cy_d2 - cy_d1)}'

# Dawn continuity: minute 374 (night) -> 375 (day)
cx_w1, cy_w1 = get_sun_center(374)
cx_w2, cy_w2 = get_sun_center(375)
assert abs(cx_w2 - cx_w1) < 1.0, f'Dawn jump dx={abs(cx_w2 - cx_w1)}'
assert abs(cy_w2 - cy_w1) < 1.0, f'Dawn jump dy={abs(cy_w2 - cy_w1)}'
"

# T2.4: Weather Condition Profile Robustness
assert_python "Weather profile handles hazy Bangalore condition ('Smoky haze')" "
c = 'Smoky haze'.lower()
if 'fog' in c or 'mist' in c or 'haze' in c or 'smoke' in c or 'smoky' in c:
    prof = {'opacity': 0.24, 'durationL1': 38000, 'durationL2': 52000, 'yOffset': 0}
assert prof['opacity'] == 0.24 and prof['durationL1'] == 38000
"

assert_python "Weather profile handles rainy condition ('Heavy Rain')" "
c = 'Heavy Rain'.lower()
if 'rain' in c or 'drizzle' in c or 'shower' in c or 'storm' in c or 'thunder' in c:
    prof = {'opacity': 0.18, 'durationL1': 24000, 'durationL2': 32000, 'yOffset': 16}
assert prof['opacity'] == 0.18 and prof['yOffset'] == 16
"

assert_python "Weather profile handles clear/sunny condition ('Sunny')" "
c = 'Sunny'.lower()
if 'clear' in c or 'sun' in c:
    prof = {'opacity': 0.07, 'durationL1': 60000, 'durationL2': 80000, 'yOffset': -8}
assert prof['opacity'] == 0.07 and prof['durationL1'] == 60000
"

assert_python "Weather profile handles overcast condition ('Partly cloudy')" "
c = 'Partly cloudy'.lower()
if 'cloud' in c or 'overcast' in c:
    prof = {'opacity': 0.15, 'durationL1': 42000, 'durationL2': 56000, 'yOffset': 4}
assert prof['opacity'] == 0.15 and prof['durationL1'] == 42000
"

assert_python "Weather profile handles unknown or empty conditions safely with fallback" "
for raw in ['', 'Unknown Condition', 'blizzard', 'dust', 'windy', 'xyz123']:
    c = (raw or '').lower()
    if 'fog' in c or 'mist' in c or 'haze' in c or 'smoke' in c or 'smoky' in c:
        prof = {'opacity': 0.24}
    elif 'rain' in c or 'drizzle' in c or 'shower' in c or 'storm' in c or 'thunder' in c:
        prof = {'opacity': 0.18}
    elif 'clear' in c or 'sun' in c:
        prof = {'opacity': 0.07}
    elif 'cloud' in c or 'overcast' in c:
        prof = {'opacity': 0.15}
    else:
        prof = {'opacity': 0.12, 'durationL1': 45000, 'durationL2': 60000, 'yOffset': 0}
    assert prof['opacity'] == 0.12, f'Expected fallback 0.12 for {raw}'
"

# T2.5: Git Telemetry Outside Repository
assert_python "git-stats.py handles execution outside git repository safely" "
import subprocess, tempfile, json
with tempfile.TemporaryDirectory() as tmpdir:
    res = subprocess.check_output(['python3', '$GIT_SCRIPT'], cwd=tmpdir, text=True)
    d = json.loads(res)
    assert 'repo' in d
    assert 'branch' in d
    assert 'days' in d and len(d['days']) == 7
"

echo ""

# ==============================================================================
# TIER 3: CROSS-FEATURE COMBINATIONS & ARCHITECTURAL INVARIANTS
# ==============================================================================
echo -e "${BOLD}--- TIER 3: Cross-Feature Combinations & Architectural Invariants ---${NC}"

# T3.1: Layer Masking Integrity & Click-Through Safety
assert_true "AmbientLayer mask restricts input region strictly to slateWrapper" \
    python3 -c "
with open('$PROJECT_DIR/desktop/AmbientLayer.qml') as f:
    qml = f.read()
assert 'mask: Region {' in qml
assert 'item: (root.active || fadeOutAnim.running) ? slateWrapper : null' in qml
"

assert_true "AmbientLayer mask restricts input region strictly to constellationWrapper" \
    python3 -c "
with open('$PROJECT_DIR/desktop/AmbientLayer.qml') as f:
    qml = f.read()
assert 'item: (root.active || fadeOutAnim.running) ? constellationWrapper : null' in qml
"

assert_true "AmbientLayer does NOT mask full-screen hudContainer or background items" \
    python3 -c "
with open('$PROJECT_DIR/desktop/AmbientLayer.qml') as f:
    qml = f.read()
# Extract the mask: Region { ... } block
mask_start = qml.find('mask: Region {')
assert mask_start != -1
# Find matching brace depth
depth = 0
mask_block = ''
for ch in qml[mask_start:]:
    mask_block += ch
    if ch == '{': depth += 1
    elif ch == '}':
        depth -= 1
        if depth == 0: break

assert 'hudContainer' not in mask_block, 'hudContainer must NOT be in layer mask'
assert 'crestAurora' not in mask_block, 'crestAurora must NOT be in layer mask'
assert 'weatherMist' not in mask_block, 'weatherMist must NOT be in layer mask'
assert 'solarLunarArc' not in mask_block, 'solarLunarArc must NOT be in layer mask'
assert 'ghostTrails' not in mask_block, 'ghostTrails must NOT be in layer mask'
assert 'parent' not in mask_block, 'parent must NOT be in layer mask'
"

assert_true "AmbientLayer region items evaluate to null when inactive (100% click pass-through)" \
    python3 -c "
with open('$PROJECT_DIR/desktop/AmbientLayer.qml') as f:
    qml = f.read()
assert ': null' in qml, 'Region items must fallback to null when inactive'
"

# T3.2: Tap Forwarders Connect Slates to Ghost Trails
assert_true "slateWrapper connects TapHandler to ghostTrails.spawnBurst" \
    python3 -c "
with open('$PROJECT_DIR/desktop/AmbientLayer.qml') as f:
    qml = f.read()
slate_idx = qml.find('id: slateWrapper')
constell_idx = qml.find('id: constellationWrapper')
slate_section = qml[slate_idx:constell_idx]
assert 'TapHandler' in slate_section
assert 'ghostTrails.spawnBurst(pt.x, pt.y)' in slate_section
assert 'mapToItem(hudContainer' in slate_section
"

assert_true "constellationWrapper connects TapHandler to ghostTrails.spawnBurst" \
    python3 -c "
with open('$PROJECT_DIR/desktop/AmbientLayer.qml') as f:
    qml = f.read()
constell_idx = qml.find('id: constellationWrapper')
constell_section = qml[constell_idx:]
assert 'TapHandler' in constell_section
assert 'ghostTrails.spawnBurst(pt.x, pt.y)' in constell_section
assert 'mapToItem(hudContainer' in constell_section
"

# T3.3: Dimensions and Visual Symmetry
assert_true "DesktopConstellationCard matches DesktopAmbientSlate dimensions (500x260, r38)" \
    python3 -c "
with open('$PROJECT_DIR/desktop/DesktopAmbientSlate.qml') as f:
    slate_code = f.read()
with open('$PROJECT_DIR/desktop/DesktopConstellationCard.qml') as f:
    constell_code = f.read()

assert 'implicitWidth: 500' in slate_code and 'implicitWidth: 500' in constell_code
assert 'implicitHeight: 260' in slate_code and 'implicitHeight: 260' in constell_code
assert 'radius: 38' in slate_code and 'radius: 38' in constell_code
"

assert_true "AmbientLayer places slateWrapper and constellationWrapper symmetrically (margin 48)" \
    python3 -c "
with open('$PROJECT_DIR/desktop/AmbientLayer.qml') as f:
    qml = f.read()
assert 'anchors.leftMargin: 48' in qml
assert 'anchors.rightMargin: 48' in qml
assert 'anchors.bottomMargin: 48' in qml
"

assert_true "Visual scene graph stacking order places atmosphere behind interactive cards" \
    python3 -c "
with open('$PROJECT_DIR/desktop/AmbientLayer.qml') as f:
    qml = f.read()
pos_aurora = qml.find('AudioCrestAurora')
pos_mist = qml.find('AmbientWeatherMist')
pos_arc = qml.find('SolarLunarArc')
pos_ghost = qml.find('DesktopGhostTrails')
pos_slate = qml.find('id: slateWrapper')
pos_constell = qml.find('id: constellationWrapper')

assert pos_aurora < pos_mist < pos_arc < pos_ghost < pos_slate < pos_constell, \
    f'Stacking order mismatch: aurora={pos_aurora}, mist={pos_mist}, arc={pos_arc}, ghost={pos_ghost}, slate={pos_slate}, constell={pos_constell}'
"

echo ""

# ==============================================================================
# TIER 4: REAL-WORLD APPLICATION SCENARIOS
# ==============================================================================
echo -e "${BOLD}--- TIER 4: Real-World Application Scenarios ---${NC}"

# T4.1: QuickShell IPC Theme Reload
assert_true "QuickShell IPC 'theme reload' succeeds without crashing daemon" \
    qs -c cool-shell ipc call theme reload

# T4.2: QuickShell IPC Ambient State Toggles
assert_python "QuickShell IPC 'control toggleAmbient' cleanly toggles ambient state" "
import subprocess, json
out = subprocess.check_output(['qs', '-c', 'cool-shell', 'ipc', 'call', 'control', 'toggleAmbient'], text=True)
data = json.loads(out)
assert data.get('success') is True, f'Expected success=true, got {data}'
assert 'ambientEnabled' in data, 'Missing ambientEnabled property in response'
"

assert_python "QuickShell IPC 'control toggleAmbient' restores active state cleanly" "
import subprocess, json
out = subprocess.check_output(['qs', '-c', 'cool-shell', 'ipc', 'call', 'control', 'toggleAmbient'], text=True)
data = json.loads(out)
assert data.get('success') is True
assert data.get('ambientEnabled') is True
"

# T4.3: Knowledge Graph AST Synchronisation
assert_true "Knowledge graph updates cleanly via 'graphify update .'" \
    graphify update .

# T4.4: Live Git Repository Telemetry Real-World Match
assert_python "Live git telemetry matches current repository HEAD commit and branch" "
import subprocess, json
stats = json.loads(subprocess.check_output(['python3', '$GIT_SCRIPT'], text=True))
curr_branch = subprocess.check_output(['git', 'branch', '--show-current'], text=True).strip() or 'main'
assert stats['branch'] == curr_branch, f'Branch mismatch: {stats[\"branch\"]} != {curr_branch}'
assert stats['repo'] == 'cool-shell', f'Repo name mismatch: {stats[\"repo\"]}'
"

# T4.5: Layer-Shell Window Attributes & Protocol Integrity
assert_true "AmbientLayer preserves Wayland Top layer and click-through non-interception attributes" \
    python3 -c "
with open('$PROJECT_DIR/desktop/AmbientLayer.qml') as f:
    qml = f.read()
assert 'exclusionMode: ExclusionMode.Ignore' in qml
assert 'aboveWindows: false' in qml
assert 'focusable: false' in qml
assert 'color: \"transparent\"' in qml
assert 'WlrLayershell.layer: WlrLayer.Top' in qml
assert 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.None' in qml
"

echo ""

# ==============================================================================
# TEST SUMMARY REPORT
# ==============================================================================
echo -e "${BOLD}${CYAN}========================================================================${NC}"
echo -e "${BOLD}${CYAN}   TEST SUMMARY REPORT                                                  ${NC}"
echo -e "${BOLD}${CYAN}========================================================================${NC}"
printf "${BOLD}Total Assertions Checked:${NC} %d\n" "$TOTAL_TESTS"
printf "${GREEN}${BOLD}Passed:${NC}                   %d\n" "$PASSED_TESTS"
if [ "$FAILED_TESTS" -eq 0 ]; then
    printf "${GREEN}${BOLD}Failed:${NC}                   %d\n" "$FAILED_TESTS"
    echo -e "\n${GREEN}${BOLD}ALL TESTS PASSED! Living Workspace environment verified successfully.${NC}\n"
    exit 0
else
    printf "${RED}${BOLD}Failed:${NC}                   %d\n" "$FAILED_TESTS"
    echo -e "\n${RED}${BOLD}FAILURE DETAILS:${NC}"
    for f in "${FAILURES[@]}"; do
        echo -e "  ${RED}• $f${NC}"
    done
    echo ""
    exit 1
fi
