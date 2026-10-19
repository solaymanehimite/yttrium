import QtQuick
import QtQuick.Layouts

import qs.src.bar.notch_widgets
import qs.src.services

// Small, independent controls keep the bar quiet and make each action easy to target.
RowLayout {
    id: indicators

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
        property bool osdVisible: false
        property bool menuOpen: false
        property real animatedWidth: collapsedWidth
        property real displayedVolume: Audio.volume
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

        width: animatedWidth
        height: 28
        Layout.preferredWidth: animatedWidth
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter
        onOsdVisibleChanged: animatedWidth = osdVisible ? expandedWidth : collapsedWidth
        Behavior on animatedWidth {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Behavior on displayedVolume {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: volumeControl.osdVisible ? "transparent"
                : (volumeHover.hovered ? Theme.indicatorHover : "transparent")
        }

        Item {
            id: sliderVisual
            x: volumeControl.osdVisible ? 3 : 0
            y: volumeControl.osdVisible ? -1 : 0
            width: volumeControl.width
            height: 28
            opacity: volumeControl.osdVisible ? 1 : 0
            transform: Scale {
                origin.x: sliderVisual.width / 2
                origin.y: sliderVisual.height / 2
                yScale: 1
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
                clip: true

                Rectangle {
                    x: 1
                    y: 1
                    width: (parent.width - 2) * Math.max(0, Math.min(1,
                        volumeControl.displayedVolume))
                    height: parent.height - 2
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
            width: volumeControl.osdVisible ? Math.max(0, Math.min(16,
                volumeControl.width * volumeControl.displayedVolume
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
            onClicked: volumeControl.menuOpen = !volumeControl.menuOpen
        }

        Timer {
            id: volumeOsdTimer
            interval: 1200
            onTriggered: volumeControl.osdVisible = false
        }

        function showVolumeOsd() {
            volumeControl.osdVisible = true;
            volumeOsdTimer.restart();
        }

        Connections {
            target: Audio
            function onVolumeChanged() { volumeControl.showVolumeOsd(); }
            function onMutedChanged() { volumeControl.showVolumeOsd(); }
        }

        VolumeMenu {
            hostWindow: indicators.barWindow
            anchorItem: volumeControl
            open: volumeControl.menuOpen
            onDismissed: volumeControl.menuOpen = false
        }
    }

    Item {
        id: brightnessControl
        property bool osdVisible: false
        property bool menuOpen: false
        property real animatedWidth: collapsedWidth
        property real displayedBrightness: Brightness.brightness
        readonly property int collapsedWidth: 28
        readonly property int expandedWidth: 84

        width: animatedWidth
        height: 28
        Layout.preferredWidth: animatedWidth
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter
        onOsdVisibleChanged: animatedWidth = osdVisible ? expandedWidth : collapsedWidth
        Behavior on animatedWidth {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Behavior on displayedBrightness {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: brightnessControl.osdVisible ? "transparent"
                : (brightnessHover.hovered ? Theme.indicatorHover : "transparent")
        }

        Item {
            id: brightnessSliderVisual
            x: brightnessControl.osdVisible ? 3 : 0
            y: brightnessControl.osdVisible ? -1 : 0
            width: brightnessControl.width
            height: 28
            opacity: brightnessControl.osdVisible ? 1 : 0
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
                anchors.fill: parent
                radius: 14
                color: Theme.indicatorHover
                clip: true

                Rectangle {
                    x: 1
                    y: 1
                    width: (parent.width - 2) * Math.max(0, Math.min(1,
                        brightnessControl.displayedBrightness))
                    height: parent.height - 2
                    radius: parent.radius
                    color: Theme.barText
                }
            }
        }

        Image {
            z: 2
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: Icon.getPath("sun" + Theme.topBarIconSuffix)
            sourceSize: Qt.size(15, 15)
            smooth: true
        }

        Item {
            id: brightnessFilledIconMask
            z: 3
            x: brightnessControl.width - 22
            y: (brightnessControl.height - height) / 2
            width: brightnessControl.osdVisible ? Math.max(0, Math.min(16,
                brightnessControl.width * brightnessControl.displayedBrightness
                    - (brightnessControl.width - 22))) : 0
            height: 16
            clip: true

            Image {
                width: 16
                height: 16
                source: Icon.getPath("sun_black")
                sourceSize: Qt.size(15, 15)
                smooth: true
            }
        }

        HoverHandler { id: brightnessHover; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            onClicked: brightnessControl.menuOpen = !brightnessControl.menuOpen
        }

        Timer {
            id: brightnessOsdTimer
            interval: 1200
            onTriggered: brightnessControl.osdVisible = false
        }

        function showBrightnessOsd() {
            brightnessControl.osdVisible = true;
            brightnessOsdTimer.restart();
        }

        Connections {
            target: Brightness
            function onBrightnessChanged() { brightnessControl.showBrightnessOsd(); }
        }

        BrightnessMenu {
            hostWindow: indicators.barWindow
            anchorItem: brightnessControl
            open: brightnessControl.menuOpen
            onDismissed: brightnessControl.menuOpen = false
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
