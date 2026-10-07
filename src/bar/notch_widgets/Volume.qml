import QtQuick
import QtQuick.Layouts

Image {
    id: volume

    property real rasterScale: 1.0

    width: 15
    height: 15
    sourceSize.width: 15 * volume.rasterScale
    sourceSize.height: 15 * volume.rasterScale
    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: 15
    Layout.preferredHeight: 15
    smooth: true
    asynchronous: true
}
