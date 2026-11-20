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
    property color activeAccentColor: Island.Theme ? Island.Theme.primary : "#e8799e"
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

    // Outer capsule body / track container
    Rectangle {
        id: capsuleBody
        anchors.fill: parent
        radius: width / 2
        color: Island.Theme ? (Island.Theme.isLightMode ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1.0, 1.0, 1.0, 0.08)) : Qt.rgba(1.0, 1.0, 1.0, 0.08)
        scale: dragArea.pressed ? 0.98 : (hoverHandler.hovered ? 1.01 : 1.0)
        clip: true

        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

        // =====================================================================
        // BASE LAYER (Rendered on top of dark track before liquid fill)
        // High contrast light elements
        // =====================================================================

        // Base percentage readout (Top)
        Text {
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.valueText.length > 0 ? root.valueText : Math.round(root.value * 100) + "%"
            font.pixelSize: 11
            font.bold: true
            font.family: Island.Theme ? Island.Theme.fontFamily : "Geist"
            color: Island.Theme ? Island.Theme.foreground : "#ffffff"
        }

        // Base icon glyph (Bottom)
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.isMuted ? (root.iconActive || root.icon) : root.icon
            font.family: Island.Theme ? Island.Theme.iconFontFamily : "sans-serif"
            font.pixelSize: 20
            color: root.isMuted ? (Island.Theme ? Island.Theme.red : "#e04b73") : (Island.Theme ? Island.Theme.foreground : "#ffffff")
        }

        // =====================================================================
        // LIQUID FILL VIEWPORT (Bottom-up clipped container)
        // Everything inside is clipped exactly to the fluid level!
        // =====================================================================
        Item {
            id: fillViewport
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(0, Math.min(capsuleBody.height, capsuleBody.height * root.displayValue))
            clip: true
            visible: root.displayValue > 0.005

            // The fluid fill: congruent full capsule pill, anchored to bottom
            Rectangle {
                width: capsuleBody.width
                height: capsuleBody.height
                anchors.bottom: parent.bottom
                radius: width / 2
                color: root.isMuted 
                    ? (Island.Theme && Island.Theme.isLightMode ? "#787b86" : "#464853")
                    : (Island.Theme && Island.Theme.isLightMode ? Island.Theme.primary : root.activeFillColor)
                opacity: root.isMuted ? 0.6 : 1.0

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            // Inverted contrast percentage text inside liquid (visible when liquid reaches top)
            Text {
                y: -(capsuleBody.height - fillViewport.height) + 16
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.valueText.length > 0 ? root.valueText : Math.round(root.value * 100) + "%"
                font.pixelSize: 11
                font.bold: true
                font.family: Island.Theme ? Island.Theme.fontFamily : "Geist"
                color: root.isMuted 
                    ? "#ffffff" 
                    : (Island.Theme && Island.Theme.isLightMode ? "#ffffff" : "#12131a")
            }

            // Inverted contrast icon inside liquid (visible when liquid covers bottom)
            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.isMuted ? (root.iconActive || root.icon) : root.icon
                font.family: Island.Theme ? Island.Theme.iconFontFamily : "sans-serif"
                font.pixelSize: 20
                color: root.isMuted 
                    ? "#ffffff" 
                    : (Island.Theme && Island.Theme.isLightMode ? "#ffffff" : "#12131a")
            }
        }

        // =====================================================================
        // OVERLAY BORDER (Rendered on top of fill to ensure a clean unbroken edge)
        // =====================================================================
        Rectangle {
            id: borderOverlay
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: dragArea.pressed 
                ? (Island.Theme ? Island.Theme.glassBorderActive : "#e8799e") 
                : (hoverHandler.hovered ? (Island.Theme ? Island.Theme.glassBorder : Qt.rgba(1, 1, 1, 0.15)) : (Island.Theme ? Island.Theme.glassBorderSubtle : Qt.rgba(1, 1, 1, 0.08)))
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: 120 } }
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

        property real pressY: 0
        property bool isDragging: false

        onPressed: (mouse) => {
            pressY = mouse.y;
            isDragging = false;
            if (mouse.y <= height - 42) {
                root.updateFromY(mouse.y);
            }
        }

        onPositionChanged: (mouse) => {
            if (pressed) {
                if (Math.abs(mouse.y - pressY) > 4) {
                    isDragging = true;
                }
                if (isDragging || mouse.y <= height - 42) {
                    root.updateFromY(mouse.y);
                }
            }
        }

        onReleased: (mouse) => {
            if (!isDragging && mouse.y > height - 42) {
                root.iconTapped();
            } else if (isDragging || mouse.y <= height - 42) {
                root.updateFromY(mouse.y);
            }
        }
    }
}
