import Quickshell
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Wayland
import qs.src.services

PanelWindow {
    id: menu

    required property var hostWindow
    required property var anchorItem
    property bool open: false
    signal dismissed()
    property real menuX: 8
    property real menuY: 0
    readonly property int menuWidth: Math.round(240 * Config.uiScale)
    readonly property int menuHeight: Math.round(122 * Config.uiScale)
    readonly property bool nightLightOn: nightLightProcess.running

    screen: hostWindow ? hostWindow.screen : null
    visible: open
    color: "transparent"

    BackgroundEffect.blurRegion: Region {
        item: menuBox
        radius: 12
    }

    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-brightness-menu"

    Process { id: nightLightProcess; command: ["wlsunset"] }

    function updatePosition() {
        if (!anchorItem || !hostWindow)
            return;
        const point = anchorItem.mapToGlobal(0, 0);
        const screenX = screen ? screen.x : 0;
        const screenY = screen ? screen.y : 0;
        const centerX = point.x - screenX + anchorItem.width / 2;
        menuX = Math.max(8, Math.min(hostWindow.width - menuWidth - 8,
            centerX - menuWidth / 2));
        menuY = point.y - screenY + anchorItem.height + 12;
    }

    onVisibleChanged: if (visible) updatePosition()

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: menu.dismissed()
    }

    Rectangle {
        id: menuBox
        x: menu.menuX
        y: menu.menuY
        width: menu.menuWidth
        height: menu.menuHeight
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

        Image {
            anchors {
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: -35
            }
            width: 18
            height: 18
            source: Icon.getPath("sun" + Theme.topBarIconSuffix)
            sourceSize: Qt.size(18, 18)
        }

        Rectangle {
            id: brightnessTrack
            x: 48
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 18
            height: 18
            radius: 9
            color: Theme.indicatorHover
            clip: true

            Rectangle {
                x: 1
                y: 1
                width: (parent.width - 2) * Math.max(0, Math.min(1,
                    Brightness.brightness))
                height: parent.height - 2
                radius: parent.radius
                color: Theme.barText
            }

            MouseArea {
                anchors.fill: parent
                onPressed: function(mouse) {
                    Brightness.setBrightness(Math.max(0, Math.min(1,
                        mouse.x / width)));
                }
                onPositionChanged: function(mouse) {
                    if (pressed)
                        Brightness.setBrightness(Math.max(0, Math.min(1,
                            mouse.x / width)));
                }
            }
        }

        Rectangle {
            x: 10
            y: 54
            width: parent.width - 20
            height: 1
            color: Theme.menuBorder
        }

        Rectangle {
            x: 10
            y: 62
            width: parent.width - 20
            height: 24
            radius: 7
            color: nightLightMouse.containsMouse ? Theme.menuHover : "transparent"

            Image {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                source: Icon.getPath("night-light" + Theme.topBarIconSuffix)
                sourceSize: Qt.size(16, 16)
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.verticalCenter: parent.verticalCenter
                text: "Night light"
                color: Theme.menuText
                font.family: Config.fontFamily
                font.pixelSize: Math.round(12 * Config.uiScale)
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: nightLightOn ? "On" : "Off"
                color: Theme.menuMutedText
                font.family: Config.fontFamily
                font.pixelSize: Math.round(11 * Config.uiScale)
            }
            MouseArea {
                id: nightLightMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: nightLightProcess.running = !nightLightProcess.running
            }
        }

        Rectangle {
            x: 10
            y: 90
            width: parent.width - 20
            height: 24
            radius: 7
            color: themeMouse.containsMouse ? Theme.menuHover : "transparent"

            Image {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                source: Icon.getPath("theme" + Theme.topBarIconSuffix)
                sourceSize: Qt.size(16, 16)
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.dark ? "Dark mode" : "Light mode"
                color: Theme.menuText
                font.family: Config.fontFamily
                font.pixelSize: Math.round(12 * Config.uiScale)
            }
            MouseArea {
                id: themeMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Theme.toggle()
            }
        }
    }
}
