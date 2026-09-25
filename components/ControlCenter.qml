import QtQuick
import "../theme"

Item {
    id: root

    // =========================================================================
    // Upstream Authoritative Models & State Injections
    // =========================================================================
    property var desktopModel: null
    property var desktopState: null
    property var screen: null
    property bool wallpaperEnabled: true
    property bool ambientEnabled: true

    // Action Signals (Unidirectional Event Flow to shellRoot)
    signal toggleWallpaper()
    signal toggleAmbient()

    // Dual-Layer Hover Boundary (Passive root HoverHandler)
    HoverHandler {
        id: rootHoverHandler
    }

    readonly property bool hovered: rootHoverHandler.hovered

    Theme {
        id: theme
    }

    Column {
        anchors.fill: parent
        spacing: 12

        // =====================================================================
        // SECTION 1: Cyber-Tactical Header
        // =====================================================================
        Item {
            width: parent.width
            height: theme.surfaceHeaderHeight

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: "// CONTROL CENTER"
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "monospace"
                    font.letterSpacing: 1.5
                    color: theme.primaryTextColor
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: {
                        if (root.desktopState && root.desktopState.currentWorkspaceIsUrgent) return "#ff3366";
                        if (root.desktopState && root.desktopState.currentWorkspaceHasFullscreen) return "#ffb700";
                        return "#00ff88";
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SYS.ONLINE"
                    font.pixelSize: 8
                    font.bold: true
                    font.family: "monospace"
                    color: theme.secondaryTextColor
                }
            }
        }

        // Hairline Divider
        Rectangle {
            width: parent.width
            height: 1
            color: theme.surfaceDividerColor
        }

        // =====================================================================
        // SECTION 2: Desktop Environment Controls (Wallpaper & Ambient)
        // =====================================================================
        Text {
            text: "// SYSTEM MODES"
            font.pixelSize: 8
            font.bold: true
            font.family: "monospace"
            font.letterSpacing: 1.5
            color: theme.mutedTextColor
        }

        // 1. Wallpaper Engine Toggle Card
        Rectangle {
            id: wallpaperCard
            width: parent.width
            height: 52
            radius: theme.surfaceCardCornerRadius
            color: wallpaperTap.pressed
                ? theme.surfaceCardFocusedBackground
                : (wallpaperHover.hovered ? theme.surfaceCardHoverBackground : theme.surfaceCardBackground)
            border.color: root.wallpaperEnabled ? theme.actionActiveBorder : theme.surfaceCardBorder
            border.width: 1

            HoverHandler {
                id: wallpaperHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: wallpaperTap
                acceptedButtons: Qt.LeftButton
                onTapped: root.toggleWallpaper()
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    width: parent.width - 50

                    Text {
                        text: "WALLPAPER ENGINE"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "monospace"
                        color: theme.primaryTextColor
                    }

                    Text {
                        text: root.wallpaperEnabled ? "ACTIVE // 60 FPS VSYNC" : "INACTIVE // DISABLED"
                        font.pixelSize: 8
                        font.family: "monospace"
                        color: root.wallpaperEnabled ? theme.actionActiveText : theme.mutedTextColor
                    }
                }

                // Tactical Capsule Switch
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 20
                    radius: 10
                    color: root.wallpaperEnabled ? theme.actionActiveBackground : theme.workspaceEmptyBackground
                    border.color: root.wallpaperEnabled ? theme.actionActiveBorder : theme.surfaceBadgeBorder
                    border.width: 1

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.wallpaperEnabled ? 23 : 3
                        width: 14
                        height: 14
                        radius: 7
                        color: root.wallpaperEnabled ? theme.actionActiveText : theme.mutedTextColor

                        Behavior on x {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }

        // 2. Ambient Overlay Toggle Card
        Rectangle {
            id: ambientCard
            width: parent.width
            height: 52
            radius: theme.surfaceCardCornerRadius
            color: ambientTap.pressed
                ? theme.surfaceCardFocusedBackground
                : (ambientHover.hovered ? theme.surfaceCardHoverBackground : theme.surfaceCardBackground)
            border.color: root.ambientEnabled ? theme.actionActiveBorder : theme.surfaceCardBorder
            border.width: 1

            HoverHandler {
                id: ambientHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: ambientTap
                acceptedButtons: Qt.LeftButton
                onTapped: root.toggleAmbient()
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    width: parent.width - 50

                    Text {
                        text: "AMBIENT OVERLAY"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "monospace"
                        color: theme.primaryTextColor
                    }

                    Text {
                        text: {
                            if (!root.ambientEnabled) return "OFFLINE // SUPPRESSED";
                            if (root.desktopState && root.desktopState.ambientActive) return "ENGAGED // IDLE DETECTED";
                            return "ARMED // MONITORING IDLE";
                        }
                        font.pixelSize: 8
                        font.family: "monospace"
                        color: {
                            if (!root.ambientEnabled) return "#60ffffff";
                            if (root.desktopState && root.desktopState.ambientActive) return "#00e5ff";
                            return theme.mutedTextColor;
                        }
                    }
                }

                // Tactical Capsule Switch
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 20
                    radius: 10
                    color: root.ambientEnabled ? theme.actionActiveBackground : theme.workspaceEmptyBackground
                    border.color: root.ambientEnabled ? theme.actionActiveBorder : theme.surfaceBadgeBorder
                    border.width: 1

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.ambientEnabled ? 23 : 3
                        width: 14
                        height: 14
                        radius: 7
                        color: root.ambientEnabled ? theme.actionActiveText : theme.mutedTextColor

                        Behavior on x {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // SECTION 3: Focused Workspace Telemetry Context
        // =====================================================================
        Text {
            text: "// FOCUSED WORKSPACE"
            font.pixelSize: 8
            font.bold: true
            font.family: "monospace"
            font.letterSpacing: 1.5
            color: theme.mutedTextColor
        }

        Rectangle {
            width: parent.width
            height: 64
            radius: theme.surfaceCardCornerRadius
            color: theme.surfaceCardBackground
            border.color: theme.surfaceCardBorder
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Row 1: WS Identifier & Surface Count
                Item {
                    width: parent.width
                    height: 18

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            height: 18
                            implicitWidth: wsBadgeText.implicitWidth + 10
                            radius: theme.surfaceTagCornerRadius
                            color: theme.workspaceFocusedBackground
                            border.color: theme.workspaceFocusedBorder
                            border.width: 1

                            Text {
                                id: wsBadgeText
                                anchors.centerIn: parent
                                text: {
                                    const id = root.desktopState ? root.desktopState.currentWorkspaceId : -1;
                                    return id !== -1 ? "WS " + id : "WS --";
                                }
                                font.pixelSize: 9
                                font.bold: true
                                font.family: "monospace"
                                color: theme.workspaceFocusedText
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                const name = root.desktopState && root.desktopState.currentWorkspace
                                    ? (root.desktopState.currentWorkspace.name || "")
                                    : "";
                                return name ? "NAME: \"" + name + "\"" : "";
                            }
                            font.pixelSize: 8
                            font.family: "monospace"
                            color: theme.secondaryTextColor
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const count = root.desktopState ? root.desktopState.currentSurfaceCount : 0;
                            if (count === 0) return "EMPTY";
                            return count === 1 ? "1 SURFACE" : count + " SURFACES";
                        }
                        font.pixelSize: 9
                        font.bold: true
                        font.family: "monospace"
                        color: theme.workspaceHudValueText
                    }
                }

                // Row 2: Status Indicators (Fullscreen & Urgent)
                Row {
                    spacing: 6

                    // Fullscreen Indicator
                    Rectangle {
                        height: 16
                        implicitWidth: fsText.implicitWidth + 8
                        radius: 3
                        color: (root.desktopState && root.desktopState.currentWorkspaceHasFullscreen)
                            ? theme.workspaceHudFullscreenBackground
                            : theme.workspaceEmptyBackground
                        border.color: (root.desktopState && root.desktopState.currentWorkspaceHasFullscreen)
                            ? theme.workspaceHudFullscreenBadge
                            : theme.workspaceEmptyBorder
                        border.width: 1

                        Text {
                            id: fsText
                            anchors.centerIn: parent
                            text: (root.desktopState && root.desktopState.currentWorkspaceHasFullscreen)
                                ? "⛶ FULLSCREEN ACTIVE"
                                : "WINDOWED"
                            font.pixelSize: 7
                            font.bold: true
                            font.family: "monospace"
                            color: (root.desktopState && root.desktopState.currentWorkspaceHasFullscreen)
                                ? theme.workspaceHudFullscreenBadge
                                : theme.mutedTextColor
                        }
                    }

                    // Urgency Indicator
                    Rectangle {
                        height: 16
                        implicitWidth: urgText.implicitWidth + 8
                        radius: 3
                        color: (root.desktopState && root.desktopState.currentWorkspaceIsUrgent)
                            ? theme.workspaceHudUrgentBackground
                            : theme.workspaceEmptyBackground
                        border.color: (root.desktopState && root.desktopState.currentWorkspaceIsUrgent)
                            ? theme.workspaceHudUrgentBadge
                            : theme.workspaceEmptyBorder
                        border.width: 1

                        Text {
                            id: urgText
                            anchors.centerIn: parent
                            text: (root.desktopState && root.desktopState.currentWorkspaceIsUrgent)
                                ? "! URGENT DETECTED"
                                : "NOMINAL"
                            font.pixelSize: 7
                            font.bold: true
                            font.family: "monospace"
                            color: (root.desktopState && root.desktopState.currentWorkspaceIsUrgent)
                                ? theme.workspaceHudUrgentBadge
                                : theme.mutedTextColor
                        }
                    }
                }
            }
        }

        // =====================================================================
        // SECTION 4: Desktop Topology Summary
        // =====================================================================
        Text {
            text: "// DESKTOP TOPOLOGY"
            font.pixelSize: 8
            font.bold: true
            font.family: "monospace"
            font.letterSpacing: 1.5
            color: theme.mutedTextColor
        }

        Rectangle {
            width: parent.width
            height: 94
            radius: theme.surfaceCardCornerRadius
            color: theme.surfaceCardBackground
            border.color: theme.surfaceCardBorder
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Row A: Workspaces Total / Occupied
                Item {
                    width: parent.width
                    height: 16

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "WORKSPACES:"
                        font.pixelSize: 8
                        font.family: "monospace"
                        color: theme.mutedTextColor
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const tot = root.desktopModel ? root.desktopModel.workspaceCount : 0;
                            const occ = root.desktopModel ? root.desktopModel.occupiedWorkspaceCount : 0;
                            return tot + " TOTAL (" + occ + " OCCUPIED)";
                        }
                        font.pixelSize: 8
                        font.bold: true
                        font.family: "monospace"
                        color: theme.primaryTextColor
                    }
                }

                // Row B: Active Surfaces / Apps
                Item {
                    width: parent.width
                    height: 16

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ACTIVE SURFACES:"
                        font.pixelSize: 8
                        font.family: "monospace"
                        color: theme.mutedTextColor
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const surfs = root.desktopModel ? root.desktopModel.surfaceCount : 0;
                            const apps = root.desktopModel ? root.desktopModel.applicationCount : 0;
                            return surfs + " SURFACES (" + apps + " APPS)";
                        }
                        font.pixelSize: 8
                        font.bold: true
                        font.family: "monospace"
                        color: theme.primaryTextColor
                    }
                }

                // Row C: Screen Output Identity
                Item {
                    width: parent.width
                    height: 16

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "DISPLAY OUTPUT:"
                        font.pixelSize: 8
                        font.family: "monospace"
                        color: theme.mutedTextColor
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const mon = root.screen ? root.screen.name : "PRIMARY";
                            const w = root.screen ? root.screen.width : 1920;
                            const h = root.screen ? root.screen.height : 1080;
                            return mon + " (" + w + "x" + h + ")";
                        }
                        font.pixelSize: 8
                        font.bold: true
                        font.family: "monospace"
                        color: theme.actionActiveText
                    }
                }
            }
        }

        // =====================================================================
        // SECTION 5: Footer Status Branding
        // =====================================================================
        Rectangle {
            width: parent.width
            height: 1
            color: theme.surfaceDividerColor
        }

        Item {
            width: parent.width
            height: 16

            Text {
                anchors.centerIn: parent
                text: "SYS // PRANC.SHELL v0.26"
                font.pixelSize: 8
                font.family: "monospace"
                font.letterSpacing: 1.5
                color: theme.mutedTextColor
            }
        }
    }
}
