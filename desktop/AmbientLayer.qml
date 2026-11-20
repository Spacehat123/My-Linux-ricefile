import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    // =========================================================================
    // Injected State & Configuration
    // =========================================================================
    property var screen: null
    property bool idle: false
    property bool workspaceEmpty: false
    property bool enabled: true
    property bool alwaysOn: false
    readonly property bool active: (alwaysOn || idle || workspaceEmpty) && enabled

    // Lifecycle visibility: stays visible while active or while fade-out is running
    visible: active || fadeOutAnim.running

    // Fullscreen geometry anchors
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Layer-shell configuration matching FloatingMediaCompanion 1:1
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false
    focusable: false
    color: "transparent"

    WlrLayershell.namespace: "pranc-shell-ambient-slate"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Explicit Wayland region mask targeting the slate geometry
    mask: Region {
        item: (root.active || fadeOutAnim.running) ? slateWrapper : null
    }

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

        Item {
            id: slateWrapper
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 48
            anchors.bottomMargin: 48
            width: slateInstance.implicitWidth
            height: slateInstance.implicitHeight

            // Desktop Ambient Weather & Clock Slate (Frosted Glass Plate on Bottom Left)
            DesktopAmbientSlate {
                id: slateInstance
                anchors.fill: parent
                active: root.active && (hudContainer.opacity > 0.0)
            }
        }
    }
}
