import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    // Lifecycle switches
    property bool enabled: true
    property bool activeRendering: true

    // Visibility tracks master enabled flag
    visible: enabled

    // Anchors to cover the entire screen
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

    WlrLayershell.namespace: "pranc-shell-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Complete input transparency: empty Region informs compositor to pass all pointer events through
    mask: Region {}

    // GPU-accelerated ShaderEffect surface
    ShaderEffect {
        id: shaderEffect
        anchors.fill: parent
        visible: root.enabled

        property real time: 0.0
        property vector2d resolution: Qt.vector2d(root.width > 0 ? root.width : 1920,
                                                  root.height > 0 ? root.height : 1080)

        fragmentShader: "shaders/wallpaper.frag.qsb"

        // Pure C++ animation driver: zero per-frame JavaScript overhead
        NumberAnimation {
            id: timeDriver
            target: shaderEffect
            property: "time"
            from: 0.0
            to: 6.28318530718 // 2 * PI for seamless harmonic loop
            duration: 60000   // 60-second period for calm ambient motion
            loops: Animation.Infinite
            running: root.enabled && root.activeRendering
            easing.type: Easing.Linear
        }
    }
}
