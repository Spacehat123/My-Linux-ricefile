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
        "gamemode": 300
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
        "gamemode": 84
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
        "gamemode": 20
    })
    signal openSettingsRequested(string category)
    property string activeScreenName: ""
    property string panel: "collapsed"
    property int noticeTick: 0
    readonly property bool expanded: panel !== "collapsed" && panel !== "clock"
    readonly property int targetWidth: expanded ? (panelWidths[panel] || 145) : 145
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
            close();
            openSettingsRequested();
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
