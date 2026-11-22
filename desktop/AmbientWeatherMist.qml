import QtQuick
import "../island" as Island

Item {
    id: root

    property bool active: true
    anchors.fill: parent

    readonly property string condition: Island.WeatherState ? (Island.WeatherState.condition || "") : ""

    // Weather condition profile mapping
    readonly property var profile: {
        const c = condition.toLowerCase();
        if (c.includes("fog") || c.includes("mist") || c.includes("haze") || c.includes("smoke") || c.includes("smoky")) {
            return { opacity: 0.24, durationL1: 38000, durationL2: 52000, yOffset: 0 };
        } else if (c.includes("rain") || c.includes("drizzle") || c.includes("shower") || c.includes("storm") || c.includes("thunder")) {
            return { opacity: 0.18, durationL1: 24000, durationL2: 32000, yOffset: 16 };
        } else if (c.includes("clear") || c.includes("sun")) {
            return { opacity: 0.07, durationL1: 60000, durationL2: 80000, yOffset: -8 };
        } else if (c.includes("cloud") || c.includes("overcast")) {
            return { opacity: 0.15, durationL1: 42000, durationL2: 56000, yOffset: 4 };
        } else {
            return { opacity: 0.12, durationL1: 45000, durationL2: 60000, yOffset: 0 };
        }
    }

    opacity: active ? profile.opacity : 0.0
    Behavior on opacity {
        NumberAnimation {
            duration: 2000
            easing.type: Easing.InOutQuad
        }
    }

    // Layer 1: Primary Valley Mist Ribbon (Left-to-Right Drift)
    Item {
        id: layer1
        width: root.width * 2
        height: root.height * 0.42
        y: root.height * 0.52 + root.profile.yOffset

        NumberAnimation on x {
            from: 0
            to: -root.width
            duration: root.profile.durationL1
            loops: Animation.Infinite
        }

        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { to: root.height * 0.52 + root.profile.yOffset + 10; duration: 15000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.52 + root.profile.yOffset - 10; duration: 15000; easing.type: Easing.InOutSine }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.35; color: Qt.rgba(Island.Theme.muted.r, Island.Theme.muted.g, Island.Theme.muted.b, 0.40) }
                GradientStop { position: 0.65; color: Qt.rgba(Island.Theme.aqua.r, Island.Theme.aqua.g, Island.Theme.aqua.b, 0.28) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // Layer 2: Sub-Ridge Counter-Drift Ribbon (Right-to-Left Drift)
    Item {
        id: layer2
        width: root.width * 2
        height: root.height * 0.34
        y: root.height * 0.64 + root.profile.yOffset

        NumberAnimation on x {
            from: -root.width
            to: 0
            duration: root.profile.durationL2
            loops: Animation.Infinite
        }

        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { to: root.height * 0.64 + root.profile.yOffset - 8; duration: 18000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.64 + root.profile.yOffset + 8; duration: 18000; easing.type: Easing.InOutSine }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.40; color: Qt.rgba(Island.Theme.bg1.r * 1.5, Island.Theme.bg1.g * 1.5, Island.Theme.bg1.b * 1.5, 0.35) }
                GradientStop { position: 0.70; color: Qt.rgba(Island.Theme.muted.r, Island.Theme.muted.g, Island.Theme.muted.b, 0.18) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }
}
