import QtQuick
import "components"

// Collapsed pill content: extremely compact live-activity status. No clock.
// Props are fed by Notch (single screen instance each). Shows at most:
// [unread bubble] [primary label] [mic dot] [cam dot], all elided to fit.
Item {
    id: root

    property int unread: 0
    property string label: ""
    property bool micActive: false
    property bool camActive: false
    property bool recActive: false
    property int shelfCount: 0
    property string weatherMini: ""
    property bool volumeActive: false
    property string volumeText: ""
    property bool volumeMuted: false
    property string btConnected: ""
    property bool mediaPlaying: false

    implicitHeight: 24

    Row {
        anchors.centerIn: parent
        spacing: 5
        visible: !root.volumeActive

        // Unread bubble: only when unread exist. Pops in with overshoot;
        // rapid increments coalesce via restart (final count always correct).
        Rectangle {
            id: unreadBubble
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 9
            visible: root.unread > 0
            color: Theme.primary

            ShellText {
                anchors.centerIn: parent
                text: root.unread > 9 ? "9+" : String(root.unread)
                font.pixelSize: 10
                font.weight: Font.Bold
                color: "#000000"
            }

            SequentialAnimation {
                id: bubblePop

                NumberAnimation {
                    target: unreadBubble
                    property: "scale"
                    from: 0.7
                    to: 1.08
                    duration: 150
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: unreadBubble
                    property: "scale"
                    to: 1
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Connections {
                function onUnreadChanged() {
                    if (root.unread > 0)
                        bubblePop.restart();
                    else
                        unreadBubble.scale = 1;
                }

                target: root
            }
        }

        // Recording dot with enhanced pulse.
        Rectangle {
            id: recDot
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            visible: root.recActive
            color: Theme.red

            // Enhanced pulse: scale + opacity pulse synced with IslandHub.recBlinkOn
            // but smoother (scale + fade instead of just border blink).
            // Loop stops on its own when recActive goes false; the stop
            // fade below resets scale/opacity so nothing sticks mid-pulse.
            SequentialAnimation {
                id: recPulse
                loops: Animation.Infinite
                running: root.recActive

                ParallelAnimation {
                    NumberAnimation {
                        target: recDot
                        property: "scale"
                        to: 1.3
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: recDot
                        property: "opacity"
                        to: 0.5
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: recDot
                        property: "scale"
                        to: 1
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: recDot
                        property: "opacity"
                        to: 1
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // Stop fade: shrink out, then reset for next recording.
            SequentialAnimation {
                id: recStop

                ParallelAnimation {
                    NumberAnimation {
                        target: recDot
                        property: "scale"
                        to: 0.6
                        duration: 150
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: recDot
                        property: "opacity"
                        to: 0
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                PropertyAction {
                    target: recDot
                    property: "scale"
                    value: 1
                }

                PropertyAction {
                    target: recDot
                    property: "opacity"
                    value: 1
                }
            }

            Connections {
                function onRecActiveChanged() {
                    if (!root.recActive)
                        recStop.restart();
                }

                target: root
            }
        }

        // Primary activity label (single slot; shrinks when weather shares the pill).
        // Content morph: old text dips (scale+fade 110ms), swaps, new pops in.
        ShellText {
            id: primaryLabel

            property string shown: ""
            text: shown
            transformOrigin: Item.Center
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            width: Math.min(implicitWidth, root.weatherMini !== "" ? 68 : 104)
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.recActive ? Theme.red : Theme.shellForeground
            font.pixelSize: 11
            font.weight: Font.DemiBold

            function syncLabel() {
                if (shown === root.label)
                    return ;
                if (shown === "") {
                    shown = root.label;
                    return ;
                }
                if (morphOut.running || morphIn.running) {
                    shown = root.label;
                    scale = 1;
                    opacity = 1;
                    return ;
                }
                morphOut.restart();
            }

            ParallelAnimation {
                id: morphOut

                NumberAnimation {
                    target: primaryLabel
                    property: "scale"
                    to: 0.6
                    duration: 110
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: primaryLabel
                    property: "opacity"
                    to: 0
                    duration: 110
                    easing.type: Easing.OutCubic
                }

                onFinished: {
                    primaryLabel.shown = root.label;
                    morphIn.restart();
                }
            }

            ParallelAnimation {
                id: morphIn

                NumberAnimation {
                    target: primaryLabel
                    property: "scale"
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: primaryLabel
                    property: "opacity"
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Connections {
                // Fires whenever the bound label prop changes upstream.
                function onLabelChanged() {
                    primaryLabel.syncLabel();
                }

                target: root
            }

            Component.onCompleted: primaryLabel.syncLabel()
        }

        // Music waveform: real amplitude bars from the PipeWire monitor tap.
        // Pops in on play; pause hides instantly (calm). Bars themselves
        // animate via height Behavior while playing, still when paused.
        Row {
            id: waveRow
            anchors.verticalCenter: parent.verticalCenter
            visible: root.mediaPlaying && !root.volumeActive
            spacing: 1
            transformOrigin: Item.Center

            ParallelAnimation {
                id: wavePop

                NumberAnimation {
                    target: waveRow
                    property: "scale"
                    from: 0.6
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: waveRow
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Connections {
                function onMediaPlayingChanged() {
                    if (root.mediaPlaying)
                        wavePop.restart();
                }

                target: root
            }

            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 2
                    height: 2 + (IslandHub.levels[index] || 0) * 10
                    radius: 1
                    color: Theme.primary
                    opacity: 0.7

                    Behavior on height {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        // Shelf count: only when idle (no primary label).
        ShellText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label === "" && root.shelfCount > 0
            text: "⧉ " + root.shelfCount
            color: Theme.muted
            font.pixelSize: 11
        }

        // Pinned weather: right side, alongside the label when one is shown.
        // Pops on refresh; disappear stays instant (calm).
        ShellText {
            id: weatherText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.weatherMini !== ""
            text: root.weatherMini
            color: Theme.muted
            font.pixelSize: 11
            transformOrigin: Item.Center

            ParallelAnimation {
                id: weatherPop

                NumberAnimation {
                    target: weatherText
                    property: "scale"
                    from: 0.8
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: weatherText
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Connections {
                function onWeatherMiniChanged() {
                    if (root.weatherMini !== "")
                        weatherPop.restart();
                }

                target: root
            }
        }

        // Mic: small YELLOW indicator, only while capturing.
        // Pops on appear; hide stays instant (calm, debounce already lags).
        Rectangle {
            id: micDot
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            visible: root.micActive
            color: "#e5c535"
            transformOrigin: Item.Center

            ParallelAnimation {
                id: micPop

                NumberAnimation {
                    target: micDot
                    property: "scale"
                    from: 0
                    to: 1
                    duration: 180
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: micDot
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            Connections {
                function onMicActiveChanged() {
                    if (root.micActive)
                        micPop.restart();
                }

                target: root
            }
        }

        // Camera: small PURPLE indicator, only while held. Same treatment.
        Rectangle {
            id: camDot
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            visible: root.camActive
            color: "#c678dd"
            transformOrigin: Item.Center

            ParallelAnimation {
                id: camPop

                NumberAnimation {
                    target: camDot
                    property: "scale"
                    from: 0
                    to: 1
                    duration: 180
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: camDot
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            Connections {
                function onCamActiveChanged() {
                    if (root.camActive)
                        camPop.restart();
                }

                target: root
            }
        }

        // Bluetooth connect/disconnect: icon slides+fades in on connect,
        // lingers briefly then retracts/fades on disconnect.
        Rectangle {
            id: btIcon
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12
            radius: 6
            visible: btShown !== ""
            color: Theme.primary

            property string btShown: ""

            transform: Translate {
                id: btSlide
            }

            ShellText {
                anchors.centerIn: parent
                text: "󰂯"
                font.family: Theme.iconFontFamily
                font.pixelSize: 8
                color: "#000000"
            }

            SequentialAnimation {
                id: btSlideAnim

                ParallelAnimation {
                    NumberAnimation {
                        target: btSlide
                        property: "x"
                        from: 14
                        to: 0
                        duration: 300
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: btIcon
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }

            SequentialAnimation {
                id: btFadeOut

                PauseAnimation {
                    duration: 400
                }

                NumberAnimation {
                    target: btIcon
                    property: "opacity"
                    to: 0
                    duration: 300
                    easing.type: Easing.OutCubic
                }

                ScriptAction {
                    script: btIcon.btShown = ""
                }

                PropertyAction {
                    target: btIcon
                    property: "opacity"
                    value: 1
                }
            }

            Connections {
                function onBtConnectedChanged() {
                    if (root.btConnected !== "") {
                        btFadeOut.stop();
                        btIcon.btShown = root.btConnected;
                        btIcon.opacity = 1;
                        btSlideAnim.restart();
                    } else if (btIcon.btShown !== "") {
                        btFadeOut.restart();
                    }
                }

                target: root
            }
        }
    }

    // Volume takeover: exclusive state over the fill, nothing else visible.
    // Dark chip keeps the text readable at any fill level.
    Rectangle {
        anchors.centerIn: parent
        width: volRow.width + 14
        height: 18
        radius: 9
        visible: root.volumeActive
        color: "#90000000"

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: volRow
            anchors.centerIn: parent
            spacing: 5
            transformOrigin: Item.Center

            // Swap pop: icon/%-text changes (incl. mute) punch in lightly.
            // Coalesced via restart; gated to the exclusive volume window.
            ParallelAnimation {
                id: volPop

                NumberAnimation {
                    target: volRow
                    property: "scale"
                    from: 0.85
                    to: 1
                    duration: 120
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: volRow
                    property: "opacity"
                    from: 0.4
                    to: 1
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            Connections {
                function onVolumeTextChanged() {
                    if (root.volumeActive)
                        volPop.restart();
                }

                function onVolumeMutedChanged() {
                    if (root.volumeActive)
                        volPop.restart();
                }

                target: root
            }

            ShellText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.volumeMuted ? "󰝟" : "󰕾"
                color: Theme.shellForeground
                font.family: Theme.iconFontFamily
                font.pixelSize: 12
                font.weight: Font.Bold
            }

            ShellText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.volumeText
                color: Theme.shellForeground
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
    }
}
