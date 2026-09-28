import QtQuick
import Quickshell
pragma Singleton

// CallState: STUB architecture for calls/communication.
// LIMITATION: desktop Linux exposes no generic incoming-call API. Telephony
// (ModemManager/ofono) is rarely present and PipeWire call streams are
// indistinguishable from ordinary mic use, so nothing here is faked:
// active stays false until a real provider registers one.
// A future integration (e.g. ModemManager voice-call DBus) only needs to
// set active/caller/controls; IslandHub + CollapsedStatus already route it.
Singleton {
    id: root

    property bool active: false
    property bool incoming: false
    property string caller: ""
    property bool canAnswer: false
    property bool canDecline: false
    property bool canMute: false
    property bool canEnd: false

    // Provider hook: integrations call register(call) with the fields above.
    function register(info) {
        if (!info)
            return;
        active = info.active === true;
        incoming = info.incoming === true;
        caller = info.caller || "";
        canAnswer = info.canAnswer === true;
        canDecline = info.canDecline === true;
        canMute = info.canMute === true;
        canEnd = info.canEnd === true;
    }
    function clear() {
        active = false;
        incoming = false;
        caller = "";
    }
}
