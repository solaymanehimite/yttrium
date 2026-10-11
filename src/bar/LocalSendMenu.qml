import Quickshell
import QtQuick
import QtQuick.Controls
import Quickshell.Wayland
import qs.src.services

PanelWindow {
    id: menu

    required property var controller
    required property var hostWindow
    required property var anchorItem

    readonly property int menuWidth: Math.round(280 * Config.uiScale)
    readonly property int rowHeight: Math.round(36 * Config.uiScale)
    property real menuX: 8

    screen: hostWindow ? hostWindow.screen : null
    visible: controller.menuOpen
    color: "transparent"

    BackgroundEffect.blurRegion: Region {
        item: menuBox
        radius: 12
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-localsend-menu"

    function anchorX() {
        if (!anchorItem)
            return 0;
        const point = menu.anchorItem.mapToGlobal(0, 0);
        return point.x - (screen ? screen.x : 0);
    }

    function updatePosition() {
        if (!anchorItem || !hostWindow)
            return;
        const point = menu.anchorItem.mapToGlobal(0, 0);
        const screenX = screen ? screen.x : 0;
        menuX = Math.max(8, Math.min(hostWindow.width - menuWidth - 8,
            point.x - screenX - menuWidth + anchorItem.width));
    }

    onVisibleChanged: {
        if (visible)
            updatePosition();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: menu.controller.closeMenu()
    }

    // Keep the icon a drop target while this menu is open. The menu sits in a
    // separate overlay surface, above the bar's own DropArea.
    DropArea {
        x: menu.anchorX()
        y: 0
        width: anchorItem ? anchorItem.width : 0
        height: Math.round(30 * Config.uiScale)
        enabled: controller.running
        onEntered: controller.draggingOver = true
        onExited: controller.draggingOver = false
        onDropped: function(drop) {
            controller.draggingOver = false;
            controller.addDrop(drop);
        }
    }

    Rectangle {
        id: menuBox
        y: 34
        property real contentHeight: 0
        x: menu.menuX
        width: menu.menuWidth
        height: Math.max(0, Math.min(menu.height - y - 10, contentHeight + 12))
        radius: 12
        color: Theme.menuBackground
        border.width: 0
        border.color: Theme.menuBorder
        clip: true
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: function(mouse) { mouse.accepted = true; }
        }

        DropArea {
            anchors.fill: parent
            onEntered: controller.draggingOver = true
            onExited: controller.draggingOver = false
            onDropped: function(drop) {
                controller.draggingOver = false;
                controller.addDrop(drop);
            }
        }

        Column {
            id: contentColumn
            Component.onCompleted: menuBox.contentHeight = implicitHeight
            onImplicitHeightChanged: menuBox.contentHeight = implicitHeight
            anchors {
                fill: parent
                margins: 6
            }
            spacing: 2

            Item {
                width: parent.width
                height: 34

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    text: controller.pendingCount > 0
                        ? "Send " + controller.pendingCount + " item"
                            + (controller.pendingCount === 1 ? "" : "s")
                        : "LocalSend"
                    color: Theme.menuText
                    font.family: Config.fontFamily
                    font.pixelSize: Math.round(15 * Config.uiScale)
                    font.weight: 600
                }

                Text {
                    anchors {
                        right: parent.right
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    text: controller.sending ? "Sending…" : "Devices"
                    color: Theme.menuText
                    font.family: Config.fontFamily
                    font.pixelSize: Math.round(12 * Config.uiScale)
                }
            }

            Item {
                visible: controller.pendingCount === 0
                width: parent.width
                height: visible ? 32 : 0

                Text {
                    anchors.centerIn: parent
                    text: "Drop files or text here"
                    color: Theme.menuText
                    font.family: Config.fontFamily
                    font.pixelSize: Math.round(13 * Config.uiScale)
                }
            }

            Item {
                visible: controller.pendingCount > 0
                    && controller.devices.length === 0
                width: parent.width
                height: visible ? 36 : 0

                Text {
                    anchors.centerIn: parent
                    text: controller.discovering
                        ? "Looking for devices…"
                        : (controller.error || "No devices found")
                    color: controller.error ? "#c43d4b" : Theme.menuMutedText
                    font.family: Config.fontFamily
                    font.pixelSize: Math.round(13 * Config.uiScale)
                }
            }

            Repeater {
                model: controller.devices

                delegate: Item {
                    required property var modelData
                    width: contentColumn.width
                    height: menu.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: deviceMouse.containsMouse ? Theme.menuHover : "transparent"
                    }

                    Text {
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: 10
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: String(modelData.alias || "Unknown device")
                        color: Theme.menuText
                        elide: Text.ElideRight
                        font.family: Config.fontFamily
                        font.pixelSize: Math.round(14 * Config.uiScale)
                    }

                    MouseArea {
                        id: deviceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !controller.sending
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: controller.sendTo(modelData)
                    }
                }
            }

            Item {
                visible: controller.pendingCount > 0
                width: contentColumn.width
                height: visible ? 34 : 0

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: clearMouse.containsMouse ? Theme.menuHover : "transparent"
                }

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    text: "Clear tray"
                    color: Theme.menuText
                    font.family: Config.fontFamily
                    font.pixelSize: Math.round(13 * Config.uiScale)
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controller.clearPending()
                }
            }
        }
    }
}
