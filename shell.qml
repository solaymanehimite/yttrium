import Quickshell
import QtQuick
import qs.src.bar
import qs.src.services

PanelWindow {
    id: bar

    // Keep the cleartouchd client alive for the lifetime of the shell.
    readonly property var multiPadService: MultiPad
    readonly property int niriGap: Config.barGap

    anchors {
        top: true
        left: true
        right: true
    }

    // Match layout.gaps in ~/.config/niri/config.kdl. The extra exclusive
    // space leaves the same gap between the bar and the first window below.
    margins {
        top: bar.niriGap
        left: bar.niriGap
        right: bar.niriGap
    }
    exclusiveZone: implicitHeight + bar.niriGap

    implicitHeight: Config.barHeight
    color: "transparent"

    GlobalMenu {
        barWindow: bar
    }
    RightIndicators {
        barWindow: bar
        onControlCenterClicked: notch.openControlCenter()
    }
    Notch {
        id: notch
    }
    // Tray {}

}
