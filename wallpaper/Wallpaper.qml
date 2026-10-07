import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    // =========================================================================
    // Injected Authoritative Configuration
    // =========================================================================
    property bool enabled: true
    property bool activeRendering: true
    property string mediaType: "video"
    property string mediaSource: ""
    property bool live: true

    // Lifecycle visibility: window is mapped to layer-shell only when active
    visible: enabled && activeRendering && mediaType === "video" && mediaSource !== ""

    onLiveChanged: _syncPlayback()
    onVisibleChanged: _syncPlayback()

    function _syncPlayback() {
        if (!root.visible || root.mediaType !== "video" || root.mediaSource === "") {
            return;
        }

        if (root.live) {
            if (mediaPlayer.playbackState === MediaPlayer.PausedState || mediaPlayer.playbackState === MediaPlayer.StoppedState) {
                mediaPlayer.play();
            }
        } else {
            if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                mediaPlayer.pause();
            } else if (mediaPlayer.playbackState === MediaPlayer.StoppedState) {
                mediaPlayer.play();
            }
        }
    }

    // Fullscreen monitor coverage
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Layer-shell protocol parameters
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false
    focusable: false
    color: "transparent"

    WlrLayershell.namespace: "cool-shell-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Absolute pointer passthrough: zero input interception (click-through)
    mask: Region {}

    // =========================================================================
    // Native Hardware-Accelerated Video Surface (QtMultimedia + FFmpeg)
    // =========================================================================
    MediaPlayer {
        id: mediaPlayer
        source: (root.visible && root.mediaType === "video") ? root.mediaSource : ""
        loops: MediaPlayer.Infinite
        videoOutput: videoOutputLayer
        audioOutput: AudioOutput {
            muted: true
            volume: 0.0
        }

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia && root.visible) {
                root._syncPlayback();
            }
        }

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState && root.visible && source !== "") {
                root._syncPlayback();
            } else if (playbackState === MediaPlayer.PlayingState && !root.live) {
                pause();
            }
        }
    }

    VideoOutput {
        id: videoOutputLayer
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        visible: root.visible
    }
}
