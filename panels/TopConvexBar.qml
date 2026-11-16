import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import "../island" as Island
import "../island/components" as IslandComp
import "../island/panels"

PanelWindow {
    id: root

    // Bar base dimensions: 40px base height matching Minflair Convex
    readonly property int baseHeight: 40
    readonly property int flareWidth: 18
    readonly property int flareHeight: 12
    readonly property int bottomRadius: 12

    readonly property HyprlandMonitor activeMonitor: {
        if (typeof Hyprland !== "undefined") {
            if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor)
                return Hyprland.focusedWorkspace.monitor;
            if (Hyprland.focusedMonitor)
                return Hyprland.focusedMonitor;
        }
        return null;
    }

    readonly property bool isCurrentScreen: {
        if (Island.ShellState && Island.ShellState.activeScreenName !== "")
            return root.screen && root.screen.name === Island.ShellState.activeScreenName;
        if (activeMonitor && root.screen)
            return root.screen.name === activeMonitor.name;
        return Quickshell.screens.length > 0 && root.screen === Quickshell.screens[0];
    }

    readonly property bool isExpanded: Boolean(Island.ShellState && Island.ShellState.expanded && isCurrentScreen)
    property string displayedPanel: "control"
    property bool contentStaged: false

    readonly property bool screenHasFullscreen: {
        if (typeof Hyprland === "undefined") return false;
        if (activeMonitor && root.screen && root.screen.name === activeMonitor.name) {
            return Hyprland.focusedWorkspace ? Boolean(Hyprland.focusedWorkspace.hasFullscreen) : false;
        }
        if (Hyprland.workspaces) {
            const list = Hyprland.workspaces.values;
            for (let i = 0; i < list.length; ++i) {
                const ws = list[i];
                if (ws && ws.active && ws.monitor && root.screen && ws.monitor.name === root.screen.name) {
                    return Boolean(ws.hasFullscreen);
                }
            }
        }
        return false;
    }

    // Autohide on fullscreen or Game Mode when not expanded
    visible: (!screenHasFullscreen && !(Island.ShellState && Island.ShellState.gameMode)) || isExpanded

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    aboveWindows: true
    focusable: root.isExpanded
    // IslandSpacer already reserves the 42px exclusive zone cleanly
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "cool-shell-topbar"

    // Wayland input mask: clicks below 40px pass straight to windows when collapsed
    mask: Region {
        Region {
            x: 0
            y: 0
            width: root.width
            height: root.isExpanded ? root.height : root.baseHeight
        }
    }

    // Active media player
    readonly property var activePlayer: (() => {
        const players = Mpris.players.values;
        for (let i = 0; i < players.length; ++i) {
            if (players[i] && players[i].isPlaying)
                return players[i];
        }
        return players.length > 0 ? players[0] : null;
    })()

    readonly property bool isPlaying: activePlayer ? activePlayer.isPlaying : false
    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""

    // Battery
    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercent: battery ? Math.round(battery.percentage * 100) : 100
    readonly property bool isCharging: battery ? (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged) : false

    // Center wing dimension calculations: Always wide with generous border padding
    readonly property real idleCenterWidth: Math.max(310, centerIdleRow.implicitWidth + 56)
    // Extra 96px width and 68px height ensure luxurious padding from curved borders to content
    readonly property real targetExpandedWidth: (Island.ShellState && Island.ShellState.panelWidths[displayedPanel] || 500) + 96
    readonly property real targetExpandedHeight: (Island.ShellState && Island.ShellState.panelHeights[displayedPanel] || 260) + 68

    // Smooth GPU-accelerated morphing properties using ease-in, ease-out, and overshoot
    property real animatedCenterWidth: isExpanded ? targetExpandedWidth : idleCenterWidth
    property real animatedCenterHeight: isExpanded ? targetExpandedHeight : baseHeight
    property real centerRadius: isExpanded ? 22 : bottomRadius

    Behavior on animatedCenterWidth {
        NumberAnimation {
            duration: root.isExpanded ? 360 : 260
            easing.type: root.isExpanded ? Easing.InOutBack : Easing.InOutCubic
            easing.overshoot: 1.18
        }
    }

    Behavior on animatedCenterHeight {
        NumberAnimation {
            duration: root.isExpanded ? 370 : 260
            easing.type: root.isExpanded ? Easing.InOutBack : Easing.InOutCubic
            easing.overshoot: 1.20
        }
    }

    Behavior on centerRadius {
        NumberAnimation {
            duration: root.isExpanded ? 360 : 260
            easing.type: Easing.InOutCubic
        }
    }

    // Section widths: Left wing starts from left with padding and expands for music track
    readonly property real leftW: Math.max(260, leftRow.implicitWidth + 80)
    readonly property real centerW: Math.round(animatedCenterWidth)
    readonly property real centerHeight: Math.max(baseHeight, Math.round(animatedCenterHeight))
    readonly property real rightW: Math.max(260, rightRow.implicitWidth + 60)
    readonly property real centerX: Math.round((width - centerW) / 2)

    // Mathematical Bézier generator for Minflair Convex shape
    function getConvexPath(w, h, lW, cX, cW, rW, fw, fh, br, cH, baseH, cbr) {
        if (w <= 0 || h <= 0) return "";
        let bh = baseH;
        let centerR = (cbr !== undefined && cbr > 0) ? cbr : br;
        let tb = 0;

        let p = `M 0 0 `;
        // 1. Left wing
        p += `L 0 ${bh} `;
        p += `L ${lW - fw - br} ${bh} `;
        p += `C ${lW - fw - br * 0.45} ${bh}, ${lW - fw} ${bh - br * 0.45}, ${lW - fw} ${bh - br} `;
        if (bh - br > fh + tb)
            p += `L ${lW - fw} ${fh + tb} `;
        p += `C ${lW - fw} ${fh * 0.45 + tb}, ${lW - fw * 0.55} ${tb}, ${lW} ${tb} `;

        // 2. Bridge 1
        p += `L ${cX} ${tb} `;

        // 3. Flare into center wing (morphs downward when expanded!)
        p += `C ${cX + fw * 0.55} ${tb}, ${cX + fw} ${fh * 0.45 + tb}, ${cX + fw} ${fh + tb} `;
        if (cH - centerR > fh + tb)
            p += `L ${cX + fw} ${cH - centerR} `;
        p += `C ${cX + fw} ${cH - centerR * 0.45}, ${cX + fw + centerR * 0.45} ${cH}, ${cX + fw + centerR} ${cH} `;

        // 4. Center wing bottom
        p += `L ${cX + cW - fw - centerR} ${cH} `;
        p += `C ${cX + cW - fw - centerR * 0.45} ${cH}, ${cX + cW - fw} ${cH - centerR * 0.45}, ${cX + cW - fw} ${cH - centerR} `;
        if (cH - centerR > fh + tb)
            p += `L ${cX + cW - fw} ${fh + tb} `;
        p += `C ${cX + cW - fw} ${fh * 0.45 + tb}, ${cX + cW - fw * 0.55} ${tb}, ${cX + cW} ${tb} `;

        // 5. Bridge 2
        let rX = w - rW;
        p += `L ${rX} ${tb} `;

        // 6. Flare into right wing
        p += `C ${rX + fw * 0.55} ${tb}, ${rX + fw} ${fh * 0.45 + tb}, ${rX + fw} ${fh + tb} `;
        if (bh - br > fh + tb)
            p += `L ${rX + fw} ${bh - br} `;
        p += `C ${rX + fw} ${bh - br * 0.45}, ${rX + fw + br * 0.45} ${bh}, ${rX + fw + br} ${bh} `;

        // 7. Right wing and close
        p += `L ${w} ${bh} `;
        p += `L ${w} 0 `;
        p += `Z`;
        return p;
    }

    // Dismissal MouseArea: clicking outside the expanded center wing closes the panel
    MouseArea {
        anchors.fill: parent
        enabled: root.isExpanded
        z: 0
        onClicked: (mouse) => {
            let inCenter = (mouse.x >= root.centerX && mouse.x <= root.centerX + root.centerW && mouse.y <= root.centerHeight);
            if (!inCenter && Island.ShellState) {
                Island.ShellState.close();
            }
        }
    }

    // Panel reference dictionary
    readonly property Item activePanelItem: {
        const panels = {
            "control": controlPanel,
            "launcher": launcherPanel,
            "clipboard": clipboardPanel,
            "todo": todoPanel,
            "notes": quickNotesPanel,
            "theme": themePanel,
            "wallpaper": wallpaperPanel,
            "capture": capturePanel,
            "power": powerPanel,
            "notifications": notifCenterPanel,
            "timer": timerPanel,
            "shelf": shelfPanel,
            "weather": weatherPanel,
            "gamemode": gameModePanel,
            "ai": aiPromptPanel,
            "phone": phonePanel,
            "caption": captionPanel
        };
        return panels[displayedPanel] || null;
    }

    function focusInitialControl() {
        if (!root.isExpanded || !activePanelItem)
            return;
        panelHost.forceActiveFocus();
        if (typeof activePanelItem.takeInitialFocus === "function") {
            activePanelItem.takeInitialFocus();
            return;
        }
        const initial = activePanelItem.nextItemInFocusChain(true);
        if (initial)
            initial.forceActiveFocus(Qt.TabFocusReason);
    }

    function moveFocus(forward) {
        if (!root.isExpanded)
            return;
        const current = root.activeFocusItem;
        if (!current) {
            focusInitialControl();
            return;
        }
        const target = current.nextItemInFocusChain(forward);
        if (target)
            target.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
    }

    Connections {
        target: Island.ShellState

        function onPanelChanged() {
            if (root.isExpanded) {
                stageTimer.restart();
                root.displayedPanel = Island.ShellState.panel;
                if (Island.ShellState.panel === "notifications" && Island.IslandHub)
                    Island.IslandHub.markSeen();
                focusTimer.restart();
            } else {
                stageTimer.stop();
                root.contentStaged = false;
            }
        }
    }

    Timer {
        id: stageTimer
        interval: 130
        onTriggered: root.contentStaged = true
    }

    Timer {
        id: focusTimer
        interval: 150
        onTriggered: root.focusInitialControl()
    }

    // Minflair Organic Shape Silhouette - Reactive to Desktop Theme & Morphs Seamlessly
    Shape {
        id: bgShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        z: 1

        ShapePath {
            strokeWidth: 1
            strokeColor: Island.Theme ? Island.Theme.glassBorderSubtle : Qt.rgba(1, 1, 1, 0.08)
            fillColor: Island.Theme ? Island.Theme.surfaceOpaque : "#08090d"

            Behavior on fillColor {
                ColorAnimation { duration: 250 }
            }

            PathSvg {
                path: root.getConvexPath(
                    root.width,
                    root.height,
                    root.leftW,
                    root.centerX,
                    root.centerW,
                    root.rightW,
                    root.flareWidth,
                    root.flareHeight,
                    root.bottomRadius,
                    root.centerHeight,
                    root.baseHeight,
                    root.centerRadius
                )
            }
        }
    }

    // -------------------------------------------------------------------------
    // LEFT SECTION: Sparkle + Workspaces (1..4) + Now Playing Track Capsule!
    // -------------------------------------------------------------------------
    Row {
        id: leftRow
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.top: parent.top
        height: root.baseHeight
        spacing: 10
        z: 2

        // Minflair Sparkle Icon (Launcher / Dashboard Trigger)
        Item {
            width: 28
            height: 28
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: minflairMouse.containsMouse ? (Island.Theme ? Island.Theme.glassCardHover : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
                scale: minflairMouse.pressed ? 0.92 : (minflairMouse.containsMouse ? 1.06 : 1.0)

                Behavior on scale {
                    NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                }
            }

            IslandComp.MinflairSparkle {
                id: minflairIcon
                iconSize: 18
                iconColor: Island.Theme ? Island.Theme.primary : "#ff2a5f"
                anchors.centerIn: parent
            }

            MouseArea {
                id: minflairMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (Island.ShellState) {
                        Island.ShellState.show("launcher", root.screen ? root.screen.name : "");
                    }
                }
            }
        }

        // Minflair Workspaces Capsule: Default 4 workspaces, dynamically expands on overflow
        Rectangle {
            height: 26
            radius: 13
            color: Island.Theme ? Qt.rgba(Island.Theme.bg1.r, Island.Theme.bg1.g, Island.Theme.bg1.b, 0.72) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Island.Theme ? Island.Theme.glassBorderSubtle : Qt.rgba(1, 1, 1, 0.07)
            width: wsIndicator.implicitWidth + 16
            anchors.verticalCenter: parent.verticalCenter

            readonly property int activeWsId: (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace.id : 1

            readonly property int maxOccupiedWsId: {
                let maxId = 4;
                if (typeof Hyprland !== "undefined") {
                    if (Hyprland.workspaces && Hyprland.workspaces.values) {
                        const list = Hyprland.workspaces.values;
                        for (let i = 0; i < list.length; i++) {
                            const ws = list[i];
                            if (!ws || ws.id <= 0) continue;
                            let hasWins = false;
                            if (ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0)
                                hasWins = true;
                            if (!hasWins && Hyprland.toplevels && Hyprland.toplevels.values) {
                                hasWins = Hyprland.toplevels.values.some((top) => top && top.workspace && top.workspace.id === ws.id);
                            }
                            if (hasWins && ws.id > maxId)
                                maxId = ws.id;
                        }
                    }
                    if (Hyprland.toplevels && Hyprland.toplevels.values) {
                        for (let j = 0; j < Hyprland.toplevels.values.length; j++) {
                            const top = Hyprland.toplevels.values[j];
                            if (top && top.workspace && top.workspace.id > maxId)
                                maxId = top.workspace.id;
                        }
                    }
                }
                return Math.max(4, maxId, activeWsId);
            }

            Row {
                id: wsIndicator
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: parent.parent.maxOccupiedWsId

                    Rectangle {
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property bool isActive: wsId === parent.parent.activeWsId

                        width: isActive ? 22 : 6
                        height: 6
                        radius: 3
                        color: isActive
                            ? (Island.Theme ? Island.Theme.primary : "#ff2a5f")
                            : (Island.Theme ? Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.3) : Qt.rgba(1, 1, 1, 0.35))

                        Behavior on width {
                            NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 180 }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof Hyprland !== "undefined" && Hyprland.dispatch)
                                    Hyprland.dispatch("hl.dsp.focus({ workspace = " + parent.wsId + " })");
                            }
                        }
                    }
                }
            }

            // Mouse wheel to switch workspaces
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (wheel) => {
                    if (typeof Hyprland !== "undefined" && Hyprland.dispatch) {
                        Hyprland.dispatch("hl.dsp.focus({ workspace = '" + (wheel.angleDelta.y < 0 ? "e+1" : "e-1") + "' })");
                    }
                }
            }
        }

        // Now Playing Music Capsule (In Left Section!)
        Rectangle {
            id: leftMusicCapsule
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            radius: 13
            color: Island.Theme ? Qt.rgba(Island.Theme.bg1.r, Island.Theme.bg1.g, Island.Theme.bg1.b, 0.72) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Island.Theme ? Island.Theme.glassBorderSubtle : Qt.rgba(1, 1, 1, 0.07)
            visible: root.isPlaying && root.trackTitle !== ""
            width: visible ? (leftMusicRow.implicitWidth + 16) : 0
            clip: true

            Behavior on width {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Row {
                id: leftMusicRow
                anchors.centerIn: parent
                spacing: 6

                // Mini Cava Visualizer Bars
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Repeater {
                        model: 4

                        Rectangle {
                            required property int index
                            width: 2.5
                            radius: 1.25
                            color: Island.Theme ? Island.Theme.primary : "#ff2a5f"

                            readonly property var levels: Island.IslandHub ? Island.IslandHub.levels : [0, 0, 0, 0]
                            height: Math.max(3, Math.min(12, Math.round(2 + ((levels && levels[index]) || 0.25) * 10)))

                            Behavior on height {
                                NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }

                // Track Title & Artist Text
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (!root.isPlaying) return "";
                        let s = root.trackArtist !== "" ? (root.trackArtist + " - " + root.trackTitle) : root.trackTitle;
                        return s.length > 28 ? (s.slice(0, 26) + "…") : s;
                    }
                    font.family: Island.Theme ? Island.Theme.fontFamily : "Geist"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Island.Theme ? Island.Theme.foreground : "#ffffff"
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        if (Island.ShellState) Island.ShellState.show("media", root.screen ? root.screen.name : "");
                        return;
                    }
                    if (mouse.button === Qt.RightButton) {
                        if (Island.IslandHub) Island.IslandHub.mediaNext();
                        return;
                    }
                    if (mouse.button === Qt.MiddleButton) {
                        if (Island.IslandHub) Island.IslandHub.mediaPlayPause();
                        return;
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // CENTER SECTION: Always Wide (Date + Time + Weather), Command Center Trigger, Hosts Panels
    // -------------------------------------------------------------------------
    Item {
        id: centerWrap
        x: root.centerX
        anchors.top: parent.top
        width: root.centerW
        height: root.centerHeight
        z: 3

        // A) Idle Content: Date + Time + Weather/Status (Wide & Balanced)
        Row {
            id: centerIdleRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            height: root.baseHeight
            spacing: 8
            visible: opacity > 0.001
            opacity: root.isExpanded ? 0.0 : 1.0

            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }

            // Date: "Sun, 15 Nov"
            Text {
                id: dateLabel
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(new Date(), "ddd, d MMM")
                font.family: Island.Theme ? Island.Theme.fontFamily : "Geist"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Island.Theme ? Island.Theme.muted : Qt.rgba(1, 1, 1, 0.7)
            }

            // Separator dot
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "•"
                font.pixelSize: 10
                color: Island.Theme ? Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.25) : Qt.rgba(1, 1, 1, 0.25)
            }

            // Digital Clock: "5:47 PM"
            Text {
                id: clockLabel
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    let d = new Date();
                    let h = d.getHours();
                    let m = String(d.getMinutes()).padStart(2, '0');
                    let ap = h >= 12 ? "PM" : "AM";
                    let h12 = h % 12 || 12;
                    return h12 + ":" + m + " " + ap;
                }
                font.family: Island.Theme ? Island.Theme.fontFamily : "Geist"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: Island.Theme ? Island.Theme.foreground : "#ffffff"

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: {
                        clockLabel.text = Qt.binding(() => {
                            let d = new Date();
                            let h = d.getHours();
                            let m = String(d.getMinutes()).padStart(2, '0');
                            let ap = h >= 12 ? "PM" : "AM";
                            let h12 = h % 12 || 12;
                            return h12 + ":" + m + " " + ap;
                        });
                        dateLabel.text = Qt.formatDateTime(new Date(), "ddd, d MMM");
                    }
                }
            }

            // Separator dot
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "•"
                font.pixelSize: 10
                color: Island.Theme ? Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.25) : Qt.rgba(1, 1, 1, 0.25)
            }

            // Live Weather / Mini Status Pill
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                IslandComp.MinflairSvgIcon {
                    icon: "sun"
                    iconSize: 12
                    iconColor: Island.Theme ? Island.Theme.yellow : "#f59e0b"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (Island.WeatherState && Island.WeatherState.tempC && Island.WeatherState.tempC !== "")
                        ? (Island.WeatherState.tempC + "°C")
                        : "24°C"
                    font.family: Island.Theme ? Island.Theme.fontFamily : "Geist"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Island.Theme ? Island.Theme.muted : Qt.rgba(1, 1, 1, 0.75)
                }
            }

            // Live Countdown Timer Pill
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 20
                radius: 10
                color: Island.Theme ? Qt.rgba(Island.Theme.orange.r, Island.Theme.orange.g, Island.Theme.orange.b, 0.18) : Qt.rgba(255, 149, 0, 0.18)
                border.width: 1
                border.color: Island.Theme ? Qt.rgba(Island.Theme.orange.r, Island.Theme.orange.g, Island.Theme.orange.b, 0.45) : Qt.rgba(255, 149, 0, 0.45)
                visible: Island.TimerState && Island.TimerState.hasActive
                width: timerRow.implicitWidth + 12

                Row {
                    id: timerRow
                    anchors.centerIn: parent
                    spacing: 5

                    IslandComp.MinflairSvgIcon {
                        icon: "alarm"
                        iconSize: 12
                        iconColor: Island.Theme ? Island.Theme.orange : "#ff9500"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Island.TimerState ? Island.TimerState.activeRemainingText : ""
                        font.family: Island.Theme ? Island.Theme.fontFamily : "Geist"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Island.Theme ? Island.Theme.orange : "#ff9500"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Island.ShellState)
                            Island.ShellState.show("timer", root.screen ? root.screen.name : "");
                    }
                }
            }

            // Live AI Generation Pill
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 20
                radius: 10
                color: Island.Theme ? Qt.rgba(Island.Theme.blue.r, Island.Theme.blue.g, Island.Theme.blue.b, 0.22) : Qt.rgba(99, 102, 241, 0.22)
                border.width: 1
                border.color: Island.Theme ? Qt.rgba(Island.Theme.blue.r, Island.Theme.blue.g, Island.Theme.blue.b, 0.5) : Qt.rgba(99, 102, 241, 0.5)
                visible: Island.IslandHub && Island.IslandHub.aiGenerating
                width: aiGenRow.implicitWidth + 12

                Row {
                    id: aiGenRow
                    anchors.centerIn: parent
                    spacing: 5

                    IslandComp.MinflairSvgIcon {
                        icon: "sparkles"
                        iconSize: 12
                        iconColor: Island.Theme ? Island.Theme.blue : "#818cf8"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Generating…"
                        font.family: Island.Theme ? Island.Theme.fontFamily : "Geist"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Island.Theme ? Island.Theme.blue : "#818cf8"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Island.ShellState)
                            Island.ShellState.show("ai", root.screen ? root.screen.name : "");
                    }
                }
            }
        }

        // Direct MouseArea on center: Left click opens COMMAND CENTER!
        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.baseHeight
            enabled: !root.isExpanded
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            hoverEnabled: true

            property int _wheelDeltaAccum: 0

            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    if (Island.ShellState) {
                        Island.ShellState.show("control", root.screen ? root.screen.name : "");
                    }
                    return;
                }
                if (mouse.button === Qt.RightButton) {
                    if (mouse.x < width / 2) {
                        if (Island.IslandHub) Island.IslandHub.mediaPrevious();
                    } else {
                        if (Island.IslandHub) Island.IslandHub.mediaNext();
                    }
                    return;
                }
                if (mouse.button === Qt.MiddleButton) {
                    if (Island.IslandHub) Island.IslandHub.mediaPlayPause();
                    return;
                }
            }

            onWheel: (wheel) => {
                let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                if (delta === 0) return;
                _wheelDeltaAccum += delta;
                const stepThreshold = 40;
                if (Math.abs(_wheelDeltaAccum) >= stepThreshold) {
                    let steps = Math.trunc(_wheelDeltaAccum / stepThreshold);
                    _wheelDeltaAccum = _wheelDeltaAccum % stepThreshold;
                    if (Island.IslandHub) Island.IslandHub.adjustVolume(steps * 2);
                }
                wheel.accepted = true;
            }
        }

        // Shelf Drag-and-Drop Area
        DropArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.baseHeight
            enabled: !root.isExpanded
            onDropped: (drop) => {
                if (drop.hasUrls && Island.ShelfState) {
                    for (let i = 0; i < drop.urls.length; ++i) {
                        Island.ShelfState.addFile(drop.urls[i]);
                    }
                }
            }
        }

        // B) Expanded Panel Host: Floating gracefully with luxurious 48px side and 28px vertical padding!
        FocusScope {
            id: panelHost
            anchors.fill: parent
            anchors.leftMargin: 48
            anchors.rightMargin: 48
            anchors.topMargin: 24
            anchors.bottomMargin: 28
            clip: true
            visible: root.isExpanded
            opacity: root.contentStaged ? 1.0 : 0.0
            focus: root.isExpanded

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
            }

            transform: Translate {
                y: root.contentStaged ? 0 : 12
                Behavior on y {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.22
                    }
                }
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    if (Island.ShellState) Island.ShellState.close();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                    root.moveFocus(true);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                    root.moveFocus(false);
                    event.accepted = true;
                    return;
                }
            }

            ControlPanel {
                id: controlPanel
                width: parent.width
                height: parent.height
                visible: root.displayedPanel === "control"
            }

            LauncherPanel {
                id: launcherPanel
                width: parent.width
                visible: root.displayedPanel === "launcher"
            }

            ClipboardPanel {
                id: clipboardPanel
                width: parent.width
                visible: root.displayedPanel === "clipboard"
            }

            TodoPanel {
                id: todoPanel
                width: parent.width
                visible: root.displayedPanel === "todo"
            }

            QuickNotesPanel {
                id: quickNotesPanel
                width: parent.width
                height: parent.height
                visible: root.displayedPanel === "notes"
            }

            ThemePanel {
                id: themePanel
                width: parent.width
                height: parent.height
                visible: root.displayedPanel === "theme"
            }

            WallpaperPanel {
                id: wallpaperPanel
                width: parent.width
                height: parent.height
                visible: root.displayedPanel === "wallpaper"
            }

            CapturePanel {
                id: capturePanel
                width: parent.width
                visible: root.displayedPanel === "capture"
            }

            PowerPanel {
                id: powerPanel
                width: parent.width
                visible: root.displayedPanel === "power"
            }



            NotifCenterPanel {
                id: notifCenterPanel
                width: parent.width
                visible: root.displayedPanel === "notifications"
            }

            TimerPanel {
                id: timerPanel
                width: parent.width
                visible: root.displayedPanel === "timer"
            }

            ShelfPanel {
                id: shelfPanel
                width: parent.width
                visible: root.displayedPanel === "shelf"
            }

            WeatherPanel {
                id: weatherPanel
                width: parent.width
                visible: root.displayedPanel === "weather"
            }

            GameModePanel {
                id: gameModePanel
                width: parent.width
                height: parent.height
                visible: root.displayedPanel === "gamemode"
            }

            AiPromptPanel {
                id: aiPromptPanel
                width: parent.width
                visible: root.displayedPanel === "ai"
            }

            PhonePanel {
                id: phonePanel
                width: parent.width
                visible: root.displayedPanel === "phone"
            }

            CaptionActionPanel {
                id: captionPanel
                width: parent.width
                visible: root.displayedPanel === "caption"
            }
        }
    }

    // -------------------------------------------------------------------------
    // RIGHT SECTION: Status Capsule + System Tray + Battery + Power
    // -------------------------------------------------------------------------
    Row {
        id: rightRow
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.top: parent.top
        height: root.baseHeight
        spacing: 10
        z: 2

        // Recording Indicator
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 22
            radius: 11
            color: Island.Theme ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.18) : Qt.rgba(255, 42, 95, 0.18)
            border.width: 1
            border.color: Island.Theme ? Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.5) : Qt.rgba(255, 42, 95, 0.5)
            visible: Island.IslandHub && Island.IslandHub.recordingActive
            width: recRow.implicitWidth + 12

            Row {
                id: recRow
                anchors.centerIn: parent
                spacing: 5

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: Island.Theme ? Island.Theme.red : "#ff2a5f"
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: Island.IslandHub && Island.IslandHub.recordingActive
                        NumberAnimation { to: 0.3; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "REC"
                    font.family: Island.Theme ? Island.Theme.fontFamily : "Geist"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Island.Theme ? Island.Theme.red : "#ff2a5f"
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (Island.IslandHub)
                        Island.IslandHub.toggleRecording();
                }
            }
        }

        // Minflair Status Capsule (Unified Tool Suite)
        Rectangle {
            id: statusCapsule
            anchors.verticalCenter: parent.verticalCenter
            height: 28
            radius: 14
            color: Island.Theme ? Qt.rgba(Island.Theme.bg1.r, Island.Theme.bg1.g, Island.Theme.bg1.b, 0.72) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Island.Theme ? Island.Theme.glassBorderSubtle : Qt.rgba(1, 1, 1, 0.07)
            width: capsuleRow.implicitWidth + 12

            Row {
                id: capsuleRow
                anchors.centerIn: parent
                spacing: 2

                // Command Center Grid Button
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: ccMouse.containsMouse ? (Island.Theme ? Island.Theme.glassCardHover : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    IslandComp.MinflairSvgIcon {
                        icon: "tune"
                        iconSize: 14
                        iconColor: Island.ShellState && Island.ShellState.panel === "control"
                            ? (Island.Theme ? Island.Theme.primary : "#ff2a5f")
                            : (Island.Theme ? Island.Theme.foreground : "#ffffff")
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: ccMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Island.ShellState.show("control", root.screen ? root.screen.name : "")
                    }
                }

                // Notifications Bell with Unread Badge
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: notifMouse.containsMouse ? (Island.Theme ? Island.Theme.glassCardHover : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    IslandComp.MinflairSvgIcon {
                        icon: (Island.IslandHub && Island.IslandHub.unreadCount > 0) ? "bell-dot" : "bell"
                        iconSize: 14
                        iconColor: (Island.IslandHub && Island.IslandHub.unreadCount > 0)
                            ? (Island.Theme ? Island.Theme.red : "#ff2a5f")
                            : (Island.ShellState && Island.ShellState.panel === "notifications" ? (Island.Theme ? Island.Theme.primary : "#ff2a5f") : (Island.Theme ? Island.Theme.foreground : "#ffffff"))
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: notifMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Island.ShellState.show("notifications", root.screen ? root.screen.name : "")
                    }
                }

                // Wallpaper Switcher Button
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: wpMouse.containsMouse ? (Island.Theme ? Island.Theme.glassCardHover : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    IslandComp.MinflairSvgIcon {
                        icon: "picture"
                        iconSize: 14
                        iconColor: Island.ShellState && Island.ShellState.panel === "wallpaper"
                            ? (Island.Theme ? Island.Theme.primary : "#ff2a5f")
                            : (Island.Theme ? Island.Theme.foreground : "#ffffff")
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: wpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Island.ShellState.show("wallpaper", root.screen ? root.screen.name : "")
                    }
                }

                // AI Studio Button
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: aiMouse.containsMouse ? (Island.Theme ? Island.Theme.glassCardHover : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    IslandComp.MinflairSvgIcon {
                        icon: "sparkles"
                        iconSize: 14
                        iconColor: Island.ShellState && Island.ShellState.panel === "ai"
                            ? (Island.Theme ? Island.Theme.primary : "#ff2a5f")
                            : (Island.Theme ? Island.Theme.foreground : "#ffffff")
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: aiMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Island.ShellState.show("ai", root.screen ? root.screen.name : "")
                    }
                }

                // Screen Capture Button
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: capMouse.containsMouse ? (Island.Theme ? Island.Theme.glassCardHover : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    IslandComp.MinflairSvgIcon {
                        icon: "capture"
                        iconSize: 14
                        iconColor: Island.ShellState && Island.ShellState.panel === "capture"
                            ? (Island.Theme ? Island.Theme.primary : "#ff2a5f")
                            : (Island.Theme ? Island.Theme.foreground : "#ffffff")
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: capMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Island.ShellState.show("capture", root.screen ? root.screen.name : "")
                    }
                }

                // Clipboard History Button
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: clipMouse.containsMouse ? (Island.Theme ? Island.Theme.glassCardHover : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    IslandComp.MinflairSvgIcon {
                        icon: "clipboard"
                        iconSize: 14
                        iconColor: Island.ShellState && Island.ShellState.panel === "clipboard"
                            ? (Island.Theme ? Island.Theme.primary : "#ff2a5f")
                            : (Island.Theme ? Island.Theme.foreground : "#ffffff")
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: clipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Island.ShellState.show("clipboard", root.screen ? root.screen.name : "")
                    }
                }
            }
        }

        // Dynamic System Tray Items
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: SystemTray.items

                Item {
                    id: trayWrapper
                    required property var modelData

                    width: 16
                    height: 16
                    visible: modelData && modelData.id !== ""

                    Image {
                        anchors.fill: parent
                        source: trayWrapper.modelData ? (trayWrapper.modelData.icon || "") : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton && trayWrapper.modelData.hasMenu) {
                                trayWrapper.modelData.openMenu(mouse.x, mouse.y);
                            } else if (trayWrapper.modelData.activate) {
                                trayWrapper.modelData.activate(mouse.x, mouse.y);
                            }
                        }
                    }
                }
            }
        }

        // Battery Indicator with percentage readout + Apple sleek battery icon
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.batteryPercent + "%"
                font.family: Island.Theme ? Island.Theme.fontFamily : "Geist"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Island.Theme ? Island.Theme.foreground : "#ffffff"
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 12

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 10
                    radius: 2.5
                    color: "transparent"
                    border.width: 1
                    border.color: Island.Theme ? Island.Theme.glassBorder : Qt.rgba(1, 1, 1, 0.45)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 1.5
                        width: Math.max(0, Math.min(15, 15 * (root.batteryPercent / 100)))
                        radius: 1.5
                        color: root.batteryPercent <= 20
                            ? (Island.Theme ? Island.Theme.red : "#ff2a5f")
                            : (root.isCharging ? (Island.Theme ? Island.Theme.green : "#34c759") : (Island.Theme ? Island.Theme.foreground : "#ffffff"))
                    }
                }

                // Positive terminal nub
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: 4
                    radius: 1
                    color: Island.Theme ? Island.Theme.glassBorder : Qt.rgba(1, 1, 1, 0.45)
                }
            }
        }

        // Power Menu Trigger Button
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 13
            color: pwrMouse.containsMouse ? (Island.Theme ? Island.Theme.glassCardHover : Qt.rgba(1, 1, 1, 0.08)) : "transparent"

            IslandComp.MinflairSvgIcon {
                icon: "power"
                iconSize: 15
                iconColor: Island.ShellState && Island.ShellState.panel === "power"
                    ? (Island.Theme ? Island.Theme.red : "#ff2a5f")
                    : (Island.Theme ? Island.Theme.foreground : "#ffffff")
                anchors.centerIn: parent
            }

            MouseArea {
                id: pwrMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Island.ShellState.show("power", root.screen ? root.screen.name : "")
            }
        }
    }
}
