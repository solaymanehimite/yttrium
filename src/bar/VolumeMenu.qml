import Quickshell
import QtQuick
import QtQuick.Controls
import Quickshell.Wayland
import qs.src.services

PanelWindow {
    id: menu

    required property var hostWindow
    required property var anchorItem
    property bool open: false
    signal dismissed()

    readonly property int menuWidth: Math.round(280 * Config.uiScale)
    readonly property int rowHeight: Math.round(42 * Config.uiScale)
    property real menuX: 8
    property real menuY: 0

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
    WlrLayershell.namespace: "quickshell-volume-menu"

    component SliderRow: Item {
        required property string label
        required property real level
        required property var setLevel
        property string iconSource: Icon.getPath("volume/volume_medium"
            + Theme.topBarIconSuffix)

        width: contentColumn.width
        height: menu.rowHeight

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: rowHover.hovered ? Theme.menuHover : "transparent"
        }

        HoverHandler { id: rowHover }

        Image {
            anchors {
                left: parent.left
                leftMargin: 10
                verticalCenter: parent.verticalCenter
            }
            width: 16
            height: 16
            source: iconSource
            sourceSize: Qt.size(16, 16)
            smooth: true
        }

        Text {
            anchors {
                left: parent.left
                leftMargin: 34
                right: parent.right
                rightMargin: 10
                top: parent.top
                topMargin: 3
            }
            text: label
            color: Theme.menuText
            font.family: Config.fontFamily
            font.pixelSize: Math.round(11 * Config.uiScale)
            elide: Text.ElideRight
        }

        Rectangle {
            id: rowTrack
            anchors {
                left: parent.left
                leftMargin: 34
                right: parent.right
                rightMargin: 10
                bottom: parent.bottom
                bottomMargin: 5
            }
            height: 8
            radius: 4
            color: Theme.indicatorHover
            clip: true

            Rectangle {
                x: 1
                y: 1
                width: (parent.width - 2) * Math.max(0, Math.min(1, level))
                height: parent.height - 2
                radius: parent.radius
                color: Theme.barText
            }

            MouseArea {
                anchors.fill: parent
                onPressed: function(mouse) {
                    setLevel(Math.max(0, Math.min(1, mouse.x / width)));
                }
                onPositionChanged: function(mouse) {
                    if (pressed)
                        setLevel(Math.max(0, Math.min(1, mouse.x / width)));
                }
            }
        }
    }

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
        height: Math.min(menu.height - y - 10,
            contentColumn.implicitHeight + 12)
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

        Column {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 6
            spacing: Config.space2

            SliderRow {
                label: "Output"
                level: Audio.volume
                iconSource: Icon.getPath(Audio.muted
                    ? "volume/volume_muted_red" + Theme.topBarIconSuffix
                    : "volume/volume_medium" + Theme.topBarIconSuffix)
                setLevel: function(value) { Audio.setVolume(value); }
            }

            Repeater {
                model: Audio.appStreams

                SliderRow {
                    required property var modelData
                    label: String(modelData.properties["application.name"]
                        || modelData.description || modelData.name || "Application")
                    level: modelData.audio.volume
                    iconSource: Icon.getPath("volume/volume_medium"
                        + Theme.topBarIconSuffix)
                    setLevel: function(value) {
                        Audio.setStreamVolume(modelData, value);
                    }
                }
            }
        }
    }
}
