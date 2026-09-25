import QtQuick
import "../theme"

Item {
    id: root

    // =========================================================================
    // Upstream Injected Model & Screen Context
    // =========================================================================
    property var desktopModel: null
    property var interactionModel: null
    property var desktopState: null
    property var screen: null
    property bool filterCurrentMonitor: false

    Theme {
        id: theme
    }

    // Passive root hover boundary ensuring unbreakable bar continuity
    HoverHandler {
        id: rootHoverHandler
    }

    readonly property bool hovered: rootHoverHandler.hovered
    readonly property int workspaceCount: desktopModel ? desktopModel.workspaceCount : 0
    readonly property int focusedWorkspaceId: desktopModel ? desktopModel.focusedWorkspaceId : -1
    readonly property var currentFocusedWorkspace: desktopModel ? desktopModel.focusedWorkspace : null

    // Transition tracking state (zero polling / zero timers)
    property int previousWorkspaceId: -1
    property int transitionDirection: 1
    property int activeSlotIndex: 0
    property bool initialized: false

    // React to focused workspace ID changes (spatial exit / enter transitions)
    onFocusedWorkspaceIdChanged: {
        const curId = root.focusedWorkspaceId;
        if (curId === -1) return;

        if (!root.initialized) {
            root.previousWorkspaceId = curId;
            if (root.desktopModel && root.desktopModel.focusedWorkspace) {
                slot0.applyWorkspace(root.desktopModel.focusedWorkspace);
            }
            root.initialized = true;
            return;
        }

        const dir = (root.desktopState && root.desktopState.workspaceTransitionDirectionSign !== 0)
            ? root.desktopState.workspaceTransitionDirectionSign
            : (curId >= root.previousWorkspaceId ? 1 : -1);
        root.transitionDirection = dir;
        root.previousWorkspaceId = curId;

        const nextSlot = (root.activeSlotIndex === 0) ? 1 : 0;
        const comp = root.desktopModel ? root.desktopModel.focusedWorkspace : null;

        if (nextSlot === 0) {
            slot0.applyWorkspace(comp);
            animToSlot0.direction = dir;
            animToSlot0.restart();
        } else {
            slot1.applyWorkspace(comp);
            animToSlot1.direction = dir;
            animToSlot1.restart();
        }
        root.activeSlotIndex = nextSlot;
    }

    // In-place reactive updates when surface count or fullscreen changes on current workspace
    onCurrentFocusedWorkspaceChanged: {
        const comp = root.currentFocusedWorkspace;
        if (!comp) return;

        if (root.initialized && comp.id === root.focusedWorkspaceId) {
            if (root.activeSlotIndex === 0) {
                slot0.applyWorkspace(comp);
            } else {
                slot1.applyWorkspace(comp);
            }
        }
    }

    implicitHeight: theme.workspaceItemHeight
    implicitWidth: navContainer.implicitWidth
    width: implicitWidth
    height: implicitHeight

    Row {
        id: navContainer
        anchors.centerIn: parent
        spacing: theme.workspaceHudSpacing

        // =====================================================================
        // SECTION 1: Contextual Workspace Information Surface (HUD)
        // =====================================================================
        Item {
            id: contextHud
            width: theme.workspaceHudWidth
            height: theme.workspaceItemHeight
            clip: true

            Rectangle {
                anchors.fill: parent
                radius: theme.workspaceHudCornerRadius
                color: theme.workspaceHudBackground
                border.color: theme.workspaceHudBorder
                border.width: 1
            }

            // Slot 0 (A-slot)
            Item {
                id: slot0
                anchors.fill: parent
                x: 0
                opacity: 1.0

                property string wsIdText: "01"
                property string surfaceCountText: "EMPTY"
                property bool hasFullscreen: false
                property bool isUrgent: false
                property string monitorText: ""

                function applyWorkspace(ws) {
                    if (!ws) {
                        wsIdText = "--";
                        surfaceCountText = "EMPTY";
                        hasFullscreen = false;
                        isUrgent = false;
                        monitorText = "";
                        return;
                    }
                    const rawName = ws.name || String(ws.id);
                    if (/^\d+$/.test(rawName)) {
                        const num = parseInt(rawName, 10);
                        wsIdText = num < 10 ? "0" + num : String(num);
                    } else {
                        wsIdText = rawName;
                    }

                    if (ws.surfaceCount === 0) {
                        surfaceCountText = "EMPTY";
                    } else if (ws.surfaceCount === 1) {
                        surfaceCountText = "1 SURFACE";
                    } else {
                        surfaceCountText = ws.surfaceCount + " SURFACES";
                    }

                    hasFullscreen = Boolean(ws.hasFullscreen);
                    isUrgent = Boolean(ws.urgent);
                    monitorText = ws.monitorName || "";
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // Micro-Identity Capsule
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30

                        Text {
                            text: "SYS.WS"
                            font.pixelSize: 7
                            font.bold: true
                            font.family: "monospace"
                            color: theme.workspaceHudLabelText
                        }

                        Text {
                            text: slot0.wsIdText
                            font.pixelSize: 15
                            font.bold: true
                            font.family: "monospace"
                            color: theme.workspaceFocusedBorder
                        }
                    }

                    // Tactical Telemetry Stack
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Row {
                            spacing: 4

                            Text {
                                text: slot0.surfaceCountText
                                font.pixelSize: 9
                                font.bold: true
                                font.family: "monospace"
                                color: slot0.surfaceCountText === "EMPTY" ? theme.workspaceHudMutedText : theme.workspaceHudValueText
                            }

                            // Fullscreen indicator tag
                            Rectangle {
                                visible: slot0.hasFullscreen
                                width: 22
                                height: 11
                                radius: 2
                                color: theme.workspaceHudFullscreenBackground
                                border.color: theme.workspaceHudFullscreenBadge
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "FS"
                                    font.pixelSize: 7
                                    font.bold: true
                                    font.family: "monospace"
                                    color: theme.workspaceHudFullscreenBadge
                                }
                            }

                            // Urgent indicator tag
                            Rectangle {
                                visible: slot0.isUrgent
                                width: 26
                                height: 11
                                radius: 2
                                color: theme.workspaceHudUrgentBackground
                                border.color: theme.workspaceHudUrgentBadge
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "CRIT"
                                    font.pixelSize: 7
                                    font.bold: true
                                    font.family: "monospace"
                                    color: theme.workspaceHudUrgentBadge
                                }
                            }
                        }

                        // Monitor context
                        Row {
                            spacing: 3
                            visible: slot0.monitorText !== ""

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 3
                                radius: 1.5
                                color: theme.workspaceHudMonitorBadge
                            }

                            Text {
                                text: slot0.monitorText
                                font.pixelSize: 8
                                font.family: "monospace"
                                color: theme.workspaceOtherMonitorText
                            }
                        }
                    }
                }
            }

            // Slot 1 (B-slot)
            Item {
                id: slot1
                anchors.fill: parent
                x: theme.workspaceTransitionDistance
                opacity: 0.0

                property string wsIdText: "01"
                property string surfaceCountText: "EMPTY"
                property bool hasFullscreen: false
                property bool isUrgent: false
                property string monitorText: ""

                function applyWorkspace(ws) {
                    if (!ws) {
                        wsIdText = "--";
                        surfaceCountText = "EMPTY";
                        hasFullscreen = false;
                        isUrgent = false;
                        monitorText = "";
                        return;
                    }
                    const rawName = ws.name || String(ws.id);
                    if (/^\d+$/.test(rawName)) {
                        const num = parseInt(rawName, 10);
                        wsIdText = num < 10 ? "0" + num : String(num);
                    } else {
                        wsIdText = rawName;
                    }

                    if (ws.surfaceCount === 0) {
                        surfaceCountText = "EMPTY";
                    } else if (ws.surfaceCount === 1) {
                        surfaceCountText = "1 SURFACE";
                    } else {
                        surfaceCountText = ws.surfaceCount + " SURFACES";
                    }

                    hasFullscreen = Boolean(ws.hasFullscreen);
                    isUrgent = Boolean(ws.urgent);
                    monitorText = ws.monitorName || "";
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30

                        Text {
                            text: "SYS.WS"
                            font.pixelSize: 7
                            font.bold: true
                            font.family: "monospace"
                            color: theme.workspaceHudLabelText
                        }

                        Text {
                            text: slot1.wsIdText
                            font.pixelSize: 15
                            font.bold: true
                            font.family: "monospace"
                            color: theme.workspaceFocusedBorder
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Row {
                            spacing: 4

                            Text {
                                text: slot1.surfaceCountText
                                font.pixelSize: 9
                                font.bold: true
                                font.family: "monospace"
                                color: slot1.surfaceCountText === "EMPTY" ? theme.workspaceHudMutedText : theme.workspaceHudValueText
                            }

                            Rectangle {
                                visible: slot1.hasFullscreen
                                width: 22
                                height: 11
                                radius: 2
                                color: theme.workspaceHudFullscreenBackground
                                border.color: theme.workspaceHudFullscreenBadge
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "FS"
                                    font.pixelSize: 7
                                    font.bold: true
                                    font.family: "monospace"
                                    color: theme.workspaceHudFullscreenBadge
                                }
                            }

                            Rectangle {
                                visible: slot1.isUrgent
                                width: 26
                                height: 11
                                radius: 2
                                color: theme.workspaceHudUrgentBackground
                                border.color: theme.workspaceHudUrgentBadge
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "CRIT"
                                    font.pixelSize: 7
                                    font.bold: true
                                    font.family: "monospace"
                                    color: theme.workspaceHudUrgentBadge
                                }
                            }
                        }

                        Row {
                            spacing: 3
                            visible: slot1.monitorText !== ""

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 3
                                radius: 1.5
                                color: theme.workspaceHudMonitorBadge
                            }

                            Text {
                                text: slot1.monitorText
                                font.pixelSize: 8
                                font.family: "monospace"
                                color: theme.workspaceOtherMonitorText
                            }
                        }
                    }
                }
            }

            // Directional Transitions (A/B ping-pong)
            ParallelAnimation {
                id: animToSlot0
                property int direction: 1

                NumberAnimation {
                    target: slot0
                    property: "x"
                    from: animToSlot0.direction * theme.workspaceTransitionDistance
                    to: 0
                    duration: theme.workspaceTransitionDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: slot0
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: theme.workspaceTransitionDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: slot1
                    property: "x"
                    from: 0
                    to: -animToSlot0.direction * theme.workspaceTransitionDistance
                    duration: theme.workspaceTransitionDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: slot1
                    property: "opacity"
                    from: 1.0
                    to: 0.0
                    duration: theme.workspaceTransitionDuration
                    easing.type: Easing.OutCubic
                }
            }

            ParallelAnimation {
                id: animToSlot1
                property int direction: 1

                NumberAnimation {
                    target: slot1
                    property: "x"
                    from: animToSlot1.direction * theme.workspaceTransitionDistance
                    to: 0
                    duration: theme.workspaceTransitionDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: slot1
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: theme.workspaceTransitionDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: slot0
                    property: "x"
                    from: 0
                    to: -animToSlot1.direction * theme.workspaceTransitionDistance
                    duration: theme.workspaceTransitionDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: slot0
                    property: "opacity"
                    from: 1.0
                    to: 0.0
                    duration: theme.workspaceTransitionDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        // =====================================================================
        // SECTION 2: Tactical Cyber-Divider
        // =====================================================================
        Item {
            id: hudDivider
            width: 9
            height: theme.workspaceItemHeight

            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: 18
                color: theme.surfaceDividerColor
            }

            Rectangle {
                anchors.centerIn: parent
                width: 3
                height: 3
                rotation: 45
                color: theme.workspaceFocusedBorder
                opacity: 0.8
            }
        }

        // =====================================================================
        // SECTION 3: Spatial Workspace Pill Strip with Sliding Focal Cursor
        // =====================================================================
        Item {
            id: pillStripContainer
            implicitWidth: layoutRow.implicitWidth
            implicitHeight: theme.workspaceItemHeight

            property var currentPill: null

            // Smooth sliding focal reticle cursor (spatially continuous on jumps)
            Rectangle {
                id: focalReticle
                anchors.verticalCenter: parent.verticalCenter
                height: theme.workspaceItemHeight
                radius: theme.workspaceCornerRadius
                color: theme.workspaceFocalCursorGlow
                border.color: theme.workspaceFocalCursorBorder
                border.width: 1.5
                visible: targetPill !== null

                property var targetPill: {
                    const fid = root.focusedWorkspaceId;
                    const wc = root.workspaceCount;
                    if (fid === -1) return null;
                    if (pillStripContainer.currentPill && pillStripContainer.currentPill.workspaceId === fid) {
                        return pillStripContainer.currentPill;
                    }
                    if (!repeater) return null;
                    for (let i = 0; i < repeater.count; ++i) {
                        const item = repeater.itemAt(i);
                        if (item && item.workspaceId === fid) return item;
                    }
                    return null;
                }

                x: targetPill ? (layoutRow.x + targetPill.x) : 0
                width: targetPill ? targetPill.width : theme.workspaceItemMinWidth

                Behavior on x {
                    NumberAnimation {
                        duration: theme.workspaceTransitionDuration
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: theme.workspaceTransitionDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Row {
                id: layoutRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: theme.workspaceSpacing

                Repeater {
                    id: repeater
                    model: {
                        if (!root.desktopModel || !root.desktopModel.workspaces) return [];
                        const list = root.desktopModel.workspaces;
                        if (!root.filterCurrentMonitor || !root.screen) return list;
                        return list.filter(w => w && w.monitorName === root.screen.name);
                    }

                    delegate: Item {
                        id: pillDelegate
                        required property var modelData
                        required property int index

                        readonly property int workspaceId: modelData ? modelData.id : -1
                        readonly property bool isFocused: modelData ? Boolean(modelData.focused) : false
                        readonly property bool isOccupied: modelData ? Boolean(modelData.occupied) : false
                        readonly property bool isUrgent: modelData ? Boolean(modelData.urgent) : false
                        readonly property bool isOtherMonitor: Boolean(
                            root.screen && modelData && modelData.monitorName && modelData.monitorName !== root.screen.name
                        )

                        onIsFocusedChanged: {
                            if (isFocused) {
                                pillStripContainer.currentPill = pillDelegate;
                            }
                        }
                        Component.onCompleted: {
                            if (isFocused) {
                                pillStripContainer.currentPill = pillDelegate;
                            }
                        }

                        HoverHandler {
                            id: pillHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        readonly property bool isHovered: pillHover.hovered

                        implicitHeight: theme.workspaceItemHeight
                        implicitWidth: Math.max(
                            theme.workspaceItemMinWidth,
                            pillContent.implicitWidth + theme.workspacePaddingHorizontal * 2
                        )
                        width: implicitWidth
                        height: implicitHeight

                        // Visual Capsule Surface
                        Rectangle {
                            id: pillBg
                            anchors.fill: parent
                            radius: theme.workspaceCornerRadius

                            color: {
                                if (pillDelegate.isUrgent) return theme.workspaceUrgentBackground;
                                if (pillDelegate.isFocused) return theme.workspaceFocusedBackground;
                                if (pillDelegate.isHovered) return theme.workspaceHoverBackground;
                                if (pillDelegate.isOccupied) return theme.workspaceOccupiedBackground;
                                return theme.workspaceEmptyBackground;
                            }

                            border.width: pillDelegate.isFocused ? 0 : 1
                            border.color: {
                                if (pillDelegate.isUrgent) return theme.workspaceUrgentBorder;
                                if (pillDelegate.isHovered) return theme.workspaceHoverBorder;
                                if (pillDelegate.isOccupied) return theme.workspaceOccupiedBorder;
                                return theme.workspaceEmptyBorder;
                            }

                            opacity: pillDelegate.isOtherMonitor && !pillDelegate.isFocused ? 0.65 : 1.0
                            scale: pillTap.pressed ? 0.96 : 1.0

                            Behavior on color {
                                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                            Behavior on border.color {
                                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                            Behavior on scale {
                                NumberAnimation { duration: 80 }
                            }

                            Row {
                                id: pillContent
                                anchors.centerIn: parent
                                spacing: 4

                                // Hover cue bracket
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "›"
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.family: "monospace"
                                    color: theme.workspaceHoverBracketColor
                                    visible: pillDelegate.isHovered && !pillDelegate.isFocused
                                }

                                // Identifier
                                Text {
                                    id: labelText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        if (!pillDelegate.modelData) return "";
                                        const rawName = pillDelegate.modelData.name || String(pillDelegate.modelData.id);
                                        if (/^\d+$/.test(rawName)) {
                                            const num = parseInt(rawName, 10);
                                            return num < 10 ? "0" + num : String(num);
                                        }
                                        return rawName;
                                    }
                                    font.pixelSize: 11
                                    font.bold: pillDelegate.isFocused || pillDelegate.isOccupied
                                    font.family: "monospace"

                                    color: {
                                        if (pillDelegate.isUrgent) return theme.workspaceUrgentText;
                                        if (pillDelegate.isFocused) return theme.workspaceFocusedText;
                                        if (pillDelegate.isOccupied) return theme.workspaceOccupiedText;
                                        return theme.workspaceEmptyText;
                                    }

                                    Behavior on color {
                                        ColorAnimation { duration: 140 }
                                    }
                                }

                                // Surface Activity Slivers (Pips)
                                Row {
                                    id: pipRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    visible: pillDelegate.isOccupied && pillDelegate.modelData && pillDelegate.modelData.surfaceCount > 0

                                    readonly property int surfCount: pillDelegate.modelData ? pillDelegate.modelData.surfaceCount : 0
                                    readonly property int displayCount: Math.min(surfCount, 3)
                                    readonly property bool hasOverflow: surfCount > 3

                                    Repeater {
                                        model: pipRow.displayCount

                                        Rectangle {
                                            width: 3
                                            height: 8
                                            radius: 1.5

                                            color: {
                                                if (pillDelegate.isUrgent) return theme.workspaceUrgentPip;
                                                if (pillDelegate.isFocused) return theme.workspaceFocusedPip;
                                                return theme.workspaceOccupiedPip;
                                            }

                                            Behavior on color {
                                                ColorAnimation { duration: 140 }
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: pipRow.hasOverflow
                                        text: "+"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: pillDelegate.isFocused ? theme.workspaceFocusedPip : theme.workspaceOccupiedPip
                                    }
                                }

                                // Secondary monitor indicator pip
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 3
                                    radius: 1.5
                                    visible: pillDelegate.isOtherMonitor && (root.desktopModel ? root.desktopModel.monitorCount > 1 : false)
                                    color: theme.workspaceOtherMonitorText
                                }
                            }
                        }

                        // Native click dispatch through InteractionModel
                        TapHandler {
                            id: pillTap
                            acceptedButtons: Qt.LeftButton
                            onTapped: {
                                if (root.interactionModel && pillDelegate.modelData) {
                                    root.interactionModel.requestWorkspaceSwitch(pillDelegate.modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
