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

    // Lifecycle visibility: window is mapped to layer-shell ONLY when video is active and in-view (live).
    // When an opaque window/tab is open (live === false) or when a static image is used (mediaType === "image"),
    // this window unmaps completely (visible = false) so awww-daemon handles the background at 0% GPU/CPU cost.
    visible: enabled && activeRendering && mediaType === "video" && mediaSource !== "" && live

    onLiveChanged: _syncPlayback()
    onVisibleChanged: _syncPlayback()
    onMediaSourceChanged: {
        if (root.visible && root.live && root.mediaType === "video" && root.mediaSource !== "") {
            mediaPlayer.stop();
            mediaPlayer.play();
        } else {
            _syncPlayback();
        }
    }

    function _syncPlayback() {
        if (root.mediaType !== "video" || root.mediaSource === "" || !root.visible || !root.live) {
            if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                mediaPlayer.pause();
            }
            return;
        }

        if (mediaPlayer.playbackState === MediaPlayer.PausedState || mediaPlayer.playbackState === MediaPlayer.StoppedState) {
            mediaPlayer.play();
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
        source: (root.visible && root.live && root.mediaType === "video") ? root.mediaSource : ""
        loops: MediaPlayer.Infinite
        videoOutput: videoOutputLayer
        audioOutput: null

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia && root.visible && root.live) {
                root._syncPlayback();
            }
        }

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState && root.visible && root.live && source !== "") {
                root._syncPlayback();
            } else if (playbackState === MediaPlayer.PlayingState && (!root.live || !root.visible)) {
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
