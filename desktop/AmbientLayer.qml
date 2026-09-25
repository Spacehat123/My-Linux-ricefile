import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    // =========================================================================
    // Injected State & Configuration
    // =========================================================================
    property bool idle: false
    property bool enabled: true
    readonly property bool active: idle && enabled

    // Lifecycle visibility: stays visible while active or while fade-out is running
    visible: active || fadeOutAnim.running

    // Fullscreen geometry anchors
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Layer-shell configuration
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false
    focusable: false
    color: "transparent"

    WlrLayershell.namespace: "pranc-shell-ambient"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Absolute pointer passthrough: zero mouse/touch event interception
    mask: Region {}

    Theme {
        id: theme
    }

    // =========================================================================
    // Emergence / Dismissal Animation Controllers
    // =========================================================================
    NumberAnimation {
        id: fadeInAnim
        target: hudContainer
        property: "opacity"
        to: 1.0
        duration: theme.ambientFadeInDuration
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: fadeOutAnim
        target: hudContainer
        property: "opacity"
        to: 0.0
        duration: theme.ambientFadeOutDuration
        easing.type: Easing.OutQuad
    }

    onActiveChanged: {
        if (active) {
            fadeOutAnim.stop();
            fadeInAnim.start();
        } else {
            fadeInAnim.stop();
            fadeOutAnim.start();
        }
    }

    // =========================================================================
    // Scene Graph Resource Gate: completely unrendered when dismissed
    // =========================================================================
    Item {
        id: hudContainer
        anchors.fill: parent
        opacity: 0.0
        visible: opacity > 0.0

        // 1. Four screen corner tactical brackets
        AmbientCornerBrackets {
            anchors.fill: parent
            screenName: root.screen ? (root.screen.name ?? "") : ""
            active: root.active && (hudContainer.opacity > 0.0)
        }

        // 2. Central focal tactical reticle
        AmbientReticle {
            anchors.centerIn: parent
            active: root.active && (hudContainer.opacity > 0.0)
        }

        // 3. Floating telemetry HUD node
        AmbientTelemetry {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: theme.ambientCornerOffset + 16
            screenName: root.screen ? (root.screen.name ?? "") : ""
            active: root.active && (hudContainer.opacity > 0.0)
        }
    }
}
