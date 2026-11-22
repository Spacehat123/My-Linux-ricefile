import QtQuick
import Quickshell
import "../island" as Island

Item {
    id: root

    property bool active: true
    anchors.fill: parent

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    // Full Circle Celestial Orbit Geometry
    readonly property real centerX: width / 2
    readonly property real centerY: height * 0.44
    readonly property real radius: Math.min(width * 0.24, height * 0.32)

    // Bangalore Astronomical Timing (12.97° N, 77.59° E)
    // Bangalore Solar Noon is at 12:08 (728 minutes)
    // Dawn is at 06:15 (375 minutes) and Dusk is at 18:15 (1095 minutes)
    readonly property int currentMinutes: {
        const d = sysClock.date;
        return d.getHours() * 60 + d.getMinutes();
    }
    readonly property bool isDay: currentMinutes >= 375 && currentMinutes < 1095

    // Continuous 24-hour circular orbital angle (radians)
    // At Solar Noon (728 min), angle = -PI/2 (zenith / apex at top of circle)
    // At Dusk (~18:08 min), angle = 0 (right / setting)
    // At Nadir (00:08 min), angle = +PI/2 (nadir / bottom of circle)
    // At Dawn (~06:08 min), angle = PI (left / rising)
    readonly property real sunAngle: ((currentMinutes - 728) / 1440.0) * 2 * Math.PI - Math.PI / 2
    readonly property real moonAngle: sunAngle + Math.PI

    // Exact positions on the full circle orbit
    readonly property real sunX: centerX + radius * Math.cos(sunAngle)
    readonly property real sunY: centerY + radius * Math.sin(sunAngle)

    readonly property real moonX: centerX + radius * Math.cos(moonAngle)
    readonly property real moonY: centerY + radius * Math.sin(moonAngle)

    // Opacity: full brilliance when above horizon, softly dimmed during subterranean transit
    readonly property real sunOpacity: root.isDay ? 1.0 : 0.22
    readonly property real moonOpacity: (!root.isDay) ? 0.42 : 0.14

    // ONLY SUN AND MOON - Zero lines, zero text labels, zero tick marks.

    // Celestial Body: Sun Beacon (Small radiant point light with continuous Gaussian bloom & diffraction rays)
    Item {
        id: sunContainer
        x: root.sunX - width / 2
        y: root.sunY - height / 2
        width: 44
        height: 44
        opacity: root.sunOpacity
        Behavior on opacity {
            NumberAnimation { duration: 600 }
        }

        Canvas {
            id: sunCanvas
            anchors.fill: parent
            antialiasing: true
            renderTarget: Canvas.Image

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2;
                var cy = height / 2;
                var r = width / 2;

                // 1. Continuous smooth radial bloom (pure white core falling off smoothly to 0 alpha with zero hard edge)
                var radGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
                radGrad.addColorStop(0.00, "rgba(255, 255, 255, 1.0)");
                radGrad.addColorStop(0.08, "rgba(255, 255, 245, 0.95)");
                radGrad.addColorStop(0.20, "rgba(255, 245, 210, 0.50)");
                radGrad.addColorStop(0.38, "rgba(255, 230, 170, 0.18)");
                radGrad.addColorStop(0.65, "rgba(255, 215, 140, 0.04)");
                radGrad.addColorStop(1.00, "rgba(255, 200, 120, 0.00)");

                ctx.fillStyle = radGrad;
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.fill();

                // 2. Optical Diffraction Starburst Rays (Smooth linear alpha fade to needle tips)
                // Horizontal needle beam
                var hGrad = ctx.createLinearGradient(cx - 16, cy, cx + 16, cy);
                hGrad.addColorStop(0.00, "rgba(255, 255, 255, 0.0)");
                hGrad.addColorStop(0.35, "rgba(255, 255, 255, 0.35)");
                hGrad.addColorStop(0.50, "rgba(255, 255, 255, 0.90)");
                hGrad.addColorStop(0.65, "rgba(255, 255, 255, 0.35)");
                hGrad.addColorStop(1.00, "rgba(255, 255, 255, 0.0)");
                ctx.fillStyle = hGrad;
                ctx.fillRect(cx - 16, cy - 0.75, 32, 1.5);

                // 3. Brilliant pinpoint optical center spark
                ctx.fillStyle = "#ffffff";
                ctx.fillRect(cx - 1.0, cy - 1.0, 2.0, 2.0);
            }
        }
    }

    // Celestial Body: Silver Crescent Moon (Nighttime active - soft, serene & understated)
    Item {
        id: moonContainer
        x: root.moonX - width / 2
        y: root.moonY - height / 2
        width: 24
        height: 24
        opacity: root.moonOpacity
        Behavior on opacity {
            NumberAnimation { duration: 600 }
        }

        Text {
            anchors.centerIn: parent
            text: "󰽥"
            font.family: Island.Theme.iconFontFamily
            font.pixelSize: 12
            color: Qt.rgba(0.80, 0.78, 0.90, 0.75)
        }
    }
}
