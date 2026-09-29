import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Wayland
import "components"
import "panels"

PanelWindow {
    id: window

    readonly property int contentPadding: 14
    readonly property int collapsedHeight: 24
    readonly property int cornerWing: 12
    readonly property int topGap: 10
    readonly property int canvasWidth: 552
    readonly property int canvasHeight: 600
    readonly property int requestedTopPadding: ShellState.panel === "launcher" ? 10 : contentPadding
    readonly property int requestedBottomPadding: ShellState.panel === "launcher" ? 4 : contentPadding
    readonly property int displayedTopPadding: displayedPanel === "launcher" ? 10 : contentPadding
    readonly property int displayedBottomPadding: displayedPanel === "launcher" ? 4 : contentPadding
    readonly property real targetVisualWidth: ShellState.targetWidth + cornerWing * 2
    readonly property real targetVisualHeight: ShellState.expanded ? panelContentHeight + requestedTopPadding + requestedBottomPadding : collapsedHeight
    readonly property real panelContentHeight: ShellState.expanded ? Math.max(ShellState.panelHeights[ShellState.panel] || 0, requestedPanel ? requestedPanel.implicitHeight : 0) : 0
    property bool clockRevealed: true
    property bool recBlinkOn: false
    // Staged reveal: panel content fades/slides in 150ms after the pill
    // has stretched, so the island grows around the content.
    property bool contentStaged: false
    property int lastUnread: 0
    property string displayedPanel: "control"
    // Prefer the currently playing player, fallback to first available
    readonly property var islandPlayer: (() => {
        const players = Mpris.players.values;
        for (let i = 0; i < players.length; ++i) {
            if (players[i] && players[i].isPlaying)
                return players[i];
        }
        return players.length > 0 ? players[0] : null;
    })()
    readonly property real mediaFraction: islandPlayer && islandPlayer.length > 0 ? Math.min(1, islandPlayer.position / islandPlayer.length) : 0
    readonly property bool mediaActive: islandPlayer !== null && islandPlayer.length > 0
    readonly property Item activePanel: {
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
            "media": mediaPanel,
            "notifications": notifCenterPanel,
            "timer": timerPanel,
            "shelf": shelfPanel,
            "weather": weatherPanel
        };
        return panels[displayedPanel] || null;
    }
    readonly property Item requestedPanel: {
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
            "media": mediaPanel,
            "notifications": notifCenterPanel,
            "timer": timerPanel,
            "shelf": shelfPanel,
            "weather": weatherPanel
        };
        return panels[ShellState.panel] || null;
    }

    function focusInitialControl() {
        if (!ShellState.expanded || !activePanel)
            return ;

        if (typeof activePanel.takeInitialFocus === "function") {
            activePanel.takeInitialFocus();
            return ;
        }
        activePanel.forceActiveFocus(Qt.TabFocusReason);
        const firstControl = activePanel.nextItemInFocusChain(true);
        if (firstControl && firstControl !== activePanel)
            firstControl.forceActiveFocus(Qt.TabFocusReason);

    }

    function moveFocus(forward) {
        const current = window.activeFocusItem;
        if (!current) {
            focusInitialControl();
            return ;
        }
        const target = current.nextItemInFocusChain(forward);
        if (target)
            target.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);

    }

    margins.left: Math.round((screen.width - canvasWidth) / 2)
    implicitWidth: canvasWidth
    implicitHeight: canvasHeight
    color: "transparent"
    aboveWindows: true
    focusable: ShellState.expanded
    exclusionMode: ExclusionMode.Ignore
    // Overlay layer so the island renders above fullscreen windows (e.g. games)
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
        left: true
    }

    // Switch dimmer: panel cross-fade on switch/restore (multiplies stage).
    property real switchDim: 1

    Connections {
        function onPanelChanged() {
            if (ShellState.expanded) {
                clockRevealTimer.stop();
                stageTimer.restart();
                window.clockRevealed = false;
                if (window.contentStaged && window.displayedPanel !== ShellState.panel) {
                    // Switch while open: dip out, swap, fade back in.
                    panelSwitch.restart();
                } else {
                    window.displayedPanel = ShellState.panel;
                }
                if (ShellState.panel === "notifications")
                    IslandHub.markSeen();
                focusTimer.restart();
                snapPop.restart();
            } else {
                stageTimer.stop();
                window.contentStaged = false;
                clockRevealTimer.restart();
                snapPop.restart();
            }
        }

        target: ShellState
    }

    Connections {
        function onUnreadCountChanged() {
            if (window.screen === Quickshell.screens[0] && IslandHub.unreadCount > window.lastUnread)
                arrivalPop.restart();
            window.lastUnread = IslandHub.unreadCount;
        }

        target: IslandHub
    }

    FocusScope {
        id: notchSurface

        transformOrigin: Item.TopCenter
        anchors.top: parent.top
        anchors.topMargin: window.topGap
        anchors.horizontalCenter: parent.horizontalCenter
        width: window.targetVisualWidth
        height: window.targetVisualHeight
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                ShellState.close();
                event.accepted = true;
                return ;
            }
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                window.moveFocus(true);
                event.accepted = true;
                return ;
            }
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                window.moveFocus(false);
                event.accepted = true;
                return ;
            }
        }

        Rectangle {
            id: notchBody

            x: window.cornerWing
            y: 0
            width: parent.width - window.cornerWing * 2
            height: parent.height
            radius: Math.min(Theme.radius, height / 2)
            color: Theme.shellBackground

            // Timer countdown: thin progress line along the pill bottom.
            Rectangle {
                id: timerLine

                height: 2
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                anchors.leftMargin: 10
                width: Math.max(0, (parent.width - 20) * TimerState.progressFraction)
                visible: TimerState.progressFraction >= 0
                color: Theme.primary

                Behavior on width {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }

                SequentialAnimation {
                    id: urgentPulse
                    loops: Animation.Infinite
                    running: TimerState.urgentRemaining >= 0

                    NumberAnimation {
                        target: timerLine
                        property: "opacity"
                        to: 0.35
                        duration: 500
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: timerLine
                        property: "opacity"
                        to: 1
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Item {
            id: volumeFillClip

            // Inset by the border width so the fill stays strictly inside
            // the pill edge at every level (never touches the outline).
            x: notchBody.x + 2
            y: notchBody.y + 2
            width: notchBody.width - 4
            height: notchBody.height - 4
            clip: true
            visible: opacity > 0
            opacity: IslandHub.volumeActive ? 1 : 0

            Rectangle {
                id: volumeFill

                // Horizontal fill, left to right: width = volume %.
                width: parent.width * (IslandHub.volumeActive ? Math.max(0, Math.min(100, IslandHub.volumePercent)) : 0) / 100
                height: parent.height
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                radius: Math.max(0, notchBody.radius - 2)
                color: Theme.primary

                Behavior on width {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Screenshot scan sweep: white bar sweeps left->right across the pill.
        Item {
            id: shotSweepClip

            x: notchBody.x + 2
            y: notchBody.y + 2
            width: notchBody.width - 4
            height: notchBody.height - 4
            clip: true
            visible: false

            Rectangle {
                id: shotSweep
                width: 26
                height: parent.height
                x: -width
                color: "white"
                opacity: 0.85
            }

            SequentialAnimation {
                id: sweepAnim

                PropertyAction {
                    target: shotSweepClip
                    property: "visible"
                    value: true
                }

                NumberAnimation {
                    target: shotSweep
                    property: "x"
                    from: -26
                    to: shotSweepClip.width
                    duration: 450
                    easing.type: Easing.OutCubic
                }

                PropertyAction {
                    target: shotSweepClip
                    property: "visible"
                    value: false
                }
            }
        }

        // Micro particle burst: 4 sparse dots for major events only.
        // Driven by one progress property; delegates bind positions to it.
        Item {
            id: burstLayer

            property real burstT: 0
            anchors.fill: notchBody
            visible: burstAnim.running

            Repeater {
                model: [{ dx: -13, dy: 12 }, { dx: 13, dy: 12 }, { dx: -6, dy: 16 }, { dx: 6, dy: 16 }]

                Rectangle {
                    required property var modelData
                    width: 3
                    height: 3
                    radius: 1.5
                    color: Theme.primary
                    x: burstLayer.width / 2 - 1 + modelData.dx * burstLayer.burstT
                    y: burstLayer.height - 4 + modelData.dy * burstLayer.burstT
                    opacity: 1 - burstLayer.burstT
                }
            }

            NumberAnimation {
                id: burstAnim
                target: burstLayer
                property: "burstT"
                from: 0
                to: 1
                duration: 350
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: borderGlow

            x: notchBody.x
            y: notchBody.y
            width: notchBody.width
            height: notchBody.height
            radius: notchBody.radius
            color: "transparent"
            border.width: 2
            border.color: IslandHub.flashActive ? IslandHub.flashColor : (IslandHub.recordingActive ? Theme.red : Theme.foreground)
            opacity: IslandHub.flashActive ? 1 : (IslandHub.recordingActive ? (recBlinkOn ? 1 : 0) : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }

        Item {
            id: mediaRingClip

            x: notchBody.x
            y: notchBody.y
            width: notchBody.width * window.mediaFraction
            height: notchBody.height
            clip: true
            visible: window.mediaActive && !IslandHub.volumeActive

            Behavior on width {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }

            SequentialAnimation {
                id: ringDip

                NumberAnimation {
                    target: mediaRingClip
                    property: "opacity"
                    to: 0
                    duration: 150
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: mediaRingClip
                    property: "opacity"
                    to: 1
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            // Track-end ring morph: when a track finishes (isPlaying drops
            // near 100%), dip the ring; it restarts for the next track.
            Connections {
                target: window.islandPlayer
                function onIsPlayingChanged() {
                    if (window.islandPlayer && !window.islandPlayer.isPlaying && window.mediaFraction > 0.95)
                        ringDip.restart();
                }
            }

            Rectangle {
                width: notchBody.width
                height: notchBody.height
                radius: notchBody.radius
                color: "transparent"
                border.width: 3
                border.color: Theme.primary
            }
        }

        Shape {
            x: 0
            width: window.cornerWing
            height: window.cornerWing
            visible: false
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: leftShoulderPath

                readonly property real size: window.cornerWing

                strokeWidth: Math.max(borderGlow.opacity * 2, window.mediaActive ? 2 : 0)
                strokeColor: borderGlow.opacity > 0.01 ? Theme.foreground : Theme.primary
                fillColor: Theme.shellBackground
                startX: 0
                startY: 0

                PathLine {
                    x: leftShoulderPath.size + 2
                    y: 0
                }

                PathLine {
                    x: leftShoulderPath.size + 2
                    y: leftShoulderPath.size
                }

                PathCubic {
                    control1X: leftShoulderPath.size + 2
                    control1Y: leftShoulderPath.size * 0.448
                    control2X: leftShoulderPath.size * 0.552
                    control2Y: 0
                    x: 0
                    y: 0
                }

            }

        }

        Shape {
            x: parent.width - width
            width: window.cornerWing
            height: window.cornerWing
            visible: false
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: rightShoulderPath

                readonly property real size: window.cornerWing

                strokeWidth: Math.max(borderGlow.opacity * 2, window.mediaActive ? 2 : 0)
                strokeColor: borderGlow.opacity > 0.01 ? Theme.foreground : Theme.primary
                fillColor: Theme.shellBackground
                startX: rightShoulderPath.size
                startY: 0

                PathLine {
                    x: -2
                    y: 0
                }

                PathLine {
                    x: -2
                    y: rightShoulderPath.size
                }

                PathCubic {
                    control1X: -2
                    control1Y: rightShoulderPath.size * 0.448
                    control2X: rightShoulderPath.size * 0.448
                    control2Y: 0
                    x: rightShoulderPath.size
                    y: 0
                }

            }

        }

        CollapsedStatus {
            anchors.left: notchBody.left
            anchors.right: notchBody.right
            anchors.top: parent.top
            height: window.collapsedHeight
            visible: opacity > 0
            opacity: window.clockRevealed ? 1 : 0
            unread: IslandHub.unreadCount
            label: IslandHub.primaryLabel(window.islandPlayer ? (window.islandPlayer.trackTitle || "") : "", window.islandPlayer ? (window.islandPlayer.trackArtist || "") : "")
            mediaPlaying: window.islandPlayer ? window.islandPlayer.isPlaying : false
            micActive: PrivacyState.micActive
            camActive: PrivacyState.camActive
            recActive: IslandHub.recordingActive
            shelfCount: ShelfState.files.length
            weatherMini: WeatherState.collapsedVisible ? WeatherState.tempC : ""
            volumeActive: IslandHub.volumeActive
            volumeText: IslandHub.volumeText
            volumeMuted: IslandHub.volumeMuted
            btConnected: BtState.connectedNames.length > 0 ? BtState.connectedNames[0] : ""

            Behavior on opacity {
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !ShellState.expanded
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            // NOTE: Ctrl+click media transport lives in Hyprland
            // (CTRL + mouse:272/273 -> playerctl previous/next). Handled at
            // the compositor because layershell delivery of release-time
            // modifiers proved unreliable; no transport here by design.
            onClicked: (mouse) => {
                if (mouse.button !== Qt.LeftButton)
                    return ;
                // Plain click always opens control center (hub for everything).
                ShellState.show("control");
            }
        }

        DropArea {
            id: shelfDropArea
            anchors.fill: notchBody
            enabled: !ShellState.expanded

            onEntered: {
                shelfStretch.restart();
            }

            onExited: {
                shelfRelease.restart();
            }

            onDropped: (drop) => {
                shelfRelease.stop();
                shelfStretch.stop();
                if (drop.hasUrls && window.screen === Quickshell.screens[0]) {
                    const added = ShelfState.addUrls(drop.urls);
                    if (added > 0) {
                        IslandHub.showTransient(ShelfState.lastEvent, 3000);
                        IslandHub.flashBorder(Theme.primary, 600);
                        IslandHub.burst();
                        absorbPop.restart();
                        return ;
                    }
                }
                shelfRelease.restart();
            }
        }

        // Shelf drag stretch: island stretches toward the file being dragged.
        SequentialAnimation {
            id: shelfStretch

            PropertyAnimation {
                target: notchBody
                property: "scale"
                to: 1.08
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        SequentialAnimation {
            id: shelfRelease

            PropertyAnimation {
                target: notchBody
                property: "scale"
                to: 1
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: panelHost

            anchors.left: notchBody.left
            anchors.right: notchBody.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: window.contentPadding
            anchors.rightMargin: window.contentPadding
            anchors.topMargin: window.displayedTopPadding
            anchors.bottomMargin: window.displayedBottomPadding
            visible: opacity > 0
            opacity: (window.contentStaged ? 1 : 0) * window.switchDim
            clip: true

            transform: Translate {
                id: panelSlide
                y: window.contentStaged ? 0 : 8

                Behavior on y {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }

            ControlPanel {
                id: controlPanel

                width: parent.width
                height: parent.height
                visible: window.displayedPanel === "control"
            }

            LauncherPanel {
                id: launcherPanel

                width: parent.width
                visible: window.displayedPanel === "launcher"
            }

            ClipboardPanel {
                id: clipboardPanel

                width: parent.width
                visible: window.displayedPanel === "clipboard"
            }

            TodoPanel {
                id: todoPanel

                width: parent.width
                visible: window.displayedPanel === "todo"
            }

            QuickNotesPanel {
                id: quickNotesPanel

                width: parent.width
                height: parent.height
                visible: window.displayedPanel === "notes"
            }

            ThemePanel {
                id: themePanel

                width: parent.width
                height: parent.height
                visible: window.displayedPanel === "theme"
            }

            WallpaperPanel {
                id: wallpaperPanel

                width: parent.width
                height: parent.height
                visible: window.displayedPanel === "wallpaper"
            }

            CapturePanel {
                id: capturePanel

                width: parent.width
                visible: window.displayedPanel === "capture"
            }

            PowerPanel {
                id: powerPanel

                width: parent.width
                visible: window.displayedPanel === "power"
            }

            MediaPanel {
                id: mediaPanel

                width: parent.width
                visible: window.displayedPanel === "media"
            }

            NotifCenterPanel {
                id: notifCenterPanel

                width: parent.width
                visible: window.displayedPanel === "notifications"
            }

            TimerPanel {
                id: timerPanel

                width: parent.width
                visible: window.displayedPanel === "timer"
            }

            ShelfPanel {
                id: shelfPanel

                width: parent.width
                visible: window.displayedPanel === "shelf"
            }

            WeatherPanel {
                id: weatherPanel

                width: parent.width
                visible: window.displayedPanel === "weather"
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animationFast
                    easing.type: Easing.OutCubic
                }

            }

        }

        // Panel switch cross-fade: dip, swap content, fade back.
        SequentialAnimation {
            id: panelSwitch

            NumberAnimation {
                target: window
                property: "switchDim"
                to: 0
                duration: 120
                easing.type: Easing.OutCubic
            }

            ScriptAction {
                script: window.displayedPanel = ShellState.panel
            }

            NumberAnimation {
                target: window
                property: "switchDim"
                to: 1
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        // Shelf absorb pop: bounce on successful drop, then settle.
        // absorbPop chains into shelfRelease on finish (no concurrent
        // scale drivers).
        SequentialAnimation {
            id: absorbPop

            PropertyAnimation {
                target: notchBody
                property: "scale"
                to: 1.12
                duration: 100
                easing.type: Easing.OutCubic
            }

            PropertyAnimation {
                target: notchBody
                property: "scale"
                to: 1
                duration: 140
                easing.type: Easing.OutCubic
            }

            onFinished: shelfRelease.stop()
        }

        // Snap: 100% -> 80% -> 100% micro-overshoot on EVERY island
        // open/collapse/switch (visual only, geometry untouched).
        // Top-center origin keeps the top edge fixed (screen-edge gap constant).
        SequentialAnimation {
            id: snapPop

            PropertyAnimation {
                target: notchSurface
                property: "scale"
                to: 0.8
                duration: 150
                easing.type: Easing.OutCubic
            }

            PropertyAnimation {
                target: notchSurface
                property: "scale"
                to: 1
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        // Arrival pop: brief acknowledge on new notifications.
        SequentialAnimation {
            id: arrivalPop

            PropertyAnimation {
                target: notchSurface
                property: "scale"
                to: 1.04
                duration: 140
                easing.type: Easing.OutCubic
            }

            PropertyAnimation {
                target: notchSurface
                property: "scale"
                to: 1
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.animationNormal
                easing.type: Easing.OutCubic
            }

        }

        Behavior on height {
            enabled: !clipboardPanel.previewTransitionActive

            NumberAnimation {
                duration: Theme.animationNormal
                easing.type: Easing.OutCubic
            }

        }

    }

    Timer {
        id: stageTimer

        interval: 150
        onTriggered: {
            if (ShellState.expanded)
                window.contentStaged = true;
        }
    }

    Timer {
        interval: 500
        running: IslandHub.recordingActive
        repeat: true
        onTriggered: window.recBlinkOn = !window.recBlinkOn
    }

    Connections {
        target: BtState
        function onEventTickChanged() {
            IslandHub.showTransient(BtState.lastEvent, 3000);
            IslandHub.flashBorder(Theme.blue, 800);
            IslandHub.burst();
        }
    }

    Connections {
        target: TimerState
        function onDoneTickChanged() {
            snapPop.restart();
        }
    }

    Connections {
        target: PowerState
        function onPlugEventTickChanged() {
            IslandHub.showTransient(PowerState.lastPlugEvent, 3000);
            IslandHub.flashBorder(PowerState.charging ? Theme.primary : Theme.foreground, 800);
        }
    }

    Connections {
        target: ShelfState
        function onEventTickChanged() {
            IslandHub.showTransient(ShelfState.lastEvent, 3000);
        }
    }

    HyprlandFocusGrab {
        windows: [window]
        active: ShellState.expanded && Backend.captureSelectionMode !== "region"
        onCleared: {
            if (ShellState.expanded && Backend.captureSelectionMode !== "region")
                ShellState.close();

        }
    }

    Timer {
        id: focusTimer

        interval: 35
        onTriggered: window.focusInitialControl()
    }

    Timer {
        id: clockRevealTimer

        interval: 150
        onTriggered: {
            if (!ShellState.expanded)
                window.clockRevealed = true;

        }
    }

    SequentialAnimation {
        id: noticeFlash

        loops: 2

        NumberAnimation {
            target: borderGlow
            property: "opacity"
            from: 0
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: borderGlow
            property: "opacity"
            to: 0
            duration: 380
            easing.type: Easing.InCubic
        }

    }

    Connections {
        target: IslandHub
        function onSweepTickChanged() {
            sweepAnim.restart();
        }
    }

    Connections {
        target: IslandHub
        function onBurstTickChanged() {
            burstAnim.restart();
        }
    }

    Connections {
        target: ShellState
        function onNoticeTickChanged() {
            noticeFlash.restart();
        }
    }

    Timer {
        interval: 1000
        running: window.islandPlayer && window.islandPlayer.isPlaying
        repeat: true
        onTriggered: window.islandPlayer.positionChanged()
    }

    Shortcut {
        sequence: "Escape"
        enabled: ShellState.expanded
        onActivated: ShellState.close()
    }

    mask: Region {
        item: notchBody
        topLeftRadius: notchBody.radius
        topRightRadius: notchBody.radius
        bottomLeftRadius: notchBody.radius
        bottomRightRadius: notchBody.radius
    }

}
