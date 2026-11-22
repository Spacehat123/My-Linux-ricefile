import QtQuick
import "../island" as Island

Item {
    id: root

    property bool active: true
    anchors.fill: parent

    // Pool configuration
    readonly property int maxGlyphs: 24
    readonly property int maxRipples: 8
    property int glyphIndex: 0
    property int rippleIndex: 0

    readonly property var glyphVocabulary: [
        "0x7F", "SYS::OK", "λ", "RUNNING", "42°C",
        "SYNC", "0xFF", "ACK", "0x3A", "FLOW", "LIVE"
    ]

    function spawnBurst(originX, originY) {
        if (!root.active) return;
        // Spawn 3 glyphs with slight offsets
        for (let i = 0; i < 3; i++) {
            const angle = (Math.PI * 2 / 3) * i + (Math.random() * 0.4 - 0.2);
            const dist = 12 + Math.random() * 20;
            const gx = originX + Math.cos(angle) * dist;
            const gy = originY + Math.sin(angle) * dist;
            const text = glyphVocabulary[Math.floor(Math.random() * glyphVocabulary.length)];
            spawnGlyph(gx, gy, text);
        }
        spawnRipple(originX, originY);
    }

    function spawnGlyph(gx, gy, text) {
        const item = glyphRepeater.itemAt(glyphIndex);
        glyphIndex = (glyphIndex + 1) % maxGlyphs;
        if (item) {
            item.launch(gx, gy, text);
        }
    }

    function spawnRipple(rx, ry) {
        const item = rippleRepeater.itemAt(rippleIndex);
        rippleIndex = (rippleIndex + 1) % maxRipples;
        if (item) {
            item.launch(rx, ry);
        }
    }

    // Gentle ambient dust generator during idle / empty workspace
    Timer {
        interval: 3200
        running: root.active && root.visible
        repeat: true
        onTriggered: {
            if (Math.random() > 0.4) {
                const rx = 100 + Math.random() * (root.width - 200);
                const ry = 150 + Math.random() * (root.height - 350);
                root.spawnGlyph(rx, ry, Math.random() > 0.5 ? "·" : "+");
            }
        }
    }

    // Kinetic Ripples
    Repeater {
        id: rippleRepeater
        model: root.maxRipples

        Rectangle {
            id: rip
            width: 8
            height: 8
            radius: width / 2
            color: "transparent"
            border.color: Island.Theme.primary
            border.width: 1.5
            opacity: 0.0
            visible: opacity > 0.0

            property real targetRadius: 46

            function launch(lx, ly) {
                x = lx - width / 2;
                y = ly - height / 2;
                ripAnim.stop();
                ripAnim.start();
            }

            ParallelAnimation {
                id: ripAnim
                NumberAnimation { target: rip; property: "scale"; from: 0.5; to: 4.5; duration: 750; easing.type: Easing.OutQuad }
                NumberAnimation { target: rip; property: "opacity"; from: 0.75; to: 0.0; duration: 750; easing.type: Easing.OutQuad }
            }
        }
    }

    // Ghost Glyphs
    Repeater {
        id: glyphRepeater
        model: root.maxGlyphs

        Text {
            id: glyphText
            opacity: 0.0
            visible: opacity > 0.0
            font.family: Island.Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1.5
            color: Island.Theme.primary

            property real targetY: 0
            property real driftX: 0

            function launch(lx, ly, txt) {
                text = txt;
                x = lx;
                y = ly;
                targetY = ly - (45 + Math.random() * 35);
                driftX = lx + (Math.random() * 30 - 15);
                anim.stop();
                anim.start();
            }

            ParallelAnimation {
                id: anim
                NumberAnimation { target: glyphText; property: "y"; to: glyphText.targetY; duration: 1600; easing.type: Easing.OutCubic }
                NumberAnimation { target: glyphText; property: "x"; to: glyphText.driftX; duration: 1600; easing.type: Easing.OutQuad }
                SequentialAnimation {
                    NumberAnimation { target: glyphText; property: "opacity"; from: 0.0; to: 0.95; duration: 150; easing.type: Easing.OutQuad }
                    PauseAnimation { duration: 650 }
                    NumberAnimation { target: glyphText; property: "opacity"; to: 0.0; duration: 800; easing.type: Easing.InQuad }
                }
            }
        }
    }
}
