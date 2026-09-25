import QtQuick
import "../theme"

Item {
    id: root

    property bool active: false

    Theme {
        id: theme
    }

    width: theme.ambientReticleSize
    height: theme.ambientReticleSize

    // Outer Orbital Ring with slow harmonic drift
    Rectangle {
        id: outerRing
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: theme.ambientLineWidth
        border.color: theme.ambientHudFaint

        // Pure C++ linear drift: 1 revolution every 120 seconds
        NumberAnimation {
            id: ringDriver
            target: outerRing
            property: "rotation"
            from: 0
            to: 360
            duration: 120000
            loops: Animation.Infinite
            running: root.active
            easing.type: Easing.Linear
        }

        // Cardinal Tick Marks
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: theme.ambientLineWidth
            height: 8
            color: theme.ambientHudSecondary
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: theme.ambientLineWidth
            height: 8
            color: theme.ambientHudSecondary
        }
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: theme.ambientLineWidth
            color: theme.ambientHudSecondary
        }
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: theme.ambientLineWidth
            color: theme.ambientHudSecondary
        }
    }

    // Inner Concentric Ring
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.55
        height: width
        radius: width / 2
        color: "transparent"
        border.width: theme.ambientLineWidth
        border.color: theme.ambientHudSubtle
    }

    // Central Focal Crosshair
    Rectangle {
        anchors.centerIn: parent
        width: 4
        height: 4
        radius: 2
        color: theme.ambientHudSecondary
    }

    // Reticle Standby Caption
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 24
        text: "STANDBY"
        font.pixelSize: 8
        font.family: "monospace"
        font.letterSpacing: 3
        color: theme.ambientHudText
    }
}
