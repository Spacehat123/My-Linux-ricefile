import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

Item {
    id: root

    property bool active: true
    property var historyData: ({})
    property int totalSessions: 0
    property string hoveredInfo: ""

    implicitWidth: 480
    implicitHeight: 120

    Theme {
        id: theme
    }

    // Refresh history data periodically
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: historyProc.running = true
    }

    Process {
        id: historyProc
        command: ["python3", Quickshell.shellPath("scripts/study-mode.py"), "history"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    root.historyData = parsed;
                    let sum = 0;
                    for (let d in parsed) {
                        sum += (parsed[d] || 0);
                    }
                    root.totalSessions = sum;
                } catch (e) {}
            }
        }
    }

    // Glass Background Card
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(0.06, 0.08, 0.11, 0.75) // Dark translucent background
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.10)
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Header Row: Count & Settings
            Row {
                width: parent.width
                Item {
                    width: parent.width
                    height: 16

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.hoveredInfo !== "" ? root.hoveredInfo : (root.totalSessions + " study sessions completed")
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: root.hoveredInfo !== "" ? "#58a6ff" : "#e6edf3"
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: "2026"
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                            color: "#8b949e"
                        }
                    }
                }
            }

            // Month Labels Header
            Row {
                width: parent.width
                spacing: 4
                Item { width: 22; height: 10 } // Day label offset
                Row {
                    spacing: 34
                    Text { text: "Oct"; font.pixelSize: 8; color: "#7d8590"; font.family: theme.fontFamily }
                    Text { text: "Nov"; font.pixelSize: 8; color: "#7d8590"; font.family: theme.fontFamily }
                    Text { text: "Dec"; font.pixelSize: 8; color: "#7d8590"; font.family: theme.fontFamily }
                    Text { text: "Jan"; font.pixelSize: 8; color: "#7d8590"; font.family: theme.fontFamily }
                    Text { text: "Feb"; font.pixelSize: 8; color: "#7d8590"; font.family: theme.fontFamily }
                    Text { text: "Mar"; font.pixelSize: 8; color: "#7d8590"; font.family: theme.fontFamily }
                }
            }

            // The Heatmap Grid (7 Days × 24 Weeks)
            Row {
                spacing: 6

                // Day Labels (Mon, Wed, Fri)
                Column {
                    spacing: 3
                    Item { width: 18; height: 10 }
                    Text { text: "Mon"; font.pixelSize: 7; color: "#7d8590"; font.family: theme.fontFamily }
                    Item { width: 18; height: 10 }
                    Text { text: "Wed"; font.pixelSize: 7; color: "#7d8590"; font.family: theme.fontFamily }
                    Item { width: 18; height: 10 }
                    Text { text: "Fri"; font.pixelSize: 7; color: "#7d8590"; font.family: theme.fontFamily }
                    Item { width: 18; height: 10 }
                }

                // Grid of 24 Weeks
                Row {
                    spacing: 3

                    Repeater {
                        model: 24 // 24 Weeks displayed horizontally
                        delegate: Column {
                            id: weekCol
                            required property int index
                            spacing: 3

                            Repeater {
                                model: 7 // 7 Days (Mon=0 to Sun=6)
                                delegate: Rectangle {
                                    id: dayCell
                                    required property int index
                                    width: 10
                                    height: 10
                                    radius: 2

                                    // Compute date string for this cell
                                    readonly property string dateKey: {
                                        // Base start date: 2026-10-12 (Today)
                                        // Week index + day index
                                        const now = new Date(2026, 9, 12); // Oct 12, 2026
                                        const daysOffset = (weekCol.index * 7) + dayCell.index;
                                        const cellDate = new Date(now.getTime() + daysOffset * 86400000);
                                        const y = cellDate.getFullYear();
                                        const m = String(cellDate.getMonth() + 1).padStart(2, '0');
                                        const d = String(cellDate.getDate()).padStart(2, '0');
                                        return `${y}-${m}-${d}`;
                                    }

                                    readonly property int count: root.historyData[dateKey] || 0

                                    // GitHub style green shades
                                    color: {
                                        if (count <= 0) return "#161b22"; // GitHub empty
                                        if (count === 1) return "#0e4429"; // 1 session
                                        if (count === 2) return "#006d32"; // 2 sessions
                                        if (count === 3) return "#26a641"; // 3 sessions
                                        return "#39d353";                 // 4+ sessions
                                    }

                                    border.color: (count > 0) ? Qt.rgba(0.2, 0.8, 0.4, 0.2) : Qt.rgba(1.0, 1.0, 1.0, 0.04)
                                    border.width: 1

                                    HoverHandler {
                                        id: cellHover
                                        onHoveredChanged: {
                                            if (hovered) {
                                                root.hoveredInfo = (dayCell.count === 0 ? "No" : dayCell.count) + " sessions on " + dayCell.dateKey;
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
                    color: "#7d8590"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle { width: 8; height: 8; radius: 2; color: "#161b22"; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 8; height: 8; radius: 2; color: "#0e4429"; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 8; height: 8; radius: 2; color: "#006d32"; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 8; height: 8; radius: 2; color: "#26a641"; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 8; height: 8; radius: 2; color: "#39d353"; anchors.verticalCenter: parent.verticalCenter }

                Text {
                    text: "More"
                    font.family: theme.fontFamily
                    font.pixelSize: 8
                    color: "#7d8590"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
