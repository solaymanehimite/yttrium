import Quickshell
import QtQuick
import QtQuick.Controls
import Quickshell.Wayland

PanelWindow {
    id: menu

    required property var controller
    required property var hostWindow
    required property var anchorItem

    readonly property int menuWidth: 280
    readonly property int rowHeight: 36
    property real menuX: 8

    screen: hostWindow ? hostWindow.screen : null
    visible: controller.menuOpen
    color: "transparent"

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
        const point = anchorItem.mapToGlobal(0, 0);
        return point.x - (screen ? screen.x : 0);
    }

    function updatePosition() {
        if (!anchorItem || !hostWindow)
            return;
        const point = anchorItem.mapToGlobal(0, 0);
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
        height: 30
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
        x: menu.menuX
        y: 34
        width: menu.menuWidth
        height: Math.min(menu.height - y - 10, contentColumn.implicitHeight + 12)
        radius: 12
        color: "#e60b1218"
        border.width: 1
        border.color: "#33485a"
        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse.accepted = true
        }

        Column {
            id: contentColumn
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
                    text: controller.pendingFiles.length > 0
                        ? "Send " + controller.pendingFiles.length + " file"
                            + (controller.pendingFiles.length === 1 ? "" : "s")
                        : "LocalSend"
                    color: "white"
                    font.pixelSize: 15
                    font.weight: 600
                }

                Text {
                    anchors {
                        right: parent.right
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    text: controller.sending ? "Sending…" : "Devices"
                    color: "#91a0ad"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#26313b"
            }

            Item {
                visible: controller.pendingFiles.length === 0
                width: parent.width
                height: visible ? 32 : 0

                Text {
                    anchors.centerIn: parent
                    text: "Drop files on the icon first"
                    color: "#91a0ad"
                    font.pixelSize: 13
                }
            }

            Item {
                visible: controller.pendingFiles.length > 0
                    && controller.devices.length === 0
                width: parent.width
                height: visible ? 36 : 0

                Text {
                    anchors.centerIn: parent
                    text: controller.discovering
                        ? "Looking for devices…"
                        : (controller.error || "No devices found")
                    color: controller.error ? "#ff9d9d" : "#91a0ad"
                    font.pixelSize: 13
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
                        color: deviceMouse.containsMouse ? "#263c4c" : "transparent"
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
                        color: "white"
                        elide: Text.ElideRight
                        font.pixelSize: 14
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
        }
    }
}
