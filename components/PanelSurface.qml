import QtQuick
import "../theme"

Rectangle {
    id: root

    Theme {
        id: theme
    }

    // Visual surface styling bound to Theme tokens
    property int cornerRadius: theme.panelCornerRadius
    color: theme.panelBackground
    border.color: theme.panelBorder
    border.width: theme.panelBorderWidth
    radius: cornerRadius

    // Optional clipping for rounded surfaces
    property bool clipContent: false
    clip: clipContent

    // Idiomatic QML child hosting
    default property alias contentData: surfaceContent.data

    Item {
        id: surfaceContent
        anchors.fill: parent
    }
}
