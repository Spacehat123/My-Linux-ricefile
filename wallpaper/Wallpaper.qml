import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    // Lifecycle switches
    property bool enabled: true
    property bool activeRendering: true

    // Media background configuration
    // mediaType: "procedural" | "image" | "video"
    property string mediaType: "procedural"
    property string mediaSource: ""

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

    // Layer 1: GPU-accelerated procedural ShaderEffect surface
    ShaderEffect {
        id: shaderEffect
        anchors.fill: parent
        visible: root.enabled && root.mediaType === "procedural"

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
            running: root.enabled && root.activeRendering && root.mediaType === "procedural"
            easing.type: Easing.Linear
        }
    }

    // Layer 2: Static / Animated image media surface
    Image {
        id: imageLayer
        anchors.fill: parent
        visible: root.enabled && root.mediaType === "image"
        source: (root.enabled && root.mediaType === "image") ? root.mediaSource : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
    }

    // Layer 3: Video media surface (native QtMultimedia with ffmpeg backend)
    MediaPlayer {
        id: mediaPlayer
        source: (root.enabled && root.mediaType === "video") ? root.mediaSource : ""
        loops: MediaPlayer.Infinite
        videoOutput: videoOutputLayer
        audioOutput: AudioOutput {
            muted: true
            volume: 0.0
        }

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia && root.enabled && root.mediaType === "video") {
                play();
            }
        }

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState && root.enabled && root.mediaType === "video" && source != "") {
                play();
            }
        }
    }

    VideoOutput {
        id: videoOutputLayer
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        visible: root.enabled && root.mediaType === "video"
    }
}
