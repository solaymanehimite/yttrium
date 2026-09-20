import QtQuick
import QtQuick.Layouts

Image {
    id: volume

    property real rasterScale: 1.0

    width: 16
    height: 16
    sourceSize.width: 16 * volume.rasterScale
    sourceSize.height: 16 * volume.rasterScale
    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: 16
    Layout.preferredHeight: 16
    smooth: true
    asynchronous: true
}
