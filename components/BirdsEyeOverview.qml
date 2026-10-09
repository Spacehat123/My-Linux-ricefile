import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
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

    // Current workspace id
    readonly property int activeWorkspaceId: {
        if (workspaceModel && workspaceModel.workspaceManager) {
            return workspaceModel.workspaceManager.focusedWorkspaceId || 1;
        }
        return 1;
    }

    // Windows on the active workspace sorted left-to-right along the tape
    readonly property var currentSurfaces: {
        if (!surfaceModel) return [];
        const list = surfaceModel.getSurfacesForWorkspace(activeWorkspaceId);
        if (!list || list.length === 0) return [];
        return list.slice().sort((a, b) => {
            const ax = (a && a.geomX !== undefined) ? a.geomX : 0;
            const bx = (b && b.geomX !== undefined) ? b.geomX : 0;
            return ax - bx;
        });
    }

    property int selectedIndex: 0

    onOpenChanged: {
        if (open) {
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
            root.forceActiveFocus();
        }
    }

    function focusWindow(addr) {
        if (!addr) return;
        const cleanAddr = addr.toString().replace(/^0x/i, "");
        if (compositorActionLayer) {
            compositorActionLayer.focusSurface(cleanAddr);
        }
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:0x" + cleanAddr + "\" })"]);
        root.closeRequested();
    }

    // =========================================================================
    // Backdrop Tint & Blur
    // =========================================================================
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#d8090d16"
        opacity: root.open ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                id: closeAnim
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    // =========================================================================
    // Keyboard Handler
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
    }

    // =========================================================================
    // Main Viewport Content
    // =========================================================================
    Item {
        id: mainContent
        anchors.fill: parent
        opacity: root.open ? 1.0 : 0.0
        scale: root.open ? 1.0 : 0.94

        Behavior on opacity {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            SpringAnimation { spring: 3.5; damping: 0.32; epsilon: 0.005 }
        }

        // ---------------------------------------------------------------------
        // Top Header Pill (Workspace info + controls)
        // ---------------------------------------------------------------------
        Rectangle {
            id: headerPill
            anchors.top: parent.top
            anchors.topMargin: 36
            anchors.horizontalCenter: parent.horizontalCenter
            height: 52
            radius: 26
            color: Island.Theme.glassBackground
            border.color: Island.Theme.glassBorder
            border.width: 1
            implicitWidth: headerRow.implicitWidth + 40

            RowLayout {
                id: headerRow
                anchors.centerIn: parent
                spacing: 16

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25)
                    border.color: Island.Theme.primary
                    border.width: 1.5

                    Text {
                        anchors.centerIn: parent
                        text: "🦅"
                        font.pixelSize: 16
                    }
                }

                ColumnLayout {
                    spacing: 2

                    RowLayout {
                        spacing: 8
                        Text {
                            text: "BIRD'S-EYE VIEW"
                            color: Island.Theme.foreground
                            font.pixelSize: 13
                            font.bold: true
                            font.letterSpacing: 1.2
                        }
                        Rectangle {
                            height: 16
                            radius: 8
                            color: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.25)
                            implicitWidth: wsText.implicitWidth + 12
                            Text {
                                id: wsText
                                anchors.centerIn: parent
                                text: "WORKSPACE " + root.activeWorkspaceId
                                color: Island.Theme.primary
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }
                    }

                    Text {
                        text: root.currentSurfaces.length + " App" + (root.currentSurfaces.length === 1 ? "" : "s") + " on Extended Horizontal Tape • [← / →] Navigate • [Enter / Click] Focus • [Super + R] Close"
                        color: Island.Theme.muted
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeHover.hovered ? "#35ffffff" : "#1affffff"
                    border.color: Island.Theme.glassBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Island.Theme.foreground
                        font.pixelSize: 12
                    }

                    HoverHandler { id: closeHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // Empty State (if no windows on workspace)
        // ---------------------------------------------------------------------
        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 160
            radius: 20
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
                    text: "No Windows on Workspace " + root.activeWorkspaceId
                    color: Island.Theme.foreground
                    font.pixelSize: 15
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Open applications to scroll through them"
                    color: Island.Theme.muted
                    font.pixelSize: 12
                }
            }
        }

        // ---------------------------------------------------------------------
        // Horizontal Ribbon of Windows (Matches Xiaomi Fold 0:16 Pinch-Overview)
        // ---------------------------------------------------------------------
        Item {
            id: ribbonContainer
            anchors.centerIn: parent
            width: Math.min(root.screenW * 0.94, cardsRow.implicitWidth)
            height: 380
            visible: root.currentSurfaces.length > 0

            // Auto-calculate card size based on number of windows to fit on screen
            readonly property int numCards: Math.max(1, root.currentSurfaces.length)
            readonly property real availableW: (root.screenW * 0.92) - ((numCards - 1) * 24)
            readonly property real targetCardW: Math.min(380, Math.max(220, Math.floor(availableW / numCards)))
            readonly property real targetCardH: Math.round(targetCardW * 0.62)

            Row {
                id: cardsRow
                anchors.centerIn: parent
                spacing: 24

                Repeater {
                    model: root.currentSurfaces

                    delegate: Item {
                        id: cardDelegate
                        required property var modelData
                        required property int index

                        width: ribbonContainer.targetCardW
                        height: ribbonContainer.targetCardH + 50 // Extra height for info bar

                        readonly property bool isSelected: root.selectedIndex === index
                        readonly property bool isFocused: modelData ? modelData.activated : false

                        // Check position along the tape
                        readonly property real gx: modelData ? (modelData.geomX || 0) : 0
                        readonly property real gw: modelData ? (modelData.geomWidth || 1920) : 1920
                        readonly property bool isOnScreen: (gx >= -40) && (gx + gw <= root.screenW + 40)
                        readonly property bool isTapeLeft: (gx + gw < 80)
                        readonly property bool isTapeRight: (gx > root.screenW - 80)

                        // Hover & Spring lift animation
                        scale: isSelected ? 1.05 : (cardHover.hovered ? 1.02 : 1.0)
                        opacity: isSelected ? 1.0 : (isOnScreen ? 0.92 : 0.72)

                        Behavior on scale {
                            SpringAnimation { spring: 4.5; damping: 0.35; epsilon: 0.005 }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 160 }
                        }

                        // Card Outline and Glow
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: 20
                            color: "transparent"
                            border.color: cardDelegate.isSelected ? Island.Theme.primary : (cardDelegate.isFocused ? "#5033ccff" : "transparent")
                            border.width: cardDelegate.isSelected ? 2.5 : 1.5
                            visible: cardDelegate.isSelected || cardDelegate.isFocused
                        }

                        // Main Window Card Body
                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: cardDelegate.isSelected ? "#24131f30" : "#1a0f1622"
                            border.color: cardDelegate.isSelected ? Island.Theme.primary : Island.Theme.glassBorder
                            border.width: 1
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                // Top Header inside card
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    // App Icon
                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 8
                                        color: "#20ffffff"
                                        border.color: "#30ffffff"
                                        border.width: 1

                                        Image {
                                            anchors.centerIn: parent
                                            width: 20
                                            height: 20
                                            sourceSize: Qt.size(20, 20)
                                            source: (cardDelegate.modelData && cardDelegate.modelData.appId) ? Quickshell.iconPath(cardDelegate.modelData.appId, "application-x-executable") : ""
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }

                                    // App Name
                                    Text {
                                        Layout.fillWidth: true
                                        text: (cardDelegate.modelData && cardDelegate.modelData.appName) ? cardDelegate.modelData.appName : "App"
                                        color: cardDelegate.isSelected ? Island.Theme.primary : Island.Theme.foreground
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    // Tape Position Badge
                                    Rectangle {
                                        height: 18
                                        radius: 9
                                        color: cardDelegate.isOnScreen ? "#2000ff99" : (cardDelegate.isTapeLeft ? "#2033ccff" : "#20ffaa00")
                                        border.color: cardDelegate.isOnScreen ? "#8000ff99" : (cardDelegate.isTapeLeft ? "#8033ccff" : "#80ffaa00")
                                        border.width: 1
                                        implicitWidth: tapeText.implicitWidth + 12

                                        Text {
                                            id: tapeText
                                            anchors.centerIn: parent
                                            text: cardDelegate.isOnScreen ? "● ON SCREEN" : (cardDelegate.isTapeLeft ? "◀ LEFT" : "RIGHT ▶")
                                            color: cardDelegate.isOnScreen ? "#00ff99" : (cardDelegate.isTapeLeft ? "#33ccff" : "#ffaa00")
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                    }
                                }

                                // Stylized Window Miniature Canvas Mockup
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 10
                                    color: "#0d000000"
                                    border.color: "#18ffffff"
                                    border.width: 1
                                    clip: true

                                    // Simulated App Header
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

                                    // Window Title preview
                                    Text {
                                        anchors.centerIn: parent
                                        width: parent.width - 24
                                        text: (cardDelegate.modelData && cardDelegate.modelData.title) ? cardDelegate.modelData.title : ""
                                        color: Island.Theme.foreground
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }
                                }

                                // Bottom Details Footer
                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Col " + (index + 1) + " • " + (cardDelegate.modelData ? (cardDelegate.modelData.geomWidth + "×" + cardDelegate.modelData.geomHeight) : "")
                                        color: Island.Theme.muted
                                        font.pixelSize: 10
                                        font.family: "monospace"
                                    }

                                    Rectangle {
                                        height: 18
                                        radius: 9
                                        color: cardDelegate.isSelected ? Island.Theme.primary : "#18ffffff"
                                        implicitWidth: clickHintText.implicitWidth + 12

                                        Text {
                                            id: clickHintText
                                            anchors.centerIn: parent
                                            text: cardDelegate.isSelected ? "SELECT ↵" : "CLICK"
                                            color: cardDelegate.isSelected ? "#000000" : Island.Theme.muted
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                    }
                                }
                            }

                            HoverHandler {
                                id: cardHover
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
                                    root.focusWindow(cardDelegate.modelData.address);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
