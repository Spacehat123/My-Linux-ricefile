import QtQuick
import "../theme"

Item {
    id: root

    // =========================================================================
    // Upstream Authoritative Models & Screen Context
    // =========================================================================
    property var desktopModel: null
    property var surfaceModel: null
    property var interactionModel: null
    property var screen: null
    property bool filterCurrentMonitor: false

    Theme {
        id: theme
    }

    // Passive root hover boundary (non-blocking, doesn't absorb wheel or clicks)
    HoverHandler {
        id: rootHoverHandler
    }

    readonly property bool hovered: rootHoverHandler.hovered

    // Reactive scalar state shortcuts
    readonly property int totalSurfaces: desktopModel ? desktopModel.surfaceCount : 0
    readonly property int urgentSurfaces: desktopModel ? desktopModel.urgentSurfaceCount : 0
    readonly property int appCount: desktopModel ? desktopModel.applicationCount : 0
    readonly property int monitorCount: desktopModel ? desktopModel.monitorCount : 1

    // =========================================================================
    // Header HUD
    // =========================================================================
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: theme.surfaceHeaderHeight

        // Tactical Category Title & Workspace Context
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                text: "// SURFACES"
                font.pixelSize: 11
                font.bold: true
                font.family: "monospace"
                font.letterSpacing: 1.5
                color: theme.primaryTextColor
            }

            // Lightweight Focused Workspace Context Badge
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 16
                implicitWidth: wsContextText.implicitWidth + 8
                radius: theme.surfaceTagCornerRadius
                color: theme.surfaceTagFocusedBackground
                border.color: theme.surfaceTagBorder
                border.width: 1

                Text {
                    id: wsContextText
                    anchors.centerIn: parent
                    text: {
                        const wsId = root.desktopModel ? root.desktopModel.focusedWorkspaceId : -1;
                        return wsId !== -1 ? "WS " + wsId : "WS -";
                    }
                    font.pixelSize: 9
                    font.bold: true
                    font.family: "monospace"
                    color: theme.surfaceTagFocusedText
                }
            }
        }

        // Global Metrics (Total & Urgent Badges)
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Surface Count Badge
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                implicitWidth: badgeText.implicitWidth + 10
                radius: theme.surfaceTagCornerRadius
                color: theme.surfaceBadgeBackground
                border.color: theme.surfaceBadgeBorder
                border.width: 1

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.totalSurfaces + (root.totalSurfaces === 1 ? " SURFACE" : " SURFACES")
                    font.pixelSize: 9
                    font.bold: true
                    font.family: "monospace"
                    color: theme.secondaryTextColor
                }
            }

            // Urgent Alert Badge
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                implicitWidth: urgentText.implicitWidth + 10
                radius: theme.surfaceTagCornerRadius
                color: theme.surfaceBadgeUrgentBackground
                visible: root.urgentSurfaces > 0

                Text {
                    id: urgentText
                    anchors.centerIn: parent
                    text: "! " + root.urgentSurfaces
                    font.pixelSize: 9
                    font.bold: true
                    font.family: "monospace"
                    color: theme.surfaceBadgeUrgentText
                }
            }
        }

        // Hairline Divider
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: theme.surfaceDividerColor
        }
    }

    // =========================================================================
    // Scrollable Application Surface List
    // =========================================================================
    ListView {
        id: appListView
        anchors.top: header.bottom
        anchors.topMargin: theme.itemSpacing
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        spacing: theme.surfaceCardSpacing
        boundsBehavior: Flickable.StopAtBounds

        model: {
            if (!root.desktopModel || !root.desktopModel.applications) return [];
            return root.desktopModel.applications;
        }

        delegate: Item {
            id: appCardDelegate
            required property var modelData
            required property int index

            width: appListView.width
            implicitHeight: cardBg.implicitHeight

            readonly property bool isFocused: modelData ? Boolean(modelData.isFocused) : false
            readonly property bool isUrgent: modelData ? Boolean(modelData.isUrgent) : false

            // Passive hover tracking on the card
            HoverHandler {
                id: cardHover
                cursorShape: Qt.PointingHandCursor
            }

            readonly property bool isHovered: cardHover.hovered

            Rectangle {
                id: cardBg
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: cardColumn.implicitHeight + theme.surfaceCardPadding * 2
                radius: theme.surfaceCardCornerRadius

                // Color based on focus / urgency / hover / normal
                color: {
                    if (appCardDelegate.isUrgent) return theme.surfaceCardUrgentBackground;
                    if (appCardDelegate.isFocused) return theme.surfaceCardFocusedBackground;
                    if (appCardDelegate.isHovered) return theme.surfaceCardHoverBackground;
                    return theme.surfaceCardBackground;
                }

                border.width: (appCardDelegate.isFocused || appCardDelegate.isUrgent) ? 1.5 : 1
                border.color: {
                    if (appCardDelegate.isUrgent) return theme.surfaceCardUrgentBorder;
                    if (appCardDelegate.isFocused) return theme.surfaceCardFocusedBorder;
                    if (appCardDelegate.isHovered) return theme.surfaceCardHoverBorder;
                    return theme.surfaceCardBorder;
                }

                Behavior on color {
                    ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
                Behavior on border.color {
                    ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                }

                Column {
                    id: cardColumn
                    anchors.top: parent.top
                    anchors.topMargin: theme.surfaceCardPadding
                    anchors.left: parent.left
                    anchors.leftMargin: theme.surfaceCardPadding
                    anchors.right: parent.right
                    anchors.rightMargin: theme.surfaceCardPadding
                    spacing: theme.surfaceItemSpacing

                    // -------------------------------------------------------------
                    // Application Card Header Row
                    // -------------------------------------------------------------
                    Row {
                        width: parent.width
                        spacing: 6

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: {
                                if (root.interactionModel && appCardDelegate.modelData && appCardDelegate.modelData.primarySurface) {
                                    root.interactionModel.requestSurfaceFocus(appCardDelegate.modelData.primarySurface.address);
                                }
                            }
                        }

                        // Tactical Status Pip Glyphs
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: appCardDelegate.isFocused ? "◈" : (appCardDelegate.isUrgent ? "!" : "◇")
                            font.pixelSize: 11
                            font.bold: true
                            color: {
                                if (appCardDelegate.isUrgent) return theme.surfaceCardUrgentPip;
                                if (appCardDelegate.isFocused) return theme.surfaceCardFocusedPip;
                                return theme.secondaryTextColor;
                            }
                        }

                        // App Display Name
                        Text {
                            id: appNameLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: appCardDelegate.modelData ? (appCardDelegate.modelData.appName || "Unknown") : ""
                            font.pixelSize: 12
                            font.bold: true
                            font.family: "sans-serif"
                            color: theme.primaryTextColor
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 120)
                        }

                        // Multiplicity Indicator (e.g. "(2)")
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "(" + (appCardDelegate.modelData ? appCardDelegate.modelData.count : 0) + ")"
                            font.pixelSize: 10
                            font.family: "monospace"
                            color: theme.secondaryTextColor
                        }

                        Item {
                            // Flexible spacer
                            width: 1
                            height: 1
                        }

                        // Right-aligned Workspace Badge
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 16
                            implicitWidth: wsTagText.implicitWidth + 8
                            radius: theme.surfaceTagCornerRadius
                            color: appCardDelegate.isFocused ? theme.surfaceTagFocusedBackground : theme.surfaceTagBackground
                            border.color: theme.surfaceTagBorder
                            border.width: 1

                            Text {
                                id: wsTagText
                                anchors.centerIn: parent
                                text: {
                                    const pSurf = appCardDelegate.modelData ? appCardDelegate.modelData.primarySurface : null;
                                    const wsName = pSurf ? (pSurf.workspaceName || String(pSurf.workspaceId)) : "";
                                    return wsName ? "WS " + wsName : "WS -";
                                }
                                font.pixelSize: 9
                                font.bold: true
                                font.family: "monospace"
                                color: appCardDelegate.isFocused ? theme.surfaceTagFocusedText : theme.surfaceTagText
                            }
                        }

                        // Optional Monitor Badge if Multi-Monitor
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 16
                            implicitWidth: monTagText.implicitWidth + 8
                            radius: theme.surfaceTagCornerRadius
                            color: theme.surfaceTagBackground
                            border.color: theme.surfaceTagBorder
                            border.width: 1
                            visible: root.monitorCount > 1 && Boolean(appCardDelegate.modelData && appCardDelegate.modelData.primarySurface && appCardDelegate.modelData.primarySurface.monitorName)

                            Text {
                                id: monTagText
                                anchors.centerIn: parent
                                text: {
                                    const pSurf = appCardDelegate.modelData ? appCardDelegate.modelData.primarySurface : null;
                                    return pSurf ? (pSurf.monitorName || "") : "";
                                }
                                font.pixelSize: 9
                                font.bold: false
                                font.family: "monospace"
                                color: theme.secondaryTextColor
                            }
                        }
                    }

                    // -------------------------------------------------------------
                    // Individual Surface Window Rows
                    // -------------------------------------------------------------
                    Repeater {
                        model: appCardDelegate.modelData ? appCardDelegate.modelData.surfaces : []

                        delegate: Rectangle {
                            id: windowRow
                            required property var modelData
                            required property int index

                            width: cardColumn.width
                            property bool drawerOpen: false
                            height: drawerOpen ? (theme.surfaceItemHeight + 28) : theme.surfaceItemHeight
                            radius: theme.surfaceItemCornerRadius

                            readonly property bool surfFocused: modelData ? Boolean(modelData.activated) : false
                            readonly property bool surfUrgent: modelData ? Boolean(modelData.urgent) : false

                            HoverHandler {
                                id: rowHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            readonly property bool surfHovered: rowHover.hovered

                            color: {
                                if (windowRow.surfUrgent) return theme.surfaceItemUrgentBackground;
                                if (windowRow.surfFocused) return theme.surfaceItemFocusedBackground;
                                if (windowRow.surfHovered) return theme.surfaceItemHoverBackground;
                                return theme.surfaceItemBackground;
                            }

                            border.width: (windowRow.surfFocused || windowRow.surfUrgent) ? 1 : 0
                            border.color: {
                                if (windowRow.surfUrgent) return theme.surfaceItemUrgentBorder;
                                if (windowRow.surfFocused) return theme.surfaceItemFocusedBorder;
                                return "transparent";
                            }
                            scale: rowTap.pressed && !actionClusterHover.hovered ? 0.98 : 1.0

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }
                            Behavior on scale {
                                NumberAnimation { duration: 80 }
                            }
                            Behavior on height {
                                NumberAnimation { duration: 120 }
                            }

                            Column {
                                anchors.fill: parent
                                spacing: 2

                                // Main window row
                                Item {
                                    width: parent.width
                                    height: theme.surfaceItemHeight

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        spacing: 4

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: windowRow.surfFocused ? "›" : (windowRow.surfHovered ? "→" : "·")
                                            font.pixelSize: 11
                                            font.bold: windowRow.surfFocused || windowRow.surfHovered
                                            color: {
                                                if (windowRow.surfFocused) return theme.surfaceCardFocusedPip;
                                                if (windowRow.surfHovered) return theme.actionFocusPromptColor;
                                                return theme.secondaryTextColor;
                                            }
                                        }

                                        Text {
                                            id: windowTitle
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: {
                                                if (!windowRow.modelData) return "Window";
                                                return windowRow.modelData.title || windowRow.modelData.initialTitle || "Window";
                                            }
                                            font.pixelSize: 10
                                            font.family: "sans-serif"
                                            font.bold: windowRow.surfFocused
                                            color: windowRow.surfFocused ? theme.primaryTextColor : theme.secondaryTextColor
                                            elide: Text.ElideRight
                                            width: windowRow.width - actionCluster.width - 24
                                        }

                                        Item {
                                            width: 1
                                            height: 1
                                        }

                                        // Action Cluster (revealed on hover or when drawer open)
                                        Row {
                                            id: actionCluster
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3
                                            opacity: (windowRow.surfHovered || windowRow.drawerOpen || actionClusterHover.hovered) ? theme.actionAffordanceOpacityHover : theme.actionAffordanceOpacityRest
                                            visible: opacity > 0.0

                                            HoverHandler {
                                                id: actionClusterHover
                                            }

                                            // Fullscreen toggle button
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: theme.actionButtonSize
                                                height: theme.actionButtonSize
                                                radius: theme.actionButtonCornerRadius
                                                color: windowRow.modelData && windowRow.modelData.fullscreen ? theme.actionActiveBackground : (fsHover.hovered ? theme.surfaceItemHoverBackground : theme.actionCloseBackground)
                                                border.width: 1
                                                border.color: windowRow.modelData && windowRow.modelData.fullscreen ? theme.actionActiveBorder : (fsHover.hovered ? theme.actionFocusPromptColor : theme.actionCloseBorder)
                                                scale: fsTap.pressed ? 0.88 : 1.0

                                                HoverHandler { id: fsHover; cursorShape: Qt.PointingHandCursor }
                                                TapHandler {
                                                    id: fsTap
                                                    acceptedButtons: Qt.LeftButton
                                                    onTapped: {
                                                        if (root.interactionModel && windowRow.modelData) {
                                                            root.interactionModel.requestSurfaceToggleFullscreen(windowRow.modelData.address);
                                                        }
                                                    }
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "⛶"
                                                    font.pixelSize: 9
                                                    color: windowRow.modelData && windowRow.modelData.fullscreen ? theme.actionActiveText : (fsHover.hovered ? theme.primaryTextColor : theme.secondaryTextColor)
                                                }

                                                Behavior on scale { NumberAnimation { duration: 80 } }
                                            }

                                            // Floating toggle button
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: theme.actionButtonSize
                                                height: theme.actionButtonSize
                                                radius: theme.actionButtonCornerRadius
                                                visible: root.interactionModel ? root.interactionModel.canToggleFloating(windowRow.modelData ? windowRow.modelData.address : "") : false
                                                color: windowRow.modelData && windowRow.modelData.floating ? theme.actionActiveBackground : (floatHover.hovered ? theme.surfaceItemHoverBackground : theme.actionCloseBackground)
                                                border.width: 1
                                                border.color: windowRow.modelData && windowRow.modelData.floating ? theme.actionActiveBorder : (floatHover.hovered ? theme.actionFocusPromptColor : theme.actionCloseBorder)
                                                scale: floatTap.pressed ? 0.88 : 1.0

                                                HoverHandler { id: floatHover; cursorShape: Qt.PointingHandCursor }
                                                TapHandler {
                                                    id: floatTap
                                                    acceptedButtons: Qt.LeftButton
                                                    onTapped: {
                                                        if (root.interactionModel && windowRow.modelData) {
                                                            root.interactionModel.requestSurfaceToggleFloating(windowRow.modelData.address);
                                                        }
                                                    }
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "❐"
                                                    font.pixelSize: 9
                                                    color: windowRow.modelData && windowRow.modelData.floating ? theme.actionActiveText : (floatHover.hovered ? theme.primaryTextColor : theme.secondaryTextColor)
                                                }

                                                Behavior on scale { NumberAnimation { duration: 80 } }
                                            }

                                            // Relocate to workspace drawer toggle
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: theme.actionButtonSize
                                                height: theme.actionButtonSize
                                                radius: theme.actionButtonCornerRadius
                                                color: windowRow.drawerOpen ? theme.actionActiveBackground : (relocHover.hovered ? theme.surfaceItemHoverBackground : theme.actionCloseBackground)
                                                border.width: 1
                                                border.color: windowRow.drawerOpen ? theme.actionActiveBorder : (relocHover.hovered ? theme.actionFocusPromptColor : theme.actionCloseBorder)
                                                scale: relocTap.pressed ? 0.88 : 1.0

                                                HoverHandler { id: relocHover; cursorShape: Qt.PointingHandCursor }
                                                TapHandler {
                                                    id: relocTap
                                                    acceptedButtons: Qt.LeftButton
                                                    onTapped: {
                                                        windowRow.drawerOpen = !windowRow.drawerOpen;
                                                    }
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "⇄"
                                                    font.pixelSize: 10
                                                    color: windowRow.drawerOpen ? theme.actionActiveText : (relocHover.hovered ? theme.primaryTextColor : theme.secondaryTextColor)
                                                }

                                                Behavior on scale { NumberAnimation { duration: 80 } }
                                            }

                                            // Close button
                                            Rectangle {
                                                id: closeBtn
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: theme.actionButtonSize
                                                height: theme.actionButtonSize
                                                radius: theme.actionButtonCornerRadius
                                                color: closeHover.hovered ? theme.actionCloseHoverBackground : theme.actionCloseBackground
                                                border.width: 1
                                                border.color: closeHover.hovered ? theme.actionCloseHoverBorder : theme.actionCloseBorder
                                                scale: closeTap.pressed ? 0.85 : 1.0

                                                HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                                                TapHandler {
                                                    id: closeTap
                                                    acceptedButtons: Qt.LeftButton
                                                    onTapped: {
                                                        if (root.interactionModel && windowRow.modelData) {
                                                            root.interactionModel.requestSurfaceClose(windowRow.modelData.address);
                                                        }
                                                    }
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "×"
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    font.family: "sans-serif"
                                                    color: closeHover.hovered ? theme.actionCloseHoverText : theme.actionCloseText
                                                }

                                                Behavior on scale { NumberAnimation { duration: 80 } }
                                            }

                                            Behavior on opacity {
                                                NumberAnimation { duration: theme.animDurationAffordance }
                                            }
                                        }
                                    }

                                    // Interactive row tap handler for surface focus intent
                                    TapHandler {
                                        id: rowTap
                                        acceptedButtons: Qt.LeftButton
                                        onTapped: {
                                            if (!actionClusterHover.hovered && !windowRow.drawerOpen && root.interactionModel && windowRow.modelData) {
                                                root.interactionModel.requestSurfaceFocus(windowRow.modelData.address);
                                            }
                                        }
                                    }
                                }

                                // Inline Relocation Drawer
                                Rectangle {
                                    id: relocationDrawer
                                    visible: windowRow.drawerOpen
                                    width: parent.width - 12
                                    height: 22
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    radius: 4
                                    color: theme.actionDrawerBackground
                                    border.width: 1
                                    border.color: theme.actionDrawerBorder

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        spacing: 4

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "MOVE:"
                                            font.pixelSize: 8
                                            font.bold: true
                                            font.family: "monospace"
                                            color: theme.mutedTextColor
                                        }

                                        Repeater {
                                            model: root.desktopModel ? root.desktopModel.workspaces : []

                                            Rectangle {
                                                id: wsPill
                                                required property var modelData
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 16
                                                height: 16
                                                radius: 3
                                                property bool isCurrent: windowRow.modelData && windowRow.modelData.workspaceId === modelData.id
                                                opacity: isCurrent ? 0.35 : (wsPillHover.hovered ? 1.0 : 0.8)
                                                color: isCurrent ? "transparent" : (wsPillHover.hovered ? theme.actionActiveBackground : theme.surfaceBadgeBackground)
                                                border.width: 1
                                                border.color: isCurrent ? theme.actionCloseBorder : (wsPillHover.hovered ? theme.actionActiveBorder : theme.surfaceBadgeBorder)
                                                scale: wsPillTap.pressed ? 0.88 : 1.0

                                                HoverHandler {
                                                    id: wsPillHover
                                                    enabled: !wsPill.isCurrent
                                                    cursorShape: Qt.PointingHandCursor
                                                }

                                                TapHandler {
                                                    id: wsPillTap
                                                    enabled: !wsPill.isCurrent
                                                    acceptedButtons: Qt.LeftButton
                                                    onTapped: {
                                                        if (root.interactionModel && windowRow.modelData) {
                                                            root.interactionModel.requestSurfaceMove(windowRow.modelData.address, wsPill.modelData.id);
                                                            windowRow.drawerOpen = false;
                                                        }
                                                    }
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: String(wsPill.modelData.id)
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    font.family: "monospace"
                                                    color: wsPill.isCurrent ? theme.mutedTextColor : (wsPillHover.hovered ? theme.actionActiveText : theme.primaryTextColor)
                                                }

                                                Behavior on scale { NumberAnimation { duration: 80 } }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // Empty State HUD
    // =========================================================================
    Item {
        anchors.centerIn: parent
        width: parent.width
        height: 100
        visible: root.totalSurfaces === 0

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "[ // ]"
                font.pixelSize: 18
                font.bold: true
                font.family: "monospace"
                color: theme.mutedTextColor
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "// NO ACTIVE SURFACES"
                font.pixelSize: 11
                font.bold: true
                font.family: "monospace"
                font.letterSpacing: 1.2
                color: theme.mutedTextColor
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "All workspaces clear"
                font.pixelSize: 10
                font.family: "sans-serif"
                color: theme.mutedTextColor
                opacity: 0.7
            }
        }
    }

    // =========================================================================
    // Minimal Tactile Scrollbar
    // =========================================================================
    Rectangle {
        id: scrollTrack
        anchors.top: appListView.top
        anchors.bottom: appListView.bottom
        anchors.right: parent.right
        width: theme.scrollbarWidth
        color: theme.scrollbarTrackColor
        visible: appListView.visibleArea.heightRatio < 1.0

        Rectangle {
            id: scrollThumb
            width: parent.width
            height: Math.max(24, appListView.visibleArea.heightRatio * appListView.height)
            y: appListView.visibleArea.yPosition * appListView.height
            radius: 1.5
            color: (appListView.moving || appListView.flicking) ? theme.scrollbarThumbActiveColor : theme.scrollbarThumbColor

            Behavior on color {
                ColorAnimation { duration: 140 }
            }
        }
    }
}
