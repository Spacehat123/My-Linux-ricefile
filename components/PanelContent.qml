import QtQuick
import "../theme"

Item {
    id: root

    // Orientation metadata (Qt.Vertical for sidebars, Qt.Horizontal for bottom bar)
    property int orientation: Qt.Vertical

    Theme {
        id: theme
    }

    // Layout insets bound to Theme tokens
    property real padding: theme.panelPadding
    property real topPadding: padding
    property real bottomPadding: padding
    property real leftPadding: padding
    property real rightPadding: padding

    // Inter-item spacing token
    property real spacing: theme.itemSpacing

    // Idiomatic child hosting forwarding items and objects into the padded container
    default property alias contentData: contentContainer.data

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.topMargin: root.topPadding
        anchors.bottomMargin: root.bottomPadding
        anchors.leftMargin: root.leftPadding
        anchors.rightMargin: root.rightPadding
    }
}
