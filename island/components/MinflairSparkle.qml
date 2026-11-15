import QtQuick
import QtQuick.Shapes
import ".." as Island

Item {
    id: root

    property int iconSize: 18
    property color iconColor: Island.Theme ? Island.Theme.primary : "#ff2a5f"
    property string plusStarPath: "M 11.6 2.5 Q 12 1.2 12.4 2.5 L 14 10 L 21.5 11.6 Q 22.8 12 21.5 12.4 L 14 14 L 12.4 21.5 Q 12 22.8 11.6 21.5 L 10 14 L 2.5 12.4 Q 1.2 12 2.5 11.6 L 10 10 Z"
    property bool enableIntroAnim: true
    property bool enableIntervalAnim: true

    width: iconSize
    height: iconSize
    implicitWidth: iconSize
    implicitHeight: iconSize

    Item {
        id: starContainer
        width: 24
        height: 24
        scale: root.iconSize / 24
        rotation: 45
        anchors.centerIn: parent

        Item {
            id: mainStarShape
            width: 24
            height: 24
            transformOrigin: Item.Center

            Shape {
                width: 24
                height: 24
                preferredRendererType: Shape.CurveRenderer
                opacity: 0.45

                ShapePath {
                    fillColor: root.iconColor
                    strokeColor: "transparent"
                    strokeWidth: 0
                    PathSvg { path: root.plusStarPath }
                }
            }

            Shape {
                id: innerStar
                width: 24
                height: 24
                preferredRendererType: Shape.CurveRenderer
                scale: 0.65
                transformOrigin: Item.Center

                ShapePath {
                    fillColor: "#ffffff"
                    strokeColor: "transparent"
                    strokeWidth: 0
                    PathSvg { path: root.plusStarPath }
                }
            }
        }
    }

    Timer {
        id: intervalTimer
        interval: 8000
        running: root.enableIntervalAnim
        repeat: true
        onTriggered: {
            sparkleAnim.restart();
        }
    }

    SequentialAnimation {
        id: sparkleAnim

        ParallelAnimation {
            NumberAnimation {
                target: starContainer
                property: "rotation"
                from: 45
                to: 405
                duration: 900
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
            SequentialAnimation {
                NumberAnimation {
                    target: starContainer
                    property: "scale"
                    to: (root.iconSize / 24) * 1.25
                    duration: 400
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: starContainer
                    property: "scale"
                    to: (root.iconSize / 24)
                    duration: 500
                    easing.type: Easing.OutBounce
                }
            }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            sparkleAnim.restart();
        }
    }
}
