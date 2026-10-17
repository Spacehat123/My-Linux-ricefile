import QtQuick
import ".."
import "../components"

// Timer panel: stopwatch + countdowns + focus session.
// The island shows these ONLY while active (see TimerState).
FocusScope {
    id: root

    function takeInitialFocus() {
        swButton.forceActiveFocus(Qt.TabFocusReason);
    }

    implicitWidth: 352
    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 10

        PanelHeader {
            title: "Timer"
            onCloseRequested: ShellState.close()
        }

        // Stopwatch row.
        Row {
            width: parent.width
            spacing: 8

            // Circular timer dial motif
            Rectangle {
                width: 34
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: (TimerState.swRunning || TimerState.hasActive) ? Theme.primaryContainer : Theme.bg1
                border.color: (TimerState.swRunning || TimerState.hasActive) ? Theme.primary : Theme.bg2
                border.width: 1.5

                ShellText {
                    anchors.centerIn: parent
                    text: "\uf017"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 14
                    color: (TimerState.swRunning || TimerState.hasActive) ? Theme.primary : Theme.muted
                }
            }

            ShellText {
                width: 75
                anchors.verticalCenter: parent.verticalCenter
                text: IslandHub.formatElapsed(TimerState.swElapsedSec)
                font.pixelSize: 20
                font.weight: Font.Bold
            }

            Rectangle {
                id: swButton
                width: 110
                height: 32
                radius: 16
                color: swMouse.containsMouse ? Theme.primaryContainer : Theme.bg1
                activeFocusOnTab: true
                Keys.onReturnPressed: toggleSw()
                Keys.onSpacePressed: toggleSw()
                function toggleSw() {
                    if (TimerState.swRunning)
                        TimerState.swPause();
                    else
                        TimerState.swStart();
                }

                ShellText {
                    anchors.centerIn: parent
                    text: TimerState.swRunning ? "Pause" : "Start"
                    font.pixelSize: 12
                }

                MouseArea {
                    id: swMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.toggleSw()
                }
            }

            Rectangle {
                width: 80
                height: 32
                radius: 16
                color: rstMouse.containsMouse ? Theme.primaryContainer : Theme.bg1

                ShellText {
                    anchors.centerIn: parent
                    text: "Reset"
                    font.pixelSize: 12
                }

                MouseArea {
                    id: rstMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: TimerState.swReset()
                }
            }
        }

        // Countdown presets.
        ShellText {
            text: "Countdown"
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        Row {
            width: parent.width
            spacing: 6

            Repeater {
                model: [1, 5, 10, 25, 60]
                delegate: Rectangle {
                    required property var modelData
                    width: 56
                    height: 30
                    radius: 15
                    color: cdMouse.containsMouse ? Theme.primaryContainer : Theme.bg1

                    ShellText {
                        anchors.centerIn: parent
                        text: modelData + "m"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: cdMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TimerState.addCountdown(modelData, "")
                    }
                }
            }
        }

        Repeater {
            model: TimerState.countdowns
            delegate: Row {
                required property var modelData
                required property int index
                width: content.width
                spacing: 8

                ShellText {
                    width: 150
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: (modelData.label ? modelData.label + " " : "") + IslandHub.formatElapsed(modelData.running ? Math.max(0, Math.ceil(modelData.base - Date.now() / 1000)) : modelData.remainingSec)
                    color: modelData.running ? Theme.shellForeground : Theme.muted
                    font.pixelSize: 12
                }

                Rectangle {
                    width: 90
                    height: 30
                    radius: 15
                    color: tglMouse.containsMouse ? Theme.primaryContainer : Theme.bg1

                    ShellText {
                        anchors.centerIn: parent
                        text: modelData.running ? "Pause" : "Start"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: tglMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TimerState.toggleCountdown(modelData.id)
                    }
                }

                Rectangle {
                    width: 70
                    height: 30
                    radius: 15
                    color: delMouse.containsMouse ? Theme.red : Theme.bg1

                    ShellText {
                        anchors.centerIn: parent
                        text: "Drop"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: delMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TimerState.removeCountdown(modelData.id)
                    }
                }
            }
        }

        // Focus session.
        ShellText {
            text: "Focus"
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        Row {
            width: parent.width
            spacing: 6

            Repeater {
                model: [15, 25, 50]
                delegate: Rectangle {
                    required property var modelData
                    width: 56
                    height: 30
                    radius: 15
                    color: fMouse.containsMouse ? Theme.primaryContainer : Theme.bg1

                    ShellText {
                        anchors.centerIn: parent
                        text: modelData + "m"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: fMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TimerState.startFocus(modelData)
                    }
                }
            }

            Rectangle {
                visible: TimerState.focusActive
                width: 130
                height: 30
                radius: 15
                color: endMouse.containsMouse ? Theme.red : Theme.bg1

                ShellText {
                    anchors.centerIn: parent
                    text: "End (" + IslandHub.formatElapsed(TimerState.focusRemainingSec) + ")"
                    font.pixelSize: 12
                }

                MouseArea {
                    id: endMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: TimerState.endFocus()
                }
            }
        }

        ShellText {
            visible: TimerState.focusActive
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Focus silences notification popups (Do Not Disturb)."
            color: Theme.muted
            font.pixelSize: 11
        }
    }
}
