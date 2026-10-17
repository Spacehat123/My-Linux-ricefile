import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import ".."
import "../components"

FocusScope {
    id: root

    property string mode: "region"
    property bool recordingMode: false
    readonly property var source: Pipewire.defaultAudioSource
    readonly property color accent: recordingMode ? Theme.red : Theme.primary
    readonly property var currentMode: {
        const modes = {
            "full": {
                "title": "Full screen",
                "shortTitle": "Display",
                "description": "Everything on this display"
            },
            "window": {
                "title": "Window",
                "shortTitle": "Window",
                "description": "Pick an open window"
            },
            "region": {
                "title": "Region",
                "shortTitle": "Area",
                "description": "Draw a frame on screen"
            }
        };
        return modes[mode];
    }

    function takeInitialFocus() {
        const modes = ["full", "window", "region"];
        focusCaptureMode(Math.max(0, modes.indexOf(mode)));
    }

    function focusCaptureMode(index) {
        const count = captureModes.count;
        const next = (index + count) % count;
        const item = captureModes.itemAt(next);
        if (item) {
            mode = item.modelData.key;
            item.forceActiveFocus(Qt.TabFocusReason);
        }
    }

    implicitWidth: 367
    implicitHeight: content.implicitHeight

    PwObjectTracker {
        objects: [root.source]
    }

    Timer {
        id: captureDelay

        interval: Theme.animationNormal + 100
        onTriggered: Backend.capture(root.mode)
    }

    Timer {
        id: recordDelay

        interval: Theme.animationNormal + 100
        onTriggered: Backend.startRecording(root.mode, Backend.recordAudio)
    }

    Timer {
        id: lensDelay

        interval: Theme.animationNormal + 150
        onTriggered: Quickshell.execDetached([Quickshell.shellPath("scripts/screen-lens.sh").toString().replace(/^file:\/\//, "")])
    }

    Shortcut {
        sequence: "Return"
        enabled: ShellState.panel === "capture"
        onActivated: captureButton.activate()
    }

    Shortcut {
        sequence: "Enter"
        enabled: ShellState.panel === "capture"
        onActivated: captureButton.activate()
    }

    Column {
        id: content

        width: parent.width
        spacing: 9

        Row {
            width: parent.width
            height: 30

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - captureKind.width
                spacing: 0

                ShellText {
                    text: "Capture"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                ShellText {
                    text: root.recordingMode ? (Backend.recording ? "Recording now" : "Screen recording") : "Screen capture"
                    color: root.recordingMode && Backend.recording ? Theme.red : Theme.mutedDark
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                }
            }

            Row {
                id: captureKind

                height: parent.height
                spacing: 2

                Repeater {
                    model: [{
                        "title": "Still",
                        "icon": "󰄀",
                        "recording": false
                    }, {
                        "title": "Record",
                        "icon": "󰑊",
                        "recording": true
                    }]

                    delegate: FocusScope {
                        id: kindButton

                        required property var modelData
                        readonly property bool selected: root.recordingMode === modelData.recording

                        width: 70
                        height: parent.height
                        activeFocusOnTab: true
                        Keys.onReturnPressed: root.recordingMode = modelData.recording
                        Keys.onEnterPressed: root.recordingMode = modelData.recording
                        Keys.onSpacePressed: root.recordingMode = modelData.recording
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.title

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: kindPointer.containsMouse ? Theme.bg1 : "transparent"
                            border.width: kindButton.activeFocus ? 1 : 0
                            border.color: root.accent

                            Behavior on color {
                                ColorAnimation { duration: Theme.animationFast }
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            ShellText {
                                text: kindButton.modelData.icon
                                color: kindButton.selected ? (kindButton.modelData.recording ? Theme.red : Theme.primary) : Theme.mutedDark
                                font.pixelSize: 11
                            }

                            ShellText {
                                text: kindButton.modelData.title
                                color: kindButton.selected ? Theme.foreground : Theme.mutedDark
                                font.pixelSize: 9
                                font.weight: kindButton.selected ? Font.Bold : Font.Medium
                            }
                        }

                        MouseArea {
                            id: kindPointer

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.recordingMode = kindButton.modelData.recording
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: 118
            spacing: 8

            Rectangle {
                width: 105
                height: parent.height
                radius: Theme.radius
                color: Theme.bg0
                border.width: 1
                border.color: Qt.rgba(0.83, 0.78, 0.67, 0.06)

                Column {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 2

                    Repeater {
                        id: captureModes

                        model: [{
                            "key": "full",
                            "icon": "󰍹",
                            "title": "Display"
                        }, {
                            "key": "window",
                            "icon": "󰖲",
                            "title": "Window"
                        }, {
                            "key": "region",
                            "icon": "󰆞",
                            "title": "Area"
                        }]

                        delegate: FocusScope {
                            id: targetButton

                            required property var modelData
                            required property int index
                            readonly property bool selected: root.mode === modelData.key

                            width: parent.width
                            height: 34
                            activeFocusOnTab: true
                            Keys.onReturnPressed: root.focusCaptureMode(index)
                            Keys.onEnterPressed: root.focusCaptureMode(index)
                            Keys.onSpacePressed: root.focusCaptureMode(index)
                            Keys.onUpPressed: root.focusCaptureMode(index - 1)
                            Keys.onDownPressed: root.focusCaptureMode(index + 1)
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.title

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusSmall
                                color: targetButton.selected ? (root.recordingMode ? Qt.rgba(0.90, 0.49, 0.50, 0.14) : Theme.primaryContainer) : (targetPointer.containsMouse ? Theme.bg1 : "transparent")
                                border.width: targetButton.activeFocus ? 1 : 0
                                border.color: root.accent

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animationFast }
                                }
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                ShellText {
                                    width: 15
                                    text: targetButton.modelData.icon
                                    color: targetButton.selected ? root.accent : Theme.mutedDark
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                ShellText {
                                    text: targetButton.modelData.title
                                    color: targetButton.selected ? Theme.foreground : Theme.muted
                                    font.pixelSize: 9
                                    font.weight: targetButton.selected ? Font.DemiBold : Font.Medium
                                }
                            }

                            MouseArea {
                                id: targetPointer

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.focusCaptureMode(targetButton.index)
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: viewfinder

                width: parent.width - 113
                height: parent.height
                radius: Theme.radius
                color: Theme.bg0
                border.width: 1
                border.color: Qt.rgba(0.83, 0.78, 0.67, 0.08)
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 9
                    border.color: Qt.rgba(0.12, 0.14, 0.15, 0.18)
                }

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 11
                    anchors.rightMargin: 11
                    anchors.topMargin: 8
                    height: 20

                    ShellText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.recordingMode ? (root.currentMode.shortTitle + " Recording") : root.currentMode.shortTitle
                        color: root.accent
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        visible: root.recordingMode && Backend.recording

                        ShellText {
                            text: "Recording"
                            color: Theme.red
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5
                            height: 5
                            radius: 3
                            color: Theme.red
                        }
                    }

                    FocusScope {
                        id: micPill

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.recordingMode && !Backend.recording
                        width: micContent.implicitWidth + 14
                        height: 20
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Toggle microphone audio"

                        function toggle() {
                            Backend.recordAudio = !Backend.recordAudio;
                            if (Backend.recordAudio && root.source && root.source.audio && root.source.audio.muted)
                                root.source.audio.muted = false;
                        }

                        Keys.onReturnPressed: toggle()
                        Keys.onEnterPressed: toggle()
                        Keys.onSpacePressed: toggle()

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: micPointer.containsMouse ? Theme.bg2 : (Backend.recordAudio ? Qt.rgba(0.90, 0.49, 0.50, 0.12) : Theme.bg1)
                            border.width: micPill.activeFocus ? 1 : (Backend.recordAudio ? 1 : 0)
                            border.color: Backend.recordAudio ? Qt.rgba(0.90, 0.49, 0.50, 0.35) : Theme.bg2

                            Behavior on color {
                                ColorAnimation { duration: Theme.animationFast }
                            }
                        }

                        Row {
                            id: micContent

                            anchors.centerIn: parent
                            spacing: 4

                            ShellText {
                                text: !Backend.recordAudio ? "󰍭" : (root.source && root.source.audio && root.source.audio.muted ? "󰍭" : "󰍬")
                                color: Backend.recordAudio ? Theme.red : Theme.mutedDark
                                font.pixelSize: 10
                            }

                            ShellText {
                                text: !Backend.recordAudio ? "Mic Off" : (root.source && root.source.audio && root.source.audio.muted ? "Muted" : "Mic On")
                                color: Backend.recordAudio ? Theme.foreground : Theme.mutedDark
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: micPointer

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: micPill.toggle()
                        }
                    }
                }

                Rectangle {
                    id: displayFrame

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 31
                    width: parent.width - 46
                    height: 56
                    radius: 3
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.bg3

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.mode === "full" ? parent.width : (root.mode === "window" ? 126 : 111)
                        height: root.mode === "full" ? parent.height : (root.mode === "window" ? 48 : 38)
                        radius: root.mode === "window" ? 4 : 1
                        color: root.recordingMode ? Qt.rgba(0.90, 0.49, 0.50, 0.08) : (root.mode === "window" ? Theme.primaryContainer : Qt.rgba(0.65, 0.75, 0.50, 0.08))
                        border.width: 1
                        border.color: root.accent

                        Behavior on width {
                            NumberAnimation { duration: Theme.animationNormal; easing.type: Easing.OutCubic }
                        }

                        Behavior on height {
                            NumberAnimation { duration: Theme.animationNormal; easing.type: Easing.OutCubic }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 5
                            spacing: 3
                            visible: root.mode === "window"

                            Repeater {
                                model: 3

                                Rectangle {
                                    width: 3
                                    height: 3
                                    radius: 2
                                    color: index === 0 ? Theme.red : Theme.mutedDark
                                }
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            radius: 9
                            color: Theme.red
                            visible: root.recordingMode

                            Rectangle {
                                anchors.centerIn: parent
                                width: 6
                                height: 6
                                radius: Backend.recording ? 1 : 3
                                color: Theme.bgDim
                            }
                        }

                        Repeater {
                            model: root.mode === "region" ? 4 : 0

                            Rectangle {
                                required property int index

                                x: index % 2 === 0 ? -2 : parent.width - 2
                                y: index < 2 ? -2 : parent.height - 2
                                width: 4
                                height: 4
                                radius: 1
                                color: root.accent
                            }
                        }
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 11
                    anchors.rightMargin: 11
                    anchors.bottomMargin: 8

                    ShellText {
                        width: parent.width
                        text: root.recordingMode ? (root.currentMode.description + (Backend.recordAudio ? (root.source && root.source.description ? (" · " + root.source.description) : " · Mic audio") : " · Video only")) : root.currentMode.description
                        color: Theme.muted
                        font.pixelSize: 8
                        elide: Text.ElideRight
                    }
                }
            }
        }

        FocusScope {
            id: captureButton

            function activate() {
                if (root.recordingMode) {
                    if (Backend.recording) {
                        Backend.stopRecording();
                    } else {
                        ShellState.close();
                        recordDelay.restart();
                    }
                } else {
                    ShellState.close();
                    captureDelay.restart();
                }
            }

            width: parent.width
            height: 42
            activeFocusOnTab: true
            Keys.onReturnPressed: activate()
            Keys.onEnterPressed: activate()
            Keys.onSpacePressed: activate()
            Accessible.role: Accessible.Button
            Accessible.name: root.recordingMode ? (Backend.recording ? "Stop recording" : "Start recording") : "Take screenshot"

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: actionPointer.containsMouse ? Theme.bg1 : Theme.bg0
                border.width: parent.activeFocus ? 1 : 0
                border.color: root.accent

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast }
                }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    text: root.recordingMode ? (Backend.recording ? "󰓛" : "󰑊") : "󰄀"
                    color: root.accent
                    font.pixelSize: 15
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 70
                    spacing: 0

                    ShellText {
                        text: root.recordingMode ? (Backend.recording ? "Stop recording" : "Record " + root.currentMode.title.toLowerCase()) : "Capture " + root.currentMode.title.toLowerCase()
                        color: Theme.foreground
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }

                    ShellText {
                        text: root.recordingMode ? (Backend.recording ? "Recording in progress" : (root.currentMode.shortTitle + " · " + (Backend.recordAudio ? "MP4 + Audio" : "MP4 video"))) : "Saved to Pictures"
                        color: Theme.mutedDark
                        font.pixelSize: 7
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 22
                    radius: Theme.radiusSmall
                    color: Theme.bg1
                    border.width: 1
                    border.color: Theme.bg2

                    ShellText {
                        anchors.centerIn: parent
                        text: "↵"
                        color: Theme.muted
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }
            }

            MouseArea {
                id: actionPointer

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: captureButton.activate()
            }
        }

        FocusScope {
            id: lensButton
            width: parent.width
            height: 36
            activeFocusOnTab: true
            Keys.onReturnPressed: activateLens()
            Keys.onEnterPressed: activateLens()
            Keys.onSpacePressed: activateLens()

            function activateLens() {
                ShellState.close();
                lensDelay.restart();
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: lensPointer.containsMouse ? Theme.bg1 : Theme.bg0
                border.width: 1
                border.color: lensPointer.containsMouse ? Theme.primary : Qt.rgba(0.83, 0.78, 0.67, 0.08)

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast }
                }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    text: "󰄀"
                    color: Theme.primary
                    font.pixelSize: 14
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 90
                    spacing: 0

                    ShellText {
                        text: "Screen Lens"
                        color: Theme.foreground
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }

                    ShellText {
                        text: "OCR, QR, & Color to Clipboard"
                        color: Theme.mutedDark
                        font.pixelSize: 7
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 50
                    height: 20
                    radius: Theme.radiusSmall
                    color: Theme.bg1
                    border.width: 1
                    border.color: Theme.bg2

                    ShellText {
                        anchors.centerIn: parent
                        text: "󰘳 󰘶 S"
                        color: Theme.muted
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }
                }
            }

            MouseArea {
                id: lensPointer
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: lensButton.activateLens()
            }
        }

        ShellText {
            width: parent.width
            visible: Backend.lastError.length > 0 || Backend.lastCapture.length > 0
            text: Backend.lastError || Backend.lastCapture
            color: Backend.lastError ? Theme.red : Theme.muted
            elide: Text.ElideMiddle
            font.pixelSize: 8
        }
    }
}
