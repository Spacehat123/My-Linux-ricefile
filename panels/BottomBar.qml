import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../components"

PanelWindow {
    id: root

    property bool open: false
    visible: open || closeAnim.running

    // Injected desktop composition model
    property var desktopModel: null
    property var interactionModel: null
    property var desktopState: null

    signal takeScreenshot()

    // Dual-layer hover guard ensuring unbreakable hover continuity
    readonly property bool hovered: mouseArea.containsMouse || (workspaceNav && workspaceNav.hovered) || (screenshotBtn && screenshotBtn.hovered)

    Theme {
        id: theme
    }

    anchors {
        bottom: true
    }

    implicitWidth: Math.max(580, (workspaceNav ? workspaceNav.implicitWidth : 0) + 60 + theme.panelPadding * 2)
    implicitHeight: 64
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    WlrLayershell.namespace: "pranc-shell"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
        id: content
        anchors.fill: parent
        opacity: 0.0

        transform: Translate {
            id: contentTranslate
            y: 24
        }

        PanelSurface {
            anchors.fill: parent
            radius: theme.panelCornerRadius
            border.color: theme.panelBorder

            PanelContent {
                anchors.fill: parent
                orientation: Qt.Horizontal

                Row {
                    id: bottomBarRow
                    anchors.centerIn: parent
                    spacing: 12

                    // Reusable Workspace Navigator HUD
                    WorkspaceNavigator {
                        id: workspaceNav
                        desktopModel: root.desktopModel
                        interactionModel: root.interactionModel
                        desktopState: root.desktopState
                        screen: root.screen
                    }

                    // Elegant vertical divider
                    Rectangle {
                        width: 1
                        height: theme.workspaceItemHeight - 8
                        color: theme.panelBorder
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Taskbar Screenshot Button
                    Item {
                        id: screenshotBtn
                        width: theme.workspaceItemHeight
                        height: theme.workspaceItemHeight
                        anchors.verticalCenter: parent.verticalCenter

                        readonly property bool hovered: btnMouseArea.containsMouse

                        Rectangle {
                            id: btnBg
                            anchors.fill: parent
                            radius: theme.workspaceCornerRadius
                            color: screenshotBtn.hovered ? theme.workspaceFocusedBackground : theme.workspaceOccupiedBackground
                            border.color: screenshotBtn.hovered ? theme.workspaceFocusedBorder : theme.workspaceOccupiedBorder
                            border.width: 1

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }

                            // Camera Icon
                            Text {
                                anchors.centerIn: parent
                                text: "📷"
                                font.pixelSize: 14
                                color: screenshotBtn.hovered ? theme.workspaceFocusedText : theme.primaryTextColor
                                scale: btnMouseArea.pressed ? 0.9 : (screenshotBtn.hovered ? 1.08 : 1.0)

                                Behavior on scale {
                                    NumberAnimation { duration: 100 }
                                }
                            }
                        }

                        MouseArea {
                            id: btnMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                console.log("[pranc-shell] BottomBar: Screenshot button clicked");
                                root.takeScreenshot();
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onEntered: console.log("[pranc-shell] BottomBar mouse ENTERED")
        onExited: console.log("[pranc-shell] BottomBar mouse EXITED")
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: contentTranslate
            property: "y"
            to: 0
            duration: theme.animDurationOpen
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 1.0
            duration: theme.animDurationOpen
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: contentTranslate
            property: "y"
            to: 24
            duration: theme.animDurationClose
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 0.0
            duration: theme.animDurationClose
            easing.type: Easing.InCubic
        }
    }

    onOpenChanged: {
        if (open) {
            closeAnim.stop()
            openAnim.start()
        } else {
            openAnim.stop()
            closeAnim.start()
        }
    }
}