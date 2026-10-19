import QtQuick
import QtQuick.Layouts
import qs.src.services as Services

// A compact, authored battery glyph.
Item {
    id: battery

    property real rasterScale: 1.0
    readonly property real percentage: Services.PowerBattery.percentage
    readonly property bool batteryAvailable: Services.PowerBattery.available
    readonly property color backgroundColor: Services.Theme.batteryTrack
    readonly property color fillColor: Services.Theme.notchText
    readonly property color pinColor: Services.PowerBattery.fullyCharged ? fillColor : backgroundColor

    visible: batteryAvailable
    width: 22
    height: 14
    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: visible ? 22 : 0
    Layout.preferredHeight: 14

    Rectangle {
        id: body
        x: 0
        y: 1
        width: 19
        height: 12
        radius: 3
        color: battery.backgroundColor
        clip: true

        Rectangle {
            x: 1
            y: 1
            width: Math.max(0, (body.width - 2) * battery.percentage / 100)
            height: body.height - 2
            radius: 2
            color: battery.fillColor
        }
    }

    Rectangle {
        x: 19
        y: 4
        width: 3
        height: 6
        radius: 1.5
        color: battery.pinColor
    }
}
