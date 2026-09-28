import QtQuick
import Quickshell
pragma Singleton

// AiState: extension point for AI utilities. No model, API key, or daemon is
// required or bundled: available stays false until the user provides a
// backend (e.g. ollama/llama.cpp), at which point providers can register
// utilities here and the island can surface them. Nothing is faked.
Singleton {
    id: root

    property bool available: false
    property string backendName: ""
    property var utilities: [] // [{id, label}]

    function registerUtility(id, label) {
        const next = utilities.slice();
        for (let i = 0; i < next.length; ++i) {
            if (next[i].id === id)
                return;
        }
        next.push({ id: id, label: label });
        utilities = next;
    }
}
