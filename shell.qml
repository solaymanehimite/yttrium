import Quickshell
import QtQuick
import qs.src.bar
import qs.src.services

PanelWindow {
    id: bar

    // Keep the cleartouchd client alive for the lifetime of the shell.
    readonly property var multiPadService: MultiPad
    readonly property int niriGap: Config.barGap
    readonly property int exclusiveZonePadding: 6
    readonly property int reservedHeight: implicitHeight + exclusiveZonePadding * 2

    anchors {
        top: true
        left: true
        right: true
    }

    // Keep the bar spacing balanced with the side margins. Niri adds the
    // configured layout gap between the reserved bar space and first window.
    margins {
        top: bar.niriGap
        left: bar.niriGap
        right: bar.niriGap
    }
    exclusiveZone: reservedHeight

    implicitHeight: Config.barHeight
    color: "transparent"

    // Keep the top reservation for the compositor, but leave the old bar
    // surface empty. The notch is now the only visible top-level control.
    Notch {
        id: notch
    }

}
