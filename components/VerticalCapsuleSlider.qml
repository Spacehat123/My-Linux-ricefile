import QtQuick
import "../island" as Island

Item {
    id: root

    property real value: 0.0          // 0.0 to 1.0
    property string icon: ""          // Nerd font icon glyph
    property string iconActive: ""    // Optional alternate icon
    property string label: ""         // e.g. "Brightness" or "Volume"
    property string valueText: ""     // e.g. "75%" or "Muted"
    property color activeFillColor: "#ffffff"
    property color activeAccentColor: Island.Theme.primary
    property bool isMuted: false

    signal moved(real val)
    signal iconTapped()

    implicitWidth: 72
    implicitHeight: 158

    // Animated display value for butter-smooth visual transitions
    property real displayValue: root.value
    Behavior on displayValue {
        enabled: !dragArea.pressed
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    function updateFromY(mouseY) {
        // Dragging from bottom up: bottom is 0%, top is 100%
        const normalized = 1.0 - (mouseY / height);
        const clamped = Math.max(0.0, Math.min(1.0, normalized));
        root.moved(clamped);
    }

    // Outer capsule body (Translucent Glass Track)
    Rectangle {
        id: capsuleBody
        anchors.fill: parent
        radius: width / 2
        color: Island.Theme.glassCard
        border.color: dragArea.pressed ? Island.Theme.glassBorderActive : (hoverHandler.hovered ? Island.Theme.glassBorder : Island.Theme.glassBorderSubtle)
        border.width: 1
        clip: true
        scale: dragArea.pressed ? 0.98 : (hoverHandler.hovered ? 1.01 : 1.0)

        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        // Fluid fill container: A rectangular viewport that clips an identical full capsule
        // from the bottom up. Eliminates all geometry/arc inversion bugs across 0% - 100%.
        Item {
            id: fillViewport
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(0, Math.min(capsuleBody.height, capsuleBody.height * root.displayValue))
            clip: true
            visible: root.displayValue > 0.005

            // The full capsule fill: perfectly congruent with capsuleBody
            Rectangle {
                width: capsuleBody.width
                height: capsuleBody.height
                anchors.bottom: parent.bottom
                radius: width / 2
                color: root.isMuted 
                    ? Qt.rgba(0.5, 0.5, 0.5, 0.3) 
                    : (Island.Theme && Island.Theme.isLightMode ? Island.Theme.primary : root.activeFillColor)
                opacity: root.isMuted ? 0.4 : 0.95

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }

        // Top value percentage readout
        Text {
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.valueText.length > 0 ? root.valueText : Math.round(root.value * 100) + "%"
            font.pixelSize: 11
            font.bold: true
            font.family: Island.Theme.fontFamily
            // Invert text contrast dynamically if fluid fill reaches top
            color: (root.displayValue > 0.85 && !root.isMuted) 
                ? (Island.Theme && Island.Theme.isLightMode ? "#ffffff" : "#0a0a0f") 
                : Island.Theme.foreground
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        // Bottom Icon Circle
        Rectangle {
            id: iconCircle
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            width: 36
            height: 36
            radius: 18
            color: "transparent"

            Text {
                id: iconGlyph
                anchors.centerIn: parent
                text: root.isMuted ? (root.iconActive || root.icon) : root.icon
                font.family: Island.Theme.iconFontFamily
                font.pixelSize: 18
                // High contrast color depending on whether the fill is behind the icon
                color: root.isMuted 
                    ? Island.Theme.red 
                    : ((root.displayValue > 0.35) 
                        ? (Island.Theme && Island.Theme.isLightMode ? "#ffffff" : "#1a1924") 
                        : Island.Theme.foreground)
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            HoverHandler { id: iconHover }
            TapHandler {
                onTapped: root.iconTapped()
            }
        }

        // Subtle specular glass edge reflection
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        onPressed: (mouse) => {
            root.updateFromY(mouse.y);
        }

        onPositionChanged: (mouse) => {
            if (pressed) {
                root.updateFromY(mouse.y);
            }
        }
    }
}
