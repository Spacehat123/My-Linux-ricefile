pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // =========================================================================
    // Desktop Ambient Authoritative State & Templates
    // =========================================================================
    // Templates:
    //  - "pranc": User's custom setup (horizontal clock, 0.5-alpha divider line, 4-line radial telemetry vitals ring, top-right weather)
    //  - "default": Clean vertical stacked clock (18 over 33), date, clean telemetry chips, weather
    //  - "minimal": Sleek single-line horizontal clock (HH:MM), date subtitle, subtle weather badge
    property string template: "pranc"

    // Positions: "top-left", "top-right", "bottom-left", "bottom-right", "center", "center-left"
    property string clockPosition: "top-left"

    // Visual Elements Toggles
    property bool showSunMoon: true
    property bool showParticles: true
    property bool showWeatherMist: true
    property bool showConstellationCard: true

    signal configChanged()

    function setTemplate(tpl: string) {
        if (tpl === "pranc" || tpl === "default" || tpl === "minimal") {
            root.template = tpl;
            saveConfig();
            configChanged();
        }
    }

    function cycleTemplate() {
        if (root.template === "pranc") root.setTemplate("default");
        else if (root.template === "default") root.setTemplate("minimal");
        else root.setTemplate("pranc");
    }

    function setClockPosition(pos: string) {
        const valid = ["top-left", "top-right", "bottom-left", "bottom-right", "center", "center-left"];
        if (valid.indexOf(pos) !== -1) {
            root.clockPosition = pos;
            saveConfig();
            configChanged();
        }
    }

    function cycleClockPosition() {
        const positions = ["top-left", "center", "bottom-left", "top-right"];
        let idx = positions.indexOf(root.clockPosition);
        if (idx === -1) idx = 0;
        root.setClockPosition(positions[(idx + 1) % positions.length]);
    }

    function setShowSunMoon(val: bool) {
        root.showSunMoon = Boolean(val);
        saveConfig();
        configChanged();
    }

    function toggleSunMoon() {
        setShowSunMoon(!root.showSunMoon);
    }

    function setShowParticles(val: bool) {
        root.showParticles = Boolean(val);
        saveConfig();
        configChanged();
    }

    function toggleParticles() {
        setShowParticles(!root.showParticles);
    }

    function setShowWeatherMist(val: bool) {
        root.showWeatherMist = Boolean(val);
        saveConfig();
        configChanged();
    }

    function setShowConstellationCard(val: bool) {
        root.showConstellationCard = Boolean(val);
        saveConfig();
        configChanged();
    }

    function saveConfig() {
        try {
            const data = {
                template: root.template,
                clockPosition: root.clockPosition,
                showSunMoon: root.showSunMoon,
                showParticles: root.showParticles,
                showWeatherMist: root.showWeatherMist,
                showConstellationCard: root.showConstellationCard
            };
            configFile.setText(JSON.stringify(data, null, 2) + "\n");
        } catch(e) {
            console.warn("[AmbientConfig] Failed to save config:", e);
        }
    }

    function loadConfig() {
        try {
            const raw = configFile.text();
            if (!raw || raw.trim() === "") return;
            const obj = JSON.parse(raw);
            if (obj.template) root.template = obj.template;
            if (obj.clockPosition) root.clockPosition = obj.clockPosition;
            if (obj.showSunMoon !== undefined) root.showSunMoon = Boolean(obj.showSunMoon);
            if (obj.showParticles !== undefined) root.showParticles = Boolean(obj.showParticles);
            if (obj.showWeatherMist !== undefined) root.showWeatherMist = Boolean(obj.showWeatherMist);
            if (obj.showConstellationCard !== undefined) root.showConstellationCard = Boolean(obj.showConstellationCard);
        } catch(e) {
            console.warn("[AmbientConfig] Failed to parse config JSON:", e);
        }
    }

    FileView {
        id: configFile
        path: Quickshell.shellPath("desktop/ambient_config.json")
        preload: true
        atomicWrites: true
        watchChanges: false
        onLoaded: root.loadConfig()
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                root.saveConfig();
            }
        }
    }
}
