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
    // Adapter power state (BlueZ Powered). Null-safe for missing adapter.
    readonly property bool available: !!adapter
    readonly property bool powered: adapter ? !!adapter.enabled : false
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
    // Rich device snapshot for Control Center / debugging.
    readonly property var deviceDetails: {
        if (!adapter || !adapter.devices)
            return [];
        const out = [];
        const devs = adapter.devices.values;
        for (let i = 0; i < devs.length; ++i) {
            const d = devs[i];
            if (!d)
                continue;
            out.push({
                name: d.name || d.deviceName || "device",
                address: d.address || "",
                connected: !!d.connected,
                paired: !!(d.paired || d.bonded)
            });
        }
        return out;
    }

    property string lastEvent: ""
    property int eventTick: 0
    property var prevConnected: []

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            const now = root.connectedNames;
            const prev = root.prevConnected;
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
        }
    }

    // Seed baseline silently so startup/reload never flashes a stale event.
    Component.onCompleted: root.prevConnected = root.connectedNames
}
