import Quickshell
import QtQuick
import qs.src.bar

PanelWindow {
    id: bar
    surfaceFormat.opaque: false

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 30 // Set Top padding (not actual size)
    color: "transparent"

    GlobalMenu {}
    Notch {}
}
