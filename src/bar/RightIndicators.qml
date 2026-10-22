import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

import qs.src.bar.notch_widgets
import qs.src.services

// Persistent controls sit as a compact cluster at the right edge of the bar.
RowLayout {
    id: indicators

    required property var barWindow

    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    height: parent.height
    spacing: Config.space8

    function volumeIconName() {
        if (Audio.muted)
            return "volume/volume_muted_red";
        if (Audio.volume < 0.33)
            return "volume/volume_low";
        if (Audio.volume < 0.66)
            return "volume/volume_medium";
        return "volume/volume_high";
    }

    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property string bluetoothIconName: bluetoothAdapter && bluetoothAdapter.enabled
        ? "bluetooth/on" : "bluetooth/off"

    // LocalSend remains independent because it owns its own transfer menu.
    LocalSendIndicator {
        hostWindow: indicators.barWindow
    }

    Item {
        id: controlGroup
        width: 118
        height: 28
        Layout.preferredWidth: width
        Layout.preferredHeight: height
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: groupHover.hovered ? Theme.indicatorHover : "transparent"
        }

        Row {
            anchors.centerIn: parent
            spacing: Config.space24

            Volume {
                anchors.verticalCenter: parent.verticalCenter
                source: Icon.getPath(indicators.volumeIconName()
                    + Theme.topBarIconSuffix)
                rasterScale: 1.0
            }

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                source: Icon.getPath(indicators.bluetoothIconName
                    + Theme.topBarIconSuffix)
                sourceSize: Qt.size(15, 15)
                smooth: true
            }

            Network {
                anchors.verticalCenter: parent.verticalCenter
                rasterScale: 1.0
                darkIcon: !Theme.dark
            }
        }

        HoverHandler {
            id: groupHover
            cursorShape: Qt.PointingHandCursor
        }

    }
}
