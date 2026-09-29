import QtQuick
import Quickshell
import Quickshell.Io
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
        "media": 520,
        "notifications": 365,
        "timer": 380,
        "shelf": 420,
        "weather": 380
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
        "media": 280,
        "notifications": 80,
        "timer": 120,
        "shelf": 120,
        "weather": 120
    })
    property string panel: "collapsed"
    property int noticeTick: 0
    readonly property bool expanded: panel !== "collapsed" && panel !== "clock"
    readonly property int targetWidth: expanded ? (panelWidths[panel] || 145) : 145
    property alias nightLightTemperature: persistence.nightLightTemperature

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
    }

    function show(name) {
        if (name === "clock" || name === "collapsed") {
            close();
            return;
        }
        if (panelWidths[name] === undefined)
            return;

        setPanel(panel === name ? "collapsed" : name);
    }

    function close() {
        setPanel("collapsed");
    }

    function cycle(offset) {
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
