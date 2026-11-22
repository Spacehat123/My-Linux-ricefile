import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    // =========================================================================
    // Injected State & Configuration
    // =========================================================================
    property var screen: null
    property bool idle: false
    property bool workspaceEmpty: false
    property bool enabled: true
    property bool alwaysOn: false
    readonly property bool active: (alwaysOn || idle || workspaceEmpty) && enabled

    // Lifecycle visibility: stays visible while active or while fade-out is running
    visible: active || fadeOutAnim.running

    // Fullscreen geometry anchors
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Layer-shell configuration
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false
    focusable: false
    color: "transparent"

    WlrLayershell.namespace: "pranc-shell-ambient-slate"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Wayland region mask: active across viewport on empty workspace for interactive fireflies,
    // horizon caustics & click ripples; collapses when inactive so zero input is intercepted.
    mask: Region {
        item: (root.active || fadeOutAnim.running) ? hudContainer : null
    }

    Theme {
        id: theme
    }

    // Emergence / Dismissal Animation Controllers
    NumberAnimation {
        id: fadeInAnim
        target: hudContainer
        property: "opacity"
        to: 1.0
        duration: theme.ambientFadeInDuration
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: fadeOutAnim
        target: hudContainer
        property: "opacity"
        to: 0.0
        duration: theme.ambientFadeOutDuration
        easing.type: Easing.OutQuad
    }

    onActiveChanged: {
        if (active) {
            fadeOutAnim.stop();
            fadeInAnim.start();
        } else {
            fadeInAnim.stop();
            fadeOutAnim.start();
        }
    }

    // Scene Graph Resource Gate
    Item {
        id: hudContainer
        anchors.fill: parent
        opacity: 0.0
        visible: opacity > 0.0

        // Real-time cursor hover & motion tracking for interactive Living Air & horizon caustics
        HoverHandler {
            id: globalHover
        }

        // Full-screen desktop tap handler (spawns cyberpunk ghost trails & ripples on clicks)
        TapHandler {
            onTapped: point => {
                ghostTrails.spawnBurst(point.position.x, point.position.y);
            }
        }

        // 1. Bangalore Weather Mist Layer
        AmbientWeatherMist {
            id: weatherMist
            anchors.fill: parent
            visible: AmbientConfig.showWeatherMist
            active: root.active && (hudContainer.opacity > 0.0) && visible
        }

        // 2. Solar & Lunar Astronomical Full Circle Orbit (Only Sun and Moon, Zero lines/text)
        SolarLunarArc {
            id: solarLunarArc
            anchors.fill: parent
            visible: AmbientConfig.showSunMoon
            active: root.active && (hudContainer.opacity > 0.0) && visible
        }

        // 3. Atmospheric Living Air (Twilight Fireflies & Interactive Horizon Light Catch)
        AtmosphericMotes {
            id: livingAir
            anchors.fill: parent
            visible: AmbientConfig.showParticles
            active: root.active && (hudContainer.opacity > 0.0) && visible
            cursorX: globalHover.point.position.x
            cursorY: globalHover.point.position.y
            cursorPresent: globalHover.hovered
            cardLeftRect: Qt.rect(slateWrapper.x, slateWrapper.y, slateWrapper.width, slateWrapper.height)
            cardRightRect: Qt.rect(constellationWrapper.x, constellationWrapper.y, constellationWrapper.width, constellationWrapper.height)
        }

        // 4. Cyberpunk Ephemeral Ghost Trails (Atmospheric / Non-blocking)
        DesktopGhostTrails {
            id: ghostTrails
            anchors.fill: parent
            visible: AmbientConfig.showGhostTrails
            active: root.active && (hudContainer.opacity > 0.0) && visible
        }

        // 5. Left Architectural Clock, Weather & Radial Telemetry Slate
        Item {
            id: slateWrapper
            width: slateInstance.implicitWidth
            height: slateInstance.implicitHeight

            Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

            x: {
                switch (AmbientConfig.clockPosition) {
                    case "center": return Math.round((parent.width - width) / 2);
                    case "top-right": return Math.max(72, parent.width - width - 72);
                    case "bottom-right": return Math.max(72, parent.width - width - 72);
                    case "bottom-left": return 72;
                    case "center-left": return 72;
                    case "top-left":
                    default: return 72;
                }
            }
            y: {
                switch (AmbientConfig.clockPosition) {
                    case "center": return Math.round((parent.height - height) / 2);
                    case "top-right": return 120;
                    case "bottom-right": return Math.max(48, parent.height - height - 80);
                    case "bottom-left": return Math.max(48, parent.height - height - 80);
                    case "center-left": return Math.round((parent.height - height) / 2);
                    case "top-left":
                    default: return 120;
                }
            }

            DesktopAmbientSlate {
                id: slateInstance
                anchors.fill: parent
                active: root.active && (hudContainer.opacity > 0.0)
            }

            TapHandler {
                onTapped: point => {
                    const pt = slateWrapper.mapToItem(hudContainer, point.position.x, point.position.y);
                    ghostTrails.spawnBurst(pt.x, pt.y);
                }
            }
        }

        // 6. Bottom-Right Constellation Coding & Momentum Card (Frosted Glass Plate)
        Item {
            id: constellationWrapper
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 48
            anchors.bottomMargin: 48
            width: constellationInstance.implicitWidth
            height: constellationInstance.implicitHeight
            visible: AmbientConfig.showConstellationCard

            DesktopConstellationCard {
                id: constellationInstance
                anchors.fill: parent
                active: root.active && (hudContainer.opacity > 0.0)
            }

            TapHandler {
                onTapped: point => {
                    const pt = constellationWrapper.mapToItem(hudContainer, point.position.x, point.position.y);
                    ghostTrails.spawnBurst(pt.x, pt.y);
                }
            }
        }
    }
}
