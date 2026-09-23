import QtQuick

QtObject {
    id: root

    // Panel surface constants
    readonly property color panelBackground: "#e0181825"
    readonly property color panelBorder: "#30ffffff"
    readonly property int panelBorderWidth: 1
    readonly property int panelCornerRadius: 12

    // Typography constants
    readonly property color primaryTextColor: "#ffffff"
    readonly property color secondaryTextColor: "#a0ffffff"
    readonly property color mutedTextColor: secondaryTextColor

    // Animation constants
    readonly property int animDurationOpen: 200
    readonly property int animDurationClose: 160
}
