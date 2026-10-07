import QtQuick
import QtQuick.Layouts

import qs.src.bar.notch_widgets
import qs.src.services

// Passive menu-bar indicators. The clock stays on the far right, like macOS;
// there is no popup, hover target, or click interaction here.
RowLayout {
    id: indicators

    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    height: parent.height
    spacing: 16

    // Left-to-right order: volume, Wi-Fi, battery, then the clock/date.
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
