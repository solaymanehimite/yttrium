import QtQuick
import QtQuick.Layouts

import qs.src.bar.notch_widgets
import qs.src.services

// Passive menu-bar indicators. The clock stays on the far right, like macOS;
// there is no popup, hover target, or click interaction here.
RowLayout {
    id: indicators

    signal controlCenterClicked()
    required property var barWindow

    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    height: parent.height
    spacing: 16

    // Left-to-right order: LocalSend, volume, Wi-Fi, battery, then the clock/date.
    LocalSendIndicator {
        hostWindow: indicators.barWindow
    }

    Item {
        Layout.preferredWidth: 100
        Layout.preferredHeight: 26
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: controlGroupMouse.containsMouse
                ? Theme.indicatorHover : "transparent"
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 16

            Volume {
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

            Network {
                rasterScale: 1.0
            }

            Battery {
                rasterScale: 1.0
            }
        }

        MouseArea {
            id: controlGroupMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: indicators.controlCenterClicked()
        }
    }

    Clock {}

}
