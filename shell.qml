import Quickshell
import qs.src.bar

PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 30 // Set Top padding (not actual size)
    color: "transparent"

    Notch {}
}
