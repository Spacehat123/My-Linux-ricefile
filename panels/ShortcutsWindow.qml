import QtQuick
import QtQuick.Layouts
import Quickshell
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

    function toggle() {
        if (root.open) hide();
        else show();
    }

    function show() {
        root.open = true;
        searchField.text = "";
        activeCategory = "All";
        searchField.forceActiveFocus();
    }

    function hide() {
        root.open = false;
    }

    function close() {
        hide();
    }

    property string activeCategory: "All"

    // Shortcuts Database derived from ~/.config/hypr/hyprland.lua
    readonly property var allShortcuts: [
        // =====================================================================
        // System & Session Hotkeys
        // =====================================================================
        {
            keys: ["SUPER", "SHIFT", "L"],
            title: "Lockscreen Theme Switcher",
            subtitle: ".local/share/veila/wallpapers",
            category: "System",
            highlightSubtitle: true
        },
        {
            keys: ["SUPER", "L"],
            title: "Lock Screen",
            subtitle: "Launch Veila lockscreen securely",
            category: "System",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "."],
            title: "Shortcuts Cheatsheet",
            subtitle: "Open this interactive keyboard shortcut window",
            category: "System",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "X"],
            title: "Power & Session Menu",
            subtitle: "Lock, sleep, restart, or shutdown",
            category: "System",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "I"],
            title: "System & Shell Settings",
            subtitle: "Open quickshell hardware and theme settings",
            category: "System",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "F1"],
            title: "Extreme Game Mode",
            subtitle: "Suspend heavy surfaces into ~50MB RAM ultra-fast mode",
            category: "System",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "SHIFT", "N"],
            title: "Night Light (Hyprsunset)",
            subtitle: "Toggle warm blue light filter for eye comfort",
            category: "System",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "SHIFT", "ESC"],
            title: "Force Kill Application",
            subtitle: "Interactive cursor crosshair to terminate frozen windows",
            category: "System",
            highlightSubtitle: false
        },

        // =====================================================================
        // Dynamic Island & Shell HUD Controls
        // =====================================================================
        {
            keys: ["SUPER"],
            title: "App Launcher & Calculator",
            subtitle: "Search desktop apps, calculate expressions, convert units",
            category: "Shell",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "Space"],
            title: "Contextual Action Hub",
            subtitle: "Floating radial hub for recent files, tools and actions",
            category: "Shell",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "A"],
            title: "Wallpaper & Live Video Picker",
            subtitle: "Browse themes, switch animated and static wallpapers",
            category: "Shell",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "C"],
            title: "Material Color Theme Selector",
            subtitle: "Material You adaptive color palette selector",
            category: "Shell",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "M"],
            title: "Now Playing & Synced Lyrics",
            subtitle: "Media player controls, track timeline, and live lyrics",
            category: "Shell",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "N"],
            title: "Notification Center",
            subtitle: "View notification stream, priority alerts and history",
            category: "Shell",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "G"],
            title: "AI Image Studio Prompt Bar",
            subtitle: "Generate fast LCM / SD images with one prompt",
            category: "Shell",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "TAB"],
            title: "Window Overview Matrix",
            subtitle: "Spatial visual overview across all active workspaces",
            category: "Shell",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "R"],
            title: "Bird's-Eye Overview & Stash",
            subtitle: "Bird's-eye layout and stashed window inspection",
            category: "Shell",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "P"],
            title: "Cycle Display Layout",
            subtitle: "Cycle multi-monitor configurations and mirror modes",
            category: "Shell",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "SHIFT", "P"],
            title: "Confirm Display Layout",
            subtitle: "Lock in multi-monitor display selection",
            category: "Shell",
            highlightSubtitle: false
        },

        // =====================================================================
        // Application Launchers
        // =====================================================================
        {
            keys: ["SUPER", "T"],
            title: "Kitty Terminal",
            subtitle: "Launch hardware-accelerated GPU terminal",
            category: "Apps",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "E"],
            title: "Dolphin File Manager",
            subtitle: "Open graphical filesystem explorer",
            category: "Apps",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "W"],
            title: "Brave Web Browser",
            subtitle: "Launch default privacy web browser",
            category: "Apps",
            highlightSubtitle: false
        },

        // =====================================================================
        // Window Tiling & Floating Management
        // =====================================================================
        {
            keys: ["SUPER", "Q"],
            title: "Close Window",
            subtitle: "Close active focused window safely",
            category: "Windows",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "V"],
            title: "Toggle Floating Window",
            subtitle: "Switch between tiled and floating mode",
            category: "Windows",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "D"],
            title: "Toggle Floating (Alternative)",
            subtitle: "Alternative quick toggle for floating state",
            category: "Windows",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "J"],
            title: "Toggle Split Orientation",
            subtitle: "Swap horizontal and vertical split direction",
            category: "Windows",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "Y"],
            title: "Pin Window Across Desktops",
            subtitle: "Keep floating window visible on all workspaces",
            category: "Windows",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "H"],
            title: "Focus Window Left",
            subtitle: "Shift keyboard focus to the left window",
            category: "Windows",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "K"],
            title: "Focus Window Right",
            subtitle: "Shift keyboard focus to the right window",
            category: "Windows",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "Arrows"],
            title: "Directional Window Focus",
            subtitle: "Move focus Left, Right, Up, or Down",
            category: "Windows",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "Left Drag"],
            title: "Move Window Interactively",
            subtitle: "Click and drag to position floating window",
            category: "Windows",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "Right Drag"],
            title: "Resize Window Interactively",
            subtitle: "Click and drag to scale window boundaries",
            category: "Windows",
            highlightSubtitle: false
        },

        // =====================================================================
        // Workspaces & Stash Pocket
        // =====================================================================
        {
            keys: ["SUPER", "1 .. 9, 0"],
            title: "Jump to Workspace 1 - 10",
            subtitle: "Instant switch to target numbered workspace",
            category: "Workspaces",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "SHIFT", "1 .. 0"],
            title: "Move Window to Workspace",
            subtitle: "Relocate focused window to workspace 1 through 10",
            category: "Workspaces",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "S"],
            title: "Toggle Stash Pocket",
            subtitle: "Slide down special hidden stash workspace",
            category: "Workspaces",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "ALT", "S"],
            title: "Send Window to Stash Pocket",
            subtitle: "Tuck active window into stash pocket scratchpad",
            category: "Workspaces",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "Scroll Wheel"],
            title: "Scroll Workspaces",
            subtitle: "Cycle smoothly through workspaces with mouse wheel",
            category: "Workspaces",
            highlightSubtitle: false
        },

        // =====================================================================
        // Productivity, OCR & Tools
        // =====================================================================
        {
            keys: ["Print"],
            title: "Quick Area Snipping Tool",
            subtitle: "Select rectangular region & copy directly to clipboard",
            category: "Tools",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "Print"],
            title: "Annotate Screenshot (Swappy)",
            subtitle: "Capture screen region and launch Swappy paint editor",
            category: "Tools",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "SHIFT", "S"],
            title: "Universal Screen Lens",
            subtitle: "OCR text extract, QR code decoder, and color sampler",
            category: "Tools",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "V"],
            title: "Clipboard History Manager",
            subtitle: "Search, preview, and restore previous clipboard entries",
            category: "Tools",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "ALT", "A"],
            title: "Audio Sink Switcher",
            subtitle: "Toggle output between Headphones, Speakers, and HDMI",
            category: "Tools",
            highlightSubtitle: false
        },
        {
            keys: ["SUPER", "ALT", "P"],
            title: "CoolPhone Android Mirroring",
            subtitle: "Toggle wireless or USB phone screen mirroring via Scrcpy",
            category: "Tools",
            highlightSubtitle: false
        },

        // =====================================================================
        // Hardware & Multimedia
        // =====================================================================
        {
            keys: ["Fn / Volume Up"],
            title: "Volume Up (+5%)",
            subtitle: "Pipewire audio master volume step up",
            category: "Media",
            highlightSubtitle: false
        },
        {
            keys: ["Fn / Volume Down"],
            title: "Volume Down (-5%)",
            subtitle: "Pipewire audio master volume step down",
            category: "Media",
            highlightSubtitle: false
        },
        {
            keys: ["Fn / Mute"],
            title: "Mute Master Audio",
            subtitle: "Toggle speaker/headphone mute",
            category: "Media",
            highlightSubtitle: false
        },
        {
            keys: ["Fn / Mic Mute"],
            title: "Mute Microphone",
            subtitle: "Toggle system microphone input recording",
            category: "Media",
            highlightSubtitle: false
        },
        {
            keys: ["Fn / Brightness Up"],
            title: "Screen Brightness Up (+5%)",
            subtitle: "Hardware display backlight level up",
            category: "Media",
            highlightSubtitle: false
        },
        {
            keys: ["Fn / Brightness Down"],
            title: "Screen Brightness Down (-5%)",
            subtitle: "Hardware display backlight level down",
            category: "Media",
            highlightSubtitle: false
        },
        {
            keys: ["Fn / Play / Pause"],
            title: "Play / Pause Media",
            subtitle: "Toggle playback across active Spotify/browser players",
            category: "Media",
            highlightSubtitle: false
        },
        {
            keys: ["Fn / Next / Prev"],
            title: "Next / Previous Track",
            subtitle: "Skip forward or rewind track via Playerctl",
            category: "Media",
            highlightSubtitle: false
        }
    ]

    // Filtered List
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
        onClicked: root.close()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
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
            spacing: 14

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
                                text: "Type to filter shortcuts (e.g. lock, veila, workspace, print)..."
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
                height: card.height - 160
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
                    border.color: modelData.highlightSubtitle 
                        ? Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.45)
                        : (rowHover.hovered ? Island.Theme.glassBorderActive : Island.Theme.glassBorderSubtle)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: rowHover }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 14

                        // Left: Key Combo Pills
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            width: 200

                            Repeater {
                                model: shortcutRow.modelData.keys

                                Rectangle {
                                    required property string modelData
                                    height: 24
                                    width: Math.max(26, keyText.implicitWidth + 12)
                                    radius: 6
                                    color: Qt.rgba(255, 255, 255, 0.08)
                                    border.color: Qt.rgba(255, 255, 255, 0.18)
                                    border.width: 1

                                    Text {
                                        id: keyText
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: "JetBrains Mono Nerd Font"
                                        color: Island.Theme.foreground
                                    }
                                }
                            }
                        }

                        // Middle: Title & Subtitle
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 200 - 90 - 28
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
                                font.pixelSize: shortcutRow.modelData.highlightSubtitle ? 10 : 9.5
                                font.family: shortcutRow.modelData.highlightSubtitle ? "JetBrains Mono Nerd Font" : Island.Theme.fontFamily
                                color: shortcutRow.modelData.highlightSubtitle ? Island.Theme.primary : Island.Theme.muted
                                font.bold: shortcutRow.modelData.highlightSubtitle
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // Right: Category Tag
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
                            }
                        }
                    }
                }
            }
        }
    }
}
