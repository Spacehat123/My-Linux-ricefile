import QtQuick
import "../theme"

Item {
    id: root

    property string screenName: ""
    property bool active: false

    Theme {
        id: theme
    }

    readonly property int bracketSize: theme.ambientBracketSize
    readonly property int offset: theme.ambientCornerOffset

    // Top-Left Tactical Bracket
    Item {
        width: root.bracketSize
        height: root.bracketSize
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: root.offset

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            width: parent.width
            height: theme.ambientLineWidth
            color: theme.ambientHudPrimary
        }
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            width: theme.ambientLineWidth
            height: parent.height
            color: theme.ambientHudPrimary
        }
        Text {
            anchors.top: parent.bottom
            anchors.left: parent.left
            anchors.topMargin: 4
            text: "SYS // AMBIENT.READY"
            font.pixelSize: 8
            font.family: "monospace"
            font.letterSpacing: 2
            color: theme.ambientHudText
        }
    }

    // Top-Right Tactical Bracket
    Item {
        width: root.bracketSize
        height: root.bracketSize
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: root.offset

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            width: parent.width
            height: theme.ambientLineWidth
            color: theme.ambientHudPrimary
        }
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            width: theme.ambientLineWidth
            height: parent.height
            color: theme.ambientHudPrimary
        }
        Text {
            anchors.top: parent.bottom
            anchors.right: parent.right
            anchors.topMargin: 4
            text: "SEC // GRID.01"
            font.pixelSize: 8
            font.family: "monospace"
            font.letterSpacing: 2
            color: theme.ambientHudText
        }
    }

    // Bottom-Left Tactical Bracket
    Item {
        width: root.bracketSize
        height: root.bracketSize
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: root.offset

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: parent.width
            height: theme.ambientLineWidth
            color: theme.ambientHudPrimary
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: theme.ambientLineWidth
            height: parent.height
            color: theme.ambientHudPrimary
        }
    }

    // Bottom-Right Tactical Bracket
    Item {
        width: root.bracketSize
        height: root.bracketSize
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: root.offset

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: parent.width
            height: theme.ambientLineWidth
            color: theme.ambientHudPrimary
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: theme.ambientLineWidth
            height: parent.height
            color: theme.ambientHudPrimary
        }
        Text {
            anchors.bottom: parent.top
            anchors.right: parent.right
            anchors.bottomMargin: 4
            text: "DISP // " + (root.screenName ? root.screenName : "ACTIVE")
            font.pixelSize: 8
            font.family: "monospace"
            font.letterSpacing: 2
            color: theme.ambientHudText
        }
    }
}
