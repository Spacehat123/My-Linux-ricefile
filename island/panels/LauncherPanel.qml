import "../Expression.js" as Expression
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import ".."
import "../components"

FocusScope {
    id: root

    property int selectedIndex: 0
    readonly property var answer: Expression.evaluate(searchInput.text)
    readonly property bool hasAnswer: answer !== null

    // =========================================================================
    // Feature 5: In-Memory Frecency Ranking Architecture
    // =========================================================================
    readonly property string frecencyDir: {
        const stateHome = Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state");
        return stateHome + "/cool-shell";
    }
    readonly property string frecencyFilePath: frecencyDir + "/launcher-frecency.json"

    property var appStats: ({})
    property bool statsDirty: false

    Process {
        id: mkdirFrecencyProc
        command: ["mkdir", "-p", root.frecencyDir]
        running: true
    }

    FileView {
        id: frecencyStore
        path: root.frecencyFilePath
        preload: true
        atomicWrites: true
        watchChanges: false
        onLoaded: {
            try {
                const raw = frecencyStore.text();
                if (raw && raw.trim()) {
                    root.appStats = JSON.parse(raw) || {};
                }
            } catch (e) {
                root.appStats = {};
            }
        }
        onLoadFailed: (err) => {
            if (err === FileViewError.FileNotFound) {
                frecencyStore.setText("{}\n");
            }
        }
    }

    Timer {
        id: frecencyFlushTimer
        interval: 3000
        repeat: false
        onTriggered: root.flushFrecency()
    }

    function recordAppLaunch(entry) {
        if (!entry) return;
        const key = entry.id || entry.name || "app";
        const now = Date.now();
        const current = root.appStats[key] || { count: 0, lastTime: now };
        root.appStats[key] = {
            count: Math.min(10000, current.count + 1),
            lastTime: now
        };
        root.statsDirty = true;
        frecencyFlushTimer.restart();
    }

    function flushFrecency() {
        if (!root.statsDirty) return;
        try {
            frecencyStore.setText(JSON.stringify(root.appStats, null, 2) + "\n");
            root.statsDirty = false;
        } catch (e) {
            console.warn("[LauncherPanel] Failed to save frecency stats:", e);
        }
    }

    function getFrecencyScore(entry) {
        if (!entry) return 0;
        const key = entry.id || entry.name || "app";
        const stat = root.appStats[key];
        if (!stat || !stat.count) return 0;
        const now = Date.now();
        const dtSec = Math.max(0, (now - (stat.lastTime || now)) / 1000);
        return stat.count * Math.exp(-0.00005 * dtSec);
    }

    // =========================================================================
    // Feature 6: Prefix-Gated Scoped File Search with In-Flight Cancellation
    // =========================================================================
    readonly property bool isFileSearch: searchInput.text.startsWith("file:") || searchInput.text.startsWith("doc:")
    property var fileResults: []

    Timer {
        id: fileDebounceTimer
        interval: 350
        repeat: false
        onTriggered: root.executeFileSearch()
    }

    Process {
        id: fdProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(Boolean);
                root.fileResults = lines.slice(0, 8);
            }
        }
    }

    function executeFileSearch() {
        if (fdProcess.running) {
            fdProcess.kill();
        }

        const raw = searchInput.text;
        const term = raw.split(":").slice(1).join(":").trim();
        if (term.length < 2) {
            root.fileResults = [];
            return;
        }

        const docsDir = Quickshell.env("XDG_DOCUMENTS_DIR") || (Quickshell.env("HOME") + "/Documents");
        const dlDir = Quickshell.env("XDG_DOWNLOAD_DIR") || (Quickshell.env("HOME") + "/Downloads");

        fdProcess.exec([
            "sh", "-c",
            "if command -v fd >/dev/null 2>&1; then fd --max-results 8 --max-depth 2 -t f \"$1\" \"$2\" \"$3\"; else find \"$2\" \"$3\" -maxdepth 2 -type f -iname \"*$1*\" 2>/dev/null | head -n 8; fi",
            "sh", term, docsDir, dlDir
        ]);
    }

    // =========================================================================
    // Navigation & Activation
    // =========================================================================
    function takeInitialFocus() {
        searchInput.forceActiveFocus(Qt.TabFocusReason);
    }

    function currentCount() {
        if (isFileSearch) return fileResults.length;
        return filteredApps.values.length;
    }

    function moveSelection(offset) {
        const count = currentCount();
        if (count === 0) {
            selectedIndex = 0;
            return;
        }

        selectedIndex = Math.max(0, Math.min(count - 1, selectedIndex + offset));
        results.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function resetSelection() {
        selectedIndex = 0;
        Qt.callLater(() => results.positionViewAtBeginning());
    }

    Connections {
        function onPanelChanged() {
            if (ShellState.panel !== "launcher") {
                searchInput.clear();
                root.fileResults = [];
                root.resetSelection();
                root.flushFrecency();
            }
        }

        target: ShellState
    }

    function activateSelection() {
        if (hasAnswer) {
            Quickshell.clipboardText = String(answer);
            IslandHub.showTransient("Copied to clipboard", 1500);
            ShellState.close();
            return;
        }
        if (isFileSearch) {
            if (fileResults.length > 0) {
                const target = fileResults[Math.max(0, Math.min(selectedIndex, fileResults.length - 1))];
                if (target) {
                    Quickshell.execDetached(["xdg-open", target]);
                    ShellState.close();
                }
            }
            return;
        }
        const values = filteredApps.values;
        if (values.length > 0) {
            const entry = values[Math.max(0, Math.min(selectedIndex, values.length - 1))];
            if (entry) {
                root.recordAppLaunch(entry);
                entry.execute();
            }
            ShellState.close();
        }
    }

    implicitWidth: 382
    implicitHeight: content.implicitHeight

    ScriptModel {
        id: filteredApps

        values: DesktopEntries.applications.values.filter((entry) => {
            if (entry.noDisplay)
                return false;

            const query = searchInput.text.toLowerCase();
            const name = String(entry.name || "").toLowerCase();
            const genericName = String(entry.genericName || "").toLowerCase();
            const keywords = entry.keywords ? entry.keywords.join(" ").toLowerCase() : "";
            return !query || name.includes(query) || genericName.includes(query) || keywords.includes(query);
        }).sort((left, right) => {
            if (!searchInput.text) {
                const scoreL = root.getFrecencyScore(left);
                const scoreR = root.getFrecencyScore(right);
                if (scoreL !== scoreR)
                    return scoreR - scoreL;
            }

            const leftName = String(left.name || "").toLowerCase();
            const rightName = String(right.name || "").toLowerCase();
            if (leftName < rightName)
                return -1;

            if (leftName > rightName)
                return 1;

            return String(left.name || "").localeCompare(String(right.name || ""));
        })
    }

    Column {
        id: content

        width: parent.width
        spacing: 8

        PanelNav {
            title: "Launcher"
            panel: "launcher"
        }

        Rectangle {
            width: parent.width
            height: 42
            color: "transparent"

            ShellText {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.isFileSearch ? "󰈙" : "󰍉"
                color: root.isFileSearch ? Theme.primary : Theme.muted
                font.pixelSize: 14
            }

            TextInput {
                id: searchInput

                anchors.left: parent.left
                anchors.leftMargin: 38
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                activeFocusOnTab: true
                onTextChanged: {
                    root.resetSelection();
                    if (root.isFileSearch) {
                        fileDebounceTimer.restart();
                    } else {
                        fileDebounceTimer.stop();
                        if (fdProcess.running) fdProcess.kill();
                    }
                }
                Keys.onDownPressed: root.moveSelection(1)
                Keys.onUpPressed: root.moveSelection(-1)
                Keys.onReturnPressed: root.activateSelection()
                Keys.onEnterPressed: root.activateSelection()
                Keys.onEscapePressed: ShellState.close()

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search apps, math, or file:doc…"
                    color: Theme.mutedDark
                    visible: !parent.text
                }
            }
        }

        Rectangle {
            width: parent.width
            height: root.hasAnswer ? 64 : 0
            radius: Theme.radiusSmall
            color: Theme.primaryContainer
            opacity: root.hasAnswer ? 1 : 0
            clip: true

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                ShellText {
                    text: String(searchInput.text).replace(/\*/g, "×").replace(/\//g, "÷")
                    color: Theme.muted
                    font.pixelSize: 9
                }

                ShellText {
                    text: root.hasAnswer ? String(root.answer) : ""
                    color: Theme.primary
                    font.pixelSize: 24
                    font.weight: Font.Bold
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: Theme.animationFast
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animationFast
                }
            }
        }

        ListView {
            id: results

            width: parent.width
            height: Math.min(5, count) * 48
            spacing: 4
            clip: true
            interactive: contentHeight > height

            model: root.isFileSearch ? root.fileResults : filteredApps

            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool isFileItem: root.isFileSearch
                readonly property string fileName: isFileItem ? String(modelData).split("/").pop() : (modelData ? modelData.name : "")
                readonly property string fileDir: isFileItem ? String(modelData) : ""

                width: results.width
                height: 44
                radius: Theme.radiusSmall
                color: index === root.selectedIndex && !root.hasAnswer ? Theme.primaryContainer : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 9

                    Rectangle {
                        width: 32
                        height: 32
                        color: "transparent"

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 20
                            visible: !isFileItem
                            source: isFileItem ? "" : Quickshell.iconPath(modelData ? modelData.icon : "", "application-x-executable")
                        }

                        ShellText {
                            anchors.centerIn: parent
                            visible: isFileItem
                            text: "󰈙"
                            font.pixelSize: 20
                            color: Theme.primary
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48
                        spacing: 1

                        ShellText {
                            width: parent.width
                            text: fileName
                            elide: Text.ElideRight
                            font.weight: Font.DemiBold
                        }

                        ShellText {
                            width: parent.width
                            text: isFileItem ? fileDir : (modelData ? (modelData.genericName || modelData.comment || "Application") : "")
                            elide: Text.ElideMiddle
                            color: Theme.muted
                            font.pixelSize: 9
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = index
                    onClicked: {
                        if (isFileItem) {
                            Quickshell.execDetached(["xdg-open", modelData]);
                            ShellState.close();
                        } else if (modelData) {
                            root.recordAppLaunch(modelData);
                            modelData.execute();
                            ShellState.close();
                        }
                    }
                }
            }
        }
    }
}
