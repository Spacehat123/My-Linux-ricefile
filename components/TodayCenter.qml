import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../island" as Island

Item {
    id: root

    // =========================================================================
    // External Injections & Screen Context
    // =========================================================================
    property var desktopModel: null
    property var surfaceModel: null
    property var interactionModel: null
    property var screen: null

    // Dual-layer hover guard ensuring sidebar remains open while cursor is inside
    HoverHandler {
        id: rootHoverHandler
    }
    readonly property bool hovered: rootHoverHandler.hovered

    // =========================================================================
    // Calendar Computation Model
    // =========================================================================
    readonly property var currentDate: new Date()
    property int calYear: currentDate.getFullYear()
    property int calMonth: currentDate.getMonth()

    readonly property string monthYearString: {
        const monthNames = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ];
        return monthNames[calMonth] + " " + calYear;
    }

    readonly property var calendarDays: {
        const days = [];
        const firstDayIndex = new Date(calYear, calMonth, 1).getDay();
        // Shift so Monday is index 0 (0: Mon, 1: Tue, ..., 6: Sun)
        const startOffset = firstDayIndex === 0 ? 6 : firstDayIndex - 1;
        const totalDaysInMonth = new Date(calYear, calMonth + 1, 0).getDate();
        const totalPrevMonthDays = new Date(calYear, calMonth, 0).getDate();

        // Previous month trailing days
        for (let i = startOffset - 1; i >= 0; i--) {
            days.push({
                day: totalPrevMonthDays - i,
                isCurrentMonth: false,
                isToday: false
            });
        }

        // Current month days
        const todayDate = currentDate.getDate();
        const isCurrentMonthNow = (currentDate.getFullYear() === calYear && currentDate.getMonth() === calMonth);

        for (let d = 1; d <= totalDaysInMonth; d++) {
            days.push({
                day: d,
                isCurrentMonth: true,
                isToday: isCurrentMonthNow && (d === todayDate)
            });
        }

        // Next month leading days to complete full grid (up to 35 or 42)
        const remaining = (7 - (days.length % 7)) % 7;
        for (let n = 1; n <= remaining; n++) {
            days.push({
                day: n,
                isCurrentMonth: false,
                isToday: false
            });
        }
        return days;
    }

    function prevMonth() {
        if (calMonth === 0) {
            calMonth = 11;
            calYear -= 1;
        } else {
            calMonth -= 1;
        }
    }

    function nextMonth() {
        if (calMonth === 11) {
            calMonth = 0;
            calYear += 1;
        } else {
            calMonth += 1;
        }
    }

    function resetToToday() {
        calYear = currentDate.getFullYear();
        calMonth = currentDate.getMonth();
    }

    // =========================================================================
    // Persistent Scratchpad Storage
    // =========================================================================
    FileView {
        id: scratchpadFile
        path: Quickshell.shellPath("island/scratchpad.txt")
        preload: true
        atomicWrites: true
        watchChanges: false
        onLoaded: {
            scratchpadInput.text = scratchpadFile.text();
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                scratchpadFile.setText("Welcome to your personal scratchpad!\nJot down quick commands, thoughts, or notes here.\n");
            }
        }
    }

    Timer {
        id: scratchpadSaveDebounce
        interval: 600
        repeat: false
        onTriggered: {
            scratchpadFile.setText(scratchpadInput.text);
        }
    }

    // =========================================================================
    // UI LAYOUT
    // =========================================================================
    Flickable {
        id: scrollArea
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: mainCol.implicitHeight + 24
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: mainCol
            width: parent.width
            spacing: 16

            // =================================================================
            // 1. HEADER: GREETING & DATE GLANCE
            // =================================================================
            Item {
                width: parent.width
                height: 52

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: Qt.formatDateTime(root.currentDate, "dddd, MMMM d")
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 18
                        font.bold: true
                        color: Island.Theme.foreground
                    }

                    Text {
                        readonly property int pendingCount: Island.TodoState.todos.filter(t => !t.done).length
                        text: pendingCount > 0 
                            ? (pendingCount + " pending task" + (pendingCount > 1 ? "s" : "") + " for today") 
                            : "All caught up for today"
                        font.family: Island.Theme.fontFamily
                        font.pixelSize: 12
                        color: Island.Theme.muted
                    }
                }

                // Today Pill badge
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28
                    implicitWidth: todayBadgeText.implicitWidth + 20
                    radius: 14
                    color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.15)
                    border.color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.4)
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰸗"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: Island.Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: todayBadgeText
                            text: Qt.formatDateTime(root.currentDate, "hh:mm")
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: Island.Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // =================================================================
            // 2. MINI MONTH CALENDAR CARD
            // =================================================================
            Rectangle {
                width: parent.width
                implicitHeight: calCol.implicitHeight + 24
                radius: Island.Theme.radiusCard
                color: Island.Theme.glassCard
                border.color: Island.Theme.glassBorderSubtle
                border.width: 1

                Column {
                    id: calCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    // Calendar Header with Navigation
                    Item {
                        width: parent.width
                        height: 28

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.monthYearString
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                            color: Island.Theme.foreground
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            // Previous Month
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                color: prevHover.containsMouse ? Island.Theme.glassCardHover : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅁"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 12
                                    color: Island.Theme.foreground
                                }
                                MouseArea {
                                    id: prevHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.prevMonth()
                                }
                            }

                            // Reset to Today
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                color: todayHover.containsMouse ? Island.Theme.glassCardHover : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰁝"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 12
                                    color: Island.Theme.primary
                                }
                                MouseArea {
                                    id: todayHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.resetToToday()
                                }
                            }

                            // Next Month
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                color: nextHover.containsMouse ? Island.Theme.glassCardHover : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅂"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 12
                                    color: Island.Theme.foreground
                                }
                                MouseArea {
                                    id: nextHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.nextMonth()
                                }
                            }
                        }
                    }

                    // Weekday Labels (Mon - Sun)
                    Grid {
                        width: parent.width
                        columns: 7
                        spacing: 0

                        Repeater {
                            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                            Item {
                                width: parent.width / 7
                                height: 20
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Island.Theme.mutedDark
                                }
                            }
                        }
                    }

                    // Month Days Grid
                    Grid {
                        width: parent.width
                        columns: 7
                        spacing: 0

                        Repeater {
                            model: root.calendarDays

                            Item {
                                width: parent.width / 7
                                height: 32

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: modelData.isToday 
                                        ? Island.Theme.primary 
                                        : (dayHover.containsMouse ? Island.Theme.glassCardHover : "transparent")

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.day
                                        font.family: Island.Theme.fontFamily
                                        font.pixelSize: 11
                                        font.bold: modelData.isToday
                                        color: modelData.isToday 
                                            ? "#0a0a0f" 
                                            : (modelData.isCurrentMonth ? Island.Theme.foreground : Island.Theme.mutedDark)
                                    }

                                    MouseArea {
                                        id: dayHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // 3. DAILY TASKS & CHECKLIST (TODOS)
            // =================================================================
            Rectangle {
                width: parent.width
                implicitHeight: todoCol.implicitHeight + 24
                radius: Island.Theme.radiusCard
                color: Island.Theme.glassCard
                border.color: Island.Theme.glassBorderSubtle
                border.width: 1

                Column {
                    id: todoCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 12

                    // Card Header with Action
                    Item {
                        width: parent.width
                        height: 26

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                text: "Tasks & To-Do"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                color: Island.Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 18
                                implicitWidth: pendingText.implicitWidth + 12
                                radius: 9
                                color: Island.Theme.glassCardHover
                                Text {
                                    id: pendingText
                                    anchors.centerIn: parent
                                    text: Island.TodoState.todos.filter(t => !t.done).length.toString()
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Island.Theme.primary
                                }
                            }
                        }

                        // Clear Completed button
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Clear Done"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 11
                            color: clearDoneHover.containsMouse ? Island.Theme.primary : Island.Theme.muted
                            visible: Island.TodoState.todos.some(t => t.done)

                            MouseArea {
                                id: clearDoneHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Island.TodoState.clearCompletedTodos()
                            }
                        }
                    }

                    // Add Task Input Capsule
                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 18
                        color: Island.Theme.glassCardHover
                        border.color: todoAddInput.activeFocus ? Island.Theme.glassBorderActive : Island.Theme.glassBorderSubtle
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: "󰐕"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 14
                                color: Island.Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            TextInput {
                                id: todoAddInput
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 28
                                color: Island.Theme.foreground
                                selectionColor: Island.Theme.primary
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 12
                                activeFocusOnTab: true

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Add a task... [Press Enter]"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Island.Theme.mutedDark
                                    visible: !parent.text && !parent.activeFocus
                                }

                                Keys.onReturnPressed: commitNewTask()
                                Keys.onEnterPressed: commitNewTask()

                                function commitNewTask() {
                                    const t = text.trim();
                                    if (t.length > 0) {
                                        Island.TodoState.addTodo(t);
                                        text = "";
                                    }
                                }
                            }
                        }
                    }

                    // Task List Items
                    Column {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: Island.TodoState.todos.slice(0, 6)

                            Rectangle {
                                id: taskRow
                                width: parent.width
                                height: 34
                                radius: 8
                                color: rowHover.containsMouse ? Island.Theme.glassCardHover : "transparent"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    spacing: 10

                                    // Round Checkbox
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: modelData.done ? Island.Theme.primary : "transparent"
                                        border.color: modelData.done ? Island.Theme.primary : Island.Theme.mutedDark
                                        border.width: 1.5

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰄬"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 11
                                            color: "#0a0a0f"
                                            visible: modelData.done
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Island.TodoState.toggleTodo(index)
                                        }
                                    }

                                    // Task Title
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 64
                                        text: modelData.text
                                        font.family: Island.Theme.fontFamily
                                        font.pixelSize: 12
                                        font.strikeout: modelData.done
                                        color: modelData.done ? Island.Theme.mutedDark : Island.Theme.foreground
                                        elide: Text.ElideRight
                                    }

                                    // Delete Action Icon
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: delHover.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.2) : "transparent"
                                        visible: rowHover.containsMouse

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰆴"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 12
                                            color: delHover.containsMouse ? "#ff5555" : Island.Theme.muted
                                        }

                                        MouseArea {
                                            id: delHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Island.TodoState.removeTodo(index)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: rowHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                        }

                        // Empty State if no tasks
                        Item {
                            width: parent.width
                            height: 38
                            visible: Island.TodoState.todos.length === 0

                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "󰸞"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 14
                                    color: Island.Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "No tasks pending. Enjoy your day!"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // 4. QUICK SCRATCHPAD / INSTANT NOTES
            // =================================================================
            Rectangle {
                width: parent.width
                implicitHeight: scratchCol.implicitHeight + 24
                radius: Island.Theme.radiusCard
                color: Island.Theme.glassCard
                border.color: Island.Theme.glassBorderSubtle
                border.width: 1

                Column {
                    id: scratchCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    Item {
                        width: parent.width
                        height: 24

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                text: "Quick Scratchpad"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                color: Island.Theme.foreground
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                text: "󰅒"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 11
                                color: Island.Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Auto-saved"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 10
                                color: Island.Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 100
                        radius: 12
                        color: Island.Theme.glassCardHover
                        border.color: scratchpadInput.activeFocus ? Island.Theme.glassBorderActive : Island.Theme.glassBorderSubtle
                        border.width: 1

                        Flickable {
                            id: textFlick
                            anchors.fill: parent
                            anchors.margins: 8
                            contentWidth: width
                            contentHeight: scratchpadInput.paintedHeight
                            clip: true

                            TextEdit {
                                id: scratchpadInput
                                width: textFlick.width
                                textFormat: TextEdit.PlainText
                                wrapMode: TextEdit.Wrap
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 12
                                color: Island.Theme.foreground
                                selectionColor: Island.Theme.primary
                                selectByMouse: true

                                Text {
                                    anchors.fill: parent
                                    text: "Type notes, quick commands, or scratchpad ideas here..."
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Island.Theme.mutedDark
                                    visible: !parent.text && !parent.activeFocus
                                }

                                onTextChanged: {
                                    scratchpadSaveDebounce.restart();
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // 5. RECENT ALERTS / NOTIFICATION CENTER
            // =================================================================
            Rectangle {
                width: parent.width
                implicitHeight: alertCol.implicitHeight + 24
                radius: Island.Theme.radiusCard
                color: Island.Theme.glassCard
                border.color: Island.Theme.glassBorderSubtle
                border.width: 1

                Column {
                    id: alertCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    Item {
                        width: parent.width
                        height: 24

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                text: "Recent Alerts"
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                color: Island.Theme.foreground
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 18
                                implicitWidth: notifBadgeCount.implicitWidth + 12
                                radius: 9
                                color: Island.Theme.glassCardHover
                                Text {
                                    id: notifBadgeCount
                                    anchors.centerIn: parent
                                    text: (Island.IslandHub.notifModel && Island.IslandHub.notifModel.values ? Island.IslandHub.notifModel.values.length : 0).toString()
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Island.Theme.primary
                                }
                            }
                        }

                        // Dismiss all
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Clear"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 11
                            color: clearNotifHover.containsMouse ? Island.Theme.primary : Island.Theme.muted
                            visible: Island.IslandHub.notifModel && Island.IslandHub.notifModel.values && Island.IslandHub.notifModel.values.length > 0

                            MouseArea {
                                id: clearNotifHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const list = Island.IslandHub.notifModel && Island.IslandHub.notifModel.values ? Island.IslandHub.notifModel.values : [];
                                    for (let i = list.length - 1; i >= 0; --i) {
                                        try {
                                            if (list[i] && list[i].dismiss) list[i].dismiss();
                                        } catch (e) {}
                                    }
                                    Island.IslandHub.markSeen();
                                }
                            }
                        }
                    }

                    // Notification List
                    Column {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: Island.IslandHub.notifModel && Island.IslandHub.notifModel.values ? Island.IslandHub.notifModel.values : []

                            Rectangle {
                                width: parent.width
                                implicitHeight: notifRow.implicitHeight + 16
                                radius: 10
                                color: Island.Theme.glassCardHover
                                border.color: Island.Theme.glassBorderSubtle
                                border.width: 1

                                Row {
                                    id: notifRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    spacing: 10

                                    // Alert Icon Capsule
                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.15)
                                        anchors.top: parent.top

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰂚"
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 13
                                            color: Island.Theme.primary
                                        }
                                    }

                                    // Content
                                    Column {
                                        width: parent.width - 40
                                        spacing: 2

                                        Text {
                                            width: parent.width
                                            text: modelData.summary || modelData.appName || "Notification"
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: Island.Theme.foreground
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.body || ""
                                            font.family: Island.Theme.fontFamily
                                            font.pixelSize: 11
                                            color: Island.Theme.muted
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
                                            visible: text.length > 0
                                        }
                                    }
                                }
                            }
                        }

                        // Empty State if no notifications
                        Item {
                            width: parent.width
                            height: 34
                            visible: !Island.IslandHub.notifModel || !Island.IslandHub.notifModel.values || Island.IslandHub.notifModel.values.length === 0

                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "󰂚"
                                    font.family: Island.Theme.iconFontFamily
                                    font.pixelSize: 13
                                    color: Island.Theme.mutedDark
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "No recent notifications"
                                    font.family: Island.Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Island.Theme.mutedDark
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
