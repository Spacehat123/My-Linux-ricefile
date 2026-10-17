import QtQuick
import "../theme"

Item {
    id: root

    property string screenName: ""
    property bool active: false

    Theme {
        id: theme
    }

    implicitWidth: 210
    implicitHeight: layout.implicitHeight + 16

    // Panel backdrop
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: theme.ambientHudDarkFill
        border.width: theme.ambientLineWidth
        border.color: theme.ambientHudSubtle
    }

    Column {
        id: layout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // Telemetry Header
        Row {
            spacing: 6
            Rectangle {
                width: 4
                height: 4
                radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: theme.ambientHudPrimary
            }
            Text {
                text: "TELEMETRY // HUD"
                font.pixelSize: 9
                font.bold: true
                font.family: "monospace"
                font.letterSpacing: 1.5
                color: theme.ambientHudAccentText
            }
        }

        // Hairline Divider
        Rectangle {
            width: parent.width
            height: theme.ambientLineWidth
            color: theme.ambientHudSubtle
        }

        // Metrics Grid (Derived from shellRoot)
        Grid {
            columns: 2
            rowSpacing: 3
            columnSpacing: 12

            Text {
                text: "WORKSPACE:"
                font.pixelSize: 8
                font.family: "monospace"
                color: theme.ambientHudText
            }
            Text {
                text: (typeof shellRoot !== "undefined" && shellRoot.currentWorkspaceName) ? shellRoot.currentWorkspaceName : "MAIN"
                font.pixelSize: 8
                font.bold: true
                font.family: "monospace"
                color: theme.ambientHudSecondary
            }

            Text {
                text: "SURFACES:"
                font.pixelSize: 8
                font.family: "monospace"
                color: theme.ambientHudText
            }
            Text {
                text: (typeof shellRoot !== "undefined") ? String(shellRoot.surfaceCount) : "0"
                font.pixelSize: 8
                font.bold: true
                font.family: "monospace"
                color: theme.ambientHudSecondary
            }

            Text {
                text: "MONITOR:"
                font.pixelSize: 8
                font.family: "monospace"
                color: theme.ambientHudText
            }
            Text {
                text: root.screenName ? root.screenName : "DEFAULT"
                font.pixelSize: 8
                font.family: "monospace"
                color: theme.ambientHudSecondary
            }

            Text {
                text: "STATE:"
                font.pixelSize: 8
                font.family: "monospace"
                color: theme.ambientHudText
            }
            Text {
                text: "IDLE // LOW-PWR"
                font.pixelSize: 8
                font.bold: true
                font.family: "monospace"
                color: theme.ambientHudPrimary
            }
        }
    }
}
