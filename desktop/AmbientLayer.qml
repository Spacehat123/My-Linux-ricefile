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
            active: root.active && (hudContainer.opacity > 0.0)
        }

        // 2. Solar & Lunar Astronomical Full Circle Orbit (Only Sun and Moon, Zero lines/text)
        SolarLunarArc {
            id: solarLunarArc
            anchors.fill: parent
            active: root.active && (hudContainer.opacity > 0.0)
        }

        // 3. Atmospheric Living Air (Twilight Fireflies & Interactive Horizon Light Catch)
        AtmosphericMotes {
            id: livingAir
            anchors.fill: parent
            active: root.active && (hudContainer.opacity > 0.0)
            cursorX: globalHover.point.position.x
            cursorY: globalHover.point.position.y
            cursorPresent: globalHover.hovered
        }

        // 4. Cyberpunk Ephemeral Ghost Trails (Atmospheric / Non-blocking)
        DesktopGhostTrails {
            id: ghostTrails
            anchors.fill: parent
            active: root.active && (hudContainer.opacity > 0.0)
        }

        // 5. Bottom-Left Clock & Weather Slate (Frosted Glass Plate)
        Item {
            id: slateWrapper
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 48
            anchors.bottomMargin: 48
            width: slateInstance.implicitWidth
            height: slateInstance.implicitHeight

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
