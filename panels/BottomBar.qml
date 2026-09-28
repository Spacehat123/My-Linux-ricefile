import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower

// Waybar replica: bottom bar, width 1000, margin-bottom 10.
// Source of truth: ~/.config/waybar/config.jsonc + style.css
// Left: hyprland/workspaces | Center: clock | Right: network, pulseaudio, battery
// Visibility (start hidden, 2px edge reveal, hide on leave) is driven by
// shell.qml via `open` + `hovered`, backed by the bottom-center EdgeTrigger.
PanelWindow {
    id: root

    property bool open: false
    visible: open || closeAnim.running

    // Injected models (wired in shell.qml)
    property var desktopModel: null
    property var interactionModel: null
    property var desktopState: null

    // Hover continuity: full-fill hover guard (same convention as the sidebars).
    // Child pill MouseAreas use hoverEnabled clicks; hover propagates to all
    // MouseAreas under the cursor, so shell.qml can hide the bar only when the
    // pointer truly leaves it.
    MouseArea {
        id: barMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
    // Covers the workspace Repeater (delegate MouseAreas aren't addressable
    // as a single id); NoButton so workspace clicks pass through.
    MouseArea {
        id: wsHover
        anchors.fill: wsRow
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
    readonly property bool hovered: barMouse.containsMouse || wsHover.containsMouse || netMouse.containsMouse || volMouse.containsMouse || batMouse.containsMouse

    // ---- Waybar palette (style.css) ----
    readonly property color wbBg: Qt.rgba(0, 0, 0, 0.62)
    readonly property color wbBgHover: Qt.rgba(1, 1, 1, 0.4)
    readonly property color wbText: "#d7d7d7"
    readonly property color wbTextHover: "#a3a1a1"
    readonly property color wbBorder: "#454446"
    readonly property string wbFont: "JetBrainsMono Nerd Font Propo"
    readonly property int wbFontSize: 12

    anchors {
        bottom: true
    }
    margins {
        bottom: 10
    }

    implicitWidth: Math.min(1000, (screen ? screen.width : 1040) - 40)
    implicitHeight: 30
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    WlrLayershell.namespace: "pranc-shell"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ---- Live system state ----
    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    // Pulseaudio: polled via wpctl (matches waybar's "{volume}%" / muted icon).
    property string volText: "--"
    property bool audioMuted: false
    Process {
        id: volPoll
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "Volume: 0.23" or "Volume: 0.23 [MUTED]"
                const m = text.match(/Volume:\s+([0-9.]+)(.*)/);
                if (m) {
                    root.audioMuted = m[2].indexOf("MUTED") !== -1;
                    root.volText = Math.round(parseFloat(m[1]) * 100) + "%";
                }
            }
        }
    }
    // Re-poll shortly after a wheel adjustment lands
    Timer {
        id: volSettle
        interval: 300
        onTriggered: volPoll.running = true
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!volSettle.running) volPoll.running = true;
        }
    }

    property var bat: UPower.displayDevice
    property bool batReady: bat ? bat.ready : false
    property real batPct: batReady ? (bat.percentage * 100.0) : -1

    function batteryIcon(p) {
        if (p >= 80) return "";
        if (p >= 60) return "";
        if (p >= 40) return "";
        if (p >= 20) return "";
        return "";
    }

    // Network: waybar monitors wlp4s0; bar shows wifi/ethernet/disconnected icon.
    property string netIcon: ""
    Process {
        id: netProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let wifi = false, eth = false;
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; ++i) {
                    const parts = lines[i].split(":");
                    if (parts.length < 2 || parts[1] !== "connected") continue;
                    if (parts[0] === "wifi") wifi = true;
                    else if (parts[0] === "ethernet") eth = true;
                }
                // format-wifi "" / format-ethernet "{ifname} " / disconnected ""
                root.netIcon = wifi ? "" : (eth ? "" : "");
            }
        }
    }
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: netProc.running = true
    }

    Process {
        id: volProc
    }

    Component.onCompleted: {
        netProc.running = true;
        volPoll.running = true;
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0.0

        transform: Translate {
            id: contentTranslate
            y: 10
        }

        // ---- Left: workspaces (format "{name}") ----
        Row {
            id: wsRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4 // margin 0 2px per button

            Repeater {
                model: root.desktopModel && root.desktopModel.workspaces ? root.desktopModel.workspaces : []

                delegate: Rectangle {
                    id: wsBtn
                    required property var modelData

                    readonly property int wsId: modelData ? modelData.id : -1
                    readonly property bool isActive: modelData ? Boolean(modelData.focused) : false
                    readonly property string wsLabel: modelData ? (modelData.name || String(modelData.id)) : ""

                    height: 20
                    width: Math.max(isActive ? 35 : 0, wsLabelText.implicitWidth + 20) // padding 0 5px
                    radius: isActive ? 15 : 10
                    color: wsMouse.containsMouse ? root.wbBgHover : (isActive ? Qt.rgba(1, 1, 1, 0.4) : root.wbBg)
                    border.color: root.wbBorder
                    border.width: 1

                    Text {
                        id: wsLabelText
                        anchors.centerIn: parent
                        text: wsBtn.wsLabel
                        font.family: root.wbFont
                        font.pixelSize: root.wbFontSize
                        font.bold: wsBtn.isActive || wsMouse.containsMouse
                        font.weight: (wsBtn.isActive || wsMouse.containsMouse) ? Font.Bold : Font.Normal
                        color: (wsBtn.isActive || wsMouse.containsMouse) ? root.wbTextHover : root.wbText
                    }

                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.interactionModel && wsBtn.wsId !== -1)
                                root.interactionModel.requestWorkspaceSwitch(wsBtn.wsId);
                        }
                    }
                }
            }
        }

        // ---- Center: clock (format-alt "%a, %d. %b  %H:%M", bold) ----
        Text {
            id: clockText
            anchors.centerIn: parent
            text: Qt.formatDateTime(sysClock.date, "ddd, dd. MMM  hh:mm")
            font.family: root.wbFont
            font.pixelSize: root.wbFontSize
            font.bold: true
            font.weight: Font.Bold
            color: "#ffffff"
        }

        // ---- Right: network, pulseaudio, battery pills ----
        Row {
            id: sysRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 20 // margin 0 10px per module

            // Network (no on-click in waybar)
            Rectangle {
                id: netPill
                height: 22
                width: Math.max(30, netLabel.implicitWidth + 10)
                radius: 11
                color: netMouse.containsMouse ? root.wbBgHover : root.wbBg
                border.color: root.wbBorder
                border.width: 1

                Text {
                    id: netLabel
                    anchors.centerIn: parent
                    text: root.netIcon
                    font.family: root.wbFont
                    font.pixelSize: root.wbFontSize
                    font.bold: netMouse.containsMouse
                    color: netMouse.containsMouse ? root.wbTextHover : root.wbText
                }
                MouseArea {
                    id: netMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            // Pulseaudio: "{volume}%" / muted "󰸈", click -> pavucontrol, scroll -> volume
            Rectangle {
                id: volPill
                height: 22
                width: Math.max(30, volLabel.implicitWidth + 10)
                radius: 11
                color: volMouse.containsMouse ? root.wbBgHover : root.wbBg
                border.color: root.wbBorder
                border.width: 1

                Text {
                    id: volLabel
                    anchors.centerIn: parent
                    text: root.audioMuted ? "󰸈" : root.volText
                    font.family: root.wbFont
                    font.pixelSize: root.wbFontSize
                    font.bold: volMouse.containsMouse
                    color: volMouse.containsMouse ? root.wbTextHover : root.wbText
                }
                MouseArea {
                    id: volMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["pavucontrol"])
                    onWheel: {
                        const step = wheel.angleDelta.y > 0 ? "1%+" : "1%-"; // scroll-step 1
                        volProc.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", step]);
                        volSettle.restart();
                    }
                }
            }

            // Battery: "{capacity} {icon}"
            Rectangle {
                id: batPill
                visible: root.batReady && root.batPct >= 0
                height: 22
                width: Math.max(30, batLabel.implicitWidth + 10)
                radius: 11
                color: batMouse.containsMouse ? root.wbBgHover : root.wbBg
                border.color: root.wbBorder
                border.width: 1

                Text {
                    id: batLabel
                    anchors.centerIn: parent
                    text: Math.round(root.batPct) + " " + root.batteryIcon(root.batPct)
                    font.family: root.wbFont
                    font.pixelSize: root.wbFontSize
                    font.bold: batMouse.containsMouse
                    color: batMouse.containsMouse ? root.wbTextHover : root.wbText
                }
                MouseArea {
                    id: batMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: contentTranslate
            property: "y"
            to: 0
            duration: 200
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 1.0
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: contentTranslate
            property: "y"
            to: 10
            duration: 160
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 0.0
            duration: 160
            easing.type: Easing.InCubic
        }
    }

    onOpenChanged: {
        if (open) {
            closeAnim.stop();
            openAnim.start();
        } else {
            openAnim.stop();
            closeAnim.start();
        }
    }
}
