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

    // Keep the bar spacing balanced with the side margins. Niri adds the
    // configured layout gap between the reserved bar space and first window.
    margins {
        top: bar.niriGap
        left: bar.niriGap
        right: bar.niriGap
    }
    exclusiveZone: implicitHeight

    implicitHeight: Config.barHeight
    color: "transparent"

    GlobalMenu {
        barWindow: bar
    }
    RightIndicators {
        barWindow: bar
        onControlCenterClicked: notch.openControlCenter()
        onVolumeClicked: notch.show("volume")
        onCalendarClicked: notch.openCalendar()
    }
    Notch {
        id: notch
    }

}
