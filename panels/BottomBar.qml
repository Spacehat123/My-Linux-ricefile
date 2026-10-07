import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import "../island" as Island

PanelWindow {
    id: root

    property bool open: false
    visible: open || closeAnim.running

    // Injected models (wired in shell.qml)
    property var desktopModel: null
    property var interactionModel: null
    property var desktopState: null

    // Hover continuity: full-fill hover guard ensures shell.qml doesn't prematurely close the dock
    MouseArea {
        id: barMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    readonly property bool hovered: barMouse.containsMouse || wsHover.containsMouse || netMouse.containsMouse || volMouse.containsMouse || batMouse.containsMouse

    anchors {
        bottom: true
    }
    margins {
        bottom: 10
    }

    implicitWidth: Math.min(980, (screen ? screen.width : 1040) - 40)
    implicitHeight: 44
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

    // Native PipeWire sink audio binding (zero process forks)
    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property bool audioMuted: sinkAudio ? sinkAudio.muted : false
    readonly property string volText: sinkAudio ? Math.round(sinkAudio.volume * 100) + "%" : "--"

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

    // Network: native NetworkManager / D-Bus properties via Quickshell.Networking (zero process forks/polling)
    readonly property var wifiDevice: Networking.devices.values.find((device) => device.type === DeviceType.Wifi) || null
    readonly property var connectedWifi: {
        if (!wifiDevice)
            return null;
        if (wifiDevice.networks) {
            const found = wifiDevice.networks.values.find((network) => network.connected);
            if (found)
                return found;
        }
        return wifiDevice.connected ? wifiDevice : null;
    }
    readonly property var ethernetDevice: Networking.devices.values.find((device) => {
        return device.type === DeviceType.Wired && (device.connected || device.hasLink === true);
    }) || null

    readonly property string netIcon: {
        if (connectedWifi)
            return "";
        if (ethernetDevice)
            return "";
        const anyConnected = Networking.devices.values.find((device) => device.connected);
        if (anyConnected)
            return anyConnected.type === DeviceType.Wifi ? "" : "";
        return "";
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0.0

        transform: Translate {
            id: contentTranslate
            y: 16
        }

        // =====================================================================
        // FLOATING LIQUID GLASS DOCK CAPSULE
        // =====================================================================
        Rectangle {
            id: dockBody
            anchors.fill: parent
            radius: 22
            color: Island.Theme.glassBackground
            border.color: Island.Theme.glassBorder
            border.width: Island.Theme.glassBorderWidth
            clip: true

            // Covers the workspace Repeater for hover tracking continuity
            MouseArea {
                id: wsHover
                anchors.fill: wsRow
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            // ---- Left: Liquid Workspace Capsules ----
            Row {
                id: wsRow
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: root.desktopModel && root.desktopModel.workspaces ? root.desktopModel.workspaces : []

                    delegate: Rectangle {
                        id: wsBtn
                        required property var modelData

                        readonly property int wsId: modelData ? modelData.id : -1
                        readonly property bool isActive: modelData ? Boolean(modelData.focused) : false
                        readonly property bool isOccupied: modelData ? (Boolean(modelData.occupied) || (modelData.surfaceCount && modelData.surfaceCount > 0)) : false
                        readonly property string wsLabel: modelData ? (modelData.name || String(modelData.id)) : ""

                        height: 28
                        width: isActive ? Math.max(46, wsLabelText.implicitWidth + 24) : (isOccupied ? 30 : 22)
                        radius: 14

                        Behavior on width {
                            SpringAnimation {
                                spring: 4.2
                                damping: 0.35
                                epsilon: 0.5
                            }
                        }

                        color: wsMouse.containsMouse
                            ? Island.Theme.glassCardHover
                            : (isActive
                                ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.22)
                                : (isOccupied ? Island.Theme.glassCard : "transparent"))

                        border.color: isActive
                            ? Island.Theme.primary
                            : (wsMouse.containsMouse ? Island.Theme.glassBorder : (isOccupied ? Island.Theme.glassBorderSubtle : "transparent"))
                        border.width: isActive ? 1.5 : 1

                        scale: wsMouse.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80 } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            // Small occupied dot indicator if not active but occupied
                            Rectangle {
                                visible: !wsBtn.isActive && wsBtn.isOccupied
                                anchors.verticalCenter: parent.verticalCenter
                                width: 4
                                height: 4
                                radius: 2
                                color: Island.Theme.muted
                            }

                            Text {
                                id: wsLabelText
                                anchors.verticalCenter: parent.verticalCenter
                                text: wsBtn.wsLabel
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: wsBtn.isActive || wsMouse.containsMouse
                                color: wsBtn.isActive ? Island.Theme.primary : (wsMouse.containsMouse ? Island.Theme.foreground : (wsBtn.isOccupied ? Island.Theme.foreground : Island.Theme.muted))
                            }
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "overview", "toggle"]);
                                    return;
                                }
                                if (root.interactionModel && wsBtn.wsId !== -1)
                                    root.interactionModel.requestWorkspaceSwitch(wsBtn.wsId);
                            }
                        }
                    }
                }

                Rectangle {
                    id: overviewBtn
                    height: 28
                    width: 28
                    radius: 14
                    color: overviewMouse.containsMouse ? Island.Theme.glassCardHover : "transparent"
                    border.color: overviewMouse.containsMouse ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰕰"
                        font.family: Island.Theme.iconFontFamily
                        font.pixelSize: 13
                        color: overviewMouse.containsMouse ? Island.Theme.primary : Island.Theme.muted
                    }

                    MouseArea {
                        id: overviewMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["qs", "-c", "cool-shell", "ipc", "call", "overview", "toggle"]);
                        }
                    }
                }
            }

            // ---- Center: Typographic Clock & Date ----
            Column {
                id: clockBlock
                anchors.centerIn: parent
                spacing: 1

                Text {
                    id: timeText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(sysClock.date, "hh:mm")
                    font.family: Island.Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: Island.Theme.foreground
                }

                Text {
                    id: dateText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(sysClock.date, "ddd, dd MMM")
                    font.family: Island.Theme.fontFamily
                    font.pixelSize: 9
                    color: Island.Theme.muted
                }
            }

            // ---- Right: System Status Module Cluster ----
            Row {
                id: sysRow
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Network Pill
                Rectangle {
                    id: netPill
                    height: 28
                    width: Math.max(34, netRow.implicitWidth + 16)
                    radius: 14
                    color: netMouse.containsMouse ? Island.Theme.glassCardHover : Island.Theme.glassCard
                    border.color: netMouse.containsMouse ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle
                    border.width: 1
                    scale: netMouse.pressed ? 0.95 : 1.0

                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: netRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.netIcon
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: netMouse.containsMouse ? Island.Theme.primary : Island.Theme.foreground
                        }
                    }

                    MouseArea {
                        id: netMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }

                // PipeWire Audio Pill
                Rectangle {
                    id: volPill
                    height: 28
                    width: Math.max(54, volRow.implicitWidth + 18)
                    radius: 14
                    color: volMouse.containsMouse ? Island.Theme.glassCardHover : Island.Theme.glassCard
                    border.color: volMouse.containsMouse ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle
                    border.width: 1
                    scale: volMouse.pressed ? 0.95 : 1.0

                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: volRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.audioMuted ? "󰖁" : (root.sinkAudio && root.sinkAudio.volume > 0.5 ? "󰕾" : "󰖀")
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: root.audioMuted ? Island.Theme.red : (volMouse.containsMouse ? Island.Theme.primary : Island.Theme.foreground)
                        }

                        Text {
                            id: volLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.audioMuted ? "Mute" : root.volText
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: volMouse.containsMouse ? Island.Theme.primary : Island.Theme.foreground
                        }
                    }

                    MouseArea {
                        id: volMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["pavucontrol"])
                        onWheel: (wheel) => {
                            if (root.sinkAudio) {
                                const step = wheel.angleDelta.y > 0 ? 0.02 : -0.02;
                                root.sinkAudio.volume = Math.max(0.0, Math.min(1.5, root.sinkAudio.volume + step));
                            }
                        }
                    }
                }

                // UPower Battery Pill
                Rectangle {
                    id: batPill
                    visible: root.batReady && root.batPct >= 0
                    height: 28
                    width: Math.max(56, batRow.implicitWidth + 18)
                    radius: 14
                    color: batMouse.containsMouse ? Island.Theme.glassCardHover : Island.Theme.glassCard
                    border.color: batMouse.containsMouse ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle
                    border.width: 1

                    Row {
                        id: batRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.batteryIcon(root.batPct)
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: root.batPct <= 20 ? Island.Theme.red : (batMouse.containsMouse ? Island.Theme.primary : Island.Theme.foreground)
                        }

                        Text {
                            id: batLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(root.batPct) + "%"
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: batMouse.containsMouse ? Island.Theme.primary : Island.Theme.foreground
                        }
                    }

                    MouseArea {
                        id: batMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
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
            duration: 220
            easing.type: Easing.OutBack
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
            to: 16
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