import QtQuick
import Quickshell
import Quickshell.Services.UPower
pragma Singleton

// PowerState: battery/charging truth from UPower. Display only; no actions.
// IslandHub/Notch consume this. This file never imports IslandHub (one-way).
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: device && device.ready
    // UPowerDeviceState: 1=charging, 4=fully charged (enum may vary; use isCharging helper below)
    readonly property real percent: hasBattery ? device.percentage : 0
    readonly property bool onBattery: UPower.onBattery
    readonly property bool charging: hasBattery && !onBattery && percent < 0.995
    readonly property bool low: hasBattery && onBattery && percent <= 0.2

    property string lastPlugEvent: ""
    property int plugEventTick: 0
    property bool wasCharging: false
    property bool wasOnBattery: true

    // Detect plug/unplug transitions for transient island feedback.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            const ch = root.charging;
            const ob = root.onBattery;
            if (root.hasBattery && (ch !== root.wasCharging || ob !== root.wasOnBattery)) {
                root.wasCharging = ch;
                root.wasOnBattery = ob;
                if (ch)
                    root.lastPlugEvent = "Charging " + Math.round(root.percent * 100) + "%";
                else if (!ob)
                    root.lastPlugEvent = "Fully charged";
                else
                    root.lastPlugEvent = "On battery " + Math.round(root.percent * 100) + "%";
                root.plugEventTick += 1;
            }
        }
    }

    Component.onCompleted: {
        root.wasCharging = root.charging;
        root.wasOnBattery = root.onBattery;
    }
}
