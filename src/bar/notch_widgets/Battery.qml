import QtQuick.Layouts
import QtQuick

import qs.src.services

// TODO:
RowLayout {
    id: battery
    property real rasterScale: 1.0

    spacing: 0

    Image {
        source: Icon.getPath("battery/100plugged")
        width: 15
        height: 15
        sourceSize.width: 15 * battery.rasterScale
        sourceSize.height: 15 * battery.rasterScale
        Layout.preferredWidth: 15
        Layout.preferredHeight: 15
        smooth: true
    }
}
