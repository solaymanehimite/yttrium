import QtQuick.Layouts
import QtQuick

import qs.src.services

// TODO:
RowLayout {
    id: battery
    spacing: 0

    Image {
        source: Icon.getPath("battery/100plugged")
        sourceSize.width: 15
        opacity: 0.7
    }
}
