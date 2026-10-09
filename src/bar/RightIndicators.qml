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

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: indicators.controlCenterClicked()
    }

    // Left-to-right order: LocalSend, volume, Wi-Fi, battery, then the clock/date.
    LocalSendIndicator {
        hostWindow: indicators.barWindow
    }

    Volume {
        source: {
            if (Audio.muted)
                return Icon.getPath("volume/volume_muted_red");
            if (Audio.volume < 0.33)
                return Icon.getPath("volume/volume_low");
            if (Audio.volume < 0.66)
                return Icon.getPath("volume/volume_medium");
            return Icon.getPath("volume/volume_high");
        }
        rasterScale: 1.0
    }

    Network {
        rasterScale: 1.0
    }

    Battery {
        rasterScale: 1.0
    }

    Clock {}

}
