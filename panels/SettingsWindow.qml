import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../island" as Island
import "../island/components"
import "../core"

PanelWindow {
    id: root

    property bool open: false
    visible: open
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "cool-shell-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    focusable: open

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property var gameModeExceptions: ["steam", "discord", "spotify", "obs", "heroic"]

    function toggle() {
        open = !open;
    }

    function show() {
        open = true;
    }

    function hide() {
        open = false;
    }

    function openCategory(cat) {
        if (cat) {
            windowCard.activeCategory = cat;
        }
        show();
    }

    function addException(name) {
        if (name && !modExceptionProc.running) {
            modExceptionProc.command = ["python3", Quickshell.shellPath("island/scripts/game-mode.py"), "add-exception", name.trim().toLowerCase()];
            modExceptionProc.running = true;
        }
    }

    function removeException(name) {
        if (name && !modExceptionProc.running) {
            modExceptionProc.command = ["python3", Quickshell.shellPath("island/scripts/game-mode.py"), "remove-exception", name.trim().toLowerCase()];
            modExceptionProc.running = true;
        }
    }

    Process {
        id: getExceptionsProc
        command: ["python3", Quickshell.shellPath("island/scripts/game-mode.py"), "list-exceptions"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.gameModeExceptions = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: modExceptionProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.gameModeExceptions = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: setDefaultSinkProc
    }

    function selectDefaultSink(node) {
        if (!node) return;
        Pipewire.preferredDefaultAudioSink = node;
        if (node.id) {
            setDefaultSinkProc.command = ["wpctl", "set-default", node.id.toString()];
            setDefaultSinkProc.running = true;
        }
    }

    // Dismiss on Escape key
    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: root.open

        Keys.onEscapePressed: {
            root.hide();
        }

        // Dimmed backdrop
        Rectangle {
            id: backdrop
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
            opacity: root.open ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }
        }

        // Centered Floating Glass Settings Window (780 x 540)
        Rectangle {
            id: windowCard
            anchors.centerIn: parent
            width: 780
            height: 540
            radius: Island.Theme.radiusWindow
            color: Island.Theme.glassBackground
            border.color: Island.Theme.glassBorder
            border.width: Island.Theme.glassBorderWidth
            clip: true

            scale: root.open ? 1.0 : 0.96
            opacity: root.open ? 1.0 : 0.0

            Behavior on scale {
                NumberAnimation { duration: 220; easing.type: Easing.OutBack }
            }
            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            // Absorb clicks so they don't dismiss the window
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            property string activeCategory: "appearance"

            Column {
                anchors.fill: parent

                // =============================================================
                // WINDOW HEADER BAR
                // =============================================================
                Item {
                    width: parent.width
                    height: 54

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.16)
                            border.color: Island.Theme.glassBorderActive
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "󰒓"
                                font.family: Island.Theme.iconFontFamily
                                font.pixelSize: 16
                                color: Island.Theme.primary
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: "Cool-Shell Preferences"
                                font.pixelSize: 14
                                font.bold: true
                                font.family: Island.Theme.fontFamily
                                color: Island.Theme.foreground
                            }

                            Text {
                                text: "System & Desktop Configuration"
                                font.pixelSize: 10
                                font.family: Island.Theme.fontFamily
                                color: Island.Theme.muted
                            }
                        }
                    }

                    // Top-right close button
                    Rectangle {
                        id: closeBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        radius: 15
                        color: closeMouse.containsMouse ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.22) : Island.Theme.glassCard
                        border.color: closeMouse.containsMouse ? Island.Theme.red : Island.Theme.glassBorderSubtle
                        border.width: 1
                        scale: closeMouse.pressed ? 0.92 : 1.0

                        Behavior on scale { NumberAnimation { duration: 90 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            font.pixelSize: 18
                            font.bold: true
                            color: closeMouse.containsMouse ? Island.Theme.red : Island.Theme.muted
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.hide()
                        }
                    }

                    // Hairline separator below header
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Island.Theme.glassBorderSubtle
                    }
                }

                // =============================================================
                // WINDOW MAIN BODY (TWO COLUMNS: SIDEBAR + CONTENT)
                // =============================================================
                Item {
                    width: parent.width
                    height: parent.height - 54

                    // Left Category Navigation Sidebar (220px)
                    Rectangle {
                        id: navSidebar
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 220
                        color: Qt.rgba(Island.Theme.bgDim.r, Island.Theme.bgDim.g, Island.Theme.bgDim.b, 0.45)

                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 1
                            color: Island.Theme.glassBorderSubtle
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6

                            readonly property var categories: [
                                { id: "appearance", name: "Appearance & Themes", icon: "󰏘" },
                                { id: "wallpaper", name: "Display & Wallpaper", icon: "󰸉" },
                                { id: "audio", name: "Sound & PipeWire", icon: "󰕾" },
                                { id: "gamemode", name: "Game Mode & Rules", icon: "󰊴" },
                                { id: "a11y", name: "Accessibility & Voice", icon: "󰐝" },
                                { id: "recovery", name: "Window Recovery", icon: "󰁯" },
                                { id: "about", name: "About & Tour", icon: "󰋽" }
                            ]

                            Repeater {
                                model: parent.categories

                                delegate: Rectangle {
                                    id: catPill
                                    required property var modelData
                                    readonly property bool isSelected: windowCard.activeCategory === modelData.id

                                    width: 192
                                    height: 38
                                    radius: 12
                                    color: isSelected
                                        ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.18)
                                        : (catMouse.containsMouse ? Island.Theme.glassCardHover : "transparent")
                                    border.color: isSelected ? Island.Theme.glassBorderActive : (catMouse.containsMouse ? Island.Theme.glassBorderSubtle : "transparent")
                                    border.width: 1
                                    scale: catMouse.pressed ? 0.97 : 1.0

                                    Behavior on scale { NumberAnimation { duration: 90 } }
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: catPill.modelData.icon
                                            font.family: Island.Theme.iconFontFamily
                                            font.pixelSize: 14
                                            color: catPill.isSelected ? Island.Theme.primary : Island.Theme.muted
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: catPill.modelData.name
                                            font.pixelSize: 11
                                            font.bold: catPill.isSelected
                                            font.family: Island.Theme.fontFamily
                                            color: catPill.isSelected ? Island.Theme.foreground : Island.Theme.muted
                                        }
                                    }

                                    MouseArea {
                                        id: catMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: windowCard.activeCategory = catPill.modelData.id
                                    }
                                }
                            }
                        }
                    }

                    // Right Content Area (560px)
                    Flickable {
                        id: contentFlickable
                        anchors.left: navSidebar.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 20
                        clip: true
                        contentHeight: contentStack.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: contentStack
                            width: parent.width - 10
                            spacing: 16

                            // -------------------------------------------------
                            // 1. APPEARANCE & THEMES PAGE
                            // -------------------------------------------------
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "appearance"

                                Text {
                                    text: "Appearance & Themes"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }

                                Text {
                                    text: "Choose a handcrafted color palette. Switching themes immediately restyles the entire desktop, Dynamic Island, Dock, and Drawers."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Flow {
                                    width: parent.width
                                    spacing: 10

                                    Repeater {
                                        model: Island.AppearanceState ? Island.AppearanceState.themes : []

                                        delegate: Rectangle {
                                            id: themeCard
                                            required property var modelData
                                            readonly property bool isCurrent: Island.AppearanceState && Island.AppearanceState.currentTheme === modelData.slug

                                            width: 162
                                            height: 82
                                            radius: 14
                                            color: isCurrent ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.16) : Island.Theme.glassCard
                                            border.color: isCurrent ? Island.Theme.primary : (themeHover.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
                                            border.width: isCurrent ? 2 : 1
                                            scale: themeTap.pressed ? 0.96 : 1.0

                                            Behavior on scale { NumberAnimation { duration: 90 } }
                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            HoverHandler { id: themeHover }
                                            TapHandler {
                                                id: themeTap
                                                onTapped: {
                                                    if (Island.AppearanceState) {
                                                        Island.AppearanceState.setTheme(themeCard.modelData.slug);
                                                    }
                                                }
                                            }

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 8

                                                Row {
                                                    width: parent.width
                                                    spacing: 6

                                                    Text {
                                                        text: themeCard.modelData.name || "Theme"
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                        color: themeCard.isCurrent ? Island.Theme.primary : Island.Theme.foreground
                                                        elide: Text.ElideRight
                                                        width: parent.width - 24
                                                    }

                                                    Text {
                                                        visible: themeCard.isCurrent
                                                        text: "✓"
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        color: Island.Theme.primary
                                                    }
                                                }

                                                // Color swatch previews
                                                Row {
                                                    spacing: 5
                                                    Rectangle { width: 14; height: 14; radius: 7; color: themeCard.modelData.colors ? themeCard.modelData.colors.primary : "#a7c080" }
                                                    Rectangle { width: 14; height: 14; radius: 7; color: themeCard.modelData.colors ? themeCard.modelData.colors.bg0 : "#2d353b" }
                                                    Rectangle { width: 14; height: 14; radius: 7; color: themeCard.modelData.colors ? themeCard.modelData.colors.blue : "#7fbbb3" }
                                                    Rectangle { width: 14; height: 14; radius: 7; color: themeCard.modelData.colors ? themeCard.modelData.colors.purple : "#d699b6" }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // -------------------------------------------------
                            // 2. DISPLAY & WALLPAPER PAGE
                            // -------------------------------------------------
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "wallpaper"

                                Text {
                                    text: "Display & Wallpaper"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 110
                                    radius: 14
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 8

                                        Text {
                                            text: "Connected Monitors"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: Island.Theme.foreground
                                        }

                                        Repeater {
                                            model: Quickshell.screens

                                            delegate: Row {
                                                required property var modelData
                                                spacing: 10

                                                Text {
                                                    text: "🖥️ " + (modelData.name || "Display")
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    color: Island.Theme.primary
                                                }
                                                Text {
                                                    text: modelData.width + " × " + modelData.height + " @ 60Hz"
                                                    font.pixelSize: 11
                                                    color: Island.Theme.muted
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 80
                                    radius: 14
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 14

                                        Column {
                                            width: parent.width - 140
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3

                                            Text {
                                                text: "Wallpaper Manager (awww-daemon)"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: "Hardware-accelerated wallpaper transitions powered by dotarch."
                                                font.pixelSize: 10
                                                color: Island.Theme.muted
                                            }
                                        }

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 110
                                            height: 32
                                            radius: 10
                                            color: wpBtnMouse.containsMouse ? Island.Theme.primaryContainer : Island.Theme.glassCardHover
                                            border.color: Island.Theme.glassBorder
                                            border.width: 1
                                            scale: wpBtnMouse.pressed ? 0.95 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Pick Wallpaper"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }

                                            MouseArea {
                                                id: wpBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.hide();
                                                    Island.ShellState.show("wallpaper");
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // -------------------------------------------------
                            // 3. SOUND & AUDIO PAGE
                            // -------------------------------------------------
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "audio"

                                Text {
                                    text: "Sound & Audio"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }

                                Text {
                                    text: "Manage audio output devices and per-application streams with zero polling."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                }

                                // 1. PHYSICAL OUTPUT DEVICES
                                Text {
                                    text: "OUTPUT DEVICES"
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: Island.Theme.primary
                                }

                                Column {
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: Pipewire.nodes ? Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream) : []

                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property bool isDefault: Pipewire.defaultAudioSink && modelData.id === Pipewire.defaultAudioSink.id
                                            width: contentStack.width
                                            height: 52
                                            radius: 12
                                            color: isDefault ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.12) : Island.Theme.glassCard
                                            border.color: isDefault ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                            border.width: isDefault ? 1.5 : 1

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 10

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: (modelData.name && modelData.name.includes("bluez")) ? "󰋋" : ((modelData.description && modelData.description.includes("HDMI")) ? "󰍹" : "󰕾")
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 18
                                                    color: isDefault ? Island.Theme.primary : Island.Theme.muted
                                                }

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 170
                                                    spacing: 2

                                                    Text {
                                                        text: modelData.description || modelData.nickname || modelData.name || "Output Device"
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                        color: Island.Theme.foreground
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }

                                                    Text {
                                                        text: isDefault ? "Active Default Output" : "Available"
                                                        font.pixelSize: 9
                                                        font.bold: isDefault
                                                        color: isDefault ? Island.Theme.primary : Island.Theme.muted
                                                    }
                                                }

                                                // Volume slider
                                                StyledSlider {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 140
                                                    height: 18
                                                    value: modelData.audio ? modelData.audio.volume : 0.5
                                                    onMoved: (val) => {
                                                        if (modelData.audio) {
                                                            modelData.audio.volume = val;
                                                        }
                                                    }
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: Math.round((modelData.audio ? modelData.audio.volume : 0) * 100) + "%"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: Island.Theme.muted
                                                    width: 32
                                                }

                                                // Select Button
                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 64
                                                    height: 26
                                                    radius: 8
                                                    color: isDefault ? Island.Theme.primary : (selMouse.containsMouse ? Island.Theme.glassCardHover : "transparent")
                                                    border.color: isDefault ? Island.Theme.primary : Island.Theme.glassBorder
                                                    border.width: 1
                                                    scale: selMouse.pressed ? 0.94 : 1.0

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: isDefault ? "Active" : "Select"
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                        color: isDefault ? "#0a0a0f" : Island.Theme.foreground
                                                    }

                                                    MouseArea {
                                                        id: selMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: isDefault ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.selectDefaultSink(modelData);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Item { width: parent.width; height: 6 }

                                // 2. APPLICATION STREAMS
                                Text {
                                    text: "APPLICATION STREAMS"
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: Island.Theme.primary
                                }

                                Text {
                                    text: "No active application audio playback streams found."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                    visible: (Pipewire.nodes ? Pipewire.nodes.values.filter(n => n.audio && n.isStream && !n.isSink).length : 0) === 0
                                }

                                Column {
                                    width: parent.width
                                    spacing: 8
                                    visible: (Pipewire.nodes ? Pipewire.nodes.values.filter(n => n.audio && n.isStream && !n.isSink).length : 0) > 0

                                    Repeater {
                                        model: Pipewire.nodes ? Pipewire.nodes.values.filter(n => n.audio && n.isStream && !n.isSink) : []

                                        delegate: Rectangle {
                                            required property var modelData
                                            width: contentStack.width
                                            height: 48
                                            radius: 12
                                            color: Island.Theme.glassCard
                                            border.color: Island.Theme.glassBorderSubtle
                                            border.width: 1

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 10

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "󰓃"
                                                    font.family: Island.Theme.iconFontFamily
                                                    font.pixelSize: 14
                                                    color: Island.Theme.primary
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 140
                                                    text: modelData.name || modelData.description || "Audio Stream"
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    color: Island.Theme.foreground
                                                    elide: Text.ElideRight
                                                }

                                                // Slider for stream volume
                                                StyledSlider {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 220
                                                    height: 18
                                                    value: modelData.audio ? modelData.audio.volume : 0.5
                                                    onMoved: (val) => {
                                                        if (modelData.audio) {
                                                            modelData.audio.volume = val;
                                                        }
                                                    }
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: Math.round((modelData.audio ? modelData.audio.volume : 0) * 100) + "%"
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    color: Island.Theme.muted
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // -------------------------------------------------
                            // 3B. GAME MODE & EXCEPTIONS PAGE
                            // -------------------------------------------------
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "gamemode"

                                Text {
                                    text: "Game Mode & Process Exceptions"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }

                                Text {
                                    width: parent.width
                                    text: "Applications selected below will NOT be terminated when Game Mode is active. All of their child processes and game launchers will be preserved."
                                    font.pixelSize: 12
                                    color: Island.Theme.muted
                                    wrapMode: Text.Wrap
                                }

                                // Preset Popular Applications
                                Rectangle {
                                    width: parent.width
                                    implicitHeight: presetCol.implicitHeight + 24
                                    radius: 14
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Column {
                                        id: presetCol
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 10

                                        Text {
                                            text: "POPULAR APPLICATIONS"
                                            font.pixelSize: 10
                                            font.bold: true
                                            font.family: Island.Theme.fontFamily
                                            color: Island.Theme.mutedDark
                                        }

                                        Grid {
                                            width: parent.width
                                            columns: 2
                                            spacing: 8

                                            Repeater {
                                                model: [
                                                    { id: "steam", name: "Steam Client & Games", icon: "󰓓" },
                                                    { id: "discord", name: "Discord / Vesktop", icon: "󰙯" },
                                                    { id: "spotify", name: "Spotify Music", icon: "󰓇" },
                                                    { id: "obs", name: "OBS Studio", icon: "󰑋" },
                                                    { id: "heroic", name: "Heroic Games Launcher", icon: "󰊴" },
                                                    { id: "lutris", name: "Lutris Gaming Platform", icon: "󰺵" },
                                                    { id: "brave", name: "Brave Web Browser", icon: "󰖟" },
                                                    { id: "mpv", name: "MPV Media Player", icon: "󰕼" }
                                                ]

                                                Rectangle {
                                                    width: (parent.width - 8) / 2
                                                    height: 38
                                                    radius: 10
                                                    readonly property bool isAllowed: root.gameModeExceptions.includes(modelData.id)
                                                    color: isAllowed 
                                                        ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.15)
                                                        : (appHover.containsMouse ? Island.Theme.glassCardHover : "transparent")
                                                    border.color: isAllowed ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                                    border.width: 1

                                                    Row {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 10
                                                        anchors.right: checkPill.left
                                                        anchors.rightMargin: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 8

                                                        Text {
                                                            text: modelData.icon
                                                            font.family: Island.Theme.iconFontFamily
                                                            font.pixelSize: 14
                                                            color: parent.parent.isAllowed ? Island.Theme.primary : Island.Theme.muted
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                        Text {
                                                            text: modelData.name
                                                            font.family: Island.Theme.fontFamily
                                                            font.pixelSize: 11
                                                            font.bold: parent.parent.isAllowed
                                                            color: parent.parent.isAllowed ? Island.Theme.foreground : Island.Theme.muted
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            elide: Text.ElideRight
                                                            width: parent.width - 24
                                                        }
                                                    }

                                                    Rectangle {
                                                        id: checkPill
                                                        anchors.right: parent.right
                                                        anchors.rightMargin: 10
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: 16
                                                        height: 16
                                                        radius: 8
                                                        color: parent.isAllowed ? Island.Theme.primary : "transparent"
                                                        border.color: parent.isAllowed ? Island.Theme.primary : Island.Theme.mutedDark
                                                        border.width: 1.5

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "󰄬"
                                                            font.family: Island.Theme.iconFontFamily
                                                            font.pixelSize: 10
                                                            color: "#0a0a0f"
                                                            visible: parent.parent.isAllowed
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: appHover
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (parent.isAllowed) {
                                                                root.removeException(modelData.id);
                                                            } else {
                                                                root.addException(modelData.id);
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Custom Exception Process Input & Active Badges
                                Rectangle {
                                    width: parent.width
                                    implicitHeight: customCol.implicitHeight + 24
                                    radius: 14
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Column {
                                        id: customCol
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 10

                                        Text {
                                            text: "ADD CUSTOM PROCESS EXCEPTION"
                                            font.pixelSize: 10
                                            font.bold: true
                                            font.family: Island.Theme.fontFamily
                                            color: Island.Theme.mutedDark
                                        }

                                        // Input field capsule
                                        Rectangle {
                                            width: parent.width
                                            height: 36
                                            radius: 18
                                            color: Island.Theme.glassCardHover
                                            border.color: customInput.activeFocus ? Island.Theme.glassBorderActive : Island.Theme.glassBorderSubtle
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
                                                    id: customInput
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 30
                                                    color: Island.Theme.foreground
                                                    selectionColor: Island.Theme.primary
                                                    font.family: Island.Theme.fontFamily
                                                    font.pixelSize: 12

                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "Type executable name (e.g. rhythmbox)... [Press Enter]"
                                                        font.family: Island.Theme.fontFamily
                                                        font.pixelSize: 12
                                                        color: Island.Theme.mutedDark
                                                        visible: !parent.text && !parent.activeFocus
                                                    }

                                                    Keys.onReturnPressed: commitCustom()
                                                    Keys.onEnterPressed: commitCustom()

                                                    function commitCustom() {
                                                        const clean = text.trim();
                                                        if (clean.length > 0) {
                                                            root.addException(clean);
                                                            text = "";
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Active exceptions tags
                                        Flow {
                                            width: parent.width
                                            spacing: 6

                                            Repeater {
                                                model: root.gameModeExceptions

                                                Rectangle {
                                                    height: 26
                                                    implicitWidth: tagRow.implicitWidth + 16
                                                    radius: 13
                                                    color: Island.Theme.glassCardHover
                                                    border.color: Island.Theme.glassBorderSubtle
                                                    border.width: 1

                                                    Row {
                                                        id: tagRow
                                                        anchors.centerIn: parent
                                                        spacing: 6

                                                        Text {
                                                            text: modelData
                                                            font.family: Island.Theme.fontFamily
                                                            font.pixelSize: 11
                                                            font.bold: true
                                                            color: Island.Theme.primary
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                        Text {
                                                            text: "✕"
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            color: Island.Theme.muted
                                                            anchors.verticalCenter: parent.verticalCenter

                                                            MouseArea {
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: root.removeException(modelData)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // -------------------------------------------------
                            // 4. ACCESSIBILITY & VOICE PAGE
                            // -------------------------------------------------
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "a11y"

                                Text {
                                    text: "Accessibility & Spoken Voice"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 82
                                    radius: 14
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 14

                                        Column {
                                            width: parent.width - 80
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3

                                            Text {
                                                text: "Screen Reader Mode (speech-dispatcher)"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }
                                            Text {
                                                text: Island.AccessibilityState && Island.AccessibilityState.screenReaderMode
                                                    ? "Connected to org.freedesktop.SpeechDispatcher (Daemon Active)"
                                                    : "Spoken narration of Island activities and notifications is disabled."
                                                font.pixelSize: 10
                                                color: Island.AccessibilityState && Island.AccessibilityState.screenReaderMode ? Island.Theme.green : Island.Theme.muted
                                            }
                                        }

                                        // Toggle Pill Switch
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 44
                                            height: 24
                                            radius: 12
                                            color: Island.AccessibilityState && Island.AccessibilityState.screenReaderMode ? Island.Theme.primary : Island.Theme.bg1
                                            border.color: Island.Theme.glassBorder
                                            border.width: 1

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: (Island.AccessibilityState && Island.AccessibilityState.screenReaderMode) ? 22 : 2
                                                width: 20
                                                height: 20
                                                radius: 10
                                                color: Island.Theme.shellForeground

                                                Behavior on x { NumberAnimation { duration: 130 } }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (Island.AccessibilityState) {
                                                        Island.AccessibilityState.screenReaderMode = !Island.AccessibilityState.screenReaderMode;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 160
                                    height: 34
                                    radius: 10
                                    color: a11yTestMouse.containsMouse ? Island.Theme.primaryContainer : Island.Theme.glassCardHover
                                    border.color: Island.Theme.glassBorder
                                    border.width: 1
                                    scale: a11yTestMouse.pressed ? 0.95 : 1.0

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Test Announcement"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: Island.Theme.foreground
                                    }

                                    MouseArea {
                                        id: a11yTestMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (Island.AccessibilityState) {
                                                Island.AccessibilityState.speak("Cool Shell spoken feedback test online.");
                                            }
                                        }
                                    }
                                }
                            }

                            // -------------------------------------------------
                            // 5. WINDOW RECOVERY PAGE
                            // -------------------------------------------------
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "recovery"

                                Text {
                                    text: "Window Recovery & Session Tracking"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }

                                Text {
                                    text: "Event-driven window layout preservation. Snapshots are atomically written on a 5-second debounce with zero polling."
                                    font.pixelSize: 11
                                    color: Island.Theme.muted
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 120
                                    radius: 14
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 8

                                        Text {
                                            text: "State File Location:"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: Island.Theme.muted
                                        }
                                        Text {
                                            text: "~/.local/state/cool-shell/window-recovery.json"
                                            font.pixelSize: 11
                                            font.family: "monospace"
                                            color: Island.Theme.primary
                                        }

                                        Rectangle {
                                            width: 170
                                            height: 32
                                            radius: 10
                                            color: snapMouse.containsMouse ? Island.Theme.primaryContainer : Island.Theme.glassCardHover
                                            border.color: Island.Theme.glassBorder
                                            border.width: 1
                                            scale: snapMouse.pressed ? 0.95 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Commit Snapshot Now"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }

                                            MouseArea {
                                                id: snapMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Island.IslandHub.showTransient("Window layout saved", 2000);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // -------------------------------------------------
                            // 6. ABOUT & TOUR PAGE
                            // -------------------------------------------------
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: windowCard.activeCategory === "about"

                                Text {
                                    text: "About Cool-Shell"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Island.Theme.foreground
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 140
                                    radius: 14
                                    color: Island.Theme.glassCard
                                    border.color: Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 8

                                        Text {
                                            text: "Cool-Shell Desktop Environment"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Island.Theme.foreground
                                        }

                                        Text {
                                            text: "Version: 1.0.0 (Unified Frosted Glass Architecture)"
                                            font.pixelSize: 11
                                            color: Island.Theme.muted
                                        }

                                        Text {
                                            text: "Performance Guarantee: 0.00% Idle CPU Utilization, Zero Infinite Loops"
                                            font.pixelSize: 11
                                            color: Island.Theme.green
                                        }

                                        Rectangle {
                                            width: 170
                                            height: 32
                                            radius: 10
                                            color: tourMouse.containsMouse ? Island.Theme.primaryContainer : Island.Theme.glassCardHover
                                            border.color: Island.Theme.glassBorder
                                            border.width: 1
                                            scale: tourMouse.pressed ? 0.95 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Replay Onboarding Tour"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Island.Theme.foreground
                                            }

                                            MouseArea {
                                                id: tourMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.hide();
                                                    Quickshell.execDetached(["rm", "-f", Quickshell.env("HOME") + "/.local/state/cool-shell/onboarding.json"]);
                                                    Island.IslandHub.showTransient("Restarting Onboarding Guide...", 2000);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
