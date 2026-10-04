import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        WlrLayershell.namespace: "cool-shell-gamemode"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: isExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        focusable: isExpanded
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        margins.top: 10

        color: "transparent"

        property bool isExpanded: false

        implicitWidth: notchBody.width
        implicitHeight: notchBody.height

        // Dismiss on Escape
        FocusScope {
            anchors.fill: parent
            focus: win.isExpanded

            Keys.onEscapePressed: {
                win.isExpanded = false;
            }
        }

        // Main Island Body
        Rectangle {
            id: notchBody
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top

            width: win.isExpanded ? 320 : 154
            height: win.isExpanded ? 90 : 34
            radius: win.isExpanded ? 20 : 17

            color: "#0c0c12"
            border.color: Qt.rgba(1.0, 0.3, 0.43, win.isExpanded ? 0.6 : 0.35)
            border.width: 1.5
            clip: true

            Behavior on width {
                SpringAnimation {
                    spring: 4.5
                    damping: 0.38
                    epsilon: 0.2
                }
            }

            Behavior on height {
                SpringAnimation {
                    spring: 4.5
                    damping: 0.38
                    epsilon: 0.2
                }
            }

            Behavior on radius {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            // Click on collapsed capsule expands the card
            TapHandler {
                enabled: !win.isExpanded
                onTapped: win.isExpanded = true
            }

            // -----------------------------------------------------------------
            // 1. COLLAPSED VIEW (Minimal 154x34 Crimson Capsule)
            // -----------------------------------------------------------------
            Item {
                id: collapsedContent
                anchors.fill: parent
                opacity: win.isExpanded ? 0.0 : 1.0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        color: Qt.rgba(1.0, 0.3, 0.43, 0.2)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰊴"
                            font.pixelSize: 11
                            color: "#ff4d6d"
                        }
                    }

                    Text {
                        text: "GAME MODE"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.1
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: "#ff4d6d"
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.4; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 1.0; to: 0.4; duration: 800; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // 2. EXPANDED VIEW (Single Action: Turn Game Mode Off)
            // -----------------------------------------------------------------
            Item {
                id: expandedContent
                anchors.fill: parent
                anchors.margins: 12
                opacity: win.isExpanded ? 1.0 : 0.0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 160 }
                }

                Column {
                    anchors.fill: parent
                    spacing: 10

                    // Header item
                    Item {
                        width: parent.width
                        height: 26

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 8
                                color: "#ff4d6d"
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰊴"
                                    font.pixelSize: 14
                                    color: "#0a0a0f"
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    text: "Game Mode Active"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#ffffff"
                                }

                                Text {
                                    text: "Ultra-low memory profile • 0 latency"
                                    font.pixelSize: 10
                                    color: Qt.rgba(1.0, 1.0, 1.0, 0.5)
                                }
                            }
                        }

                        // Close/collapse chevron button
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            radius: 12
                            color: closeHover.hovered ? Qt.rgba(1.0, 1.0, 1.0, 0.15) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "▲"
                                font.pixelSize: 9
                                color: Qt.rgba(1.0, 1.0, 1.0, 0.6)
                            }

                            HoverHandler { id: closeHover }
                            TapHandler {
                                onTapped: win.isExpanded = false
                            }
                        }
                    }

                    // Single Hero Action Button: "Turn Game Mode Off"
                    Rectangle {
                        id: offButton
                        width: parent.width
                        height: 30
                        radius: 8
                        color: btnHover.hovered ? "#ff6b87" : "#ff4d6d"
                        scale: btnTap.pressed ? 0.96 : 1.0

                        Behavior on scale { NumberAnimation { duration: 80 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰈆"
                                font.pixelSize: 13
                                color: "#0a0a0f"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Turn Game Mode Off"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#0a0a0f"
                            }
                        }

                        HoverHandler { id: btnHover }
                        TapHandler {
                            id: btnTap
                            onTapped: {
                                disableProc.running = true;
                            }
                        }
                    }
                }
            }
        }

        // Process to disable game mode and restore full shell
        Process {
            id: disableProc
            command: ["python3", Quickshell.shellPath("scripts/game-mode.py"), "disable"]
            onExited: function(exitCode, exitStatus) {
                Qt.quit();
            }
        }
    }
}
