import QtQuick
import QtQuick.Layouts
// A compact, authored battery glyph.
Item {
    id: battery

    property real rasterScale: 1.0
    // Demo value for tuning the compact visual treatment.
    readonly property real percentage: 67
    readonly property color backgroundColor: "#707070"
    readonly property color fillColor: "#ffffff"
    readonly property color pinColor: percentage >= 100 ? fillColor : backgroundColor

    visible: true
    width: 22
    height: 14
    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: 22
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
            width: (body.width - 2) * battery.percentage / 100
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
