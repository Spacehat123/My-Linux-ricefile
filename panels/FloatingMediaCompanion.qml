import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../island" as Island
import "../widgets/liquid-glass-media-player"

PanelWindow {
    id: root

    property var screen: null
    property bool open: false
    property bool isPinned: false

    // Default anchor position: floats directly beneath the top-bar left visualizer
    readonly property real defaultX: 140
    readonly property real defaultY: 52

    property real pillX: defaultX
    property real pillY: defaultY

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    focusable: false
    visible: open || capsuleCard.opacity > 0.001

    WlrLayershell.namespace: "pranc-shell-media-companion"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Click-through mask: Only the capsuleCard consumes pointer input; everything else passes to apps
    mask: Region {
        Region {
            item: capsuleCard
            topLeftRadius: capsuleCard ? capsuleCard.radius : 0
            topRightRadius: capsuleCard ? capsuleCard.radius : 0
            bottomLeftRadius: capsuleCard ? capsuleCard.radius : 0
            bottomRightRadius: capsuleCard ? capsuleCard.radius : 0
        }
    }

    // =========================================================================
    // EXPOSED LIQUID GLASS TUNABLE PROPERTIES
    // =========================================================================
    property alias glassBlur: glassPlayer.glassBlur
    property alias glassSaturation: glassPlayer.glassSaturation
    property alias glassTint: glassPlayer.glassTint
    property alias refractionScale: glassPlayer.refractionScale
    property alias ior: glassPlayer.ior
    property alias bezelWidth: glassPlayer.bezelWidth
    property alias chromaticAberration: glassPlayer.chromaticAberration
    property alias specularOpacity: glassPlayer.specularOpacity
    property alias lightAngle: glassPlayer.lightAngle
    property alias cornerRadius: glassPlayer.cornerRadius
    property alias shadowStrength: glassPlayer.shadowStrength
    property alias debugMode: glassPlayer.debugMode
    property alias backdropMode: glassPlayer.backdropMode

    // =========================================================================
    // MPRIS DATA MODEL
    // =========================================================================
    readonly property var allPlayers: Mpris.players.values
    readonly property var activePlayer: {
        if (!allPlayers || allPlayers.length === 0) return null;
        for (let i = 0; i < allPlayers.length; ++i) {
            if (allPlayers[i] && allPlayers[i].isPlaying)
                return allPlayers[i];
        }
        return allPlayers[0] || null;
    }

    readonly property bool isPlaying: activePlayer ? activePlayer.isPlaying : false
    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "No Media Playing") : "No Media Playing"
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string trackArtUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property real trackPosition: activePlayer ? (activePlayer.position || 0) : 0
    readonly property real trackLength: activePlayer ? (activePlayer.length || 0) : 0

    // =========================================================================
    // LIFECYCLE & STATE MACHINE (UNMOVED vs PINNED)
    // =========================================================================
    function toggle() {
        if (open) {
            closeAndReset();
        } else {
            if (!isPinned) {
                pillX = defaultX;
                pillY = defaultY;
                capsuleCard.x = defaultX;
                capsuleCard.y = defaultY;
            }
            open = true;
        }
    }

    function closeAndReset() {
        open = false;
        isPinned = false;
        pillX = defaultX;
        pillY = defaultY;
        capsuleCard.x = defaultX;
        capsuleCard.y = defaultY;
    }

    // Auto-reveal on playback start if unmoved; auto-sleep on pause if unmoved
    onIsPlayingChanged: {
        if (isPlaying) {
            pauseGraceTimer.stop();
            if (!isPinned) {
                pillX = defaultX;
                pillY = defaultY;
                capsuleCard.x = defaultX;
                capsuleCard.y = defaultY;
                open = true;
            }
        } else {
            if (!isPinned) {
                pauseGraceTimer.restart();
            }
        }
    }

    Timer {
        id: pauseGraceTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!root.isPlaying && !root.isPinned) {
                root.open = false;
            }
        }
    }

    // Listen to ShellState's toggle request (triggered by Super+M and top bar click)
    Connections {
        target: Island.ShellState
        function onToggleMediaCompanionRequested() {
            root.toggle();
        }
    }

    IpcHandler {
        target: "media_companion"

        function toggle(): string {
            root.toggle();
            return JSON.stringify({ success: true, open: root.open, isPinned: root.isPinned });
        }

        function setOpen(val: bool): string {
            if (val) {
                if (!root.isPinned) {
                    root.pillX = root.defaultX;
                    root.pillY = root.defaultY;
                    capsuleCard.x = root.defaultX;
                    capsuleCard.y = root.defaultY;
                }
                root.open = true;
            } else {
                root.closeAndReset();
            }
            return JSON.stringify({ success: true, open: root.open, isPinned: root.isPinned });
        }

        function moveTo(targetX: real, targetY: real): string {
            capsuleCard.x = targetX;
            capsuleCard.y = targetY;
            root.pillX = targetX;
            root.pillY = targetY;
            root.isPinned = true;
            return JSON.stringify({ success: true, isPinned: root.isPinned, x: targetX, y: targetY });
        }

        function setRefraction(scale: real): string {
            root.refractionScale = scale;
            return JSON.stringify({ success: true, refractionScale: root.refractionScale });
        }

        function setDebugMode(mode: int): string {
            root.debugMode = mode;
            return JSON.stringify({ success: true, debugMode: root.debugMode });
        }

        function setBackdropMode(mode: string): string {
            root.backdropMode = mode;
            return JSON.stringify({ success: true, backdropMode: root.backdropMode });
        }

        function getState(): string {
            return JSON.stringify({
                open: root.open,
                isPinned: root.isPinned,
                x: capsuleCard.x,
                y: capsuleCard.y,
                title: root.trackTitle,
                artist: root.trackArtist,
                isPlaying: root.isPlaying,
                refractionScale: root.refractionScale,
                bezelWidth: root.bezelWidth,
                debugMode: root.debugMode,
                backdropMode: root.backdropMode
            });
        }
    }

    // =========================================================================
    // THE LIQUID GLASS COMPANION CAPSULE
    // =========================================================================
    Item {
        id: capsuleCard
        x: root.pillX
        y: root.pillY
        width: 430
        height: 122
        property real radius: glassPlayer.cornerRadius

        opacity: root.open ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        LiquidGlassMediaPlayer {
            id: glassPlayer
            anchors.fill: parent
            screenX: capsuleCard.x
            screenY: capsuleCard.y

            onCloseClicked: root.closeAndReset()

            onDragged: (dx, dy) => {
                pauseGraceTimer.stop();
                const minX = 12;
                const maxX = (root.screen ? root.screen.width : 1920) - capsuleCard.width - 12;
                const minY = 48;
                const maxY = (root.screen ? root.screen.height : 1080) - capsuleCard.height - 12;

                const newX = Math.max(minX, Math.min(maxX, capsuleCard.x + dx));
                const newY = Math.max(minY, Math.min(maxY, capsuleCard.y + dy));

                capsuleCard.x = newX;
                capsuleCard.y = newY;
                root.pillX = newX;
                root.pillY = newY;

                const dist = Math.hypot(capsuleCard.x - root.defaultX, capsuleCard.y - root.defaultY);
                if (dist > 35) {
                    root.isPinned = true;
                } else {
                    root.isPinned = false;
                }
            }
        }
    }
}
