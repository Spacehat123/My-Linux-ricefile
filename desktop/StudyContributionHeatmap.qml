import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../island" as Island

Item {
    id: root

    property bool active: false
    property var historyData: ({})
    property int totalSessions: 0
    property int todaySessions: 0
    property int currentStreak: 0
    property string hoveredInfo: ""

    implicitWidth: 492
    implicitHeight: 126

    Theme {
        id: theme
    }

    SystemClock {
        id: wallClock
        precision: SystemClock.Hours
    }

    // Monday of the first week in the 24-week window (20 weeks back + current week + 3 weeks ahead)
    readonly property var startMonday: {
        const now = wallClock.date ? new Date(wallClock.date) : new Date();
        const day = now.getDay(); // 0=Sun, 1=Mon, ...
        const diffToMon = (day === 0 ? -6 : 1 - day);
        const thisMonday = new Date(now.getFullYear(), now.getMonth(), now.getDate() + diffToMon);
        return new Date(thisMonday.getTime() - (20 * 7 * 86400000));
    }

    readonly property string todayKey: {
        const now = wallClock.date ? new Date(wallClock.date) : new Date();
        const y = now.getFullYear();
        const m = String(now.getMonth() + 1).padStart(2, "0");
        const d = String(now.getDate()).padStart(2, "0");
        return `${y}-${m}-${d}`;
    }

    readonly property var monthHeaders: {
        const names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const labels = [];
        for (let i = 0; i < 6; ++i) {
            const wIndex = i * 4;
            const d = new Date(root.startMonday.getTime() + wIndex * 7 * 86400000);
            labels.push(names[d.getMonth()]);
        }
        return labels;
    }

    function refreshHistory() {
        if (!historyProc.running) {
            historyProc.running = true;
        }
    }

    onActiveChanged: {
        if (active) {
            refreshHistory();
        }
    }

    Component.onCompleted: {
        refreshHistory();
    }

    Connections {
        target: Island.ShellState
        function onStudyHistoryRevisionChanged() {
            root.refreshHistory();
        }
        function onStudyActiveChanged() {
            if (!Island.ShellState.studyActive) {
                root.refreshHistory();
            }
        }
    }

    // Refresh only while Ambient HUD is visible (60s cadence; zero background subprocesses when hidden)
    Timer {
        interval: 60000
        running: root.active
        repeat: true
        onTriggered: root.refreshHistory()
    }

    Process {
        id: historyProc
        command: ["python3", Quickshell.shellPath("scripts/study-mode.py"), "history"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim() || "{}");
                    root.historyData = parsed;
                    let sum = 0;
                    for (let d in parsed) {
                        sum += (parsed[d] || 0);
                    }
                    root.totalSessions = sum;
                    root.todaySessions = parsed[root.todayKey] || 0;

                    // Compute consecutive day streak up to today
                    let streak = 0;
                    const now = wallClock.date ? new Date(wallClock.date) : new Date();
                    const base = new Date(now.getFullYear(), now.getMonth(), now.getDate());
                    for (let back = 0; back < 365; ++back) {
                        const check = new Date(base.getTime() - back * 86400000);
                        const ky = check.getFullYear();
                        const km = String(check.getMonth() + 1).padStart(2, "0");
                        const kd = String(check.getDate()).padStart(2, "0");
                        const key = `${ky}-${km}-${kd}`;
                        if ((parsed[key] || 0) > 0) {
                            streak += 1;
                        } else if (back === 0) {
                            continue;
                        } else {
                            break;
                        }
                    }
                    root.currentStreak = streak;
                } catch (e) {}
            }
        }
    }

    // Smoked Obsidian Glass Card (Theme-Synchronized)
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(Island.Theme.bgDim.r, Island.Theme.bgDim.g, Island.Theme.bgDim.b, 0.82)
        border.color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.22)
        border.width: 1

        // Top Specular Refraction Line
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 1
            color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 7

            // Header Row: Total Sessions, Today Badge & Streak
            Item {
                width: parent.width
                height: 16

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        text: "󰑴"
                        font.family: theme.iconFontFamily
                        font.pixelSize: 12
                        color: Island.Theme.green
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.hoveredInfo !== ""
                            ? root.hoveredInfo
                            : (root.totalSessions + (root.totalSessions === 1 ? " study session completed" : " study sessions completed"))
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: root.hoveredInfo !== "" ? Island.Theme.primary : Island.Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        visible: root.todaySessions > 0
                        text: "TODAY: " + root.todaySessions
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 0.6
                        color: Island.Theme.green
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        visible: root.currentStreak > 0
                        text: "🔥 " + root.currentStreak + "d streak"
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                        color: Island.Theme.orange
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: String((wallClock.date ? wallClock.date : new Date()).getFullYear())
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                        color: Island.Theme.mutedDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Dynamic Month Labels Header
            Row {
                width: parent.width
                spacing: 4
                Item { width: 22; height: 10 }
                Row {
                    spacing: 36
                    Repeater {
                        model: root.monthHeaders
                        delegate: Text {
                            required property string modelData
                            text: modelData
                            font.pixelSize: 8
                            font.bold: true
                            color: Island.Theme.muted
                            font.family: theme.fontFamily
                        }
                    }
                }
            }

            // The Heatmap Grid (7 Days × 24 Weeks)
            Row {
                spacing: 6

                // Day Labels (Mon, Wed, Fri)
                Column {
                    spacing: 3
                    Item { width: 18; height: 10 }
                    Text { text: "Mon"; font.pixelSize: 7; color: Island.Theme.mutedDark; font.family: theme.fontFamily }
                    Item { width: 18; height: 10 }
                    Text { text: "Wed"; font.pixelSize: 7; color: Island.Theme.mutedDark; font.family: theme.fontFamily }
                    Item { width: 18; height: 10 }
                    Text { text: "Fri"; font.pixelSize: 7; color: Island.Theme.mutedDark; font.family: theme.fontFamily }
                    Item { width: 18; height: 10 }
                }

                // Grid of 24 Weeks
                Row {
                    spacing: 3

                    Repeater {
                        model: 24
                        delegate: Column {
                            id: weekCol
                            required property int index
                            spacing: 3

                            Repeater {
                                model: 7
                                delegate: Rectangle {
                                    id: dayCell
                                    required property int index
                                    width: 10
                                    height: 10
                                    radius: 2

                                    readonly property string dateKey: {
                                        const daysOffset = (weekCol.index * 7) + dayCell.index;
                                        const cellDate = new Date(root.startMonday.getTime() + daysOffset * 86400000);
                                        const y = cellDate.getFullYear();
                                        const m = String(cellDate.getMonth() + 1).padStart(2, "0");
                                        const d = String(cellDate.getDate()).padStart(2, "0");
                                        return `${y}-${m}-${d}`;
                                    }

                                    readonly property int count: root.historyData[dateKey] || 0
                                    readonly property bool isToday: dateKey === root.todayKey

                                    color: {
                                        if (count <= 0) return Qt.rgba(1.0, 1.0, 1.0, 0.05);
                                        if (count === 1) return Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.35);
                                        if (count === 2) return Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.58);
                                        if (count === 3) return Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.80);
                                        return Island.Theme.green;
                                    }

                                    border.color: isToday
                                        ? Island.Theme.primary
                                        : ((count > 0) ? Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.4) : Qt.rgba(1.0, 1.0, 1.0, 0.05))
                                    border.width: isToday ? 1.5 : 1

                                    HoverHandler {
                                        id: cellHover
                                        onHoveredChanged: {
                                            if (hovered) {
                                                root.hoveredInfo = (dayCell.count === 0 ? "No" : dayCell.count) + (dayCell.count === 1 ? " session on " : " sessions on ") + dayCell.dateKey;
                                            } else if (root.hoveredInfo.endsWith(dayCell.dateKey)) {
                                                root.hoveredInfo = "";
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Legend Row: Less -> More
            Row {
                anchors.right: parent.right
                spacing: 4

                Text {
                    text: "Less"
                    font.family: theme.fontFamily
                    font.pixelSize: 8
                    color: Island.Theme.mutedDark
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle { width: 8; height: 8; radius: 2; color: Qt.rgba(1.0, 1.0, 1.0, 0.05); anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 8; height: 8; radius: 2; color: Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.35); anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 8; height: 8; radius: 2; color: Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.58); anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 8; height: 8; radius: 2; color: Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.80); anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 8; height: 8; radius: 2; color: Island.Theme.green; anchors.verticalCenter: parent.verticalCenter }

                Text {
                    text: "More"
                    font.family: theme.fontFamily
                    font.pixelSize: 8
                    color: Island.Theme.mutedDark
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
