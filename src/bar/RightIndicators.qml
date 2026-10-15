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
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: volumeHover.hovered ? Theme.indicatorHover : "transparent"
        }
        Volume {
            anchors.centerIn: parent
            source: {
                if (Audio.muted)
                    return Icon.getPath("volume/volume_muted_red" + Theme.topBarIconSuffix);
                if (Audio.volume < 0.33)
                    return Icon.getPath("volume/volume_low" + Theme.topBarIconSuffix);
                if (Audio.volume < 0.66)
                    return Icon.getPath("volume/volume_medium" + Theme.topBarIconSuffix);
                return Icon.getPath("volume/volume_high" + Theme.topBarIconSuffix);
            }
            rasterScale: 1.0
        }
        HoverHandler { id: volumeHover; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            onClicked: indicators.volumeClicked()
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
    }

    Clock {
        Layout.leftMargin: 10
    }
}
