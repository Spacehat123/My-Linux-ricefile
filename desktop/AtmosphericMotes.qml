import QtQuick
import "../island" as Island

Item {
    id: root

    property bool active: true
    anchors.fill: parent

    // Global cursor tracking passed in from AmbientLayer
    property real cursorX: width / 2
    property real cursorY: height / 2
    property bool cursorPresent: false

    // Card collision bounds passed from AmbientLayer (with automatic fallbacks)
    property rect cardLeftRect: Qt.rect(0, 0, 0, 0)
    property rect cardRightRect: Qt.rect(0, 0, 0, 0)

    // Dynamic Solid Obstacles List (Cards & Top Bars)
    function getObstacleList() {
        const w = root.width > 100 ? root.width : 1920;
        const h = root.height > 100 ? root.height : 1080;

        // Card bounding boxes
        const leftX = (cardLeftRect.width > 0) ? cardLeftRect.x : 48;
        const leftY = (cardLeftRect.height > 0) ? cardLeftRect.y : (h - 48 - 260);
        const leftW = (cardLeftRect.width > 0) ? cardLeftRect.width : 500;
        const leftH = (cardLeftRect.height > 0) ? cardLeftRect.height : 260;

        const rightX = (cardRightRect.width > 0) ? cardRightRect.x : (w - 48 - 500);
        const rightY = (cardRightRect.height > 0) ? cardRightRect.y : (h - 48 - 260);
        const rightW = (cardRightRect.width > 0) ? cardRightRect.width : 500;
        const rightH = (cardRightRect.height > 0) ? cardRightRect.height : 260;

        // Top Bar Convex Metrics
        const wingW = Math.min(360, w * 0.22);
        const wingH = 46;

        const isNotchExpanded = Boolean(Island.ShellState && Island.ShellState.expanded);
        const notchW = isNotchExpanded
            ? (Island.ShellState.panelWidths[Island.ShellState.panel] || 480) 
            : 380;
        const notchH = isNotchExpanded
            ? ((Island.ShellState.panelHeights[Island.ShellState.panel] || 300) + 40)
            : 48;
        const notchX = (w - notchW) / 2;

        return [
            // 1. Bottom-Left Card (Clock / Weather Slate)
            { x: leftX, y: leftY, width: leftW, height: leftH },

            // 2. Bottom-Right Card (Constellation / Git Card)
            { x: rightX, y: rightY, width: rightW, height: rightH },

            // 3. Top-Left Bar (Workspaces & Sparkle Pill)
            { x: 0, y: 0, width: wingW, height: wingH },

            // 4. Top-Center Bar (Dynamic Island Notch)
            { x: notchX, y: 0, width: notchW, height: notchH },

            // 5. Top-Right Bar (System Tray / Battery / Status)
            { x: w - wingW, y: 0, width: wingW, height: wingH }
        ];
    }

    // 14 Autonomous Celestial Living Air Stars
    readonly property int moteCount: 14

    // Frame physics timer (50 FPS) for continuous 2D motion, bounce physics & cursor repulsion
    Timer {
        id: physicsTimer
        interval: 20
        repeat: true
        running: root.active && root.visible
        onTriggered: {
            for (let i = 0; i < moteRepeater.count; i++) {
                const item = moteRepeater.itemAt(i);
                if (item && typeof item.updatePhysics === "function") {
                    item.updatePhysics();
                }
            }
        }
    }

    Repeater {
        id: moteRepeater
        model: root.moteCount

        Item {
            id: mote
            required property int index

            // Star class: 0 = Diamond Glint Star, 1 = Celestial Gold Firefly, 2 = Twilight Lavender Mote
            readonly property int starClass: index % 3

            // Microscopic optical flare sizing (delicate pinpoint starlight)
            readonly property real rayLength: (starClass === 0) ? 3.2 : (starClass === 1 ? 2.6 : 2.0)
            readonly property real bloomRadius: rayLength * 1.35

            // Dynamic theme-aware star colors
            readonly property color starTint: {
                if (starClass === 1) {
                    return Qt.rgba(1.0, 0.90, 0.62, 0.80); // Warm celestial gold
                } else if (starClass === 2) {
                    return Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.80); // Aurora primary
                } else {
                    return Qt.rgba(0.92, 0.95, 1.0, 0.90); // Pure diamond silver-white
                }
            }

            // Real physical 2D coordinates & velocity vectors (No predetermined orbits!)
            property real xPos: 0.0
            property real yPos: 0.0
            property real vx: 0.0
            property real vy: 0.0

            // Interactive cursor excitation (sparkles brighter when cursor sweeps past)
            property real excitation: 0.0

            // Baseline resting starlight opacity (subtle, serene)
            readonly property real baseOpacity: 0.18 + (index % 4) * 0.04
            property real twinkleOpacity: baseOpacity

            // Dynamic twinkle animation parameters (re-randomized per twinkle event)
            property real peak1: 0.90
            property real peak2: 0.95
            property real dipVal: 0.40
            property int dUp1: 140
            property int dDown1: 400
            property int dDip: 90
            property int dUp2: 120
            property int dFade2: 500

            width: 16
            height: 16

            // Subtle scale coupling: stays strictly microscopic even when flashing
            scale: 0.90 + (twinkleOpacity - baseOpacity) * 0.25 + excitation * 0.20
            opacity: Math.min(1.0, twinkleOpacity + excitation * 0.45) * (root.active ? 1.0 : 0.0)

            // Dynamic Stochastic Twinkle Controller:
            // Truly random: rolls between single blink (~55%) and double blink (~45%),
            // with randomized peak brilliances, flash speeds, and irregular rest pauses.
            Timer {
                id: twinkleTimer
                interval: 800 + Math.floor(Math.random() * 2600) + (mote.index * 180)
                running: root.active
                repeat: false
                onTriggered: mote.triggerRandomTwinkle()
            }

            // Single Blink Animation: Fast flare -> smooth decay
            SequentialAnimation {
                id: singleBlinkAnim
                NumberAnimation {
                    target: mote
                    property: "twinkleOpacity"
                    to: mote.peak1
                    duration: mote.dUp1
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: mote
                    property: "twinkleOpacity"
                    to: mote.baseOpacity
                    duration: mote.dDown1
                    easing.type: Easing.InOutSine
                }
                onFinished: mote.scheduleNextTwinkle()
            }

            // Double Blink Animation: Flare 1 -> quick dip -> Flare 2 -> smooth decay
            SequentialAnimation {
                id: doubleBlinkAnim
                // First Blink
                NumberAnimation {
                    target: mote
                    property: "twinkleOpacity"
                    to: mote.peak1
                    duration: mote.dUp1
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: mote
                    property: "twinkleOpacity"
                    to: mote.dipVal
                    duration: mote.dDip
                    easing.type: Easing.InOutSine
                }
                // Second Blink
                NumberAnimation {
                    target: mote
                    property: "twinkleOpacity"
                    to: mote.peak2
                    duration: mote.dUp2
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: mote
                    property: "twinkleOpacity"
                    to: mote.baseOpacity
                    duration: mote.dFade2
                    easing.type: Easing.InOutSine
                }
                onFinished: mote.scheduleNextTwinkle()
            }

            function triggerRandomTwinkle() {
                if (!root.active) return;
                if (singleBlinkAnim.running || doubleBlinkAnim.running) return;

                peak1 = 0.85 + Math.random() * 0.15;
                dUp1 = 110 + Math.floor(Math.random() * 90);

                const roll = Math.random();
                if (roll < 0.55) {
                    // Single Blink
                    dDown1 = 320 + Math.floor(Math.random() * 420);
                    singleBlinkAnim.restart();
                } else {
                    // Double Blink
                    dipVal = 0.35 + Math.random() * 0.18;
                    dDip = 75 + Math.floor(Math.random() * 65);
                    peak2 = 0.88 + Math.random() * 0.12;
                    dUp2 = 95 + Math.floor(Math.random() * 85);
                    dFade2 = 380 + Math.floor(Math.random() * 420);
                    doubleBlinkAnim.restart();
                }
            }

            function scheduleNextTwinkle() {
                if (!root.active) return;
                // Organic pause before the next twinkle event (0.8s to 4.5s)
                twinkleTimer.interval = 800 + Math.floor(Math.random() * 3700);
                twinkleTimer.restart();
            }

            // Helper: Test if coordinate falls within any solid obstacle (plus safety padding)
            function isInsideAnyObstacle(px, py, obstacles) {
                const pad = 12.0;
                for (let i = 0; i < obstacles.length; i++) {
                    const obs = obstacles[i];
                    if (!obs || obs.width <= 0 || obs.height <= 0) continue;
                    if (px >= obs.x - pad && px <= obs.x + obs.width + pad &&
                        py >= obs.y - pad && py <= obs.y + obs.height + pad) {
                        return true;
                    }
                }
                return false;
            }

            // Initialization: Spawn at truly random 2D screen positions outside cards & top bars
            function initPosition() {
                const w = root.width > 100 ? root.width : 1920;
                const h = root.height > 100 ? root.height : 1080;
                const obstacles = root.getObstacleList();

                let attempts = 0;
                let chosenX = w * 0.5;
                let chosenY = h * 0.44;

                while (attempts < 40) {
                    const candidateX = 30 + Math.random() * (w - 60);
                    const candidateY = 30 + Math.random() * (h - 60);
                    if (!isInsideAnyObstacle(candidateX, candidateY, obstacles)) {
                        chosenX = candidateX;
                        chosenY = candidateY;
                        break;
                    }
                    attempts++;
                }

                xPos = chosenX;
                yPos = chosenY;

                const angle = Math.random() * 2 * Math.PI;
                const speed = 0.35 + Math.random() * 0.45; // Gentle majestic drift
                vx = Math.cos(angle) * speed;
                vy = Math.sin(angle) * speed;

                x = Math.round(xPos - width / 2);
                y = Math.round(yPos - height / 2);
            }

            Component.onCompleted: initPosition()

            // Continuous 2D Physics Update: Drift, Screen Edge Bouncing, Card & Top Bar Obstacle Bouncing
            function updatePhysics() {
                const w = root.width > 100 ? root.width : 1920;
                const h = root.height > 100 ? root.height : 1080;
                const margin = 12.0;
                const minX = margin;
                const maxX = w - margin;
                const minY = margin;
                const maxY = h - margin;

                // First-run initialization check if size was zero on startup
                if (xPos === 0.0 && yPos === 0.0) {
                    initPosition();
                    return;
                }

                // 1. Interactive Cursor Repulsion & Excitation
                if (root.cursorPresent) {
                    const dx = xPos - root.cursorX;
                    const dy = yPos - root.cursorY;
                    const dist = Math.sqrt(dx * dx + dy * dy);
                    const threshold = 135.0;

                    if (dist < threshold && dist > 1.0) {
                        const force = (threshold - dist) / threshold;
                        vx += (dx / dist) * force * 1.35;
                        vy += (dy / dist) * force * 1.35;
                        excitation = Math.min(1.0, excitation + force * 0.35);
                    } else {
                        excitation *= 0.92;
                    }
                } else {
                    excitation *= 0.92;
                }

                // 2. Continuous Brownian Steering (Subtle micro-acceleration so motion feels organic)
                vx += (Math.random() - 0.5) * 0.025;
                vy += (Math.random() - 0.5) * 0.025;

                // 3. Gentle Speed Normalization (Damps after cursor kicks, prevents stopping)
                const currentSpeed = Math.sqrt(vx * vx + vy * vy);
                if (currentSpeed > 2.0) {
                    vx *= 0.96;
                    vy *= 0.96;
                } else if (currentSpeed < 0.25) {
                    vx *= 1.06;
                    vy *= 1.06;
                }

                // 4. Update Position
                xPos += vx;
                yPos += vy;

                // 5. Outer Screen Perimeter Elastic Bounces
                if (xPos <= minX) {
                    xPos = minX;
                    vx = Math.abs(vx) * (0.88 + Math.random() * 0.24); // Bounce right
                    vy += (Math.random() - 0.5) * 0.25;
                } else if (xPos >= maxX) {
                    xPos = maxX;
                    vx = -Math.abs(vx) * (0.88 + Math.random() * 0.24); // Bounce left
                    vy += (Math.random() - 0.5) * 0.25;
                }

                if (yPos <= minY) {
                    yPos = minY;
                    vy = Math.abs(vy) * (0.88 + Math.random() * 0.24); // Bounce down
                    vx += (Math.random() - 0.5) * 0.25;
                } else if (yPos >= maxY) {
                    yPos = maxY;
                    vy = -Math.abs(vy) * (0.88 + Math.random() * 0.24); // Bounce up
                    vx += (Math.random() - 0.5) * 0.25;
                }

                // 6. Solid Obstacle Collision Bounces (Cards & Top Bars)
                const obstacles = root.getObstacleList();
                const pad = 6.0; // Buffer so the star glint doesn't clip into the frosted glass border

                for (let i = 0; i < obstacles.length; i++) {
                    const obs = obstacles[i];
                    if (!obs || obs.width <= 0 || obs.height <= 0) continue;

                    const x1 = obs.x - pad;
                    const x2 = obs.x + obs.width + pad;
                    const y1 = obs.y - pad;
                    const y2 = obs.y + obs.height + pad;

                    if (xPos >= x1 && xPos <= x2 && yPos >= y1 && yPos <= y2) {
                        // Penetration depths to all 4 edges of this obstacle
                        const dLeft = xPos - x1;
                        const dRight = x2 - xPos;
                        const dTop = yPos - y1;
                        const dBottom = y2 - yPos;

                        const minD = Math.min(dLeft, dRight, dTop, dBottom);

                        if (minD === dTop) {
                            // Hit top edge of card/bar -> bounce up
                            yPos = y1;
                            vy = -Math.abs(vy) * (0.88 + Math.random() * 0.24);
                            vx += (Math.random() - 0.5) * 0.25;
                        } else if (minD === dBottom) {
                            // Hit bottom edge of top bar -> bounce down
                            yPos = y2;
                            vy = Math.abs(vy) * (0.88 + Math.random() * 0.24);
                            vx += (Math.random() - 0.5) * 0.25;
                        } else if (minD === dLeft) {
                            // Hit left edge of obstacle -> bounce left
                            xPos = x1;
                            vx = -Math.abs(vx) * (0.88 + Math.random() * 0.24);
                            vy += (Math.random() - 0.5) * 0.25;
                        } else {
                            // Hit right edge of obstacle -> bounce right
                            xPos = x2;
                            vx = Math.abs(vx) * (0.88 + Math.random() * 0.24);
                            vy += (Math.random() - 0.5) * 0.25;
                        }

                        // Physical glass bounce glint excitation: star sparkles when hitting a card/bar
                        excitation = Math.min(1.0, excitation + 0.28);
                    }
                }

                // 7. Set Item Coordinates
                x = Math.round(xPos - width / 2);
                y = Math.round(yPos - height / 2);
            }

            // =================================================================
            // Pure Optical Celestial Star Light Rendering (Canvas 2D)
            // NO hard circles. True point spread function (PSF):
            // - Smooth Gaussian radial bloom (zero hard perimeter edge)
            // - Astroid 4-point diamond star flare (pinched concave curves)
            // - Ultra-fine diffraction needle beams (linear alpha fade)
            // - Pure pinpoint white spark center
            // =================================================================
            Canvas {
                id: starCanvas
                anchors.fill: parent
                renderTarget: Canvas.Image
                antialiasing: true

                property color themeColor: mote.starTint
                onThemeColorChanged: requestPaint()

                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var cx = width / 2;
                    var cy = height / 2;
                    var ray = mote.rayLength;
                    var bRad = mote.bloomRadius;
                    var tint = mote.starTint;

                    ctx.save();

                    // 1. Continuous Asymptotic Radial Bloom (ZERO hard perimeter edge)
                    var radGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, bRad);
                    radGrad.addColorStop(0.00, "rgba(255, 255, 255, 1.0)");
                    radGrad.addColorStop(0.18, Qt.rgba(tint.r, tint.g, tint.b, 0.85));
                    radGrad.addColorStop(0.45, Qt.rgba(tint.r, tint.g, tint.b, 0.25));
                    radGrad.addColorStop(0.75, Qt.rgba(tint.r, tint.g, tint.b, 0.05));
                    radGrad.addColorStop(1.00, "rgba(0, 0, 0, 0.0)");
                    ctx.fillStyle = radGrad;
                    ctx.beginPath();
                    ctx.arc(cx, cy, bRad, 0, 2 * Math.PI);
                    ctx.fill();

                    // 2. 4-pointed Astroid Diamond Star Flare (Pinched curved diamond)
                    var pinch = ray * 0.12;
                    ctx.beginPath();
                    ctx.moveTo(cx, cy - ray);
                    ctx.quadraticCurveTo(cx + pinch, cy - pinch, cx + ray, cy);
                    ctx.quadraticCurveTo(cx + pinch, cy + pinch, cx, cy + ray);
                    ctx.quadraticCurveTo(cx - pinch, cy + pinch, cx - ray, cy);
                    ctx.quadraticCurveTo(cx - pinch, cy - pinch, cx, cy - ray);
                    ctx.closePath();

                    var flareGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, ray);
                    flareGrad.addColorStop(0.00, "rgba(255, 255, 255, 1.0)");
                    flareGrad.addColorStop(0.35, Qt.rgba(tint.r, tint.g, tint.b, 0.85));
                    flareGrad.addColorStop(0.70, Qt.rgba(tint.r, tint.g, tint.b, 0.25));
                    flareGrad.addColorStop(1.00, "rgba(255, 255, 255, 0.0)");
                    ctx.fillStyle = flareGrad;
                    ctx.fill();

                    // 3. Microscopic Horizontal Diffraction Needle Beam
                    var hBeam = ctx.createLinearGradient(cx - ray * 1.25, cy, cx + ray * 1.25, cy);
                    hBeam.addColorStop(0.00, "rgba(255, 255, 255, 0.0)");
                    hBeam.addColorStop(0.35, Qt.rgba(tint.r, tint.g, tint.b, 0.35));
                    hBeam.addColorStop(0.50, "rgba(255, 255, 255, 0.95)");
                    hBeam.addColorStop(0.65, Qt.rgba(tint.r, tint.g, tint.b, 0.35));
                    hBeam.addColorStop(1.00, "rgba(255, 255, 255, 0.0)");
                    ctx.fillStyle = hBeam;
                    ctx.fillRect(cx - ray * 1.25, cy - 0.4, ray * 2.5, 0.8);

                    // 4. Microscopic Vertical Diffraction Needle Beam
                    var vBeam = ctx.createLinearGradient(cx, cy - ray * 1.25, cx, cy + ray * 1.25);
                    vBeam.addColorStop(0.00, "rgba(255, 255, 255, 0.0)");
                    vBeam.addColorStop(0.35, Qt.rgba(tint.r, tint.g, tint.b, 0.35));
                    vBeam.addColorStop(0.50, "rgba(255, 255, 255, 0.95)");
                    vBeam.addColorStop(0.65, Qt.rgba(tint.r, tint.g, tint.b, 0.35));
                    vBeam.addColorStop(1.00, "rgba(255, 255, 255, 0.0)");
                    ctx.fillStyle = vBeam;
                    ctx.fillRect(cx - 0.4, cy - ray * 1.25, 0.8, ray * 2.5);

                    // 5. Diagonal Micro-Spikes for Focal Diamond Stars (index % 3 === 0)
                    if (mote.starClass === 0) {
                        var dRay = ray * 0.40;
                        ctx.strokeStyle = "rgba(255, 255, 255, 0.30)";
                        ctx.lineWidth = 0.5;
                        ctx.beginPath();
                        ctx.moveTo(cx - dRay * 0.707, cy - dRay * 0.707);
                        ctx.lineTo(cx + dRay * 0.707, cy + dRay * 0.707);
                        ctx.moveTo(cx - dRay * 0.707, cy + dRay * 0.707);
                        ctx.lineTo(cx + dRay * 0.707, cy - dRay * 0.707);
                        ctx.stroke();
                    }

                    // 6. Brilliant Pinpoint Micro-Spark Center (1px optical core)
                    ctx.fillStyle = "#ffffff";
                    ctx.fillRect(cx - 0.5, cy - 0.5, 1.0, 1.0);

                    ctx.restore();
                }
            }
        }
    }
}
