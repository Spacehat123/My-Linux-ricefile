import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
pragma Singleton

Singleton {
    id: root

    readonly property var panelWidths: ({
        "control": 520,
        "launcher": 410,
        "clipboard": 365,
        "todo": 420,
        "notes": 500,
        "theme": 420,
        "wallpaper": 500,
        "capture": 395,
        "power": 380,
        "media": 460,
        "notifications": 365,
        "timer": 380,
        "shelf": 420,
        "weather": 380,
        "gamemode": 300,
        "ai": 540
    })
    readonly property var panelHeights: ({
        "control": 386,
        "launcher": 290,
        "clipboard": 80,
        "todo": 87,
        "notes": 430,
        "theme": 252,
        "wallpaper": 382,
        "capture": 208,
        "power": 56,
        "media": 220,
        "notifications": 80,
        "timer": 220,
        "shelf": 120,
        "weather": 120,
        "gamemode": 84,
        "ai": 110
    })
    readonly property var panelRadii: ({
        "control": 20,
        "launcher": 22,
        "clipboard": 20,
        "todo": 20,
        "notes": 18,
        "theme": 20,
        "wallpaper": 20,
        "capture": 22,
        "power": 28,
        "media": 32,
        "notifications": 24,
        "timer": 42,
        "shelf": 24,
        "weather": 22,
        "gamemode": 20,
        "ai": 22
    })
    signal openSettingsRequested(string category)

    function openSettings(category) {
        close();
        openSettingsRequested(category !== undefined && category !== null ? category : "");
    }
    property string activeScreenName: ""
    property string panel: "collapsed"
    property int noticeTick: 0
    readonly property bool expanded: panel !== "collapsed" && panel !== "clock"
    readonly property bool hasLiveLyrics: IslandHub.mediaPlaying && IslandHub.liveLyric.length > 0
    readonly property int targetWidth: {
        if (!expanded)
            return 145;
        if (panel === "media")
            return hasLiveLyrics ? 540 : 460;
        return panelWidths[panel] || 145;
    }
    property alias nightLightTemperature: persistence.nightLightTemperature

    // Game Mode State & Process Mediation
    property bool gameMode: false
    property int gameModeKilledCount: 0

    signal gameModeToggled(bool active)

    function toggleGameMode() {
        if (!gameModeProc.running) {
            gameModeProc.command = ["python3", Quickshell.shellPath("island/scripts/game-mode.py"), "toggle"];
            gameModeProc.running = true;
        }
    }

    function setGameMode(enabled) {
        if (gameMode !== enabled && !gameModeProc.running) {
            gameModeProc.command = ["python3", Quickshell.shellPath("island/scripts/game-mode.py"), enabled ? "enable" : "disable"];
            gameModeProc.running = true;
        }
    }

    Process {
        id: gameModeProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text);
                    root.gameMode = res.gameMode === true;
                    if (res.killedCount !== undefined) root.gameModeKilledCount = res.killedCount;
                    root.close();
                    gc();
                    root.gameModeToggled(root.gameMode);
                } catch (e) {
                    console.warn("[ShellState] gameMode error:", e);
                }
            }
        }
    }

    Process {
        id: gameModeInitProc
        command: ["python3", Quickshell.shellPath("island/scripts/game-mode.py"), "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text);
                    root.gameMode = res.gameMode === true;
                    if (res.killedCount !== undefined) root.gameModeKilledCount = res.killedCount;
                } catch (e) {}
            }
        }
    }

    // Feather Mode State & Process Mediation ("The Feather" Absolute Battery Mode)
    property bool featherMode: false
    property int featherKilledCount: 0

    signal featherModeToggled(bool active)

    function toggleFeatherMode() {
        if (!featherModeProc.running) {
            featherModeProc.command = ["python3", Quickshell.shellPath("island/scripts/feather-mode.py"), "toggle"];
            featherModeProc.running = true;
        }
    }

    function setFeatherMode(enabled) {
        if (featherMode !== enabled && !featherModeProc.running) {
            featherModeProc.command = ["python3", Quickshell.shellPath("island/scripts/feather-mode.py"), enabled ? "enable" : "disable"];
            featherModeProc.running = true;
        }
    }

    Process {
        id: featherModeProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text);
                    root.featherMode = res.featherMode === true;
                    if (res.killedCount !== undefined) root.featherKilledCount = res.killedCount;
                    root.close();
                    gc();
                    root.featherModeToggled(root.featherMode);
                } catch (e) {
                    console.warn("[ShellState] featherMode error:", e);
                }
            }
        }
    }

    Process {
        id: featherModeInitProc
        command: ["python3", Quickshell.shellPath("island/scripts/feather-mode.py"), "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text);
                    root.featherMode = res.featherMode === true;
                    if (res.killedCount !== undefined) root.featherKilledCount = res.killedCount;
                } catch (e) {}
            }
        }
    }

    // AI Image Studio Daemon state & lifecycle
    property bool aiDaemonLoaded: false

    function toggleAiDaemon() {
        if (panel === "ai") return;
        if (aiDaemonLoaded) {
            Quickshell.execDetached([Quickshell.shellPath("scripts/image-engine.sh"), "--stop"]);
            aiDaemonLoaded = false;
        } else {
            Quickshell.execDetached([Quickshell.shellPath("scripts/image-engine.sh"), "--preload"]);
            aiDaemonLoaded = true;
        }
    }

    function checkAiDaemonStatus() {
        if (!aiStatusProc.running) {
            aiStatusProc.running = true;
        }
    }

    Process {
        id: aiStatusProc
        command: [Quickshell.shellPath("scripts/image-engine.sh"), "--status"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (text) => {
                try {
                    const res = JSON.parse(text.trim());
                    if (res && res.loaded !== undefined) {
                        root.aiDaemonLoaded = (res.loaded === true);
                    }
                } catch (e) {}
            }
        }
    }

    // God's Eye View Mode state & lifecycle
    property bool godsEyeActive: false

    signal godsEyeToggled(bool active)

    function toggleGodsEye() {
        if (godsEyeActive) {
            Quickshell.execDetached([Quickshell.shellPath("scripts/gods-eye.sh"), "stop"]);
            godsEyeActive = false;
        } else {
            Quickshell.execDetached([Quickshell.shellPath("scripts/gods-eye.sh"), "start"]);
            godsEyeActive = true;
        }
        root.godsEyeToggled(godsEyeActive);
    }

    function openGodsEyeBrowser() {
        Quickshell.execDetached([Quickshell.shellPath("scripts/gods-eye.sh"), "open"]);
    }

    function checkGodsEyeStatus() {
        if (!godsEyeStatusProc.running) {
            godsEyeStatusProc.running = true;
        }
    }

    Process {
        id: godsEyeStatusProc
        command: [Quickshell.shellPath("scripts/gods-eye.sh"), "status"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (text) => {
                try {
                    const res = JSON.parse(text.trim());
                    if (res && res.running !== undefined) {
                        root.godsEyeActive = (res.running === true);
                    }
                } catch (e) {}
            }
        }
    }

    // Study Mode State & Enforcement Binding
    property bool studyActive: false
    property int studyRemaining: 0
    property bool studyOvertime: false
    property int studyOvertimeSeconds: 0
    property string studySubject: "CA / ICAI Study"
    property int studyTargetDuration: 10 // 10s for initial testing

    signal studyModeToggled(bool active)

    function startStudyMode(durationSeconds, subject) {
        const dur = durationSeconds || root.studyTargetDuration;
        const subj = subject || root.studySubject;
        Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/study-mode.py"), "start", "--duration", dur.toString(), "--subject", subj]);
        root.studyActive = true;
        root.studyOvertime = false;
        root.studyRemaining = dur;
        root.studyModeToggled(true);
    }

    function stopStudyMode() {
        Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/study-mode.py"), "stop"]);
        root.checkStudyStatus();
    }

    function checkStudyStatus() {
        if (!studyStatusProc.running) {
            studyStatusProc.running = true;
        }
    }

    Process {
        id: studyStatusProc
        command: ["python3", Quickshell.shellPath("scripts/study-mode.py"), "status"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (text) => {
                try {
                    const res = JSON.parse(text.trim());
                    if (res && res.active !== undefined) {
                        root.studyActive = (res.active === true);
                        root.studyRemaining = res.remaining_seconds || 0;
                        root.studyOvertime = (res.overtime === true);
                        root.studyOvertimeSeconds = res.overtime_seconds || 0;
                        if (res.subject) root.studySubject = res.subject;
                        if (res.target_duration) root.studyTargetDuration = res.target_duration;
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: root.studyActive ? 1000 : 3000
        running: true
        repeat: true
        onTriggered: {
            root.checkAiDaemonStatus();
            root.checkGodsEyeStatus();
            root.checkStudyStatus();
        }
    }

    // Compatibility forwarders to dedicated TodoState singleton
    property var todos: TodoState.todos
    function loadTodos() { TodoState.loadTodos(); }
    function saveTodos(next) { TodoState.saveTodos(next); }
    function addTodo(text) { TodoState.addTodo(text); }
    function toggleTodo(index) { TodoState.toggleTodo(index); }
    function updateTodo(index, changes) { TodoState.updateTodo(index, changes); }
    function removeTodo(index) { TodoState.removeTodo(index); }
    function swapTodos(first, second) { TodoState.swapTodos(first, second); }
    function clearCompletedTodos() { TodoState.clearCompletedTodos(); }
    function parseTodoInput(input) { return TodoState.parseTodoInput(input); }
    function todayKey() { return TodoState.todayKey(); }
    function tomorrowKey() { return TodoState.tomorrowKey(); }

    function setPanel(name) {
        if (name === "clock") name = "collapsed";
        panel = name;
        if (panel === "collapsed")
            activeScreenName = "";
    }

    function show(name, screenName) {
        if (gameMode) {
            setPanel(panel === "gamemode" ? "collapsed" : "gamemode");
            return;
        }
        if (name === "settings") {
            openSettings("");
            return;
        }
        if (name === "clock" || name === "collapsed") {
            close();
            return;
        }
        if (panelWidths[name] === undefined)
            return;

        if (screenName !== undefined && screenName !== null && screenName !== "") {
            activeScreenName = screenName;
        } else if (activeScreenName === "") {
            // Lock to active compositor monitor so island does not drift across monitors mid-interaction
            if (typeof Hyprland !== "undefined") {
                if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor && Hyprland.focusedWorkspace.monitor.name)
                    activeScreenName = Hyprland.focusedWorkspace.monitor.name;
                else if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name)
                    activeScreenName = Hyprland.focusedMonitor.name;
            }
            if (activeScreenName === "" && Quickshell.screens.length > 0 && Quickshell.screens[0])
                activeScreenName = Quickshell.screens[0].name || "";
        }

        setPanel(panel === name ? "collapsed" : name);
    }

    function close() {
        activeScreenName = "";
        setPanel("collapsed");
    }

    function cycle(offset) {
        if (gameMode) {
            setPanel(panel === "gamemode" ? "collapsed" : "gamemode");
            return;
        }
        const panels = ["collapsed", "control", "launcher", "clipboard", "todo", "notes", "theme", "wallpaper", "capture", "power", "media", "notifications", "timer", "shelf", "weather"];
        const current = Math.max(0, panels.indexOf(panel));
        setPanel(panels[(current + offset + panels.length) % panels.length]);
    }

    PersistentProperties {
        id: persistence

        property int nightLightTemperature: 4500

        reloadableId: "vyeos-notch-state"
    }

}
