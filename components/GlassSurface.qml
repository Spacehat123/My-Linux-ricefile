import QtQuick
import "../island" as Island

Rectangle {
    id: glass

    // Elevation levels: "deep" / 0, "surface" / 1, "elevated" / 2, "overlay" / 3
    property var elevation: 1
    readonly property int elevationLevel: {
        if (typeof elevation === "number") return Math.max(0, Math.min(3, Math.floor(elevation)));
        switch (String(elevation).toLowerCase()) {
            case "deep": return 0;
            case "surface": return 1;
            case "elevated": return 2;
            case "overlay": return 3;
            default: return 1;
        }
    }
    property bool showSpecular: true
    property bool showInnerRim: true
    property real specularMargin: 16
    property color overlayColor: Qt.rgba(Island.Theme.bg0.r, Island.Theme.bg0.g, Island.Theme.bg0.b, 0.85)

    radius: Island.Theme.radiusCard
    color: {
        switch (elevationLevel) {
            case 0: return Island.Theme.surfaceDeep;
            case 1: return Island.Theme.surfaceOpaque;
            case 2: return Island.Theme.surfaceElevated;
            case 3: return overlayColor;
            default: return Island.Theme.surfaceOpaque;
        }
    }
    border.color: Island.Theme.glassBorder
    border.width: Island.Theme.glassBorderWidth

    // Inner refractive rim (1px inset)
    Rectangle {
        id: innerRim
        visible: glass.showInnerRim
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, parent.radius - 1)
        topLeftRadius: parent.topLeftRadius > 0 ? Math.max(0, parent.topLeftRadius - 1) : parent.topLeftRadius
        topRightRadius: parent.topRightRadius > 0 ? Math.max(0, parent.topRightRadius - 1) : parent.topRightRadius
        bottomLeftRadius: parent.bottomLeftRadius > 0 ? Math.max(0, parent.bottomLeftRadius - 1) : parent.bottomLeftRadius
        bottomRightRadius: parent.bottomRightRadius > 0 ? Math.max(0, parent.bottomRightRadius - 1) : parent.bottomRightRadius
        color: "transparent"
        border.color: {
            const alphas = [0.03, 0.06, 0.08, 0.10];
            const a = (glass.elevationLevel >= 0 && glass.elevationLevel < alphas.length) ? alphas[glass.elevationLevel] : 0.06;
            return Qt.rgba(1, 1, 1, a);
        }
        border.width: 1
        z: 1
    }

    // Upper specular glass highlight strip
    Rectangle {
        id: specular
        visible: glass.showSpecular
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: glass.specularMargin
        anchors.rightMargin: glass.specularMargin
        anchors.topMargin: 1
        height: 1
        radius: 0.5
        color: {
            const alphas = [0.06, 0.10, 0.14, 0.18];
            const a = (glass.elevationLevel >= 0 && glass.elevationLevel < alphas.length) ? alphas[glass.elevationLevel] : 0.12;
            return Qt.rgba(1, 1, 1, a);
        }
        z: 2
    }
}
