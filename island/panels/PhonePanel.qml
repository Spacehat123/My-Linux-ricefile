import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../components"

Item {
    id: root

    implicitWidth: 380
    implicitHeight: 230

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Header: Device Identity + Battery Status
        Row {
            width: parent.width
            spacing: 10

            Rectangle {
                width: 36
                height: 36
                radius: 12
                color: ShellState.phoneConnected
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                    : Qt.rgba(Theme.glassCardHover.r, Theme.glassCardHover.g, Theme.glassCardHover.b, 0.5)
                border.color: ShellState.phoneConnected ? Theme.primary : Theme.glassBorderSubtle
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "📱"
                    font.pixelSize: 18
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                width: parent.width - 150

                Text {
                    text: "Android Phone"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: Theme.foreground
                }

                Text {
                    text: ShellState.phoneConnected
                        ? (ShellState.phoneMirrorActive ? "Screen Mirroring Active" : "Connected & Ready")
                        : "No Device (Connect USB or Wi-Fi)"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: ShellState.phoneConnected ? Theme.primary : Theme.muted
                    elide: Text.ElideRight
                }
            }

            // Battery Pill
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                height: 24
                implicitWidth: batteryRow.implicitWidth + 14
                radius: 12
                visible: ShellState.phoneConnected && ShellState.phoneBattery >= 0
                color: ShellState.phoneCharging
                    ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.2)
                    : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                border.color: ShellState.phoneCharging ? Theme.green : Theme.primary
                border.width: 1

                Row {
                    id: batteryRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: ShellState.phoneCharging ? "󰂄" : "󰁹"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 12
                        color: ShellState.phoneCharging ? Theme.green : Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: ShellState.phoneBattery + "%"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: ShellState.phoneCharging ? Theme.green : Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Primary Action: Toggle Screen Mirror
        Rectangle {
            width: parent.width
            height: 42
            radius: 12
            color: ShellState.phoneMirrorActive
                ? Theme.red
                : (mirrorHover.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Theme.primary)
            scale: mirrorTap.pressed ? 0.97 : 1.0

            Behavior on scale { NumberAnimation { duration: 80 } }
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: ShellState.phoneMirrorActive ? "󰅖" : "󰍹"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 15
                    color: ShellState.phoneMirrorActive ? "#ffffff" : "#0a0a0f"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: ShellState.phoneMirrorActive ? "Disconnect Phone Mirror" : "Open Phone Mirror"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: ShellState.phoneMirrorActive ? "#ffffff" : "#0a0a0f"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            HoverHandler { id: mirrorHover }
            TapHandler {
                id: mirrorTap
                onTapped: {
                    ShellState.togglePhoneMirror();
                }
            }
        }

        // Secondary Actions Grid
        Row {
            width: parent.width
            spacing: 8

            // Turn Phone Screen Off (preserves battery while mirroring)
            Rectangle {
                width: (parent.width - 8) / 2
                height: 34
                radius: 10
                color: scrHover.hovered ? Theme.glassCardHover : Theme.glassCard
                border.color: Theme.glassBorderSubtle
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "󰍺"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 13
                        color: Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Screen Power"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: scrHover }
                TapHandler {
                    onTapped: {
                        Quickshell.execDetached(["adb", "shell", "input", "keyevent", "26"]);
                        IslandHub.showTransient("📱 Phone screen toggled", 2000);
                    }
                }
            }

            // Capture Phone Screenshot to Shelf
            Rectangle {
                width: (parent.width - 8) / 2
                height: 34
                radius: 10
                color: capHover.hovered ? Theme.glassCardHover : Theme.glassCard
                border.color: Theme.glassBorderSubtle
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "󰹑"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 13
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Phone Screenshot"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: capHover }
                TapHandler {
                    onTapped: {
                        screenshotProc.running = true;
                    }
                }
            }
        }

        // Bridge & MIME Filter Info Card
        Rectangle {
            width: parent.width
            height: 52
            radius: 10
            color: Theme.glassCard
            border.color: Theme.glassBorderSubtle
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: "🛡️"
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    width: parent.width - 32

                    Text {
                        text: "Filtered File Bridge Active"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.foreground
                    }

                    Text {
                        text: "Drop files onto phone window • Images, Audio, Docs, APKs allowed"
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        color: Theme.muted
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Process {
        id: screenshotProc
        command: ["bash", "-c", "mkdir -p ~/Pictures/Screenshots && file=~/Pictures/Screenshots/phone-$(date +%Y%m%d-%H%M%S).png && adb exec-out screencap -p > \"$file\" && qs -c cool-shell ipc call island shelfAdd \"$file\" && qs -c cool-shell ipc call island showTransient '📸 Captured Phone Screenshot' 3000"]
        running: false
    }
}
