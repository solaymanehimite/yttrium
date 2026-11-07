import Quickshell
import QtQuick
import qs.src.bar
import qs.src.services

PanelWindow {
    id: bar

    // Keep the multipadd client alive for the lifetime of the shell.
    readonly property var multiPadService: MultiPad
    readonly property int barGap: Config.barGap
    readonly property int exclusiveZonePadding: 6
    // Make the transparent surface fill the existing reserved zone. This lets
    // left/right controls share the notch's vertical center without clipping.
    readonly property int reservedHeight: implicitHeight

    anchors {
        top: true
        left: true
        right: true
    }

    // Keep the bar spacing balanced with the side margins.
    margins {
        top: bar.barGap
        left: bar.barGap
        right: bar.barGap
    }
    exclusiveZone: reservedHeight

    implicitHeight: Config.barHeight + exclusiveZonePadding * 2
    color: "transparent"

    Notch {
        id: notch
    }

    WorkspaceStrip {
        hostWindow: bar
    }

    RightIndicators {
        barWindow: bar
    }
}
