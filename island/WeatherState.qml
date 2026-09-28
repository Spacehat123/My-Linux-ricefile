import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// WeatherState: current conditions via wttr.in JSON (keyless, no new deps),
// cached 30 minutes. Collapsed indicator only when pinned in the panel.
// LIMITATION: location by IP geolocation (coarse); offline shows cached/stale.
Singleton {
    id: root

    property string tempC: ""
    property string condition: ""
    property string area: ""
    property string updatedAt: ""
    property bool stale: true
    property bool pinned: false
    property bool loading: false

    readonly property string cachePath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/cool-shell-weather.json"

    function refresh() {
        if (fetchProcess.running)
            return;
        loading = true;
        fetchProcess.exec(["sh", "-c", "curl -s --max-time 15 'https://wttr.in/?format=j1' -o '" + root.cachePath.replace(/'/g, "'\\''") + "' && echo OK || echo FAIL"]);
    }

    function loadCache() {
        readProcess.running = true;
    }

    readonly property bool collapsedVisible: pinned && tempC !== ""

    Process {
        id: fetchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                if (text.trim() === "OK")
                    root.loadCache();
            }
        }
    }

    Process {
        id: readProcess
        command: ["cat", root.cachePath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const cur = data.current_condition && data.current_condition[0];
                    const near = data.nearest_area && data.nearest_area[0];
                    if (cur) {
                        root.tempC = cur.temp_C + "°";
                        root.condition = cur.weatherDesc && cur.weatherDesc[0] ? cur.weatherDesc[0].value : "";
                        root.stale = false;
                        const d = new Date();
                        root.updatedAt = d.getHours() + ":" + String(d.getMinutes()).padStart(2, "0");
                    }
                    if (near)
                        root.area = near.areaName && near.areaName[0] ? near.areaName[0].value : "";
                } catch (e) {
                }
            }
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
