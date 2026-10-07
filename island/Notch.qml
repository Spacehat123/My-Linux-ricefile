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
    readonly property int requestedTopPadding: ShellState.panel === "launcher" ? 10 : (ShellState.panel === "power" ? 8 : contentPadding)
    readonly property int requestedBottomPadding: ShellState.panel === "launcher" ? 4 : (ShellState.panel === "power" ? 8 : contentPadding)
    readonly property int displayedTopPadding: displayedPanel === "launcher" ? 10 : (displayedPanel === "power" ? 8 : contentPadding)
    readonly property int displayedBottomPadding: displayedPanel === "launcher" ? 4 : (displayedPanel === "power" ? 8 : contentPadding)
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
        if (ShellState.activeScreenName !== "")
            return window.screen && window.screen.name === ShellState.activeScreenName;
        if (activeMonitor && window.screen)
            return window.screen.name === activeMonitor.name;
        return window.screen === Quickshell.screens[0];
    }
    readonly property bool isExpanded: ShellState.expanded && isCurrentScreen
    readonly property real targetRadius: isExpanded ? (ShellState.panelRadii[ShellState.panel] || Theme.radius) : (collapsedHeight / 2)
    readonly property real targetVisualWidth: (isExpanded ? ShellState.targetWidth : 145) + cornerWing * 2
    readonly property real targetVisualHeight: isExpanded ? panelContentHeight + requestedTopPadding + requestedBottomPadding : collapsedHeight
    readonly property real panelContentHeight: isExpanded ? Math.max(ShellState.panelHeights[ShellState.panel] || 0, requestedPanel ? requestedPanel.implicitHeight : 0) : 0
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
            "weather": weatherPanel,
            "gamemode": gameModePanel
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
            "weather": weatherPanel,
            "gamemode": gameModePanel
        };
        return panels[ShellState.panel] || null;
    }

    function focusInitialControl() {
        if (!window.isExpanded || !activePanel)
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

    margins.left: screen ? Math.round((screen.width - canvasWidth) / 2) : 0
    implicitWidth: canvasWidth
    implicitHeight: canvasHeight
    color: "transparent"
    aboveWindows: true
    focusable: window.isExpanded
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
            if (window.isExpanded) {
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
                if (window.isCurrentScreen)
                    snapPop.restart();
            }
        }

        target: ShellState
    }

    Connections {
        function onUnreadCountChanged() {
            if (window.isCurrentScreen && IslandHub.unreadCount > window.lastUnread) {
                arrivalPop.restart();
                ripplePop.restart();
            }
            window.lastUnread = IslandHub.unreadCount;
        }

        target: IslandHub
    }

    FocusScope {
        id: notchSurface

        transformOrigin: Item.Top
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
            radius: window.targetRadius
            color: Theme.shellBackground

            Behavior on radius {
                SpringAnimation {
                    spring: 4.0
                    damping: 0.32
                    epsilon: 0.2
                }
            }

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

            // Shelf absorb proxy: lightweight visual stand-in for the dropped
            // file. Purely visual — filesystem semantics live in ShelfState
            // and run before this is ever shown. Flies from the drop point
            // to the pill center while shrinking/fading (see absorbFly).
            Rectangle {
                id: absorbProxy

                property string fileName: ""
                width: Math.min(notchBody.width - 16, proxyLabel.implicitWidth + 30)
                height: 20
                radius: 10
                color: Theme.primary
                visible: false
                z: 10

                ShellText {
                    id: proxyLabel

                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, notchBody.width - 46)
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    text: "⧉ " + absorbProxy.fileName
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: "#000000"
                }
            }
        }

        // Surface washes: the pill itself is the widget. Thin translucent
        // fields bound to REAL state, rendered under fills/transients.
        // Recording breathes red on the existing 500ms blink cadence
        // (no new timer); timer/media washes track real progress.
        Rectangle {
            id: recWash

            x: notchBody.x
            y: notchBody.y
            width: notchBody.width
            height: notchBody.height
            radius: notchBody.radius
            color: Theme.red
            opacity: (IslandHub.recordingActive && !IslandHub.volumeActive) ? (window.recBlinkOn ? 0.22 : 0.1) : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.OutCubic
                }
            }
        }

        Item {
            id: timerFillClip

            x: notchBody.x + 2
            y: notchBody.y + 2
            width: notchBody.width - 4
            height: notchBody.height - 4
            clip: true
            visible: TimerState.progressFraction >= 0 && !IslandHub.volumeActive && !IslandHub.recordingActive

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, TimerState.progressFraction))
                height: parent.height
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                radius: Math.max(0, notchBody.radius - 2)
                color: Theme.primary
                opacity: 0.28

                Behavior on width {
                    NumberAnimation {
                        duration: 260
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

        // Scan sweep: colored bar (sweepColor: white capture, blue BT)
        // sweeps left->right across the full pill surface, soft trail
        // behind the core. Clipped strictly to the pill.
        Item {
            id: shotSweepClip

            x: notchBody.x + 2
            y: notchBody.y + 2
            width: notchBody.width - 4
            height: notchBody.height - 4
            clip: true
            visible: false

            Rectangle {
                id: shotTrail
                width: 52
                height: parent.height
                x: shotSweep.x - width
                color: IslandHub.sweepColor
                opacity: 0.25
            }

            Rectangle {
                id: shotSweep
                width: 30
                height: parent.height
                x: -width
                color: IslandHub.sweepColor
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
                    from: -30
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

        // Notification ripple: accent ring breathes outward through the
        // pill on arrival. Clipped to the surface; nothing escapes it.
        Item {
            id: rippleClip

            x: notchBody.x + 2
            y: notchBody.y + 2
            width: notchBody.width - 4
            height: notchBody.height - 4
            clip: true

            Rectangle {
                id: notifRipple
                anchors.fill: parent
                radius: notchBody.radius
                color: "transparent"
                border.width: 2
                border.color: Theme.primary
                opacity: 0
                transformOrigin: Item.Center

                ParallelAnimation {
                    id: ripplePop

                    NumberAnimation {
                        target: notifRipple
                        property: "scale"
                        from: 0.7
                        to: 1.15
                        duration: 400
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: notifRipple
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
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
            border.color: ShellState.gameMode ? Theme.red : (IslandHub.flashActive ? IslandHub.flashColor : (IslandHub.recordingActive ? Theme.red : Theme.foreground))
            opacity: ShellState.gameMode ? 0.9 : (IslandHub.flashActive ? 1 : (IslandHub.recordingActive ? (recBlinkOn ? 1 : 0) : 0))

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

        // Completion blink: while a timer DONE awaits acknowledgement the
        // island border breathes until the user clicks the island (which
        // clears the hold). Separate overlay — never fights borderGlow.
        Rectangle {
            id: doneBlink

            x: notchBody.x
            y: notchBody.y
            width: notchBody.width
            height: notchBody.height
            radius: notchBody.radius
            color: "transparent"
            border.width: 2
            border.color: Theme.primary
            visible: TimerState.completionHold
            opacity: 1

            SequentialAnimation {
                loops: Animation.Infinite
                running: TimerState.completionHold

                NumberAnimation {
                    target: doneBlink
                    property: "opacity"
                    to: 0.25
                    duration: 500
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: doneBlink
                    property: "opacity"
                    to: 1
                    duration: 500
                    easing.type: Easing.OutCubic
                }
            }
        }

        Canvas {
            id: mediaRing

            x: notchBody.x
            y: notchBody.y
            width: notchBody.width
            height: notchBody.height
            visible: !window.isExpanded && window.mediaActive && !IslandHub.volumeActive
            opacity: 1

            property real animatedFraction: window.mediaFraction
            property color strokeColor: Theme.primary

            Behavior on animatedFraction {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }

            onAnimatedFractionChanged: requestPaint()
            onStrokeColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: {
                if (visible)
                    requestPaint();
            }
            Component.onCompleted: requestPaint()

            SequentialAnimation {
                id: ringDip

                NumberAnimation {
                    target: mediaRing
                    property: "opacity"
                    to: 0
                    duration: 150
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: mediaRing
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
                enabled: target !== null && target !== undefined
                ignoreUnknownSignals: true
                function onIsPlayingChanged() {
                    if (window.islandPlayer && !window.islandPlayer.isPlaying && window.mediaFraction > 0.95)
                        ringDip.restart();
                }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                const fraction = Math.max(0, Math.min(1, animatedFraction));
                if (fraction <= 0.0001 || width <= 0 || height <= 0)
                    return;

                const lw = 2;
                const offset = lw / 2;
                const w = width - lw;
                const h = height - lw;
                const r = Math.min(h / 2, Math.max(0.1, w / 2));
                const x0 = offset;
                const y0 = offset;

                const L1 = Math.max(0, (w / 2) - r);
                const L2 = Math.PI * r;
                const L3 = Math.max(0, w - 2 * r);
                const L4 = Math.PI * r;
                const L5 = Math.max(0, (w / 2) - r);
                const P = L1 + L2 + L3 + L4 + L5;
                if (P <= 0)
                    return;

                let rem = P * fraction;

                ctx.save();
                ctx.lineWidth = lw;
                ctx.strokeStyle = "" + strokeColor;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();

                const startX = x0 + w / 2;
                const startY = y0 + h;
                ctx.moveTo(startX, startY);

                // Segment 1: Bottom center to right corner
                if (rem <= L1) {
                    ctx.lineTo(startX + rem, startY);
                    rem = 0;
                } else {
                    ctx.lineTo(x0 + w - r, startY);
                    rem -= L1;

                    // Segment 2: Right semicircle (clockwise: bottom -> right tip -> top)
                    const cx_r = x0 + w - r;
                    const cy_r = y0 + r;
                    if (rem <= L2) {
                        const angle = Math.PI / 2 - (rem / L2) * Math.PI;
                        ctx.arc(cx_r, cy_r, r, Math.PI / 2, angle, true);
                        rem = 0;
                    } else {
                        ctx.arc(cx_r, cy_r, r, Math.PI / 2, -Math.PI / 2, true);
                        rem -= L2;

                        // Segment 3: Top straight line (moving right to left)
                        if (rem <= L3) {
                            ctx.lineTo(x0 + w - r - rem, y0);
                            rem = 0;
                        } else {
                            ctx.lineTo(x0 + r, y0);
                            rem -= L3;

                            // Segment 4: Left semicircle (clockwise: top -> left tip -> bottom)
                            const cx_l = x0 + r;
                            const cy_l = y0 + r;
                            if (rem <= L4) {
                                const angle = -Math.PI / 2 - (rem / L4) * Math.PI;
                                ctx.arc(cx_l, cy_l, r, -Math.PI / 2, angle, true);
                                rem = 0;
                            } else {
                                ctx.arc(cx_l, cy_l, r, -Math.PI / 2, -3 * Math.PI / 2, true);
                                rem -= L4;

                                // Segment 5: Bottom straight line from left back to center
                                if (rem <= L5) {
                                    ctx.lineTo(x0 + r + rem, startY);
                                    rem = 0;
                                } else {
                                    ctx.lineTo(startX, startY);
                                    rem = 0;
                                }
                            }
                        }
                    }
                }

                if (fraction >= 0.999)
                    ctx.closePath();

                ctx.stroke();
                ctx.restore();
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
            visible: opacity > 0 && !ShellState.gameMode
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

        // Dedicated Game Mode collapsed status pill
        Row {
            anchors.centerIn: notchBody
            spacing: 6
            visible: window.clockRevealed && ShellState.gameMode

            Text {
                text: "󰊴"
                font.family: Theme.iconFontFamily
                font.pixelSize: 13
                color: Theme.red
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "GAME MODE"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                color: Theme.red
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: collapsedMouseArea
            anchors.fill: parent
            enabled: !window.isExpanded
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            property int _wheelDeltaAccum: 0

            onWheel: (wheel) => {
                let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                if (delta === 0) return;
                _wheelDeltaAccum += delta;
                const stepThreshold = 40;
                if (Math.abs(_wheelDeltaAccum) >= stepThreshold) {
                    let steps = Math.trunc(_wheelDeltaAccum / stepThreshold);
                    _wheelDeltaAccum = _wheelDeltaAccum % stepThreshold;
                    IslandHub.adjustVolume(steps * 2);
                }
                wheel.accepted = true;
            }

            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    if (mouse.modifiers & Qt.ShiftModifier) {
                        IslandHub.mediaPrevious();
                    } else {
                        IslandHub.mediaNext();
                    }
                    return;
                }

                if (mouse.button === Qt.MiddleButton) {
                    IslandHub.mediaPlayPause();
                    return;
                }

                if (mouse.button !== Qt.LeftButton)
                    return;
                // Intelligent click routing: target clicked screen and open active activity
                ShellState.activeScreenName = window.screen ? window.screen.name : "";
                if (ShellState.gameMode) {
                    ShellState.show("gamemode", window.screen ? window.screen.name : "");
                    return;
                }
                // Awaiting-acknowledgement timer DONE: tap confirms it and
                // lands on the timer panel; the blink holds until this tap.
                if (TimerState.completionHold) {
                    TimerState.clearCompletionHold();
                    ShellState.show("timer", window.screen ? window.screen.name : "");
                    return ;
                }
                // Plain click opens control center
                ShellState.show("control", window.screen ? window.screen.name : "");
            }
        }

        DropArea {
            id: shelfDropArea
            anchors.fill: notchBody
            enabled: !window.isExpanded

            onEntered: {
                shelfStretch.restart();
            }

            onExited: {
                shelfRelease.restart();
            }

            onDropped: (drop) => {
                shelfRelease.stop();
                shelfStretch.stop();
                if (drop.hasUrls) {
                    const added = ShelfState.addUrls(drop.urls);
                    if (added > 0) {
                        IslandHub.showTransient(ShelfState.lastEvent, 3000);
                        IslandHub.flashBorder(Theme.primary, 600);
                        // Visual absorption only — the files are already
                        // shelved above; this proxy just flies the drop point
                        // into the pill center, then bursts + rebounds.
                        absorbFly.stop();
                        absorbProxy.fileName = String(ShelfState.lastEvent).replace(/^Saved /, "");
                        absorbProxy.x = Math.max(4, Math.min(notchBody.width - absorbProxy.width - 4, drop.x - absorbProxy.width / 2));
                        absorbProxy.y = Math.max(2, Math.min(notchBody.height - absorbProxy.height - 2, drop.y - absorbProxy.height / 2));
                        absorbProxy.scale = 1;
                        absorbProxy.opacity = 1;
                        absorbProxy.visible = true;
                        absorbFly.restart();
                        return ;
                    }
                }
                shelfRelease.restart();
            }
        }

        // Shelf drag stretch: island stretches toward the file being dragged.
        SequentialAnimation {
            id: shelfStretch

            SpringAnimation {
                target: notchBody
                property: "scale"
                to: 1.08
                spring: 4.0
                damping: 0.3
                epsilon: 0.005
            }
        }

        SequentialAnimation {
            id: shelfRelease

            SpringAnimation {
                target: notchBody
                property: "scale"
                to: 1
                spring: 3.5
                damping: 0.32
                epsilon: 0.005
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
                    SpringAnimation {
                        spring: 4.0
                        damping: 0.35
                        epsilon: 0.2
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

            GameModePanel {
                id: gameModePanel

                width: parent.width
                height: parent.height
                visible: window.displayedPanel === "gamemode"
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

        // Shelf absorb flight: proxy pulls from the drop point to the pill
        // center while shrinking/fading, island contracts toward it; on
        // arrival the proxy vanishes INTO the island, burst fires, and
        // absorbPop gives the compression/rebound. Restart coalesces rapid
        // drops (latest file wins).
        ParallelAnimation {
            id: absorbFly

            NumberAnimation {
                target: absorbProxy
                property: "x"
                to: notchBody.width / 2 - absorbProxy.width / 2
                duration: 300
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: absorbProxy
                property: "y"
                to: notchBody.height / 2 - absorbProxy.height / 2
                duration: 300
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: absorbProxy
                property: "scale"
                to: 0.4
                duration: 300
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: absorbProxy
                property: "opacity"
                to: 0.15
                duration: 300
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: notchBody
                property: "scale"
                to: 0.96
                duration: 280
                easing.type: Easing.OutCubic
            }

            onFinished: {
                absorbProxy.visible = false;
                absorbProxy.scale = 1;
                absorbProxy.opacity = 1;
                IslandHub.burst();
                absorbPop.restart();
                // Absorbed: open the shelf on the result, then auto-close
                // once the user has seen it land.
                ShellState.show("shelf", window.screen ? window.screen.name : "");
                shelfAutoClose.restart();
            }
        }

        // Shelf auto-close: after a drop-driven open, close once seen.
        // Fires only while still on the shelf panel; any navigation away
        // cancels it. Never fights the user's own panel switches.
        Timer {
            id: shelfAutoClose
            interval: 3000
            onTriggered: {
                if (ShellState.panel === "shelf")
                    ShellState.close();
            }
        }

        Connections {
            target: ShellState
            function onPanelChanged() {
                if (ShellState.panel !== "shelf")
                    shelfAutoClose.stop();
            }
        }

        // Shelf absorb pop: bounce on successful drop, then settle.
        // absorbPop chains into shelfRelease on finish (no concurrent
        // scale drivers).
        SequentialAnimation {
            id: absorbPop

            SpringAnimation {
                target: notchBody
                property: "scale"
                to: 1.12
                spring: 5.0
                damping: 0.75
                epsilon: 0.01
            }

            SpringAnimation {
                target: notchBody
                property: "scale"
                to: 1
                spring: 4.0
                damping: 0.32
                epsilon: 0.005
            }

            onFinished: shelfRelease.stop()
        }

        // Snap: physical gel-like spring overshoot on EVERY island
        // open/collapse/switch (visual only, geometry untouched).
        // Top-center origin keeps the top edge fixed (screen-edge gap constant).
        SequentialAnimation {
            id: snapPop

            SpringAnimation {
                target: notchSurface
                property: "scale"
                to: ShellState.expanded ? 0.97 : 0.94
                spring: 5.0
                damping: 0.75
                epsilon: 0.01
            }

            SpringAnimation {
                target: notchSurface
                property: "scale"
                to: 1
                spring: 4.0
                damping: 0.32
                epsilon: 0.005
            }
        }

        // Arrival pop: brief acknowledge on new notifications.
        SequentialAnimation {
            id: arrivalPop

            SpringAnimation {
                target: notchSurface
                property: "scale"
                to: 1.04
                spring: 5.0
                damping: 0.75
                epsilon: 0.01
            }

            SpringAnimation {
                target: notchSurface
                property: "scale"
                to: 1
                spring: 4.0
                damping: 0.32
                epsilon: 0.005
            }
        }

        Behavior on width {
            SpringAnimation {
                spring: 4.2
                damping: 0.32
                epsilon: 0.5
            }
        }

        Behavior on height {
            enabled: !clipboardPanel.previewTransitionActive

            SpringAnimation {
                spring: 4.2
                damping: 0.32
                epsilon: 0.5
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
            IslandHub.sweep(Theme.blue);
        }
    }

    // Timer completion: compact attention sequence on REAL zero-crossings
    // only (TimerState raises doneTick solely in its finish branches).
    // snapPop dips, burst fires dots, noticeFlash double-pulses the border.
    // All converge to resting values; nothing loops.
    Connections {
        target: TimerState
        function onDoneTickChanged() {
            snapPop.restart();
            burstAnim.restart();
            noticeFlash.restart();
        }
    }

    Connections {
        target: PowerState
        function onPlugEventTickChanged() {
            IslandHub.showTransient(PowerState.lastPlugEvent, 3000);
            IslandHub.flashBorder(PowerState.charging ? Theme.primary : Theme.foreground, 500);
            arrivalPop.restart();
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
        active: window.isExpanded && Backend.captureSelectionMode !== "region"
        onCleared: {
            if (window.isExpanded && Backend.captureSelectionMode !== "region")
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
            if (!window.isExpanded)
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
        enabled: window.isExpanded
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
