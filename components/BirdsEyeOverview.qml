import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../island" as Island

PanelWindow {
    id: root

    property bool open: false
    property var workspaceModel: null
    property var surfaceModel: null
    property var compositorActionLayer: null
    property var screen: null

    signal closeRequested()

    visible: open

    WlrLayershell.namespace: "cool-shell-birdseye"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    focusable: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property real screenW: root.screen ? root.screen.width : (parent ? parent.width : 1920)
    readonly property real screenH: root.screen ? root.screen.height : (parent ? parent.height : 1080)

    // Current workspace id (local view workspace, can be toggled by the Spaces strip)
    property int selectedWorkspaceId: -1

    readonly property int activeWorkspaceId: {
        if (selectedWorkspaceId > 0) return selectedWorkspaceId;
        if (workspaceModel && workspaceModel.workspaceManager) {
            return workspaceModel.workspaceManager.focusedWorkspaceId || 1;
        }
        return 1;
    }

    // Workspaces list from workspaceModel
    readonly property var allWorkspaces: {
        if (workspaceModel && workspaceModel.workspaces) {
            return workspaceModel.workspaces;
        }
        return [{ id: 1, name: "1", occupied: true, surfaceCount: 1 }];
    }

    // Windows on the active workspace sorted by geometry
    readonly property var currentSurfaces: {
        if (!surfaceModel) return [];
        const list = surfaceModel.getSurfacesForWorkspace(root.activeWorkspaceId);
        if (!list || list.length === 0) return [];
        return list.slice().sort((a, b) => {
            const ax = (a && a.geomX !== undefined) ? a.geomX : 0;
            const bx = (b && b.geomX !== undefined) ? b.geomX : 0;
            return ax - bx;
        });
    }

    property int selectedIndex: 0

    // Grid geometry calculation
    readonly property int surfaceCount: currentSurfaces.length
    readonly property int gridCols: surfaceCount <= 1 ? 1 : (surfaceCount <= 2 ? 2 : (surfaceCount <= 6 ? 3 : 4))
    readonly property int gridRows: Math.ceil(surfaceCount / Math.max(1, gridCols))

    onOpenChanged: {
        if (open) {
            // Reset to current active workspace
            if (workspaceModel && workspaceModel.workspaceManager) {
                selectedWorkspaceId = workspaceModel.workspaceManager.focusedWorkspaceId || 1;
            } else {
                selectedWorkspaceId = 1;
            }

            // Find which window is currently focused to start selection on it
            let focusIdx = 0;
            const focusedAddr = (surfaceModel && surfaceModel.focusedSurface) ? surfaceModel.focusedSurface.address : "";
            for (let i = 0; i < currentSurfaces.length; ++i) {
                if (currentSurfaces[i] && currentSurfaces[i].address === focusedAddr) {
                    focusIdx = i;
                    break;
                }
            }
            selectedIndex = focusIdx;
            keyHandler.forceActiveFocus();
        }
    }

    function switchWorkspace(wsId) {
        if (!wsId || wsId === root.activeWorkspaceId) return;
        root.selectedWorkspaceId = wsId;
        root.selectedIndex = 0;
        if (compositorActionLayer) {
            compositorActionLayer.switchWorkspace(wsId);
        } else if (typeof Hyprland !== "undefined" && typeof Hyprland.dispatch === "function") {
            Hyprland.dispatch("hl.dsp.workspace(" + wsId + ")");
        }
    }

    function focusWindow(addr) {
        if (!addr) return;
        const cleanAddr = addr.toString().replace(/^0x/i, "");
        if (compositorActionLayer) {
            compositorActionLayer.focusSurface(cleanAddr);
        } else if (typeof Hyprland !== "undefined" && typeof Hyprland.dispatch === "function") {
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + cleanAddr + "\" })");
        }
        root.closeRequested();
    }

    function closeWindow(addr) {
        if (!addr) return;
        const cleanAddr = addr.toString().replace(/^0x/i, "");
        if (compositorActionLayer) {
            compositorActionLayer.closeSurface(cleanAddr);
        }
    }

    // =========================================================================
    // Backdrop Tint & Blur
    // =========================================================================
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#ea080c14"
        opacity: root.open ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    // =========================================================================
    // Keyboard Handler (2D Grid & Numeric Navigation)
    // =========================================================================
    Item {
        id: keyHandler
        focus: root.open
        anchors.fill: parent

        Keys.onEscapePressed: (event) => {
            root.closeRequested();
            event.accepted = true;
        }

        Keys.onReturnPressed: (event) => {
            if (root.currentSurfaces.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.currentSurfaces.length) {
                root.focusWindow(root.currentSurfaces[root.selectedIndex].address);
            }
            event.accepted = true;
        }

        Keys.onSpacePressed: (event) => {
            if (root.currentSurfaces.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.currentSurfaces.length) {
                root.focusWindow(root.currentSurfaces[root.selectedIndex].address);
            }
            event.accepted = true;
        }

        Keys.onLeftPressed: (event) => {
            if (root.selectedIndex > 0) root.selectedIndex--;
            event.accepted = true;
        }

        Keys.onRightPressed: (event) => {
            if (root.selectedIndex < root.currentSurfaces.length - 1) root.selectedIndex++;
            event.accepted = true;
        }

        Keys.onUpPressed: (event) => {
            const next = root.selectedIndex - root.gridCols;
            if (next >= 0) root.selectedIndex = next;
            event.accepted = true;
        }

        Keys.onDownPressed: (event) => {
            const next = root.selectedIndex + root.gridCols;
            if (next < root.currentSurfaces.length) root.selectedIndex = next;
            event.accepted = true;
        }

        // Direct number keys 1-9 switch spaces
        Keys.onPressed: (event) => {
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                const wsNum = event.key - Qt.Key_0;
                root.switchWorkspace(wsNum);
                event.accepted = true;
            }
        }
    }

    // =========================================================================
    // Main Viewport Content (Lazy-loaded via Loader)
    // =========================================================================
    Loader {
        id: mainLoader
        anchors.fill: parent
        active: root.open
        sourceComponent: mainContentComp
    }

    Component {
        id: mainContentComp

        Item {
            id: mainContent
            anchors.fill: parent
            opacity: root.open ? 1.0 : 0.0
            scale: root.open ? 1.0 : 0.95

            Behavior on opacity {
                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                SpringAnimation { spring: 4.5; damping: 0.38; epsilon: 0.005 }
            }

            // -----------------------------------------------------------------
            // Mission Control: Top Spaces Strip (Workspaces Bar)
            // -----------------------------------------------------------------
            Rectangle {
                id: spacesStrip
                anchors.top: parent.top
                anchors.topMargin: 28
                anchors.horizontalCenter: parent.horizontalCenter
                height: 52
                radius: 26
                color: Island.Theme.glassBackground
                border.color: Island.Theme.glassBorder
                border.width: 1
                implicitWidth: spacesRow.implicitWidth + 36

                RowLayout {
                    id: spacesRow
                    anchors.centerIn: parent
                    spacing: 10

                    // Bird's Eye Branding Pill
                    RowLayout {
                        spacing: 8
                        Rectangle {
                            width: 30
                            height: 30
                            radius: 15
                            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.22)
                            border.color: Island.Theme.primary
                            border.width: 1.5

                            Text {
                                anchors.centerIn: parent
                                text: "🦅"
                                font.pixelSize: 15
                            }
                        }

                        Text {
                            text: "BIRD'S-EYE VIEW"
                            color: Island.Theme.foreground
                            font.pixelSize: 12
                            font.bold: true
                            font.letterSpacing: 1.1
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 24
                        color: Island.Theme.glassBorder
                    }

                    // Workspaces List
                    Repeater {
                        model: root.allWorkspaces

                        delegate: Rectangle {
                            id: spaceTab
                            required property var modelData
                            required property int index

                            readonly property bool isCurrentWs: modelData.id === root.activeWorkspaceId
                            readonly property int numApps: modelData.surfaceCount !== undefined ? modelData.surfaceCount : 0

                            height: 34
                            radius: 17
                            implicitWidth: spaceLabelRow.implicitWidth + 24
                            color: isCurrentWs ? Island.Theme.primaryContainer : (spaceHover.hovered ? "#25ffffff" : "#12ffffff")
                            border.color: isCurrentWs ? Island.Theme.primary : (spaceHover.hovered ? "#40ffffff" : "transparent")
                            border.width: 1

                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }

                            RowLayout {
                                id: spaceLabelRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "Space " + spaceTab.modelData.id
                                    color: spaceTab.isCurrentWs ? Island.Theme.foreground : Island.Theme.muted
                                    font.pixelSize: 11
                                    font.bold: spaceTab.isCurrentWs
                                }

                                Rectangle {
                                    visible: spaceTab.numApps > 0
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: spaceTab.isCurrentWs ? Island.Theme.primary : "#30ffffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: String(spaceTab.numApps)
                                        color: spaceTab.isCurrentWs ? "#000000" : Island.Theme.foreground
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }
                            }

                            HoverHandler { id: spaceHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchWorkspace(spaceTab.modelData.id)
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 24
                        color: Island.Theme.glassBorder
                    }

                    // Close Button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: closeBtnHover.hovered ? "#35ffffff" : "#1affffff"
                        border.color: Island.Theme.glassBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Island.Theme.foreground
                            font.pixelSize: 12
                        }

                        HoverHandler { id: closeBtnHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested()
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // Empty State (if no windows on workspace)
            // -----------------------------------------------------------------
            Rectangle {
                anchors.centerIn: parent
                width: 380
                height: 170
                radius: 22
                color: Island.Theme.glassBackground
                border.color: Island.Theme.glassBorder
                border.width: 1
                visible: root.currentSurfaces.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "📭"
                        font.pixelSize: 36
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No Windows on Space " + root.activeWorkspaceId
                        color: Island.Theme.foreground
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Open applications to manage them in Exposé"
                        color: Island.Theme.muted
                        font.pixelSize: 11
                    }
                }
            }

            // -----------------------------------------------------------------
            // Mission Control 2D Window Exposé Grid
            // -----------------------------------------------------------------
            Item {
                id: gridContainer
                anchors.top: spacesStrip.bottom
                anchors.topMargin: 36
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 36
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(root.screenW * 0.94, 1480)
                visible: root.currentSurfaces.length > 0

                // Dynamic card dimensions based on grid columns & rows
                readonly property real cardW: {
                    const availW = gridContainer.width - ((root.gridCols - 1) * 24);
                    return Math.min(480, Math.max(260, availW / root.gridCols));
                }
                readonly property real cardH: {
                    const availH = gridContainer.height - ((root.gridRows - 1) * 24);
                    return Math.min(320, Math.max(180, availH / Math.max(1, root.gridRows)));
                }

                Grid {
                    id: exposeGrid
                    anchors.centerIn: parent
                    columns: root.gridCols
                    spacing: 24

                    Repeater {
                        model: root.currentSurfaces

                        delegate: Item {
                            id: windowCard
                            required property var modelData
                            required property int index

                            width: gridContainer.cardW
                            height: gridContainer.cardH

                            readonly property bool isSelected: root.selectedIndex === index
                            readonly property bool isFocused: modelData ? modelData.activated : false

                            scale: isSelected ? 1.04 : (cardHoverHandler.hovered ? 1.02 : 1.0)
                            opacity: isSelected ? 1.0 : (cardHoverHandler.hovered ? 0.96 : 0.88)

                            Behavior on scale {
                                SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.005 }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }

                            // Card Outline Glow
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -4
                                radius: 20
                                color: "transparent"
                                border.color: windowCard.isSelected ? Island.Theme.primary : (windowCard.isFocused ? "#5033ccff" : "transparent")
                                border.width: windowCard.isSelected ? 2.5 : 1.5
                                visible: windowCard.isSelected || windowCard.isFocused
                            }

                            // Main Card Body
                            Rectangle {
                                anchors.fill: parent
                                radius: 16
                                color: windowCard.isSelected ? "#2a152436" : "#1e111a24"
                                border.color: windowCard.isSelected ? Island.Theme.primary : Island.Theme.glassBorder
                                border.width: 1
                                clip: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 8

                                    // Top Header: App Icon, Title, and Quick Close (✕)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        // App Icon
                                        Rectangle {
                                            width: 30
                                            height: 30
                                            radius: 8
                                            color: "#20ffffff"
                                            border.color: "#30ffffff"
                                            border.width: 1

                                            Image {
                                                anchors.centerIn: parent
                                                width: 20
                                                height: 20
                                                sourceSize: Qt.size(20, 20)
                                                source: (windowCard.modelData && windowCard.modelData.appId) ? Quickshell.iconPath(windowCard.modelData.appId, "application-x-executable") : ""
                                                fillMode: Image.PreserveAspectFit
                                            }
                                        }

                                        // App Name & Window Title
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: (windowCard.modelData && windowCard.modelData.appName) ? windowCard.modelData.appName : "Application"
                                                color: windowCard.isSelected ? Island.Theme.primary : Island.Theme.foreground
                                                font.pixelSize: 12
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: (windowCard.modelData && windowCard.modelData.title) ? windowCard.modelData.title : ""
                                                color: Island.Theme.muted
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // Quick Close Button (✕)
                                        Rectangle {
                                            width: 24
                                            height: 24
                                            radius: 12
                                            color: closeCardHover.hovered ? Qt.rgba(0.9, 0.3, 0.3, 0.3) : "#15ffffff"
                                            border.color: closeCardHover.hovered ? Island.Theme.red : "#30ffffff"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                color: closeCardHover.hovered ? Island.Theme.red : Island.Theme.muted
                                                font.pixelSize: 10
                                                font.bold: true
                                            }

                                            HoverHandler { id: closeCardHover }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.closeWindow(windowCard.modelData.address);
                                                }
                                            }
                                        }
                                    }

                                    // Window Canvas Frame (Miniature Mockup)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 10
                                        color: "#0d000000"
                                        border.color: "#18ffffff"
                                        border.width: 1
                                        clip: true

                                        // Simulated Top Window Bar
                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 18
                                            color: "#15ffffff"

                                            Row {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4

                                                Rectangle { width: 5; height: 5; radius: 2.5; color: "#ff5f56" }
                                                Rectangle { width: 5; height: 5; radius: 2.5; color: "#ffbd2e" }
                                                Rectangle { width: 5; height: 5; radius: 2.5; color: "#27c93f" }
                                            }
                                        }

                                        // Centered Title Snippet
                                        Text {
                                            anchors.centerIn: parent
                                            width: parent.width - 24
                                            text: (windowCard.modelData && windowCard.modelData.title) ? windowCard.modelData.title : ""
                                            color: Island.Theme.foreground
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                            maximumLineCount: 3
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Bottom Footer Details
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            Layout.fillWidth: true
                                            text: windowCard.modelData ? (windowCard.modelData.geomWidth + "×" + windowCard.modelData.geomHeight) : ""
                                            color: Island.Theme.muted
                                            font.pixelSize: 9
                                            font.family: "monospace"
                                        }

                                        Rectangle {
                                            height: 18
                                            radius: 9
                                            color: windowCard.isSelected ? Island.Theme.primary : "#18ffffff"
                                            implicitWidth: selectPillText.implicitWidth + 12

                                            Text {
                                                id: selectPillText
                                                anchors.centerIn: parent
                                                text: windowCard.isSelected ? "FOCUS ↵" : "SELECT"
                                                color: windowCard.isSelected ? "#000000" : Island.Theme.muted
                                                font.pixelSize: 8
                                                font.bold: true
                                            }
                                        }
                                    }
                                }

                                HoverHandler {
                                    id: cardHoverHandler
                                    onHoveredChanged: {
                                        if (hovered) {
                                            root.selectedIndex = index;
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.focusWindow(windowCard.modelData.address);
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
