import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components"
import "panels"
import "wallpaper"

ShellRoot {
    id: shellRoot

    // Authoritative shell-level state for live wallpaper
    property bool wallpaperEnabled: true

    // Temporary development IPC control for toggling/managing wallpaper
    IpcHandler {
        target: "wallpaper"

        property bool enabled: shellRoot.wallpaperEnabled

        function toggle() {
            shellRoot.wallpaperEnabled = !shellRoot.wallpaperEnabled;
            console.log("[pranc-shell] IPC: wallpaperEnabled toggled to " + shellRoot.wallpaperEnabled);
        }

        function setEnabled(val: bool) {
            shellRoot.wallpaperEnabled = val;
            console.log("[pranc-shell] IPC: wallpaperEnabled set to " + shellRoot.wallpaperEnabled);
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: monitorScope
            required property var modelData

            property bool leftSidebarOpen: false
            property bool rightSidebarOpen: false
            property bool bottomBarOpen: false

            // Live wallpaper rendering surface (WlrLayer.Background)
            Wallpaper {
                id: wallpaper
                screen: monitorScope.modelData
                enabled: shellRoot.wallpaperEnabled
            }

            // Edge trigger overlay window
            PanelWindow {
                id: triggerWindow

                screen: monitorScope.modelData

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                exclusionMode: ExclusionMode.Ignore
                aboveWindows: true
                focusable: false
                color: "transparent"

                WlrLayershell.namespace: "pranc-shell"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                mask: Region {
                    Region { item: leftTrigger }
                    Region { item: centerTrigger }
                    Region { item: rightTrigger }
                }

                // Temporary visual test & debug indicator row (top-left)
                Row {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    spacing: 3

                    // Shell alive indicator (from Task 1)
                    Rectangle {
                        width: 8
                        height: 8
                        color: "#80ffffff"
                    }

                    // Left trigger debug indicator
                    Rectangle {
                        width: 8
                        height: 8
                        color: leftTrigger.active ? "#00ff88" : "#30ffffff"
                    }

                    // Center trigger debug indicator
                    Rectangle {
                        width: 8
                        height: 8
                        color: centerTrigger.active ? "#00bfff" : "#30ffffff"
                    }

                    // Right trigger debug indicator
                    Rectangle {
                        width: 8
                        height: 8
                        color: rightTrigger.active ? "#ff0088" : "#30ffffff"
                    }
                }

                // 1. Bottom-left -> controls left sidebar opening
                EdgeTrigger {
                    id: leftTrigger
                    edge: "bottom-left"
                    triggerWidth: 120
                    triggerHeight: 2
                    debugColor: "#00ff88"

                    onActivated: {
                        console.log("[pranc-shell] Bottom-left trigger ACTIVATED")
                        monitorScope.leftSidebarOpen = true
                    }
                    onDeactivated: {
                        console.log("[pranc-shell] Bottom-left trigger DEACTIVATED")
                    }
                }

                // 2. Bottom-center -> controls bottom bar opening
                EdgeTrigger {
                    id: centerTrigger
                    edge: "bottom-center"
                    triggerWidth: 300
                    triggerHeight: 2
                    debugColor: "#00bfff"

                    onActivated: {
                        console.log("[pranc-shell] Bottom-center trigger ACTIVATED")
                        monitorScope.bottomBarOpen = true
                    }
                    onDeactivated: {
                        console.log("[pranc-shell] Bottom-center trigger DEACTIVATED")
                    }
                }

                // 3. Bottom-right -> controls right sidebar opening
                EdgeTrigger {
                    id: rightTrigger
                    edge: "bottom-right"
                    triggerWidth: 120
                    triggerHeight: 2
                    debugColor: "#ff0088"

                    onActivated: {
                        console.log("[pranc-shell] Bottom-right trigger ACTIVATED")
                        monitorScope.rightSidebarOpen = true
                    }
                    onDeactivated: {
                        console.log("[pranc-shell] Bottom-right trigger DEACTIVATED")
                    }
                }
            }

            // Left sidebar container surface
            LeftSidebar {
                id: leftSidebar
                screen: monitorScope.modelData
                open: monitorScope.leftSidebarOpen

                onHoveredChanged: {
                    if (!hovered && !leftTrigger.active) {
                        monitorScope.leftSidebarOpen = false
                    }
                }
            }

            // Right sidebar container surface
            RightSidebar {
                id: rightSidebar
                screen: monitorScope.modelData
                open: monitorScope.rightSidebarOpen

                onHoveredChanged: {
                    if (!hovered && !rightTrigger.active) {
                        monitorScope.rightSidebarOpen = false
                    }
                }
            }

            // Floating bottom bar surface
            BottomBar {
                id: bottomBar
                screen: monitorScope.modelData
                open: monitorScope.bottomBarOpen

                onHoveredChanged: {
                    if (!hovered && !centerTrigger.active) {
                        monitorScope.bottomBarOpen = false
                    }
                }
            }
        }
    }
}
