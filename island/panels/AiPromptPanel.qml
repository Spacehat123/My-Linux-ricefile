import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../components"

FocusScope {
    id: root

    implicitHeight: IslandHub.aiHasReferenceImage ? 154 : 110
    Behavior on implicitHeight {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    width: parent ? parent.width : 540

    function takeInitialFocus() {
        promptInput.forceActiveFocus(Qt.TabFocusReason);
        promptInput.selectAll();
        IslandHub.preloadAiDaemon();
    }

    function submitPrompt() {
        const text = promptInput.text.trim();
        if (text.length === 0) return;
        promptInput.text = "";
        const refImage = IslandHub.aiReferenceImage;
        IslandHub.clearAiReferenceImage();
        ShellState.close();
        IslandHub.triggerAiGeneration(text, refImage);
    }

    // Background Process for Native File Picker
    Process {
        id: filePickerProc
        command: ["zenity", "--file-selection", "--title=Select Reference Image", "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.bmp *.PNG *.JPG *.JPEG"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const path = line.trim();
                if (path.length > 0) {
                    IslandHub.setAiReferenceImage(path);
                }
            }
        }
    }

    // Panel-wide DropArea for Image Files
    DropArea {
        id: panelDropArea
        anchors.fill: parent
        onEntered: (drag) => {
            if (drag.hasUrls) drag.acceptProposedAction();
        }
        onDropped: (drop) => {
            if (drop.hasUrls && drop.urls.length > 0) {
                let u = drop.urls[0].toString();
                if (u.startsWith("file://")) {
                    u = decodeURIComponent(u.substring(7));
                }
                IslandHub.setAiReferenceImage(u);
                drop.acceptProposedAction();
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 7

        // =====================================================================
        // HEADER: Studio branding + Mode Badges + Action Buttons
        // =====================================================================
        Item {
            width: parent.width
            height: 24

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: Qt.rgba(Theme.purple.r, Theme.purple.g, Theme.purple.b, 0.2)
                    anchors.verticalCenter: parent.verticalCenter

                    ShellText {
                        anchors.centerIn: parent
                        text: "󱨊"
                        color: Theme.purple
                        font.pixelSize: 13
                    }
                }

                ShellText {
                    text: "AI Studio"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.foreground
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    height: 18
                    width: loraBadgeText.implicitWidth + 10
                    radius: 9
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                    anchors.verticalCenter: parent.verticalCenter

                    ShellText {
                        id: loraBadgeText
                        anchors.centerIn: parent
                        text: "LCM 0.8"
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: Theme.primary
                    }
                }

                // Img2Img Indicator Badge
                Rectangle {
                    height: 18
                    width: modeBadgeRow.implicitWidth + 10
                    radius: 9
                    color: IslandHub.aiHasReferenceImage 
                        ? Qt.rgba(Theme.yellow.r, Theme.yellow.g, Theme.yellow.b, 0.18)
                        : Qt.rgba(1.0, 1.0, 1.0, 0.06)
                    border.color: IslandHub.aiHasReferenceImage
                        ? Qt.rgba(Theme.yellow.r, Theme.yellow.g, Theme.yellow.b, 0.5)
                        : "transparent"
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: modeBadgeRow
                        anchors.centerIn: parent
                        spacing: 3

                        ShellText {
                            text: IslandHub.aiHasReferenceImage ? "󰄄" : "󰹍"
                            font.pixelSize: 9
                            color: IslandHub.aiHasReferenceImage ? Theme.yellow : Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        ShellText {
                            text: IslandHub.aiHasReferenceImage ? "img2img" : "text2img"
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            color: IslandHub.aiHasReferenceImage ? Theme.yellow : Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // 1. Aspect Ratio Toggle (1:1 <-> 16:9)
                Rectangle {
                    id: aspectBtn
                    height: 20
                    width: aspectRow.implicitWidth + 14
                    radius: 10
                    color: aspectMouse.containsMouse 
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28) 
                        : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animationFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animationFast } }

                    Row {
                        id: aspectRow
                        anchors.centerIn: parent
                        spacing: 4

                        ShellText {
                            text: IslandHub.aiAspectRatio === "16:9" ? "󰹑" : "󰹍"
                            font.pixelSize: 10
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        ShellText {
                            text: IslandHub.aiAspectRatio === "16:9" ? "16:9" : "1:1"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: aspectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: IslandHub.toggleAiAspectRatio()
                    }
                }

                // 2. Steps Selector (6, 8, 10, 12)
                Rectangle {
                    id: stepsBtn
                    height: 20
                    width: stepsRow.implicitWidth + 14
                    radius: 10
                    color: stepsMouse.containsMouse 
                        ? Qt.rgba(Theme.yellow.r, Theme.yellow.g, Theme.yellow.b, 0.28) 
                        : Qt.rgba(Theme.yellow.r, Theme.yellow.g, Theme.yellow.b, 0.15)
                    border.color: Qt.rgba(Theme.yellow.r, Theme.yellow.g, Theme.yellow.b, 0.45)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animationFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animationFast } }

                    Row {
                        id: stepsRow
                        anchors.centerIn: parent
                        spacing: 4

                        ShellText {
                            text: "󰑮"
                            font.pixelSize: 10
                            color: Theme.yellow
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        ShellText {
                            text: (IslandHub.aiSteps || 8) + " steps"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: stepsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: IslandHub.cycleAiSteps()
                    }
                }

                // 3. Auto-open toggle button
                Rectangle {
                    id: autoOpenBtn
                    height: 20
                    width: autoOpenRow.implicitWidth + 14
                    radius: 10
                    color: IslandHub.aiAutoOpen
                        ? (autoOpenMouse.containsMouse ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.28) : Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.15))
                        : (autoOpenMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.12) : Qt.rgba(1.0, 1.0, 1.0, 0.05))
                    border.color: IslandHub.aiAutoOpen
                        ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.45)
                        : Qt.rgba(1.0, 1.0, 1.0, 0.12)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animationFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animationFast } }

                    Row {
                        id: autoOpenRow
                        anchors.centerIn: parent
                        spacing: 4

                        ShellText {
                            text: IslandHub.aiAutoOpen ? "󰈈" : "󰈉"
                            font.pixelSize: 10
                            color: IslandHub.aiAutoOpen ? Theme.green : Theme.mutedDark
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        ShellText {
                            text: IslandHub.aiAutoOpen ? "Auto-open" : "Manual"
                            font.pixelSize: 9
                            font.weight: IslandHub.aiAutoOpen ? Font.SemiBold : Font.Normal
                            color: IslandHub.aiAutoOpen ? Theme.foreground : Theme.mutedDark
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: autoOpenMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: IslandHub.toggleAiAutoOpen()
                    }
                }

                // 4. Studio Chat WebUI Launcher
                Rectangle {
                    id: studioChatBtn
                    height: 20
                    width: studioChatRow.implicitWidth + 14
                    radius: 10
                    color: studioChatMouse.containsMouse 
                        ? Qt.rgba(Theme.purple.r, Theme.purple.g, Theme.purple.b, 0.28) 
                        : Qt.rgba(Theme.purple.r, Theme.purple.g, Theme.purple.b, 0.15)
                    border.color: Qt.rgba(Theme.purple.r, Theme.purple.g, Theme.purple.b, 0.45)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animationFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animationFast } }

                    Row {
                        id: studioChatRow
                        anchors.centerIn: parent
                        spacing: 4

                        ShellText {
                            text: "󰭹"
                            font.pixelSize: 10
                            color: Theme.purple
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        ShellText {
                            text: "Chat"
                            font.pixelSize: 9
                            font.weight: Font.SemiBold
                            color: Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: studioChatMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached([Quickshell.shellPath("scripts/launch-chat.sh")]);
                        }
                    }
                }
            }
        }

        // =====================================================================
        // ROW 2: REFERENCE IMAGE DROP SLOT + PROMPT TEXT FIELD
        // =====================================================================
        Row {
            width: parent.width
            height: 38
            spacing: 8

            // Drop Zone & Reference Thumbnail Slot
            Rectangle {
                id: refDropSlot
                width: IslandHub.aiHasReferenceImage ? 38 : 78
                height: 38
                radius: Theme.radiusSmall
                color: IslandHub.aiHasReferenceImage
                    ? "transparent"
                    : (refDropMouse.containsMouse || panelDropArea.containsDrag
                        ? Qt.rgba(Theme.purple.r, Theme.purple.g, Theme.purple.b, 0.22)
                        : Qt.rgba(1.0, 1.0, 1.0, 0.05))
                border.color: refDropMouse.containsMouse || panelDropArea.containsDrag
                    ? Theme.purple
                    : (IslandHub.aiHasReferenceImage ? Theme.glassBorder : Theme.glassBorderSubtle)
                border.width: 1
                clip: true

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.animationFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.animationFast } }

                // State 1: Reference Photo Selected
                Item {
                    anchors.fill: parent
                    visible: IslandHub.aiHasReferenceImage

                    Image {
                        anchors.fill: parent
                        source: IslandHub.aiHasReferenceImage ? ("file://" + IslandHub.aiReferenceImage) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    // Hover Clear Button Overlay
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.45)
                        opacity: refDropMouse.containsMouse ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        ShellText {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#FFFFFF"
                        }
                    }
                }

                // State 2: Empty Drop Zone / Add Photo Button
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    visible: !IslandHub.aiHasReferenceImage

                    ShellText {
                        text: "󰄄"
                        font.pixelSize: 12
                        color: refDropMouse.containsMouse ? Theme.purple : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ShellText {
                        text: "+ Photo"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: refDropMouse.containsMouse ? Theme.foreground : Theme.mutedDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: refDropMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (IslandHub.aiHasReferenceImage) {
                            IslandHub.clearAiReferenceImage();
                        } else {
                            if (!filePickerProc.running) {
                                filePickerProc.running = true;
                            }
                        }
                    }
                }
            }

            // Prompt Input Field
            Rectangle {
                id: inputContainer
                width: parent.width - refDropSlot.width - 8
                height: 38
                radius: Theme.radiusSmall
                color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
                border.color: promptInput.activeFocus ? Theme.glassBorderActive : Theme.glassBorder
                border.width: promptInput.activeFocus ? 1.5 : 1

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: Theme.animationFast } }

                TextInput {
                    id: promptInput
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    clip: true
                    selectByMouse: true
                    activeFocusOnTab: true

                    Keys.onReturnPressed: root.submitPrompt()
                    Keys.onEnterPressed: root.submitPrompt()
                    Keys.onEscapePressed: {
                        promptInput.text = "";
                        IslandHub.clearAiReferenceImage();
                        ShellState.close();
                    }

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: IslandHub.aiHasReferenceImage 
                            ? "Describe modifications to reference photo..." 
                            : "Describe the image you want to generate..."
                        color: Theme.mutedDark
                        font.pixelSize: 13
                        visible: !promptInput.text
                    }
                }
            }
        }

        // =====================================================================
        // ROW 3: STRENGTH SLIDER & QUICK PRESETS (Only shown in img2img mode)
        // =====================================================================
        Item {
            id: strengthRow
            width: parent.width
            height: 26
            visible: IslandHub.aiHasReferenceImage
            opacity: IslandHub.aiHasReferenceImage ? 1.0 : 0.0

            Behavior on opacity { NumberAnimation { duration: 150 } }

            function updateFromMouse(mx) {
                const grooveW = sliderGroove.width;
                const ratio = Math.max(0.0, Math.min(1.0, mx / grooveW));
                const val = 0.10 + ratio * (0.95 - 0.10);
                IslandHub.setAiStrength(Math.round(val * 100) / 100);
            }

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Label & Value
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    ShellText {
                        text: "󰓎"
                        font.pixelSize: 11
                        color: Theme.yellow
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ShellText {
                        text: "Strength:"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ShellText {
                        text: Math.round(IslandHub.aiStrength * 100) + "%"
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.yellow
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Interactive Slider Groove
                Rectangle {
                    id: sliderGroove
                    width: 130
                    height: 6
                    radius: 3
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                    anchors.verticalCenter: parent.verticalCenter

                    // Filled Track
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(0, Math.min(parent.width, ((IslandHub.aiStrength - 0.10) / (0.95 - 0.10)) * parent.width))
                        radius: 3
                        color: Theme.yellow
                    }

                    // Draggable Thumb
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "#FFFFFF"
                        border.color: Theme.yellow
                        border.width: 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(sliderGroove.width - 12, ((IslandHub.aiStrength - 0.10) / (0.95 - 0.10)) * (sliderGroove.width - 12)))
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (mouse) => strengthRow.updateFromMouse(mouse.x)
                        onPressed: (mouse) => strengthRow.updateFromMouse(mouse.x)
                    }
                }

                // Presets: Subtle (30%), Balanced (65%), Restyle (85%)
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: [
                            { label: "30%", val: 0.30 },
                            { label: "65%", val: 0.65 },
                            { label: "85%", val: 0.85 }
                        ]

                        Rectangle {
                            height: 18
                            width: chipText.implicitWidth + 8
                            radius: 9
                            color: Math.abs(IslandHub.aiStrength - modelData.val) < 0.05
                                ? Qt.rgba(Theme.yellow.r, Theme.yellow.g, Theme.yellow.b, 0.28)
                                : (chipMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.1) : Qt.rgba(1.0, 1.0, 1.0, 0.05))
                            border.color: Math.abs(IslandHub.aiStrength - modelData.val) < 0.05
                                ? Theme.yellow
                                : "transparent"
                            border.width: 1

                            ShellText {
                                id: chipText
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                                color: Math.abs(IslandHub.aiStrength - modelData.val) < 0.05 ? Theme.yellow : Theme.muted
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandHub.setAiStrength(modelData.val)
                            }
                        }
                    }
                }
            }

            // Mode interpretation hint
            ShellText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: IslandHub.aiStrength < 0.45 
                    ? "Subtle variation" 
                    : (IslandHub.aiStrength > 0.75 ? "Heavy restyle" : "Balanced")
                font.pixelSize: 9
                color: Theme.mutedDark
            }
        }

        // =====================================================================
        // ROW 4: ACTION HINTS & SUBMIT BUTTON
        // =====================================================================
        Item {
            width: parent.width
            height: 24

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        height: 16
                        width: 44
                        radius: 4
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
                        anchors.verticalCenter: parent.verticalCenter

                        ShellText {
                            anchors.centerIn: parent
                            text: "Enter ↵"
                            font.pixelSize: 9
                            color: Theme.muted
                        }
                    }

                    ShellText {
                        text: "Generate"
                        font.pixelSize: 10
                        color: Theme.mutedDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        height: 16
                        width: 32
                        radius: 4
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
                        anchors.verticalCenter: parent.verticalCenter

                        ShellText {
                            anchors.centerIn: parent
                            text: "Esc"
                            font.pixelSize: 9
                            color: Theme.muted
                        }
                    }

                    ShellText {
                        text: "Cancel"
                        font.pixelSize: 10
                        color: Theme.mutedDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Rectangle {
                id: genButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                width: genBtnRow.implicitWidth + 16
                radius: 12
                color: genMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.9) : Theme.primary

                Row {
                    id: genBtnRow
                    anchors.centerIn: parent
                    spacing: 5

                    ShellText {
                        text: IslandHub.aiHasReferenceImage ? "󰄄" : "󱨊"
                        font.pixelSize: 11
                        color: "#000000"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ShellText {
                        text: IslandHub.aiHasReferenceImage ? "Style Image" : "Generate"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: "#000000"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: genMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submitPrompt()
                }
            }
        }
    }
}
