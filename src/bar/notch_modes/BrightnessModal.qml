import QtQuick
import QtQuick.Layouts
import qs.src.services

RowLayout {
    id: brightnessModal
    anchors.fill: parent

    Image {
        source: Icon.getPath("sun")
    }
}
