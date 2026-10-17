import QtQuick
import QtQuick.Layouts

import qs.src.bar.notch_widgets
import qs.src.services

// Small, independent controls keep the bar quiet and make each action easy to target.
RowLayout {
    id: indicators

    signal volumeClicked()
    required property var barWindow

    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    height: parent.height
    spacing: Config.space10

    LocalSendIndicator {
        hostWindow: indicators.barWindow
    }

    Item {
        id: volumeControl
        property bool dragging: false
        property bool moved: false
        property real pressGlobalX: 0
        property real pressVolume: 0
        readonly property int collapsedWidth: 28
        readonly property int expandedWidth: 84
        readonly property int iconSlotWidth: 34
        readonly property string volumeIconName: {
            if (Audio.muted)
                return "volume/volume_muted_red";
            if (Audio.volume < 0.33)
                return "volume/volume_low";
            if (Audio.volume < 0.66)
                return "volume/volume_medium";
            return "volume/volume_high";
        }

        width: collapsedWidth
        height: 28
        Layout.preferredWidth: dragging ? expandedWidth : collapsedWidth
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter
        Behavior on Layout.preferredWidth {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: volumeControl.dragging ? "transparent"
                : (volumeHover.hovered ? Theme.indicatorHover : "transparent")
        }

        Item {
            id: sliderVisual
            x: volumeControl.dragging ? 3 : 0
            y: volumeControl.dragging ? -1 : 0
            width: volumeControl.width
            height: 28
            opacity: volumeControl.dragging ? 1 : 0
            transform: Scale {
                origin.x: sliderVisual.width / 2
                origin.y: sliderVisual.height / 2
                yScale: volumeControl.dragging ? 0.84 : 1
            }
            Behavior on x {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                height: 28
                radius: 14
                color: Theme.indicatorHover

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Audio.volume))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.barText
                }
            }
        }

        Volume {
            z: 2
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            source: Icon.getPath(volumeControl.volumeIconName
                + Theme.topBarIconSuffix)
            rasterScale: 1.0
        }

        Item {
            id: filledIconMask
            z: 3
            x: volumeControl.width - 22
            y: (volumeControl.height - height) / 2
            width: volumeControl.dragging ? Math.max(0, Math.min(16,
                volumeControl.width * Audio.volume
                    - (volumeControl.width - 22))) : 0
            height: 16
            clip: true

            Volume {
                source: Icon.getPath(volumeControl.volumeIconName + "_black")
                rasterScale: 1.0
            }
        }

        HoverHandler { id: volumeHover; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            onPressed: function(mouse) {
                volumeControl.dragging = true;
                volumeControl.moved = false;
                volumeControl.pressVolume = Audio.volume;
                volumeControl.pressGlobalX = mapToItem(null, mouse.x, mouse.y).x;
            }
            onPositionChanged: function(mouse) {
                if (!pressed)
                    return;
                const globalX = mapToItem(null, mouse.x, mouse.y).x;
                const delta = globalX - volumeControl.pressGlobalX;
                if (Math.abs(delta) < 2)
                    return;
                volumeControl.moved = true;
                Audio.setVolume(volumeControl.pressVolume
                    + delta / (volumeControl.expandedWidth - 24));
            }
            onReleased: {
                volumeControl.dragging = false;
                if (!volumeControl.moved)
                    indicators.volumeClicked();
            }
            onCanceled: volumeControl.dragging = false
        }
    }

    Item {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: networkHover.hovered ? Theme.indicatorHover : "transparent"
        }
        Network {
            anchors.centerIn: parent
            rasterScale: 1.0
            darkIcon: !Theme.dark
        }
        HoverHandler { id: networkHover; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
        }
    }

    Item {
        visible: PowerBattery.available
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: batteryHover.hovered ? Theme.indicatorHover : "transparent"
        }
        Battery {
            anchors.centerIn: parent
            scale: 0.73
            rasterScale: 1.0
        }
        HoverHandler { id: batteryHover; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
        }
    }

    Clock {
        Layout.leftMargin: 10
    }
}
