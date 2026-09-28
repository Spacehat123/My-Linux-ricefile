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
    property bool contentRevealed: false
    property bool clockRevealed: true
    property bool recBlinkOn: false
    property string displayedPanel: "control"
    readonly property var islandPlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
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

    Connections {
        function onPanelChanged() {
            window.contentRevealed = ShellState.expanded;
            if (ShellState.expanded) {
                clockRevealTimer.stop();
                window.clockRevealed = false;
                window.displayedPanel = ShellState.panel;
                if (ShellState.panel === "notifications")
                    IslandHub.markSeen();
                focusTimer.restart();
            } else {
                clockRevealTimer.restart();
            }
        }

        target: ShellState
    }

    FocusScope {
        id: notchSurface

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
        }

        Item {
            id: mediaRingClip

            x: notchBody.x
            y: notchBody.y
            width: notchBody.width * window.mediaFraction
            height: notchBody.height
            clip: true
            visible: window.mediaActive

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
            micActive: PrivacyState.micActive
            camActive: PrivacyState.camActive
            recActive: IslandHub.recordingActive
            shelfCount: ShelfState.files.length
            weatherMini: WeatherState.collapsedVisible ? WeatherState.tempC : ""

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
            // Set on press when a Ctrl+click is routed to transport, so the
            // matching release-time clicked() is swallowed even if Ctrl was
            // already released before the button came up.
            property bool ctrlClick: false
            onPressed: (mouse) => {
                // Ctrl + click = media transport. Routed on press, where the
                // modifier state is reliable, and accepted so the panel path
                // below can never fire for this gesture.
                ctrlClick = false;
                if (mouse.modifiers & Qt.ControlModifier) {
                    ctrlClick = true;
                    if (window.islandPlayer) {
                        if (mouse.button === Qt.LeftButton && window.islandPlayer.canGoPrevious)
                            window.islandPlayer.previous();
                        else if (mouse.button === Qt.RightButton && window.islandPlayer.canGoNext)
                            window.islandPlayer.next();
                    }
                    mouse.accepted = true;
                }
            }
            onClicked: (mouse) => {
                if (ctrlClick) {
                    ctrlClick = false;
                    return ;
                }
                if (mouse.modifiers & Qt.ControlModifier)
                    return ;
                if (mouse.button !== Qt.LeftButton)
                    return ;
                // Plain click always opens control center (hub for everything).
                ShellState.show("control");
            }
        }

        DropArea {
            anchors.fill: notchBody
            enabled: !ShellState.expanded
            onDropped: (drop) => {
                if (drop.hasUrls && window.screen === Quickshell.screens[0]) {
                    const added = ShelfState.addUrls(drop.urls);
                    if (added > 0) {
                        IslandHub.showTransient(ShelfState.lastEvent, 3000);
                        IslandHub.flashBorder(Theme.primary, 600);
                    }
                }
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
            opacity: window.contentRevealed ? 1 : 0
            clip: true

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
                    duration: Theme.animationNormal
                    easing.type: Easing.OutCubic
                }

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
        interval: 500
        running: IslandHub.recordingActive
        repeat: true
        onTriggered: window.recBlinkOn = !window.recBlinkOn
    }

    Connections {
        target: PowerState
        function onPlugEventTickChanged() {
            IslandHub.showTransient(PowerState.lastPlugEvent, 3000);
            IslandHub.flashBorder(PowerState.charging ? Theme.primary : Theme.foreground, 800);
        }
    }

    Connections {
        target: BtState
        function onEventTickChanged() {
            IslandHub.showTransient(BtState.lastEvent, 3000);
            IslandHub.flashBorder(Theme.blue, 800);
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
