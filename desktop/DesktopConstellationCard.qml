import QtQuick
import Quickshell
import Quickshell.Io
import "../island" as Island

Item {
    id: root

    property bool active: true
    implicitWidth: 500
    implicitHeight: 260

    // Git telemetry state
    property string gitRepo: "cool-shell"
    property string gitBranch: "main"
    property string gitLastCommit: "Syncing..."
    property int gitTotalCommits: 0
    property var gitDays: []

    // Pomodoro focus telemetry
    readonly property int completedFocus: Island.TimerState ? Island.TimerState.completedFocusSessions : 0
    readonly property int targetFocus: Island.TimerState ? Island.TimerState.targetFocusSessions : 4

    Process {
        id: gitStatsProc
        command: ["python3", Quickshell.shellPath("island/scripts/git-stats.py")]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim());
                    root.gitRepo = data.repo || "cool-shell";
                    root.gitBranch = data.branch || "main";
                    root.gitLastCommit = data.lastCommit || "";
                    root.gitTotalCommits = data.totalCommits || 0;
                    root.gitDays = data.days || [];
                    starCanvas.requestPaint();
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 60000
        running: root.active && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!gitStatsProc.running) gitStatsProc.running = true;
        }
    }

    onCompletedFocusChanged: starCanvas.requestPaint()

    // Card Body (matching DesktopAmbientSlate 1:1 - 30% more transparent)
    Rectangle {
        id: cardPlate
        anchors.fill: parent
        radius: 38
        color: Qt.rgba(Island.Theme.bg0.r, Island.Theme.bg0.g, Island.Theme.bg0.b, 0.38)
        border.color: Island.Theme.glassBorder
        border.width: 0
        clip: true

        // Inner 1px Refractive Rim
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 37
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            z: 1
        }

        // Top Specular Highlight Strip
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 1
            height: 1
            color: Qt.rgba(1, 1, 1, 0.12)
            z: 2
        }

        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            // TOP ROW: Momentum & Focus Badge
            Row {
                width: parent.width
                height: 38

                Column {
                    width: parent.width - 190
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Row {
                        spacing: 8
                        Text {
                            text: "󰊤"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 15
                            color: Island.Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.gitRepo + "  •  " + root.gitBranch
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Island.Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        text: root.gitTotalCommits + " COMMITS THIS WEEK"
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.5
                        color: Island.Theme.muted
                    }
                }

                // Focus Streak Pill Badge
                Rectangle {
                    width: 180
                    height: 32
                    radius: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.12)
                    border.color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.28)
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "󰔟"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: root.completedFocus >= root.targetFocus ? Island.Theme.green : Island.Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.completedFocus + " / " + root.targetFocus + " Focus Beads"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.completedFocus >= root.targetFocus ? Island.Theme.green : Island.Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // CENTER CANVAS: Celestial Constellation Star Map
            Item {
                width: parent.width
                height: 116

                Canvas {
                    id: starCanvas
                    anchors.fill: parent

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        const count = root.gitDays.length || 7;
                        const marginX = 28;
                        const baselineY = 74;
                        const maxAmplitude = 44;

                        // Find max commit count for scaling
                        let maxC = 1;
                        for (let i = 0; i < count; i++) {
                            const c = root.gitDays[i] ? root.gitDays[i].commits : 0;
                            if (c > maxC) maxC = c;
                        }

                        // Calculate points
                        const pts = [];
                        for (let i = 0; i < count; i++) {
                            const x = marginX + i * ((width - 2 * marginX) / Math.max(1, count - 1));
                            const c = root.gitDays[i] ? root.gitDays[i].commits : 0;
                            const y = baselineY - (c / maxC) * maxAmplitude;
                            pts.push({ x: x, y: y, commits: c, index: i });
                        }

                        // Draw constellation connecting lines
                        if (pts.length > 1) {
                            ctx.beginPath();
                            ctx.strokeStyle = Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.35);
                            ctx.lineWidth = 1.5;
                            ctx.moveTo(pts[0].x, pts[0].y);
                            for (let i = 1; i < pts.length; i++) {
                                ctx.lineTo(pts[i].x, pts[i].y);
                            }
                            ctx.stroke();
                        }

                        // Draw star nodes
                        for (let i = 0; i < pts.length; i++) {
                            const p = pts[i];
                            const isToday = (i === pts.length - 1);
                            const hasCommits = p.commits > 0;

                            // Outer halo for active stars
                            if (hasCommits || isToday) {
                                ctx.beginPath();
                                ctx.arc(p.x, p.y, hasCommits ? 8 : 5, 0, Math.PI * 2);
                                ctx.fillStyle = Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.20);
                                ctx.fill();
                            }

                            // Focus session orbit for today
                            if (isToday && root.completedFocus > 0) {
                                ctx.beginPath();
                                ctx.arc(p.x, p.y, 12, 0, Math.PI * 2);
                                ctx.strokeStyle = Qt.rgba(Island.Theme.green.r, Island.Theme.green.g, Island.Theme.green.b, 0.65);
                                ctx.lineWidth = 1.0;
                                ctx.stroke();
                            }

                            // Core star bead
                            ctx.beginPath();
                            ctx.arc(p.x, p.y, hasCommits ? 3.5 : 2.5, 0, Math.PI * 2);
                            ctx.fillStyle = hasCommits ? Island.Theme.primary : Island.Theme.mutedDark;
                            ctx.fill();
                        }
                    }
                }

                // Day Labels below Canvas
                Row {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14

                    Repeater {
                        model: root.gitDays.length || 7

                        Item {
                            required property int index
                            width: (starCanvas.width - 28) / 7
                            height: 20

                            Text {
                                anchors.centerIn: parent
                                text: (root.gitDays[index] && root.gitDays[index].dayName) ? root.gitDays[index].dayName : ["S","M","T","W","T","F","S"][index]
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: (index === 6) ? Island.Theme.primary : Island.Theme.muted
                            }
                        }
                    }
                }
            }

            // BOTTOM ROW: Telemetry & Mini Focus Streak Beads
            Row {
                width: parent.width
                height: 34

                Row {
                    width: parent.width - 120
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: "󰜘"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 13
                        color: Island.Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.gitLastCommit
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 10
                        color: Island.Theme.muted
                        elide: Text.ElideRight
                        width: parent.width - 30
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // 4 Focus Session Mini Beads
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: root.targetFocus

                        Rectangle {
                            required property int index
                            width: 8
                            height: 8
                            radius: 4
                            color: (index < root.completedFocus) ? Island.Theme.green : Qt.rgba(1, 1, 1, 0.12)
                            border.color: (index < root.completedFocus) ? Island.Theme.green : "transparent"
                            border.width: 1
                        }
                    }
                }
            }
        }
    }
}
