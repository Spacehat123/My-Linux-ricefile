import QtQuick
import "../theme"

Item {
    id: root

    // =========================================================================
    // Upstream Injected Model & Screen Context
    // =========================================================================
    property var desktopModel: null
    property var interactionModel: null
    property var screen: null
    property bool filterCurrentMonitor: false

    Theme {
        id: theme
    }

    // Passive root hover boundary (does not absorb or block pointer events)
    HoverHandler {
        id: rootHoverHandler
    }

    readonly property bool hovered: rootHoverHandler.hovered
    readonly property int workspaceCount: desktopModel ? desktopModel.workspaceCount : 0
    readonly property int focusedWorkspaceId: desktopModel ? desktopModel.focusedWorkspaceId : -1

    implicitHeight: theme.workspaceItemHeight
    implicitWidth: layoutRow.implicitWidth
    width: implicitWidth
    height: implicitHeight

    Row {
        id: layoutRow
        anchors.centerIn: parent
        spacing: theme.workspaceSpacing

        Repeater {
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

                readonly property bool isFocused: modelData ? Boolean(modelData.focused) : false
                readonly property bool isOccupied: modelData ? Boolean(modelData.occupied) : false
                readonly property bool isUrgent: modelData ? Boolean(modelData.urgent) : false
                readonly property bool isOtherMonitor: Boolean(
                    root.screen && modelData && modelData.monitorName && modelData.monitorName !== root.screen.name
                )

                // Non-blocking passive hover handler with interactive cursor
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

                    // Dynamic color binding from Theme tokens
                    color: {
                        if (pillDelegate.isUrgent) return theme.workspaceUrgentBackground;
                        if (pillDelegate.isFocused) return theme.workspaceFocusedBackground;
                        if (pillDelegate.isHovered) return theme.workspaceHoverBackground;
                        if (pillDelegate.isOccupied) return theme.workspaceOccupiedBackground;
                        return theme.workspaceEmptyBackground;
                    }

                    // Dynamic border binding from Theme tokens
                    border.width: pillDelegate.isFocused ? 1.5 : 1
                    border.color: {
                        if (pillDelegate.isUrgent) return theme.workspaceUrgentBorder;
                        if (pillDelegate.isFocused) return theme.workspaceFocusedBorder;
                        if (pillDelegate.isHovered) return theme.workspaceHoverBorder;
                        if (pillDelegate.isOccupied) return theme.workspaceOccupiedBorder;
                        return theme.workspaceEmptyBorder;
                    }

                    // Multi-monitor attenuation (softened if on another screen and not active)
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

                    // Content: Monospace ID/Name + Activity Slivers + Multi-Monitor pip
                    Row {
                        id: pillContent
                        anchors.centerIn: parent
                        spacing: 4

                        // Interactive Navigation Cue (revealed on hover when not already focused)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "monospace"
                            color: theme.workspaceHoverBracketColor
                            visible: pillDelegate.isHovered && !pillDelegate.isFocused
                        }

                        // Workspace Identifier
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

                            // Overflow indicator if > 3 surfaces
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: pipRow.hasOverflow
                                text: "+"
                                font.pixelSize: 9
                                font.bold: true
                                color: pillDelegate.isFocused ? theme.workspaceFocusedPip : theme.workspaceOccupiedPip
                            }
                        }

                        // Secondary monitor marker
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

                // Interactive tap handler for workspace switching
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
