import QtQuick
import ".."
import "../components"

// Weather: current conditions (wttr.in, cached 30 min). Collapsed pill shows
// the temperature only when pinned here, never by default.
FocusScope {
    id: root

    function takeInitialFocus() {
        refreshButton.forceActiveFocus(Qt.TabFocusReason);
    }

    implicitWidth: 352
    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 8

        PanelHeader {
            title: "Weather"
            onCloseRequested: ShellState.close()
        }

        ShellText {
            width: parent.width
            text: WeatherState.tempC ? WeatherState.tempC + "  " + WeatherState.condition : (WeatherState.loading ? "Loading…" : "Unavailable")
            font.pixelSize: 26
            font.weight: Font.Bold
        }

        ShellText {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: WeatherState.area !== ""
            text: WeatherState.area + (WeatherState.updatedAt ? " · updated " + WeatherState.updatedAt : "") + (WeatherState.stale ? " · stale" : "")
            color: Theme.muted
            font.pixelSize: 11
        }

        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                id: refreshButton
                width: 110
                height: 32
                radius: 16
                color: rfMouse.containsMouse ? Theme.primaryContainer : Theme.bg1

                ShellText {
                    anchors.centerIn: parent
                    text: "Refresh"
                    font.pixelSize: 12
                }

                MouseArea {
                    id: rfMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WeatherState.refresh()
                }
            }

            Rectangle {
                width: 170
                height: 32
                radius: 16
                color: pinMouse.containsMouse ? Theme.primaryContainer : Theme.bg1
                border.width: WeatherState.pinned ? 2 : 0
                border.color: Theme.primary

                ShellText {
                    anchors.centerIn: parent
                    text: WeatherState.pinned ? "Pinned to island" : "Pin to island"
                    font.pixelSize: 12
                }

                MouseArea {
                    id: pinMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WeatherState.pinned = !WeatherState.pinned
                }
            }
        }
    }
}
