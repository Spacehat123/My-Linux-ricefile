import QtQuick
import Quickshell.Widgets
import ".."
import "../components"

FocusScope {
    id: root

    function takeInitialFocus() {
        if (wallpaperGrid.count > 0 && wallpaperGrid.currentIndex < 0)
            wallpaperGrid.currentIndex = 0;
        wallpaperGrid.forceActiveFocus(Qt.TabFocusReason);
    }

    function moveSelection(offset) {
        if (wallpaperGrid.count === 0)
            return;
        wallpaperGrid.currentIndex = Math.max(0, Math.min(wallpaperGrid.count - 1, Math.max(0, wallpaperGrid.currentIndex) + offset));
        wallpaperGrid.positionViewAtIndex(wallpaperGrid.currentIndex, GridView.Contain);
    }

    Connections {
        target: ShellState
        function onPanelChanged() {
            if (ShellState.panel === "wallpaper")
                AppearanceState.refreshWallpapers();
        }
    }

    Connections {
        target: AppearanceState
        function onWallpapersChanged() {
            wallpaperGrid.currentIndex = AppearanceState.wallpapers.length > 0 ? 0 : -1;
        }
    }

    implicitWidth: 472
    implicitHeight: 382

    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            width: parent.width
            height: 30
            spacing: 8

            PanelNav {
                id: wallpaperNav
                anchors.verticalCenter: parent.verticalCenter
                title: "Wallpapers"
                panel: "wallpaper"
            }

            Item {
                width: parent.width - wallpaperNav.width - folderButton.width - liveFolderButton.width - parent.spacing * 3
                height: 1
            }

            FocusScope {
                id: liveFolderButton

                implicitWidth: liveFolderContent.implicitWidth + 14
                width: implicitWidth
                height: 30
                activeFocusOnTab: true
                Keys.onReturnPressed: AppearanceState.openLiveWallpaperFolder()
                Keys.onEnterPressed: AppearanceState.openLiveWallpaperFolder()
                Keys.onSpacePressed: AppearanceState.openLiveWallpaperFolder()
                Accessible.role: Accessible.Button
                Accessible.name: "Open live wallpaper folder"

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: liveFolderButton.activeFocus || liveFolderPointer.containsMouse ? Theme.bg1 : "transparent"
                }

                Row {
                    id: liveFolderContent

                    anchors.centerIn: parent
                    spacing: 5

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰿎"
                        color: Theme.primary
                        font.pixelSize: 12
                    }

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Live"
                        color: Theme.primary
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    id: liveFolderPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppearanceState.openLiveWallpaperFolder()
                }
            }

            FocusScope {
                id: folderButton

                implicitWidth: folderContent.implicitWidth + 16
                width: implicitWidth
                height: 30
                activeFocusOnTab: true
                Keys.onReturnPressed: AppearanceState.openWallpaperFolder()
                Keys.onEnterPressed: AppearanceState.openWallpaperFolder()
                Keys.onSpacePressed: AppearanceState.openWallpaperFolder()
                Accessible.role: Accessible.Button
                Accessible.name: "Open " + Theme.name + " wallpaper folder"

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: folderButton.activeFocus || folderPointer.containsMouse ? Theme.bg1 : "transparent"
                }

                Row {
                    id: folderContent

                    anchors.centerIn: parent
                    spacing: 6

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰉋"
                        color: Theme.primary
                        font.pixelSize: 12
                    }

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Theme.name
                        color: Theme.primary
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    id: folderPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppearanceState.openWallpaperFolder()
                }
            }
        }

        GridView {
            id: wallpaperGrid
            width: parent.width
            height: parent.height - 40
            cellWidth: width / 3
            cellHeight: 105
            clip: true
            model: AppearanceState.wallpapers
            keyNavigationWraps: true
            Keys.onLeftPressed: root.moveSelection(-1)
            Keys.onRightPressed: root.moveSelection(1)
            Keys.onUpPressed: root.moveSelection(-3)
            Keys.onDownPressed: root.moveSelection(3)
            Keys.onReturnPressed: if (currentItem) currentItem.activate()
            Keys.onEnterPressed: if (currentItem) currentItem.activate()
            Keys.onSpacePressed: if (currentItem) currentItem.activate()

            delegate: Item {
                id: wallpaperTile
                required property int index
                required property var modelData
                width: wallpaperGrid.cellWidth
                height: wallpaperGrid.cellHeight

                function activate() {
                    AppearanceState.setWallpaper(modelData.path);
                    ShellState.close();
                }

                ClippingRectangle {
                    id: previewContent

                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Theme.radiusSmall
                    color: "transparent"
                    contentUnderBorder: true
                    border.width: wallpaperGrid.currentIndex === index ? 2 : 1
                    border.color: wallpaperGrid.currentIndex === index ? Theme.primary : Theme.bg3

                    Image {
                        anchors.fill: parent
                        source: encodeURI("file://" + (wallpaperTile.modelData.thumbnail || wallpaperTile.modelData.path))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    Rectangle {
                        visible: !!wallpaperTile.modelData.isVideo
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 4
                        width: 22
                        height: 18
                        radius: 4
                        color: Qt.rgba(0, 0, 0, 0.7)

                        ShellText {
                            anchors.centerIn: parent
                            text: "󰿎"
                            font.pixelSize: 11
                            color: Theme.primary
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: wallpaperGrid.currentIndex = wallpaperTile.index
                    onClicked: wallpaperTile.activate()
                }
            }

            ShellText {
                anchors.centerIn: parent
                width: parent.width - 40
                visible: AppearanceState.wallpapers.length === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Theme.muted
                text: "No wallpapers in\n~/Pictures/Wallpapers/" + Theme.slug
            }
        }
    }
}
