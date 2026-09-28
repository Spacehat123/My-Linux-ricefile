import QtQuick
import Quickshell
import Quickshell.Bluetooth
pragma Singleton

// BtState: connected-device snapshot + connect/disconnect events for brief
// island feedback. Nothing is shown when nothing changed.
// This file never imports IslandHub (one-way); Notch wires events to the hub.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connectedNames: {
        if (!adapter || !adapter.devices)
            return [];
        const names = [];
        const devs = adapter.devices.values;
        for (let i = 0; i < devs.length; ++i) {
            if (devs[i] && devs[i].connected)
                names.push(devs[i].name || devs[i].deviceName || "device");
        }
        return names.sort();
    }

    property string lastEvent: ""
    property int eventTick: 0
    property var prevConnected: []

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = root.connectedNames;
            const prev = root.prevConnected;
            const joined = now.join("\n");
            for (let i = 0; i < now.length; ++i) {
                if (prev.indexOf(now[i]) < 0) {
                    root.lastEvent = now[i] + " connected";
                    root.eventTick += 1;
                }
            }
            for (let j = 0; j < prev.length; ++j) {
                if (now.indexOf(prev[j]) < 0) {
                    root.lastEvent = prev[j] + " disconnected";
                    root.eventTick += 1;
                }
            }
            root.prevConnected = now;
            void joined;
        }
    }
}
