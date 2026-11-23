import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../island" as Island

PanelWindow {
    id: root

    property bool open: false
    visible: open
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "cool-shell-shortcuts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    focusable: open

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property string homeDir: Quickshell.env("HOME") || "/home/pranc"
    readonly property string shellDir: homeDir + "/.config/quickshell/cool-shell"

    // =========================================================================
    // STATE & EDITING PROPERTIES
    // =========================================================================
    property string activeCategory: "All"
    property bool isEditing: false
    property var editingShortcut: null
    property var originalKeys: []
    // Modifier configuration and helpers
    readonly property var availableModifiers: ["SUPER", "CTRL", "ALT", "SHIFT"]
    readonly property var modifierList: availableModifiers
    readonly property var selectedModifiers: getSelectedModifiers()
    property bool modSuper: false
    property bool modCtrl: false
    property bool modAlt: false
    property bool modShift: false

    property bool isSaving: false
    property alias saving: root.isSaving
    property bool busy: false
    property string saveError: ""
    property string errorText: ""
    property var currentValidation: ({ valid: true, warning: false, conflict: false, message: "" })
    readonly property bool canSave: !isSaving && !busy && currentValidation.valid && keyInput.text.trim().length > 0
    property string statusText: ""
    property bool isError: false

    function toggleModifier(modName) {
        const mod = (modName || "").toUpperCase();
        if (mod === "SUPER") root.modSuper = !root.modSuper;
        else if (mod === "CTRL") root.modCtrl = !root.modCtrl;
        else if (mod === "ALT") root.modAlt = !root.modAlt;
        else if (mod === "SHIFT") root.modShift = !root.modShift;
        root.currentValidation = root.validateKey(keyInput.text);
    }

    function getSelectedModifiers() {
        const mods = [];
        if (root.modSuper) mods.push("SUPER");
        if (root.modCtrl) mods.push("CTRL");
        if (root.modAlt) mods.push("ALT");
        if (root.modShift) mods.push("SHIFT");
        return mods;
    }

    function updateSelectedModifiers() {
        return getSelectedModifiers();
    }

    readonly property int customCount: {
        let count = 0;
        for (let i = 0; i < allShortcuts.length; i++) {
            if (allShortcuts[i].isCustom) count++;
        }
        return count;
    }

    function toggle() {
        if (root.open) hide();
        else show();
    }

    function show() {
        root.open = true;
        searchField.text = "";
        activeCategory = "All";
        cancelEdit();
        searchField.forceActiveFocus();
    }

    function hide() {
        cancelEdit();
        root.open = false;
    }

    function close() {
        hide();
    }

    // =========================================================================
    // HELPER FUNCTIONS
    // =========================================================================
    function keysEqual(a, b) {
        if (!a || !b) return false;
        if (a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++) {
            if (a[i].toUpperCase() !== b[i].toUpperCase()) return false;
        }
        return true;
    }

    function splitModifiersAndKey(keyArray) {
        if (!keyArray || keyArray.length === 0) return { mods: "", key: "" };
        const mods = [];
        let mainKey = "";
        const modNames = ["SUPER", "CTRL", "ALT", "SHIFT"];
        for (let i = 0; i < keyArray.length; i++) {
            const k = keyArray[i];
            const upper = k.toUpperCase();
            if (modNames.indexOf(upper) !== -1) {
                mods.push(upper);
            } else {
                mainKey = k;
            }
        }
        return {
            mods: mods.join(" "),
            key: mainKey || (keyArray.length > 0 ? keyArray[keyArray.length - 1] : "")
        };
    }

    function formatComboString(keyArray) {
        if (!keyArray || keyArray.length === 0) return "";
        const parts = splitModifiersAndKey(keyArray);
        const safeKey = escapeLuaString(parts.key);
        if (parts.mods && parts.mods.length > 0) {
            const modStr = parts.mods.split(" ").join(" + ");
            return safeKey ? (modStr + " + " + safeKey) : modStr;
        }
        return safeKey;
    }

    function formatLuaDispatcher(disp, args) {
        const escaped = escapeLuaString(args || "");
        const d = (disp || "exec").toLowerCase();
        if (d === "exec") {
            return 'hl.dsp.exec_cmd("' + escaped + '")';
        } else if (d === "closewindow") {
            return 'hl.dsp.window.close()';
        } else if (d === "togglefloating") {
            return 'hl.dsp.window.float({ action = "toggle" })';
        } else if (d === "togglesplit") {
            return 'hl.dsp.layout("togglesplit")';
        } else if (d === "pin") {
            return 'hl.dsp.window.pin()';
        } else if (d === "movefocus") {
            const dir = (escaped === "l" ? "left" : (escaped === "r" ? "right" : (escaped === "u" ? "up" : (escaped === "d" ? "down" : escaped))));
            return 'hl.dsp.focus({ direction = "' + dir + '" })';
        } else if (d === "workspace") {
            const isNum = !isNaN(parseInt(escaped, 10)) && String(parseInt(escaped, 10)) === escaped;
            return isNum ? 'hl.dsp.focus({ workspace = ' + escaped + ' })' : 'hl.dsp.focus({ workspace = "' + escaped + '" })';
        } else if (d === "movetoworkspace") {
            const isNum = !isNaN(parseInt(escaped, 10)) && String(parseInt(escaped, 10)) === escaped;
            return isNum ? 'hl.dsp.window.move({ workspace = ' + escaped + ' })' : 'hl.dsp.window.move({ workspace = "' + escaped + '" })';
        } else if (d === "togglespecialworkspace") {
            return 'hl.dsp.workspace.toggle_special("' + (escaped || "stash") + '")';
        } else if (d === "movewindow") {
            return 'hl.dsp.window.drag()';
        } else if (d === "resizewindow") {
            return 'hl.dsp.window.resize()';
        } else {
            return 'hl.dsp.exec_cmd("hyprctl dispatch ' + d + (escaped ? " " + escaped : "") + '")';
        }
    }

    function escapeLuaString(str) {
        if (!str) return "";
        return str.replace(/\\/g, "\\\\")
                  .replace(/"/g, '\\"')
                  .replace(/\n/g, "\\n")
                  .replace(/\r/g, "\\r")
                  .replace(/\0/g, "");
    }

    function validateKey(keyString) {
        const trimmed = (keyString || "").trim();
        if (trimmed === "" || trimmed.length === 0) {
            return { valid: false, warning: false, conflict: false, message: "Key string cannot be empty." };
        }

        // Reject dangerous characters that could be used for Lua code injection or invalid keysyms
        if (/["'`\(\)\{\}\r\n;]|--/.test(trimmed)) {
            return { valid: false, warning: false, conflict: false, message: "Invalid key name: quotes, brackets, and syntax characters are forbidden." };
        }
        const validKeyRegex = /^[A-Za-z0-9_:\.\-]+$/;
        if (!validKeyRegex.test(trimmed)) {
            return { valid: false, warning: false, conflict: false, message: "Invalid key name. Only alphanumeric, _, -, :, . characters allowed." };
        }

        const currentCombo = [];
        if (root.modSuper) currentCombo.push("SUPER");
        if (root.modCtrl) currentCombo.push("CTRL");
        if (root.modAlt) currentCombo.push("ALT");
        if (root.modShift) currentCombo.push("SHIFT");
        currentCombo.push(trimmed);

        // Reserved compositor combinations check
        const comboStr = currentCombo.map(k => k.toUpperCase()).join("+");
        const reservedKeys = [
            "SUPER+M",
            "SUPER+SHIFT+ESC",
            "SUPER+SHIFT+ESCAPE",
            "CTRL+ALT+DELETE",
            "CTRL+ALT+F1",
            "CTRL+ALT+F2",
            "CTRL+ALT+F3"
        ];
        if (reservedKeys.indexOf(comboStr) !== -1) {
            return { valid: true, warning: true, conflict: false, message: "Warning: Reserved system key combination (" + comboStr + ")." };
        }

        // Duplicate / conflict detection against other shortcuts
        const dup = findDuplicate(currentCombo, root.editingShortcut ? root.editingShortcut.id : "");
        if (dup) {
            return { valid: true, warning: true, conflict: true, message: "Conflict: Already assigned to '" + dup.title + "'." };
        }

        return { valid: true, warning: false, conflict: false, message: "" };
    }

    function findDuplicate(comboKeys, excludeId) {
        for (let i = 0; i < allShortcuts.length; i++) {
            const item = allShortcuts[i];
            if (item.id === excludeId) continue;
            if (keysEqual(item.keys, comboKeys)) {
                return item;
            }
        }
        return null;
    }

    function startEditing(item) {
        if (!item) return;
        root.editingShortcut = item;
        root.originalKeys = [].concat(item.keys);
        root.modSuper = item.keys.indexOf("SUPER") !== -1;
        root.modCtrl = item.keys.indexOf("CTRL") !== -1;
        root.modAlt = item.keys.indexOf("ALT") !== -1;
        root.modShift = item.keys.indexOf("SHIFT") !== -1;
        root.updateSelectedModifiers();

        const parts = splitModifiersAndKey(item.keys);
        keyInput.text = parts.key;
        root.currentValidation = validateKey(parts.key);
        root.isEditing = true;
        keyInput.forceActiveFocus();
    }

    function cancelEdit() {
        root.isEditing = false;
        root.editingShortcut = null;
        root.originalKeys = [];
        root.isSaving = false;
        root.saving = false;
        root.busy = false;
        root.saveError = "";
        root.errorText = "";
        root.currentValidation = { valid: true, warning: false, conflict: false, message: "" };
    }

    function saveShortcutEdit() {
        if (root.isSaving || root.saving || root.busy || !root.editingShortcut) return;
        root.isSaving = true;
        root.saving = true;
        root.busy = true;
        root.saveError = "";
        root.errorText = "";

        const newKeys = [];
        if (root.modSuper) newKeys.push("SUPER");
        if (root.modCtrl) newKeys.push("CTRL");
        if (root.modAlt) newKeys.push("ALT");
        if (root.modShift) newKeys.push("SHIFT");
        const keyStr = keyInput.text.trim();
        if (keyStr.length > 0) newKeys.push(keyStr);

        // If re-binding is identical to current keys, treat as no-op
        if (keysEqual(newKeys, root.editingShortcut.keys)) {
            root.cancelEdit();
            return;
        }

        // Update shortcut in list
        const updated = [];
        for (let i = 0; i < allShortcuts.length; i++) {
            const item = Object.assign({}, allShortcuts[i]);
            if (item.id === root.editingShortcut.id) {
                item.keys = newKeys;
                item.isCustom = !keysEqual(newKeys, item.defaultKeys);
            }
            updated.push(item);
        }
        allShortcuts = updated;

        // Persist to drop-in file and trigger hyprctl reload
        try {
            const luaCode = generateCustomLua();
            customShortcutsFile.setText(luaCode);
            root.statusText = "Saving and reloading Hyprland...";
            root.isError = false;
            reloadProcess.running = true;
        } catch(e) {
            console.error("[Shortcuts] Failed to save shortcuts_custom.lua:", e);
            root.saveError = e.message || String(e);
            root.errorText = "Error saving shortcuts_custom.lua: " + (e.message || e);
            root.statusText = root.errorText;
            root.isError = true;
        } finally {
            root.isEditing = false;
            root.editingShortcut = null;
            root.originalKeys = [];
            root.isSaving = false;
            root.saving = false;
            root.busy = false;
        }
    }

    function resetShortcutToDefault() {
        if (root.saving || root.busy || !root.editingShortcut) return;
        root.saving = true;
        root.busy = true;

        const targetId = root.editingShortcut.id;
        const updated = [];
        for (let i = 0; i < allShortcuts.length; i++) {
            const item = Object.assign({}, allShortcuts[i]);
            if (item.id === targetId) {
                item.keys = [].concat(item.defaultKeys);
                item.isCustom = false;
            }
            updated.push(item);
        }
        allShortcuts = updated;

        try {
            const luaCode = generateCustomLua();
            customShortcutsFile.setText(luaCode);
            root.statusText = "Reset to default. Reloading Hyprland...";
            root.isError = false;
            reloadProcess.running = true;
        } catch(e) {
            console.error("[Shortcuts] Error resetting shortcut:", e);
            root.statusText = "Error resetting shortcut: " + (e.message || e);
            root.isError = true;
        } finally {
            root.cancelEdit();
        }
    }

    function resetToDefaults() {
        if (root.saving || root.busy) return;
        root.saving = true;
        root.busy = true;

        const updated = [];
        for (let i = 0; i < allShortcuts.length; i++) {
            const item = Object.assign({}, allShortcuts[i]);
            item.keys = [].concat(item.defaultKeys);
            item.isCustom = false;
            updated.push(item);
        }
        allShortcuts = updated;

        try {
            const luaCode = generateCustomLua();
            customShortcutsFile.setText(luaCode);
            root.statusText = "All shortcuts reset to defaults. Reloading Hyprland...";
            root.isError = false;
            reloadProcess.running = true;
        } catch(e) {
            console.error("[Shortcuts] Error resetting all shortcuts:", e);
            root.statusText = "Error resetting all shortcuts: " + (e.message || e);
            root.isError = true;
        } finally {
            root.saving = false;
            root.busy = false;
        }
    }

    function generateCustomLua() {
        const customList = [];
        let unbindCode = "";
        let bindCode = "";

        for (let i = 0; i < allShortcuts.length; i++) {
            const item = allShortcuts[i];
            if (!keysEqual(item.keys, item.defaultKeys)) {
                const oldCombo = formatComboString(item.defaultKeys);
                const newCombo = formatComboString(item.keys);

                customList.push({
                    id: item.id || ("shortcut_" + i),
                    title: item.title,
                    keys: item.keys,
                    originalKeys: item.defaultKeys,
                    dispatcher: item.dispatcher || "exec",
                    args: item.args || ""
                });

                // hl.unbind accepts a single combo string in Hyprland v0.56.2
                if (oldCombo && oldCombo.length > 0) {
                    unbindCode += '    hl.unbind("' + oldCombo + '")\n';
                }

                // hl.bind accepts (combo, dispatcher_or_function[, opts])
                if (newCombo && newCombo.length > 0) {
                    const isMouse = (item.id === "move_drag" || item.id === "resize_drag" || newCombo.indexOf("mouse") !== -1);
                    const optsStr = isMouse ? ", { mouse = true }" : "";
                    bindCode += '    hl.bind("' + newCombo + '", ' + formatLuaDispatcher(item.dispatcher, item.args) + optsStr + ')\n';
                }
            }
        }

        let out = "-- =============================================================================\n";
        out += "-- ⚙️ Cool-Shell User Custom Shortcuts Drop-in\n";
        out += "-- Sourced by ~/.config/hypr/hyprland.lua\n";
        out += "-- =============================================================================\n";
        out += "-- SHORTCUTS_DATA: " + JSON.stringify(customList) + "\n\n";
        out += "local hl = hl or {}\n\n";

        if (unbindCode.length > 0) {
            out += "if hl.unbind then\n";
            out += unbindCode;
            out += "end\n\n";
        }

        if (bindCode.length > 0) {
            out += "if hl.bind and hl.dsp then\n";
            out += bindCode;
            out += "end\n\n";
        }

        out += "return true\n";
        return out;
    }

    function loadCustomShortcuts() {
        try {
            const content = customShortcutsFile.text();
            if (!content || content.trim() === "") return;

            let loaded = false;
            // Robust line-based extraction of JSON metadata to avoid bracket truncation
            const dataMatch = content.match(/--\s*SHORTCUTS_DATA:\s*([^\r\n]+)/);
            if (dataMatch) {
                try {
                    const jsonStr = dataMatch[1].trim();
                    const list = JSON.parse(jsonStr);
                    if (Array.isArray(list)) {
                        applyCustomShortcuts(list);
                        loaded = true;
                    }
                } catch (err) {
                    console.warn("[Shortcuts] Corrupted JSON in SHORTCUTS_DATA, fallback to parseRawLuaBindings:", err);
                    // On corrupted JSON, fallback to parsing raw Lua bindings
                    parseRawLuaBindings(content);
                    loaded = true;
                }
            }

            if (!loaded) {
                parseRawLuaBindings(content);
            }
        } catch (e) {
            console.error("[Shortcuts] Failed to load custom shortcuts:", e);
        }
    }

    function applyCustomShortcuts(list) {
        const updated = [];
        for (let i = 0; i < allShortcuts.length; i++) {
            const item = Object.assign({}, allShortcuts[i]);
            const custom = list.find(c => (c.id && c.id === item.id) || (c.title && c.title === item.title));
            if (custom && custom.keys && Array.isArray(custom.keys)) {
                item.keys = [].concat(custom.keys);
                item.originalKeys = custom.originalKeys ? [].concat(custom.originalKeys) : [].concat(item.defaultKeys);
                item.isCustom = !keysEqual(item.keys, item.defaultKeys);
            }
            updated.push(item);
        }
        allShortcuts = updated;
    }

    function parseRawLuaBindings(content) {
        if (!content) return;
        const foundBinds = [];
        const lines = content.split(/\r?\n/);

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.indexOf("hl.bind(") === -1) continue;

            // Pattern 1: Native Hyprland Lua syntax: hl.bind("COMBO", hl.dsp.func(...))
            const nativeMatch = line.match(/hl\.bind\(\s*["']([^"']+)["']\s*,\s*hl\.dsp\.([a-zA-Z0-9_\.]+)(?:\(([^)]*)\))?/);
            if (nativeMatch) {
                const comboStr = nativeMatch[1];
                const dspFunc = nativeMatch[2];
                const dspArgsRaw = nativeMatch[3] || "";
                const combo = comboStr.split("+").map(k => k.trim()).filter(k => k.length > 0);

                let disp = "exec";
                let arg = "";

                if (dspFunc === "exec_cmd") {
                    disp = "exec";
                    const mArg = dspArgsRaw.match(/["'](.*)["']/);
                    arg = mArg ? mArg[1] : dspArgsRaw.trim();
                } else if (dspFunc === "window.close") {
                    disp = "closewindow";
                } else if (dspFunc === "window.float") {
                    disp = "togglefloating";
                } else if (dspFunc === "layout") {
                    disp = "togglesplit";
                } else if (dspFunc === "window.pin") {
                    disp = "pin";
                } else if (dspFunc === "focus") {
                    if (dspArgsRaw.indexOf("workspace") !== -1) {
                        disp = "workspace";
                        const mW = dspArgsRaw.match(/workspace\s*=\s*["']?([a-zA-Z0-9_\+\-]+)["']?/);
                        arg = mW ? mW[1] : "";
                    } else if (dspArgsRaw.indexOf("direction") !== -1) {
                        disp = "movefocus";
                        const mD = dspArgsRaw.match(/direction\s*=\s*["']?([a-zA-Z0-9]+)["']?/);
                        arg = mD ? (mD[1] === "left" ? "l" : (mD[1] === "right" ? "r" : (mD[1] === "up" ? "u" : (mD[1] === "down" ? "d" : mD[1])))) : "";
                    }
                } else if (dspFunc === "window.move") {
                    disp = "movetoworkspace";
                    const mW = dspArgsRaw.match(/workspace\s*=\s*["']?([a-zA-Z0-9_:\+\-]+)["']?/);
                    arg = mW ? mW[1] : "";
                } else if (dspFunc === "workspace.toggle_special") {
                    disp = "togglespecialworkspace";
                    const mS = dspArgsRaw.match(/["'](.*)["']/);
                    arg = mS ? mS[1] : "stash";
                } else if (dspFunc === "window.drag") {
                    disp = "movewindow";
                } else if (dspFunc === "window.resize") {
                    disp = "resizewindow";
                }

                foundBinds.push({ combo: combo, disp: disp, arg: arg });
                continue;
            }

            // Pattern 2: Legacy 4-argument syntax: hl.bind("MOD", "KEY", "DISP", "ARGS")
            const legacyMatch = line.match(/hl\.bind\(\s*["']([^"']+)["']\s*,\s*["']([^"']+)["'](?:\s*,\s*["']([^"']*)["'](?:\s*,\s*["']([^"']*)["'])?)?/);
            if (legacyMatch) {
                const mod = legacyMatch[1];
                const key = legacyMatch[2];
                const disp = legacyMatch[3] || "exec";
                const arg = legacyMatch[4] || "";
                const combo = mod.indexOf("+") !== -1 ? mod.split("+").map(k => k.trim()) : (mod ? [mod, key] : [key]);
                foundBinds.push({ combo: combo, disp: disp, arg: arg });
            }
        }

        if (foundBinds.length === 0) return;

        const updated = [];
        for (let i = 0; i < allShortcuts.length; i++) {
            const item = Object.assign({}, allShortcuts[i]);
            let matchBind = null;
            if (item.args && item.args.length > 0) {
                matchBind = foundBinds.find(b => b.disp === item.dispatcher && (item.args === b.arg || item.args.indexOf(b.arg) !== -1 || b.arg.indexOf(item.args) !== -1));
            } else {
                matchBind = foundBinds.find(b => b.disp === item.dispatcher);
            }

            if (matchBind) {
                item.keys = [].concat(matchBind.combo);
                item.isCustom = !keysEqual(item.keys, item.defaultKeys);
            }
            updated.push(item);
        }
        allShortcuts = updated;
    }

    function initializeShortcuts() {
        const initialized = [];
        for (let i = 0; i < allShortcuts.length; i++) {
            const item = Object.assign({}, allShortcuts[i]);
            if (!item.defaultKeys) item.defaultKeys = [].concat(item.keys);
            if (!item.originalKeys) item.originalKeys = [].concat(item.keys);
            item.isCustom = !keysEqual(item.keys, item.defaultKeys);
            initialized.push(item);
        }
        allShortcuts = initialized;
    }

    // =========================================================================
    // HYPRLAND PERSISTENCE (FileView & Process)
    // =========================================================================
    FileView {
        id: customShortcutsFile
        path: Quickshell.env("HOME") + "/.config/hypr/shortcuts_custom.lua"
        preload: true
        atomicWrites: true
        watchChanges: true
        onLoaded: root.loadCustomShortcuts()
        onLoadFailed: (error) => {
            root.resetToDefaults();
        }
    }

    Process {
        id: reloadProcess
        command: ["hyprctl", "reload"]
        running: false
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.statusText = "✓ Saved & Hyprland reloaded";
                root.isError = false;
            } else {
                root.statusText = "Warning: hyprctl reload returned code " + exitCode;
                root.isError = true;
            }
            statusTimer.restart();
        }
    }

    Timer {
        id: statusTimer
        interval: 3500
        onTriggered: {
            root.statusText = "";
        }
    }

    Component.onCompleted: {
        initializeShortcuts();
        loadCustomShortcuts();
    }

    // =========================================================================
    // SHORTCUTS DATABASE DERIVED FROM ~/.config/hypr/hyprland.lua
    // =========================================================================
    property var allShortcuts: [
        // =====================================================================
        // System & Session Hotkeys
        // =====================================================================
        {
            id: "lock_theme",
            keys: ["SUPER", "SHIFT", "L"],
            defaultKeys: ["SUPER", "SHIFT", "L"],
            originalKeys: ["SUPER", "SHIFT", "L"],
            title: "Lockscreen Theme Switcher",
            subtitle: ".local/share/veila/wallpapers",
            category: "System",
            highlightSubtitle: true,
            dispatcher: "exec",
            args: "/home/pranc/.local/bin/veila-theme",
            isCustom: false
        },
        {
            id: "lock_screen",
            keys: ["SUPER", "L"],
            defaultKeys: ["SUPER", "L"],
            originalKeys: ["SUPER", "L"],
            title: "Lock Screen",
            subtitle: "Launch Veila lockscreen securely",
            category: "System",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "veila lock",
            isCustom: false
        },
        {
            id: "shortcuts_window",
            keys: ["SUPER", "."],
            defaultKeys: ["SUPER", "."],
            originalKeys: ["SUPER", "."],
            title: "Shortcuts Cheatsheet",
            subtitle: "Open this interactive keyboard shortcut window",
            category: "System",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call shortcuts toggle",
            isCustom: false
        },
        {
            id: "power_menu",
            keys: ["SUPER", "X"],
            defaultKeys: ["SUPER", "X"],
            originalKeys: ["SUPER", "X"],
            title: "Power & Session Menu",
            subtitle: "Lock, sleep, restart, or shutdown",
            category: "System",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call notch toggle power",
            isCustom: false
        },
        {
            id: "settings",
            keys: ["SUPER", "I"],
            defaultKeys: ["SUPER", "I"],
            originalKeys: ["SUPER", "I"],
            title: "System & Shell Settings",
            subtitle: "Open quickshell hardware and theme settings",
            category: "System",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call settings toggle",
            isCustom: false
        },
        {
            id: "gamemode",
            keys: ["SUPER", "F1"],
            defaultKeys: ["SUPER", "F1"],
            originalKeys: ["SUPER", "F1"],
            title: "Extreme Game Mode",
            subtitle: "Suspend heavy surfaces into ~50MB RAM ultra-fast mode",
            category: "System",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "/home/pranc/.local/bin/gamemode-toggle.sh",
            isCustom: false
        },
        {
            id: "nightlight",
            keys: ["SUPER", "SHIFT", "N"],
            defaultKeys: ["SUPER", "SHIFT", "N"],
            originalKeys: ["SUPER", "SHIFT", "N"],
            title: "Night Light (Hyprsunset)",
            subtitle: "Toggle warm blue light filter for eye comfort",
            category: "System",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "/home/pranc/.local/bin/nightlight-toggle.sh",
            isCustom: false
        },
        {
            id: "kill_window",
            keys: ["SUPER", "SHIFT", "ESC"],
            defaultKeys: ["SUPER", "SHIFT", "ESC"],
            originalKeys: ["SUPER", "SHIFT", "ESC"],
            title: "Force Kill Application",
            subtitle: "Interactive cursor crosshair to terminate frozen windows",
            category: "System",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "hyprctl kill",
            isCustom: false
        },

        // =====================================================================
        // Dynamic Island & Shell HUD Controls
        // =====================================================================
        {
            id: "launcher",
            keys: ["SUPER"],
            defaultKeys: ["SUPER"],
            originalKeys: ["SUPER"],
            title: "App Launcher & Calculator",
            subtitle: "Search desktop apps, calculate expressions, convert units",
            category: "Shell",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call notch toggle launcher",
            isCustom: false
        },
        {
            id: "action_hub",
            keys: ["SUPER", "Space"],
            defaultKeys: ["SUPER", "Space"],
            originalKeys: ["SUPER", "Space"],
            title: "Contextual Action Hub",
            subtitle: "Floating radial hub for recent files, tools and actions",
            category: "Shell",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call actionhub toggle",
            isCustom: false
        },
        {
            id: "wallpaper_picker",
            keys: ["SUPER", "A"],
            defaultKeys: ["SUPER", "A"],
            originalKeys: ["SUPER", "A"],
            title: "Wallpaper & Live Video Picker",
            subtitle: "Browse themes, switch animated and static wallpapers",
            category: "Shell",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call notch toggle wallpaper",
            isCustom: false
        },
        {
            id: "theme_selector",
            keys: ["SUPER", "C"],
            defaultKeys: ["SUPER", "C"],
            originalKeys: ["SUPER", "C"],
            title: "Material Color Theme Selector",
            subtitle: "Material You adaptive color palette selector",
            category: "Shell",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call notch toggle theme",
            isCustom: false
        },
        {
            id: "media_island",
            keys: ["SUPER", "M"],
            defaultKeys: ["SUPER", "M"],
            originalKeys: ["SUPER", "M"],
            title: "Now Playing & Synced Lyrics",
            subtitle: "Media player controls, track timeline, and live lyrics",
            category: "Shell",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call notch toggle media",
            isCustom: false
        },
        {
            id: "notifications",
            keys: ["SUPER", "N"],
            defaultKeys: ["SUPER", "N"],
            originalKeys: ["SUPER", "N"],
            title: "Notification Center",
            subtitle: "View notification stream, priority alerts and history",
            category: "Shell",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call notch toggle notifications",
            isCustom: false
        },
        {
            id: "ai_studio",
            keys: ["SUPER", "G"],
            defaultKeys: ["SUPER", "G"],
            originalKeys: ["SUPER", "G"],
            title: "AI Image Studio Prompt Bar",
            subtitle: "Generate fast LCM / SD images with one prompt",
            category: "Shell",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call notch toggle ai",
            isCustom: false
        },
        {
            id: "overview",
            keys: ["SUPER", "TAB"],
            defaultKeys: ["SUPER", "TAB"],
            originalKeys: ["SUPER", "TAB"],
            title: "Window Overview Matrix",
            subtitle: "Spatial visual overview across all active workspaces",
            category: "Shell",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call overview toggle",
            isCustom: false
        },
        {
            id: "birdseye",
            keys: ["SUPER", "R"],
            defaultKeys: ["SUPER", "R"],
            originalKeys: ["SUPER", "R"],
            title: "Bird's-Eye Overview & Stash",
            subtitle: "Bird's-eye layout and stashed window inspection",
            category: "Shell",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call birdseye toggle",
            isCustom: false
        },
        {
            id: "displays_cycle",
            keys: ["SUPER", "P"],
            defaultKeys: ["SUPER", "P"],
            originalKeys: ["SUPER", "P"],
            title: "Cycle Display Layout",
            subtitle: "Cycle multi-monitor configurations and mirror modes",
            category: "Shell",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call displays cycle",
            isCustom: false
        },
        {
            id: "displays_confirm",
            keys: ["SUPER", "SHIFT", "P"],
            defaultKeys: ["SUPER", "SHIFT", "P"],
            originalKeys: ["SUPER", "SHIFT", "P"],
            title: "Confirm Display Layout",
            subtitle: "Lock in multi-monitor display selection",
            category: "Shell",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "qs -c cool-shell ipc call displays confirm",
            isCustom: false
        },

        // =====================================================================
        // Application Launchers
        // =====================================================================
        {
            id: "terminal",
            keys: ["SUPER", "T"],
            defaultKeys: ["SUPER", "T"],
            originalKeys: ["SUPER", "T"],
            title: "Kitty Terminal",
            subtitle: "Launch hardware-accelerated GPU terminal",
            category: "Apps",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "kitty",
            isCustom: false
        },
        {
            id: "file_manager",
            keys: ["SUPER", "E"],
            defaultKeys: ["SUPER", "E"],
            originalKeys: ["SUPER", "E"],
            title: "Dolphin File Manager",
            subtitle: "Open graphical filesystem explorer",
            category: "Apps",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "dolphin",
            isCustom: false
        },
        {
            id: "browser",
            keys: ["SUPER", "W"],
            defaultKeys: ["SUPER", "W"],
            originalKeys: ["SUPER", "W"],
            title: "Brave Web Browser",
            subtitle: "Launch default privacy web browser",
            category: "Apps",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "brave",
            isCustom: false
        },

        // =====================================================================
        // Window Tiling & Floating Management
        // =====================================================================
        {
            id: "close_window",
            keys: ["SUPER", "Q"],
            defaultKeys: ["SUPER", "Q"],
            originalKeys: ["SUPER", "Q"],
            title: "Close Window",
            subtitle: "Close active focused window safely",
            category: "Windows",
            highlightSubtitle: false,
            dispatcher: "closewindow",
            args: "",
            isCustom: false
        },
        {
            id: "toggle_float",
            keys: ["SUPER", "V"],
            defaultKeys: ["SUPER", "V"],
            originalKeys: ["SUPER", "V"],
            title: "Toggle Floating Window",
            subtitle: "Switch between tiled and floating mode",
            category: "Windows",
            highlightSubtitle: false,
            dispatcher: "togglefloating",
            args: "",
            isCustom: false
        },
        {
            id: "toggle_float_alt",
            keys: ["SUPER", "D"],
            defaultKeys: ["SUPER", "D"],
            originalKeys: ["SUPER", "D"],
            title: "Toggle Floating (Alternative)",
            subtitle: "Alternative quick toggle for floating state",
            category: "Windows",
            highlightSubtitle: false,
            dispatcher: "togglefloating",
            args: "",
            isCustom: false
        },
        {
            id: "toggle_split",
            keys: ["SUPER", "J"],
            defaultKeys: ["SUPER", "J"],
            originalKeys: ["SUPER", "J"],
            title: "Toggle Split Orientation",
            subtitle: "Swap horizontal and vertical split direction",
            category: "Windows",
            highlightSubtitle: false,
            dispatcher: "togglesplit",
            args: "",
            isCustom: false
        },
        {
            id: "pin_window",
            keys: ["SUPER", "Y"],
            defaultKeys: ["SUPER", "Y"],
            originalKeys: ["SUPER", "Y"],
            title: "Pin Window Across Desktops",
            subtitle: "Keep floating window visible on all workspaces",
            category: "Windows",
            highlightSubtitle: false,
            dispatcher: "pin",
            args: "",
            isCustom: false
        },
        {
            id: "focus_left",
            keys: ["SUPER", "H"],
            defaultKeys: ["SUPER", "H"],
            originalKeys: ["SUPER", "H"],
            title: "Focus Window Left",
            subtitle: "Shift keyboard focus to the left window",
            category: "Windows",
            highlightSubtitle: false,
            dispatcher: "movefocus",
            args: "l",
            isCustom: false
        },
        {
            id: "focus_right",
            keys: ["SUPER", "K"],
            defaultKeys: ["SUPER", "K"],
            originalKeys: ["SUPER", "K"],
            title: "Focus Window Right",
            subtitle: "Shift keyboard focus to the right window",
            category: "Windows",
            highlightSubtitle: false,
            dispatcher: "movefocus",
            args: "r",
            isCustom: false
        },
        {
            id: "focus_arrows",
            keys: ["SUPER", "Arrows"],
            defaultKeys: ["SUPER", "Arrows"],
            originalKeys: ["SUPER", "Arrows"],
            title: "Directional Window Focus",
            subtitle: "Move focus Left, Right, Up, or Down",
            category: "Windows",
            highlightSubtitle: false,
            dispatcher: "movefocus",
            args: "l",
            isCustom: false
        },
        {
            id: "move_drag",
            keys: ["SUPER", "Left Drag"],
            defaultKeys: ["SUPER", "Left Drag"],
            originalKeys: ["SUPER", "Left Drag"],
            title: "Move Window Interactively",
            subtitle: "Click and drag to position floating window",
            category: "Windows",
            highlightSubtitle: false,
            dispatcher: "movewindow",
            args: "",
            isCustom: false
        },
        {
            id: "resize_drag",
            keys: ["SUPER", "Right Drag"],
            defaultKeys: ["SUPER", "Right Drag"],
            originalKeys: ["SUPER", "Right Drag"],
            title: "Resize Window Interactively",
            subtitle: "Click and drag to scale window boundaries",
            category: "Windows",
            highlightSubtitle: false,
            dispatcher: "resizewindow",
            args: "",
            isCustom: false
        },

        // =====================================================================
        // Workspaces & Stash Pocket
        // =====================================================================
        {
            id: "workspace_1_10",
            keys: ["SUPER", "1 .. 9, 0"],
            defaultKeys: ["SUPER", "1 .. 9, 0"],
            originalKeys: ["SUPER", "1 .. 9, 0"],
            title: "Jump to Workspace 1 - 10",
            subtitle: "Instant switch to target numbered workspace",
            category: "Workspaces",
            highlightSubtitle: false,
            dispatcher: "workspace",
            args: "1",
            isCustom: false
        },
        {
            id: "moveto_workspace",
            keys: ["SUPER", "SHIFT", "1 .. 0"],
            defaultKeys: ["SUPER", "SHIFT", "1 .. 0"],
            originalKeys: ["SUPER", "SHIFT", "1 .. 0"],
            title: "Move Window to Workspace",
            subtitle: "Relocate focused window to workspace 1 through 10",
            category: "Workspaces",
            highlightSubtitle: false,
            dispatcher: "movetoworkspace",
            args: "1",
            isCustom: false
        },
        {
            id: "stash_toggle",
            keys: ["SUPER", "S"],
            defaultKeys: ["SUPER", "S"],
            originalKeys: ["SUPER", "S"],
            title: "Toggle Stash Pocket",
            subtitle: "Slide down special hidden stash workspace",
            category: "Workspaces",
            highlightSubtitle: false,
            dispatcher: "togglespecialworkspace",
            args: "stash",
            isCustom: false
        },
        {
            id: "stash_send",
            keys: ["SUPER", "ALT", "S"],
            defaultKeys: ["SUPER", "ALT", "S"],
            originalKeys: ["SUPER", "ALT", "S"],
            title: "Send Window to Stash Pocket",
            subtitle: "Tuck active window into stash pocket scratchpad",
            category: "Workspaces",
            highlightSubtitle: false,
            dispatcher: "movetoworkspace",
            args: "special:stash",
            isCustom: false
        },
        {
            id: "workspace_scroll",
            keys: ["SUPER", "Scroll Wheel"],
            defaultKeys: ["SUPER", "Scroll Wheel"],
            originalKeys: ["SUPER", "Scroll Wheel"],
            title: "Scroll Workspaces",
            subtitle: "Cycle smoothly through workspaces with mouse wheel",
            category: "Workspaces",
            highlightSubtitle: false,
            dispatcher: "workspace",
            args: "e+1",
            isCustom: false
        },

        // =====================================================================
        // Productivity, OCR & Tools
        // =====================================================================
        {
            id: "snip",
            keys: ["Print"],
            defaultKeys: ["Print"],
            originalKeys: ["Print"],
            title: "Quick Area Snipping Tool",
            subtitle: "Select rectangular region & copy directly to clipboard",
            category: "Tools",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: 'grim -g "$(slurp)" /tmp/snip.png && wl-copy < /tmp/snip.png',
            isCustom: false
        },
        {
            id: "annotate_snip",
            keys: ["SUPER", "Print"],
            defaultKeys: ["SUPER", "Print"],
            originalKeys: ["SUPER", "Print"],
            title: "Annotate Screenshot (Swappy)",
            subtitle: "Capture screen region and launch Swappy paint editor",
            category: "Tools",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: 'grim -g "$(slurp)" - | swappy -f -',
            isCustom: false
        },
        {
            id: "screen_lens",
            keys: ["SUPER", "SHIFT", "S"],
            defaultKeys: ["SUPER", "SHIFT", "S"],
            originalKeys: ["SUPER", "SHIFT", "S"],
            title: "Universal Screen Lens",
            subtitle: "OCR text extract, QR code decoder, and color sampler",
            category: "Tools",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "/home/pranc/.config/quickshell/cool-shell/scripts/screen-lens.sh",
            isCustom: false
        },
        {
            id: "clipboard_mgr",
            keys: ["SUPER", "V"],
            defaultKeys: ["SUPER", "V"],
            originalKeys: ["SUPER", "V"],
            title: "Clipboard History Manager",
            subtitle: "Search, preview, and restore previous clipboard entries",
            category: "Tools",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "/home/pranc/.local/bin/clipmgr",
            isCustom: false
        },
        {
            id: "audio_sink",
            keys: ["SUPER", "ALT", "A"],
            defaultKeys: ["SUPER", "ALT", "A"],
            originalKeys: ["SUPER", "ALT", "A"],
            title: "Audio Sink Switcher",
            subtitle: "Toggle output between Headphones, Speakers, and HDMI",
            category: "Tools",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "/home/pranc/.local/bin/audio-switch",
            isCustom: false
        },
        {
            id: "phone_mirror",
            keys: ["SUPER", "ALT", "P"],
            defaultKeys: ["SUPER", "ALT", "P"],
            originalKeys: ["SUPER", "ALT", "P"],
            title: "CoolPhone Android Mirroring",
            subtitle: "Toggle wireless or USB phone screen mirroring via Scrcpy",
            category: "Tools",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "/home/pranc/.config/quickshell/cool-shell/scripts/phone-ctl.sh toggle",
            isCustom: false
        },

        // =====================================================================
        // Hardware & Multimedia
        // =====================================================================
        {
            id: "volume_up",
            keys: ["Fn / Volume Up"],
            defaultKeys: ["Fn / Volume Up"],
            originalKeys: ["Fn / Volume Up"],
            title: "Volume Up (+5%)",
            subtitle: "Pipewire audio master volume step up",
            category: "Media",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
            isCustom: false
        },
        {
            id: "volume_down",
            keys: ["Fn / Volume Down"],
            defaultKeys: ["Fn / Volume Down"],
            originalKeys: ["Fn / Volume Down"],
            title: "Volume Down (-5%)",
            subtitle: "Pipewire audio master volume step down",
            category: "Media",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
            isCustom: false
        },
        {
            id: "mute_audio",
            keys: ["Fn / Mute"],
            defaultKeys: ["Fn / Mute"],
            originalKeys: ["Fn / Mute"],
            title: "Mute Master Audio",
            subtitle: "Toggle speaker/headphone mute",
            category: "Media",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
            isCustom: false
        },
        {
            id: "mute_mic",
            keys: ["Fn / Mic Mute"],
            defaultKeys: ["Fn / Mic Mute"],
            originalKeys: ["Fn / Mic Mute"],
            title: "Mute Microphone",
            subtitle: "Toggle system microphone input recording",
            category: "Media",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
            isCustom: false
        },
        {
            id: "brightness_up",
            keys: ["Fn / Brightness Up"],
            defaultKeys: ["Fn / Brightness Up"],
            originalKeys: ["Fn / Brightness Up"],
            title: "Screen Brightness Up (+5%)",
            subtitle: "Hardware display backlight level up",
            category: "Media",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "brightnessctl -e4 -n2 set 5%+",
            isCustom: false
        },
        {
            id: "brightness_down",
            keys: ["Fn / Brightness Down"],
            defaultKeys: ["Fn / Brightness Down"],
            originalKeys: ["Fn / Brightness Down"],
            title: "Screen Brightness Down (-5%)",
            subtitle: "Hardware display backlight level down",
            category: "Media",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "brightnessctl -e4 -n2 set 5%-",
            isCustom: false
        },
        {
            id: "play_pause",
            keys: ["Fn / Play / Pause"],
            defaultKeys: ["Fn / Play / Pause"],
            originalKeys: ["Fn / Play / Pause"],
            title: "Play / Pause Media",
            subtitle: "Toggle playback across active Spotify/browser players",
            category: "Media",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "playerctl play-pause",
            isCustom: false
        },
        {
            id: "next_prev",
            keys: ["Fn / Next / Prev"],
            defaultKeys: ["Fn / Next / Prev"],
            originalKeys: ["Fn / Next / Prev"],
            title: "Next / Previous Track",
            subtitle: "Skip forward or rewind track via Playerctl",
            category: "Media",
            highlightSubtitle: false,
            dispatcher: "exec",
            args: "playerctl next",
            isCustom: false
        }
    ]

    // =========================================================================
    // FILTERED LIST
    // =========================================================================
    readonly property var filteredShortcuts: {
        const query = searchField.text.trim().toLowerCase();
        const cat = root.activeCategory;

        return allShortcuts.filter(item => {
            if (cat !== "All" && item.category !== cat) return false;
            if (!query) return true;

            const inTitle = item.title.toLowerCase().indexOf(query) !== -1;
            const inSubtitle = item.subtitle.toLowerCase().indexOf(query) !== -1;
            const inCategory = item.category.toLowerCase().indexOf(query) !== -1;
            const inKeys = item.keys.some(k => k.toLowerCase().indexOf(query) !== -1);

            return inTitle || inSubtitle || inCategory || inKeys;
        });
    }

    // Dismiss on clicking backdrop
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.isEditing) {
                root.cancelEdit();
            } else {
                root.close();
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.isEditing) {
                root.cancelEdit();
            } else {
                root.close();
            }
        }
    }

    Shortcut {
        sequence: "Super+."
        onActivated: root.close()
    }

    // =========================================================================
    // MODAL CHEATSHEET CARD
    // =========================================================================
    Rectangle {
        id: card
        width: Math.min(parent.width - 64, 820)
        height: Math.min(parent.height - 80, 720)
        anchors.centerIn: parent
        radius: Island.Theme.radiusWindow
        color: Island.Theme.glassBackground
        border.color: Island.Theme.glassBorder
        border.width: Island.Theme.glassBorderWidth
        clip: true

        // Stop clicks from reaching backdrop
        MouseArea {
            anchors.fill: parent
        }

        // Specular Top Rim
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 1
            height: 1
            color: Qt.rgba(1, 1, 1, 0.14)
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // 1. TOP HEADER (Icon, Title, Search Filter & Close Button)
            Row {
                width: parent.width
                height: 44
                spacing: 12

                // Header Badge
                Rectangle {
                    width: 38
                    height: 38
                    radius: 12
                    color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.16)
                    border.color: Island.Theme.glassBorderSubtle
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "⌨"
                        font.pixelSize: 18
                        color: Island.Theme.primary
                    }
                }

                // Search Bar Input
                Rectangle {
                    width: parent.width - 38 - 44 - 24
                    height: 38
                    radius: 12
                    color: Island.Theme.glassCard
                    border.color: searchField.activeFocus ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍉"
                            font.family: Island.Theme.iconFontFamily
                            font.pixelSize: 15
                            color: Island.Theme.muted
                        }

                        TextInput {
                            id: searchField
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 30
                            font.family: Island.Theme.fontFamily
                            font.pixelSize: 13
                            color: Island.Theme.foreground
                            clip: true
                            selectByMouse: true

                            Text {
                                anchors.fill: parent
                                text: "Type to filter shortcuts (e.g. lock, terminal, workspace)..."
                                font.family: Island.Theme.fontFamily
                                font.pixelSize: 13
                                color: Island.Theme.muted
                                visible: !searchField.text && !searchField.activeFocus
                            }
                        }
                    }
                }

                // Close Button
                Rectangle {
                    width: 38
                    height: 38
                    radius: 12
                    color: closeHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Island.Theme.glassCard
                    border.color: Island.Theme.glassBorderSubtle
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 14
                        font.bold: true
                        color: Island.Theme.foreground
                    }

                    HoverHandler { id: closeHover }
                    TapHandler { onTapped: root.close() }
                }
            }

            // 2. CATEGORY PILL FILTER BAR
            Row {
                width: parent.width
                spacing: 6

                Repeater {
                    model: ["All", "System", "Shell", "Apps", "Windows", "Workspaces", "Tools", "Media"]

                    Rectangle {
                        required property string modelData
                        width: catText.implicitWidth + 18
                        height: 26
                        radius: 13
                        color: root.activeCategory === modelData
                            ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.28)
                            : (catHover.hovered ? Island.Theme.glassCardHover : "transparent")
                        border.color: root.activeCategory === modelData ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                        border.width: 1

                        HoverHandler { id: catHover }
                        TapHandler { onTapped: root.activeCategory = modelData }

                        Text {
                            id: catText
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: 10
                            font.bold: root.activeCategory === modelData
                            font.family: Island.Theme.fontFamily
                            color: root.activeCategory === modelData ? Island.Theme.foreground : Island.Theme.muted
                        }
                    }
                }

                Item {
                    width: Math.max(10, parent.width - 480)
                    height: 26
                }

                // Match count badge
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.filteredShortcuts.length + " / " + root.allShortcuts.length
                    font.pixelSize: 10
                    font.bold: true
                    font.family: Island.Theme.fontFamily
                    color: Island.Theme.muted
                }
            }

            // Separator Line
            Rectangle {
                width: parent.width
                height: 1
                color: Island.Theme.glassBorderSubtle
            }

            // 3. SHORTCUTS SCROLLABLE LIST
            ListView {
                id: shortcutsList
                width: parent.width
                height: card.height - 195
                clip: true
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds
                model: root.filteredShortcuts

                delegate: Rectangle {
                    id: shortcutRow
                    required property var modelData
                    width: shortcutsList.width
                    height: modelData.highlightSubtitle ? 54 : 44
                    radius: 12
                    color: rowHover.hovered ? Island.Theme.glassCardHover : Island.Theme.glassCard
                    border.color: modelData.isCustom 
                        ? Island.Theme.primary
                        : (modelData.highlightSubtitle 
                            ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.45)
                            : (rowHover.hovered ? Island.Theme.glassBorderActive : Island.Theme.glassBorderSubtle))
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: rowHover }

                    // Row click to edit
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.startEditing(shortcutRow.modelData);
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Left: Key Combo Pills
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            width: 210

                            Repeater {
                                model: shortcutRow.modelData.keys

                                Rectangle {
                                    required property string modelData
                                    height: 24
                                    width: Math.max(26, keyText.implicitWidth + 12)
                                    radius: 6
                                    color: shortcutRow.modelData.isCustom ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.22) : Qt.rgba(255, 255, 255, 0.08)
                                    border.color: shortcutRow.modelData.isCustom ? Island.Theme.primary : Qt.rgba(255, 255, 255, 0.18)
                                    border.width: 1

                                    Text {
                                        id: keyText
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: "JetBrains Mono Nerd Font"
                                        color: Island.Theme.foreground
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        // Middle: Title & Subtitle
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 210 - 140 - 24
                            spacing: 2

                            Text {
                                text: shortcutRow.modelData.title
                                font.pixelSize: 12
                                font.bold: true
                                font.family: Island.Theme.fontFamily
                                color: Island.Theme.foreground
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: shortcutRow.modelData.subtitle
                                font.pixelSize: shortcutRow.modelData.highlightSubtitle ? 10 : 9
                                font.family: shortcutRow.modelData.highlightSubtitle ? "JetBrains Mono Nerd Font" : Island.Theme.fontFamily
                                color: shortcutRow.modelData.highlightSubtitle ? Island.Theme.primary : Island.Theme.muted
                                font.bold: shortcutRow.modelData.highlightSubtitle
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // Right: Category Tag & Edit Button
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            // Category Tag
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 20
                                width: tagText.implicitWidth + 12
                                radius: 10
                                color: Qt.rgba(255, 255, 255, 0.05)
                                border.color: Qt.rgba(255, 255, 255, 0.08)
                                border.width: 1

                                Text {
                                    id: tagText
                                    anchors.centerIn: parent
                                    text: shortcutRow.modelData.category
                                    font.pixelSize: 9
                                    font.family: Island.Theme.fontFamily
                                    color: Island.Theme.muted
                                    elide: Text.ElideRight
                                }
                            }

                            // Interactive Edit Button
                            Rectangle {
                                id: editButton
                                anchors.verticalCenter: parent.verticalCenter
                                height: 22
                                width: 52
                                radius: 6
                                color: editBtnHover.hovered ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25) : Qt.rgba(255, 255, 255, 0.06)
                                border.color: editBtnHover.hovered ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰏫"
                                        font.pixelSize: 10
                                        font.family: Island.Theme.iconFontFamily
                                        color: editBtnHover.hovered ? Island.Theme.primary : Island.Theme.muted
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Edit"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: Island.Theme.fontFamily
                                        color: editBtnHover.hovered ? Island.Theme.primary : Island.Theme.muted
                                        elide: Text.ElideRight
                                    }
                                }

                                HoverHandler { id: editBtnHover }
                                TapHandler {
                                    onTapped: root.startEditing(shortcutRow.modelData)
                                }
                            }
                        }
                    }
                }
            }

            // Separator Line
            Rectangle {
                width: parent.width
                height: 1
                color: Island.Theme.glassBorderSubtle
            }

            // 4. FOOTER CONFIG PATH & STATUS BAR
            Row {
                width: parent.width
                height: 24
                spacing: 12

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        text: "󰌌 Config:"
                        font.pixelSize: 10
                        font.family: "JetBrains Mono Nerd Font"
                        color: Island.Theme.muted
                        elide: Text.ElideRight
                    }

                    Text {
                        id: configPathLabel
                        text: "~/.config/hypr/hyprland.lua"
                        font.pixelSize: 10
                        font.family: "JetBrains Mono Nerd Font"
                        color: Island.Theme.foreground
                        elide: Text.ElideRight

                        MouseArea {
                            id: copyPath
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.clipboardText = configPathLabel.text;
                                root.statusText = "Config path copied to clipboard!";
                                statusTimer.restart();
                            }
                        }
                    }

                    Text {
                        text: "•  Drop-in:"
                        font.pixelSize: 10
                        font.family: "JetBrains Mono Nerd Font"
                        color: Island.Theme.muted
                        elide: Text.ElideRight
                    }

                    Text {
                        id: dropinPathLabel
                        text: "~/.config/hypr/shortcuts_custom.lua"
                        font.pixelSize: 10
                        font.family: "JetBrains Mono Nerd Font"
                        color: Island.Theme.primary
                        elide: Text.ElideRight
                    }
                }

                Item {
                    Layout.fillWidth: true
                    width: 10
                    height: 20
                }

                // Status Notification Message
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.statusText
                    font.pixelSize: 10
                    font.family: Island.Theme.fontFamily
                    color: root.isError ? "#ff6b6b" : (root.statusText ? Island.Theme.primary : "transparent")
                    visible: root.statusText.length > 0
                    elide: Text.ElideRight
                }

                // Reset All Custom Shortcuts to Defaults Button
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20
                    width: resetAllText.implicitWidth + 12
                    radius: 6
                    color: resetAllHover.hovered ? Qt.rgba(1, 0, 0, 0.15) : "transparent"
                    border.color: resetAllHover.hovered ? "#ff6b6b" : Island.Theme.glassBorderSubtle
                    border.width: 1
                    visible: root.customCount > 0

                    Text {
                        id: resetAllText
                        anchors.centerIn: parent
                        text: "Reset All (" + root.customCount + ")"
                        font.pixelSize: 9
                        font.family: Island.Theme.fontFamily
                        color: resetAllHover.hovered ? "#ff6b6b" : Island.Theme.muted
                        elide: Text.ElideRight
                    }

                    HoverHandler { id: resetAllHover }
                    TapHandler {
                        onTapped: root.resetToDefaults()
                    }
                }
            }
        }

        // =====================================================================
        // IN-UI SHORTCUT EDITING MODAL OVERLAY
        // =====================================================================
        Rectangle {
            id: editModal
            anchors.fill: parent
            radius: card.radius
            color: Qt.rgba(0.04, 0.05, 0.08, 0.90)
            visible: root.isEditing
            z: 100

            MouseArea {
                anchors.fill: parent
            }

            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - 60, 520)
                spacing: 16

                // Modal Header
                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 10
                        color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.2)
                        border.color: Island.Theme.glassBorderSubtle
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰏫"
                            font.pixelSize: 16
                            font.family: Island.Theme.iconFontFamily
                            color: Island.Theme.primary
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Edit Shortcut Keybinding"
                            font.pixelSize: 14
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                            elide: Text.ElideRight
                        }

                        Text {
                            text: root.editingShortcut ? (root.editingShortcut.title + " (" + root.editingShortcut.category + ")") : ""
                            font.pixelSize: 11
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.muted
                            elide: Text.ElideRight
                        }
                    }
                }

                // Editor Controls Box
                Rectangle {
                    width: parent.width
                    height: editorCol.implicitHeight + 28
                    radius: 12
                    color: Island.Theme.glassCard
                    border.color: Island.Theme.glassBorderSubtle
                    border.width: 1

                    Column {
                        id: editorCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 14

                        // Modifier Toggles Row
                        Column {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "Modifiers"
                                font.pixelSize: 10
                                font.bold: true
                                font.family: Island.Theme.fontFamily
                                color: Island.Theme.muted
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 8

                                // SUPER
                                Rectangle {
                                    height: 28
                                    width: superText.implicitWidth + 18
                                    radius: 8
                                    color: root.modSuper ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.3) : Qt.rgba(255, 255, 255, 0.05)
                                    border.color: root.modSuper ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Text {
                                        id: superText
                                        anchors.centerIn: parent
                                        text: "SUPER"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: "JetBrains Mono Nerd Font"
                                        color: root.modSuper ? Island.Theme.foreground : Island.Theme.muted
                                        elide: Text.ElideRight
                                    }

                                    HoverHandler { id: superHov }
                                    TapHandler {
                                        onTapped: root.toggleModifier("SUPER")
                                    }
                                }

                                // CTRL
                                Rectangle {
                                    height: 28
                                    width: ctrlText.implicitWidth + 18
                                    radius: 8
                                    color: root.modCtrl ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.3) : Qt.rgba(255, 255, 255, 0.05)
                                    border.color: root.modCtrl ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Text {
                                        id: ctrlText
                                        anchors.centerIn: parent
                                        text: "CTRL"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: "JetBrains Mono Nerd Font"
                                        color: root.modCtrl ? Island.Theme.foreground : Island.Theme.muted
                                        elide: Text.ElideRight
                                    }

                                    HoverHandler { id: ctrlHov }
                                    TapHandler {
                                        onTapped: root.toggleModifier("CTRL")
                                    }
                                }

                                // ALT
                                Rectangle {
                                    height: 28
                                    width: altText.implicitWidth + 18
                                    radius: 8
                                    color: root.modAlt ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.3) : Qt.rgba(255, 255, 255, 0.05)
                                    border.color: root.modAlt ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Text {
                                        id: altText
                                        anchors.centerIn: parent
                                        text: "ALT"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: "JetBrains Mono Nerd Font"
                                        color: root.modAlt ? Island.Theme.foreground : Island.Theme.muted
                                        elide: Text.ElideRight
                                    }

                                    HoverHandler { id: altHov }
                                    TapHandler {
                                        onTapped: root.toggleModifier("ALT")
                                    }
                                }

                                // SHIFT
                                Rectangle {
                                    height: 28
                                    width: shiftText.implicitWidth + 18
                                    radius: 8
                                    color: root.modShift ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.3) : Qt.rgba(255, 255, 255, 0.05)
                                    border.color: root.modShift ? Island.Theme.primary : Island.Theme.glassBorderSubtle
                                    border.width: 1

                                    Text {
                                        id: shiftText
                                        anchors.centerIn: parent
                                        text: "SHIFT"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: "JetBrains Mono Nerd Font"
                                        color: root.modShift ? Island.Theme.foreground : Island.Theme.muted
                                        elide: Text.ElideRight
                                    }

                                    HoverHandler { id: shiftHov }
                                    TapHandler {
                                        onTapped: root.toggleModifier("SHIFT")
                                    }
                                }
                            }
                        }

                        // Key String Input Field
                        Column {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "Key String (e.g. Return, T, Space, period, Q)"
                                font.pixelSize: 10
                                font.bold: true
                                font.family: Island.Theme.fontFamily
                                color: Island.Theme.muted
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                width: parent.width
                                height: 36
                                radius: 8
                                color: Qt.rgba(0, 0, 0, 0.35)
                                border.color: (!root.currentValidation.valid) ? "#ff6b6b" : (root.currentValidation.warning ? "#ffd166" : (keyInput.activeFocus ? Island.Theme.primary : Island.Theme.glassBorderSubtle))
                                border.width: 1

                                TextInput {
                                    id: keyInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "JetBrains Mono Nerd Font"
                                    color: Island.Theme.foreground
                                    clip: true
                                    selectByMouse: true
                                    onTextChanged: {
                                        root.currentValidation = root.validateKey(keyInput.text);
                                    }
                                    onAccepted: {
                                        if (root.canSave) root.saveShortcutEdit();
                                    }
                                }
                            }
                        }

                        // Live Validation & Conflict Indicator
                        Row {
                            width: parent.width
                            spacing: 6
                            visible: root.currentValidation.message.length > 0

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: !root.currentValidation.valid ? "󰅙" : (root.currentValidation.conflict ? "󰈻" : "󰀦")
                                font.pixelSize: 12
                                font.family: Island.Theme.iconFontFamily
                                color: !root.currentValidation.valid ? "#ff6b6b" : (root.currentValidation.conflict ? "#ff9f43" : "#ffd166")
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 24
                                text: root.currentValidation.message
                                font.pixelSize: 10
                                font.family: Island.Theme.fontFamily
                                color: !root.currentValidation.valid ? "#ff6b6b" : (root.currentValidation.conflict ? "#ff9f43" : "#ffd166")
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Modal Action Buttons
                Row {
                    width: parent.width
                    spacing: 10

                    // Reset to default button
                    Rectangle {
                        height: 32
                        width: resetBtnText.implicitWidth + 20
                        radius: 8
                        color: resetBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                        border.color: Island.Theme.glassBorderSubtle
                        border.width: 1

                        Text {
                            id: resetBtnText
                            anchors.centerIn: parent
                            text: "Reset to Default"
                            font.pixelSize: 11
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.muted
                            elide: Text.ElideRight
                        }

                        HoverHandler { id: resetBtnHover }
                        TapHandler {
                            onTapped: root.resetShortcutToDefault()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        width: 10
                        height: 32
                    }

                    // Cancel button
                    Rectangle {
                        height: 32
                        width: cancelBtnText.implicitWidth + 22
                        radius: 8
                        color: cancelBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                        border.color: Island.Theme.glassBorderSubtle
                        border.width: 1

                        Text {
                            id: cancelBtnText
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.pixelSize: 11
                            font.family: Island.Theme.fontFamily
                            color: Island.Theme.foreground
                            elide: Text.ElideRight
                        }

                        HoverHandler { id: cancelBtnHover }
                        TapHandler {
                            onTapped: root.cancelEdit()
                        }
                    }

                    // Save button
                    Rectangle {
                        id: saveBtn
                        height: 32
                        width: saveBtnText.implicitWidth + 28
                        radius: 8
                        enabled: root.canSave && !root.saving && !root.busy
                        opacity: enabled ? 1.0 : 0.5
                        color: enabled ? (saveBtnHover.hovered ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.8) : Island.Theme.primary) : Qt.rgba(255, 255, 255, 0.1)

                        Text {
                            id: saveBtnText
                            anchors.centerIn: parent
                            text: root.saving ? "Saving..." : "Save"
                            font.pixelSize: 11
                            font.bold: true
                            font.family: Island.Theme.fontFamily
                            color: "#ffffff"
                            elide: Text.ElideRight
                        }

                        HoverHandler { id: saveBtnHover }
                        TapHandler {
                            onTapped: {
                                if (saveBtn.enabled) root.saveShortcutEdit();
                            }
                        }
                    }
                }
            }
        }
    }
}
