import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color fillColor: "#08080c"
    property color strokeColor: "transparent"
    property bool impacted: true
    property real wingSize: 13

    anchors.fill: parent
    opacity: impacted ? 1.0 : 0.0
    visible: opacity > 0.001

    Behavior on opacity {
        NumberAnimation { duration: 220; easing.type: Easing.InOutCubic }
    }

    // Left concave wing (bridges from top bezel down to notch left side with 1px overlap)
    Shape {
        id: leftWing
        anchors.top: parent.top
        anchors.right: parent.left
        anchors.rightMargin: -1
        width: root.wingSize + 1
        height: root.wingSize
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fillColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 0
            startY: 0

            PathLine { x: root.wingSize + 1; y: 0 }
            PathLine { x: root.wingSize + 1; y: root.wingSize }
            PathArc {
                x: 0
                y: 0
                radiusX: root.wingSize
                radiusY: root.wingSize
                direction: PathArc.Counterclockwise
            }
        }
    }

    // Right concave wing (bridges from top bezel down to notch right side with 1px overlap)
    Shape {
        id: rightWing
        anchors.top: parent.top
        anchors.left: parent.right
        anchors.leftMargin: -1
        width: root.wingSize + 1
        height: root.wingSize
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fillColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: -1
            startY: 0

            PathLine { x: root.wingSize; y: 0 }
            PathArc {
                x: -1
                y: root.wingSize
                radiusX: root.wingSize
                radiusY: root.wingSize
                direction: PathArc.Counterclockwise
            }
            PathLine { x: -1; y: 0 }
        }
    }
}
