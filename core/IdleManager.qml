import QtQuick
import Quickshell
import Quickshell.Wayland

QtObject {
    id: root

    // =========================================================================
    // Authoritative Configuration & State Properties
    // =========================================================================
    property bool enabled: true
    property int idleSeconds: 60
    property bool respectInhibitors: true

    // Headless test simulation hooks
    property bool simulationActive: false
    property bool simulatedIdle: false

    // =========================================================================
    // Wayland ext_idle_notification_v1 Integration
    // =========================================================================
    property IdleMonitor monitor: IdleMonitor {
        id: waylandMonitor
        enabled: root.enabled && !root.simulationActive
        timeout: Math.max(1, root.idleSeconds)
        respectInhibitors: root.respectInhibitors

        onIsIdleChanged: {
            if (!root.simulationActive) {
                root._handleStateChange(waylandMonitor.isIdle);
            }
        }
    }

    // =========================================================================
    // Derived Reactive Global State
    // =========================================================================
    readonly property bool idle: {
        if (!root.enabled) return false;
        if (root.simulationActive) return root.simulatedIdle;
        return waylandMonitor ? waylandMonitor.isIdle : false;
    }

    // =========================================================================
    // Signals
    // =========================================================================
    signal idleEntered()
    signal idleExited()

    // =========================================================================
    // Internal State Tracking & Event Dispatch
    // =========================================================================
    property bool _lastReportedIdle: false

    function _handleStateChange(current: bool) {
        if (root._lastReportedIdle === current) return;
        root._lastReportedIdle = current;

        if (current) {
            root.idleEntered();
            console.log("[pranc-shell:idle] System entered IDLE state (timeout=" + root.idleSeconds + "s)");
        } else {
            root.idleExited();
            console.log("[pranc-shell:idle] System resumed ACTIVE state");
        }
    }

    onIdleChanged: {
        _handleStateChange(root.idle);
    }

    // =========================================================================
    // Dynamic Control API
    // =========================================================================
    function setIdleSeconds(seconds: int) {
        root.idleSeconds = Math.max(1, seconds);
    }

    function setIdleTimeout(seconds: int) {
        setIdleSeconds(seconds);
    }

    function setEnabled(val: bool) {
        root.enabled = val;
    }

    function setRespectInhibitors(val: bool) {
        root.respectInhibitors = val;
    }

    function setSimulatedIdle(val: bool) {
        root.simulationActive = true;
        root.simulatedIdle = val;
        _handleStateChange(val);
    }

    function clearSimulation() {
        root.simulationActive = false;
        _handleStateChange(waylandMonitor ? waylandMonitor.isIdle : false);
    }
}
