import QtQuick
import Quickshell
pragma Singleton

// TimerState: stopwatch + countdowns + focus sessions. Local facility,
// no system API needed. Shown in the island ONLY while active.
// IslandHub/Notch consume this. This file never imports IslandHub (one-way).
Singleton {
    id: root

    // -- stopwatch --
    property bool swRunning: false
    property int swElapsedSec: 0
    property double swBase: 0

    // -- countdowns: [{id, label, totalSec, remainingSec, running}] --
    property var countdowns: []
    property int nextId: 1

    // -- focus session (sets IslandHub.dnd while active) --
    property bool focusActive: false
    property int focusRemainingSec: 0
    property int focusTotalSec: 25 * 60

    readonly property bool hasActive: swRunning || focusActive || activeCountdown !== null
    readonly property var activeCountdown: {
        for (let i = 0; i < countdowns.length; ++i) {
            if (countdowns[i].running)
                return countdowns[i];
        }
        return null;
    }
    readonly property string compactText: {
        if (root.completionHold)
            return (root.completedLabel ? root.completedLabel + " " : "") + "DONE";
        if (focusActive)
            return "Focus " + IslandHub.formatElapsed(focusRemainingSec);
        if (activeCountdown)
            return (activeCountdown.label ? activeCountdown.label + " " : "") + IslandHub.formatElapsed(activeCountdown.remainingSec);
        if (swRunning)
            return IslandHub.formatElapsed(swElapsedSec);
        return "";
    }
    // Timer progress for island line: 0.0 -> 1.0.
    // During the completion hold the line snaps full so the finish reads.
    readonly property real progressFraction: {
        if (root.completionHold)
            return 1;
        if (focusActive && focusTotalSec > 0)
            return 1 - focusRemainingSec / focusTotalSec;
        if (activeCountdown && activeCountdown.totalSec > 0)
            return 1 - activeCountdown.remainingSec / activeCountdown.totalSec;
        return -1; // inactive
    }
    // Urgent countdown (≤5s remaining): -1 = not urgent, else seconds remaining
    readonly property int urgentRemaining: {
        if (focusActive && focusRemainingSec > 0 && focusRemainingSec <= 5)
            return focusRemainingSec;
        if (activeCountdown && activeCountdown.remainingSec > 0 && activeCountdown.remainingSec <= 5)
            return activeCountdown.remainingSec;
        return -1;
    }

    function swStart() {
        swBase = Date.now() / 1000 - swElapsedSec;
        swRunning = true;
    }
    function swPause() {
        swElapsedSec = Math.floor(Date.now() / 1000 - swBase);
        swRunning = false;
    }
    function swReset() {
        swRunning = false;
        swElapsedSec = 0;
    }

    function addCountdown(minutes, label) {
        root.clearCompletionHold();
        const total = Math.max(60, Math.round((Number(minutes) || 5) * 60));
        const next = countdowns.slice();
        next.push({ id: nextId++, label: (label || "").slice(0, 24), totalSec: total, remainingSec: total, running: false, base: 0 });
        countdowns = next;
    }
    function toggleCountdown(id) {
        root.clearCompletionHold();
        const next = countdowns.slice();
        for (let i = 0; i < next.length; ++i) {
            if (next[i].id === id) {
                const c = Object.assign({}, next[i]);
                if (c.running) {
                    c.remainingSec = Math.max(0, Math.ceil(c.base - Date.now() / 1000));
                    c.running = false;
                } else {
                    c.base = Date.now() / 1000 + c.remainingSec;
                    c.running = true;
                }
                next[i] = c;
            }
        }
        countdowns = next;
    }
    function removeCountdown(id) {
        root.clearCompletionHold();
        countdowns = countdowns.filter((c) => c.id !== id);
    }

    function startFocus(minutes) {
        root.clearCompletionHold();
        focusTotalSec = Math.max(60, Math.round((Number(minutes) || 25) * 60));
        focusRemainingSec = focusTotalSec;
        focusActive = true;
        IslandHub.dnd = true;
    }
    function endFocus() {
        focusActive = false;
        IslandHub.dnd = false;
    }

    // One-shot completion tick: Notch watches this for a compact pop.
    property int doneTick: 0
    // Completion hold: keeps a readable DONE state after a REAL
    // zero-crossing until the user clicks the island (which clears it
    // and opens the timer panel). Never set on pause/cancel/remove —
    // only in the tick handler's finish branches.
    property string completedLabel: ""
    property bool completionHold: false
    function clearCompletionHold() {
        completionHold = false;
    }
    function raiseCompletion(label) {
        completedLabel = label || "Timer";
        completionHold = true;
        IslandHub.showTransient(completedLabel + " DONE", 1500);
        IslandHub.flashBorder(Theme.primary, 1200);
        IslandHub.burst();
        root.doneTick += 1;
    }

    Timer {
        interval: 1000
        running: root.swRunning
        repeat: true
        onTriggered: root.swElapsedSec = Math.floor(Date.now() / 1000 - root.swBase)
    }

    Timer {
        interval: 1000
        running: root.activeCountdown !== null || root.focusActive
        repeat: true
        onTriggered: {
            const now = Date.now() / 1000;
            let changed = false;
            const next = root.countdowns.slice();
            for (let i = 0; i < next.length; ++i) {
                if (next[i].running) {
                    const c = Object.assign({}, next[i]);
                    c.remainingSec = Math.max(0, Math.ceil(c.base - now));
                    if (c.remainingSec <= 0) {
                        c.running = false;
                        root.raiseCompletion(c.label);
                    }
                    next[i] = c;
                    changed = true;
                }
            }
            if (changed)
                root.countdowns = next;
            if (root.focusActive) {
                root.focusRemainingSec = Math.max(0, root.focusRemainingSec - 1);
                if (root.focusRemainingSec <= 0) {
                    root.endFocus();
                    root.raiseCompletion("Focus");
                }
            }
        }
    }
}
