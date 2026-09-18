import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var hostWindow

    property var rootMenu: null
    property var menuStack: []
    property real menuX: 0
    property real menuY: 30

    readonly property bool isOpen: visible
    readonly property var currentMenu: menuStack.length > 0 ? menuStack[menuStack.length - 1] : null
    readonly property var currentItems: currentMenu && currentMenu.children ? currentMenu.children : []
    readonly property bool canGoBack: menuStack.length > 1
    readonly property int menuWidth: 268

    signal itemActivated(var item)

    screen: hostWindow ? hostWindow.screen : null
    visible: false
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
    WlrLayershell.namespace: "quickshell-native-appmenu"

    function openAt(anchorItem, menuItem) {
        if (!anchorItem || !menuItem)
            return;

        const globalPoint = anchorItem.mapToGlobal(0, 0);
        const screenX = root.screen ? root.screen.x : 0;
        const screenY = root.screen ? root.screen.y : 0;
        const localX = globalPoint.x - screenX;
        const localY = globalPoint.y - screenY;

        root.rootMenu = menuItem;
        root.menuStack = [menuItem];
        const availableWidth = root.hostWindow ? root.hostWindow.width : root.width;
        root.menuX = Math.max(8, Math.min(availableWidth - root.menuWidth - 8, localX));
        root.menuY = Math.max(30, localY + anchorItem.height + 3);
        root.visible = true;
        menuViewport.contentY = 0;
    }

    function enterSubmenu(item) {
        if (!item || !item.children || item.children.length === 0)
            return;

        root.menuStack = root.menuStack.concat([item]);
        menuViewport.contentY = 0;
    }

    function goBack() {
        if (root.menuStack.length <= 1)
            return;

        root.menuStack = root.menuStack.slice(0, root.menuStack.length - 1);
        menuViewport.contentY = 0;
    }

    function close() {
        root.visible = false;
        Qt.callLater(function() {
            if (!root.visible) {
                root.rootMenu = null;
                root.menuStack = [];
            }
        });
    }

    function contentHeight() {
        let value = 10 + (root.canGoBack ? 30 : 0);
        for (let i = 0; i < root.currentItems.length; i++) {
            const item = root.currentItems[i];
            if (item && item.visible !== false)
                value += item.type === "separator" ? 8 : 30;
        }
        return value;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: root.close()
    }

    Rectangle {
        id: menuBox
        visible: root.visible && root.currentMenu !== null
        x: root.menuX
        y: root.menuY
        width: root.menuWidth
        height: Math.min(Math.max(38, root.contentHeight()), root.height - y - 10)
        radius: 12
        color: "#f8f8fa"
        border.width: 1
        border.color: "#26000000"
        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: function(mouse) {
                mouse.accepted = true;
            }
        }

        Flickable {
            id: menuViewport
            anchors {
                fill: parent
                margins: 6
            }
            clip: true
            contentWidth: width
            contentHeight: menuColumn.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: menuColumn
                width: menuViewport.width

                Item {
                    id: backRow
                    visible: root.canGoBack
                    width: parent.width
                    height: visible ? 30 : 0

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: backMouse.containsMouse ? "#12000000" : "transparent"

                    }

                    Item {
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        width: 12
                        height: 12

                        Rectangle {
                            x: 3
                            y: 3
                            width: 6
                            height: 1.5
                            radius: 0.75
                            rotation: -45
                            color: "#99000000"
                        }

                        Rectangle {
                            x: 3
                            y: 7
                            width: 6
                            height: 1.5
                            radius: 0.75
                            rotation: 45
                            color: "#99000000"
                        }
                    }

                    Text {
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: 32
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: String(root.currentMenu ? root.currentMenu.label : "Back").replace(/_/g, "")
                        color: "#d9000000"
                        elide: Text.ElideRight
                        font.family: "Google Sans Flex"
                        font.pixelSize: 13
                        font.weight: 600
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goBack()
                    }
                }

                Rectangle {
                    visible: root.canGoBack
                    width: parent.width - 18
                    height: visible ? 1 : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#1f000000"
                }

                Repeater {
                    model: root.currentItems

                    delegate: AppMenuRow {
                        onClicked: function(item) {
                            root.close();
                            root.itemActivated(item);
                        }
                        onSubmenuRequested: function(item) {
                            root.enterSubmenu(item);
                        }
                    }
                }
            }
        }
    }
}
