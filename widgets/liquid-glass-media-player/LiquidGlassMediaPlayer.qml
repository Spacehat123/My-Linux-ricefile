import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../../island" as Island

Item {
    id: root

    // =========================================================================
    // SECTION 13: EXPOSED OPTICAL PROPERTIES (TUNABLE UNIFORMS)
    // =========================================================================
    property real glassBlur: 3.5            // Light diffusion blur in px (2 to 8 px)
    property real glassSaturation: 1.65     // Chroma vibrancy multiplier (1.4 to 1.8)
    property color glassTint: Qt.rgba(1, 1, 1, Island.Theme && Island.Theme.isLightMode ? 0.14 : 0.09) // Light wash
    property real refractionScale: 52.0     // Lens refraction displacement scale (30 to 75)
    property real ior: 1.49                 // Index of refraction (crown glass ~ 1.49 - 1.52)
    property real bezelWidth: 15.0          // Width of curved refracting bezel band in px
    property real chromaticAberration: 0.06 // Cauchy dispersion delta (0.02 to 0.12)
    property real specularOpacity: 0.88     // Directional key light rim intensity (0.5 to 1.0)
    property real lightAngle: 45.0          // Virtual key light angle in degrees
    property real cornerRadius: 26.0        // Outer squircle corner radius in px
    property real shadowStrength: 1.0       // Depth drop shadow intensity (0.5 to 1.5)

    // Section 14: Debug Modes (0 = normal glass, 1 = surface normals, 2 = UV refraction offset)
    property int debugMode: 0

    // Backdrop Capture Mode: "auto", "screencopy", or "wallpaper"
    property string backdropMode: "auto"

    // Geometry & Layout
    implicitWidth: 430
    implicitHeight: 122
    readonly property real cardPadding: 16.0
    readonly property real innerRadius: Math.max(6.0, cornerRadius - cardPadding + 2.0)

    // Spatial Position on Screen (used for cropping screencopy and wallpaper)
    property real screenX: 140.0
    property real screenY: 52.0

    // State Signals
    signal closeClicked()
    signal dragged(real dx, real dy)

    // =========================================================================
    // DATA MODEL: MPRIS MEDIA & LYRICS
    // =========================================================================
    readonly property var allPlayers: Mpris.players ? Mpris.players.values : []
    readonly property var activePlayer: {
        if (!allPlayers || allPlayers.length === 0) return null;
        for (let i = 0; i < allPlayers.length; ++i) {
            if (allPlayers[i] && allPlayers[i].isPlaying) return allPlayers[i];
        }
        return allPlayers[0] || null;
    }
    readonly property bool isPlaying: activePlayer ? activePlayer.isPlaying : false
    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "No Media Playing") : "No Media Playing"
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string trackArtUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property real trackPosition: activePlayer ? (activePlayer.position || 0) : 0
    readonly property real trackLength: activePlayer ? (activePlayer.length || 0) : 0
    readonly property string liveLyric: (Island.IslandHub && Island.IslandHub.liveLyric) ? Island.IslandHub.liveLyric : ""

    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec < 0) return "0:00";
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // =========================================================================
    // SECTION 1 & 8: BACKDROP CAPTURE & SHADOW HIERARCHY
    // =========================================================================

    // Soft Layered Drop Shadow
    Rectangle {
        id: shadowUnderlay
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        visible: root.shadowStrength > 0.01

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.40 * root.shadowStrength)
            shadowBlur: 0.65
            shadowVerticalOffset: 12
            shadowHorizontalOffset: 0
        }
    }

    // Secondary tight grounding shadow
    Rectangle {
        id: shadowTight
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        visible: root.shadowStrength > 0.01

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.25 * root.shadowStrength)
            shadowBlur: 0.25
            shadowVerticalOffset: 3
            shadowHorizontalOffset: 0
        }
    }

    // Item containing the cropped backdrop buffer
    Item {
        id: backdropContainer
        anchors.fill: parent

        // Live Screencopy Output Capture (No static or fake fallbacks)
        ScreencopyView {
            id: screencopy
            captureSource: Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
            paintCursor: false
            live: false
            x: -root.screenX
            y: -root.screenY
            width: (Quickshell.screens && Quickshell.screens[0]) ? Quickshell.screens[0].width : 1920
            height: (Quickshell.screens && Quickshell.screens[0]) ? Quickshell.screens[0].height : 1080
            visible: true
        }
    }

    // Throttled frame capture timer to mitigate feedback loop (30 fps active, 2 fps idle)
    Timer {
        id: captureTimer
        interval: root.isPlaying ? 33 : 500 // ~30 fps during active playback
        running: (root.backdropMode === "screencopy" || root.backdropMode === "auto") && root.visible
        repeat: true
        onTriggered: {
            if (screencopy.captureSource) {
                screencopy.captureFrame();
            }
        }
    }

    // ShaderEffectSource feeding the GLSL shader
    ShaderEffectSource {
        id: backdropSource
        sourceItem: backdropContainer
        sourceRect: Qt.rect(0, 0, root.width, root.height)
        live: true
        hideSource: true
        textureSize: Qt.size(root.width, root.height)
    }

    // =========================================================================
    // SECTION 2, 3, 4, 5, 6, 7: LIQUID GLASS GLSL SHADER EFFECT
    // =========================================================================
    ShaderEffect {
        id: glassShader
        anchors.fill: parent

        // Sampler
        property var backdrop: backdropSource

        // Optical Uniforms mapped directly to GLSL std140 uniform block
        property var size: Qt.vector2d(root.width, root.height)
        property real cornerRadius: root.cornerRadius
        property real bezelWidth: root.bezelWidth
        property real refractionScale: root.refractionScale
        property real ior: root.ior
        property real dispersion: root.chromaticAberration
        property real blurRadius: root.glassBlur
        property real saturation: root.glassSaturation
        property color tint: root.glassTint
        property real specularOpacity: root.specularOpacity
        property real lightAngle: root.lightAngle
        property real isPressed: cardMouse.pressed ? 1.0 : 0.0
        property real isHovered: cardMouse.containsMouse ? 1.0 : 0.0
        property var mousePos: Qt.vector2d(cardMouse.mouseX, cardMouse.mouseY)
        property real debugMode: root.debugMode

        // Compiled Qt 6 multi-target shader bytecode
        fragmentShader: Qt.resolvedUrl("liquid_glass.frag.qsb")

        // Smooth spring response on press / hover
        scale: cardMouse.pressed ? 0.96 : (cardMouse.containsMouse ? 1.01 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: 240; easing.type: Easing.OutBack }
        }
    }

    // =========================================================================
    // SECTION 9 & 10: CRISP HIGH-CONTRAST CONTENT LAYER
    // =========================================================================
    Item {
        id: contentLayer
        anchors.fill: parent
        anchors.margins: root.cardPadding
        z: 10

        // Scale in unison with glass shader
        scale: glassShader.scale
        transformOrigin: Item.Center

        // Header: CAVA bars top-left, drag handle top-center, badges & close top-right
        Item {
            id: topHeaderRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 16

            // CAVA Mini Visualizer Bars
            Row {
                id: cavaRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2.5

                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: 2.5
                        radius: 1.25
                        color: Island.Theme ? Island.Theme.primary : "#ff2a5f"
                        readonly property var levels: (Island.IslandHub && Island.IslandHub.levels) ? Island.IslandHub.levels : [0.4, 0.7, 0.5, 0.9]
                        height: Math.max(3, Math.min(12, Math.round(2 + ((levels && levels[index]) || 0.3) * 10)))
                        Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                    }
                }
            }

            // Top Drag Handle (tactile grab pill)
            Item {
                anchors.left: cavaRow.right
                anchors.right: headerActions.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width: 36
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.28)
                }
            }

            // Badges & Close Button
            Row {
                id: headerActions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Pinned pill badge
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 16
                    width: pinnedText.implicitWidth + 12
                    radius: 8
                    color: Qt.rgba(1, 0.16, 0.37, 0.18)
                    border.width: 1
                    border.color: Qt.rgba(1, 0.16, 0.37, 0.45)

                    Text {
                        id: pinnedText
                        anchors.centerIn: parent
                        text: "󰤱 PINNED"
                        font.pixelSize: 9
                        font.bold: true
                        color: "#ff527b"
                    }
                }

                // Close Button
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    radius: 9
                    color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.25)

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 9
                        font.bold: true
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.closeClicked()
                    }
                }
            }
        }

        // Main Deck: Concentric Artwork & Track Info
        Row {
            id: mainDeckRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: topHeaderRow.bottom
            anchors.topMargin: 8
            spacing: 12

            // Concentric Album Artwork
            Rectangle {
                id: artFrame
                width: 48
                height: 48
                radius: root.innerRadius
                color: Qt.rgba(0, 0, 0, 0.35)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.25)
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.trackArtUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.trackArtUrl || root.trackArtUrl === ""
                    text: root.isPlaying ? "󰎈" : "󰝚"
                    font.pixelSize: 22
                    color: Island.Theme ? Island.Theme.primary : "#ff2a5f"
                }
            }

            // Track Titles & Rolling Lyrics
            Column {
                anchors.verticalCenter: artFrame.verticalCenter
                width: parent.width - artFrame.width - parent.spacing
                spacing: 2

                Text {
                    width: parent.width
                    text: root.trackTitle
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Island.Theme && Island.Theme.isLightMode ? "#121316" : "#ffffff"
                    style: Text.Outline
                    styleColor: Island.Theme && Island.Theme.isLightMode ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.45)
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.trackArtist !== "" ? root.trackArtist : "Playing Track"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Island.Theme && Island.Theme.isLightMode ? Qt.rgba(0.07, 0.07, 0.09, 0.82) : Qt.rgba(1, 1, 1, 0.82)
                    style: Text.Outline
                    styleColor: Island.Theme && Island.Theme.isLightMode ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(0, 0, 0, 0.35)
                    elide: Text.ElideRight
                }

                // Kinetic Synchronized Lyrics Slot
                Item {
                    width: parent.width
                    height: 14
                    clip: true
                    visible: root.liveLyric !== ""

                    Text {
                        id: lyricLabel
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        text: root.liveLyric
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Island.Theme ? Island.Theme.primary : "#ff527b"
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.4)
                        elide: Text.ElideRight

                        onTextChanged: lyricAnim.restart()
                        NumberAnimation on y {
                            id: lyricAnim
                            from: 10
                            to: 0
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        // Bottom Controls Deck: Scrubber & Transport Buttons
        Item {
            id: bottomControlsRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 26

            // Elapsed time
            Text {
                id: elapsedText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.formatTime(root.trackPosition)
                font.pixelSize: 10
                font.weight: Font.Medium
                color: Island.Theme && Island.Theme.isLightMode ? Qt.rgba(0.07, 0.07, 0.09, 0.65) : Qt.rgba(1, 1, 1, 0.65)
            }

            // Transport Buttons (Mini Glass Lenses)
            Row {
                id: transportButtonsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                spacing: 8

                // Prev Button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: prevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.3)

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.pixelSize: 12
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (root.activePlayer) root.activePlayer.previous();
                            else if (Island.IslandHub) Island.IslandHub.mediaPrevious();
                        }
                    }
                }

                // Play / Pause Button (Hero glass pill)
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: Island.Theme && Island.Theme.isLightMode ? "#121316" : "#ffffff"
                    border.width: 1
                    border.color: "#ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "󰏤" : "󰐊"
                        font.pixelSize: 13
                        color: Island.Theme && Island.Theme.isLightMode ? "#ffffff" : "#121316"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer) root.activePlayer.playPause();
                            else if (Island.IslandHub) Island.IslandHub.mediaPlayPause();
                        }
                    }
                }

                // Next Button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: nextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.3)

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.pixelSize: 12
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (root.activePlayer) root.activePlayer.next();
                            else if (Island.IslandHub) Island.IslandHub.mediaNext();
                        }
                    }
                }
            }

            // Duration time
            Text {
                id: durationText
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: transportButtonsRow.left
                anchors.rightMargin: 8
                text: root.formatTime(root.trackLength)
                font.pixelSize: 10
                font.weight: Font.Medium
                color: Island.Theme && Island.Theme.isLightMode ? Qt.rgba(0.07, 0.07, 0.09, 0.65) : Qt.rgba(1, 1, 1, 0.65)
            }

            // Interactive Progress Scrubber Track
            Item {
                id: scrubberTrack
                anchors.left: elapsedText.right
                anchors.leftMargin: 8
                anchors.right: durationText.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.22)
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.2)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: (root.trackLength > 0) ? (parent.width * Math.min(1.0, root.trackPosition / root.trackLength)) : (parent.width * 0.4)
                        radius: 2
                        color: Island.Theme ? Island.Theme.primary : "#ff2a5f"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (root.activePlayer && root.trackLength > 0) {
                            const ratio = Math.max(0.0, Math.min(1.0, mouse.x / width));
                            root.activePlayer.position = ratio * root.trackLength;
                        }
                    }
                }
            }
        }
    }

    // Interactive Drag & Key Light Angle Tracking MouseArea
    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton

        property real startMouseX: 0
        property real startMouseY: 0

        onPressed: (mouse) => {
            startMouseX = mouse.x;
            startMouseY = mouse.y;
        }

        onPositionChanged: (mouse) => {
            // Interactive tilt: light angle moves slightly with cursor
            const dx = (mouse.x - root.width * 0.5) / (root.width * 0.5);
            root.lightAngle = 45.0 + dx * 20.0;

            if (pressed) {
                root.dragged(mouse.x - startMouseX, mouse.y - startMouseY);
            }
        }

        onReleased: {
            root.lightAngle = 45.0;
        }
    }
}
