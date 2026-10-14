import QtQuick
import QtQuick.Layouts

import qs.src.bar.notch_widgets
import qs.src.services

// Passive menu-bar indicators. The clock stays on the far right, like macOS;
// there is no popup, hover target, or click interaction here.
RowLayout {
    id: indicators

    signal controlCenterClicked()
    signal notificationsClicked()
    required property var barWindow
    readonly property bool hasNotifications: notchWindow && notchWindow.notificationCount > 0
    property var notchWindow

    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    height: parent.height
    spacing: 16

    // Left-to-right order: LocalSend, volume, Wi-Fi, battery, bell, then the clock/date.
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
                // The control-center icon stays white; the menu-bar icon follows the theme.
                darkIcon: !Theme.dark
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

    Item {
        Layout.preferredWidth: 38
        Layout.preferredHeight: 26
        visible: indicators.hasNotifications

        RowLayout {
            anchors.centerIn: parent
            spacing: 4

            Image {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                source: Icon.getPath("bell" + Theme.topBarIconSuffix)
                sourceSize: Qt.size(16, 16)
            }

            Text {
                text: indicators.notchWindow.notificationCount > 99
                    ? "99+" : String(indicators.notchWindow.notificationCount)
                color: Theme.barText
                font.family: Config.fontFamily
                font.pixelSize: 11
                font.weight: 600
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: indicators.notificationsClicked()
        }
    }

    Clock {}

}
