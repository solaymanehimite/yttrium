pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: brightnessService

    FileView {
        id: actualBrightnessFile
        path: "/sys/class/backlight/intel_backlight/actual_brightness"
        watchChanges: true
    }

    FileView {
        id: maxBrightnessFile
        path: "/sys/class/backlight/intel_backlight/max_brightness"
    }

    readonly property real maxBrightness: parseFloat(maxBrightnessFile.
    text) || 1.0
    readonly property real brightness: parseFloat(actualBrightnessFile.
    text) / maxBrightness

}
