pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: brightnessService

    property real brightness: 0
    property real maxBrightness: 1

    function checkBrightness() {
        brightnessProcess.running = true;
    }

    FileView {
        id: fileWatcher
        path: "/sys/class/backlight/intel_backlight/actual_brightness"
        watchChanges: true

        onFileChanged: {
            fileWatcher.reload();
            brightnessService.checkBrightness();
        }
    }

    // Update brightness value
    Process {
        id: brightnessProcess
        command: ["brightnessctl", "get"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                brightnessService.brightness = parseFloat(this.text) / brightnessService.maxBrightness;
            }
        }
    }

    // Check for max brightness
    Process {
        command: ["brightnessctl", "m"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                brightnessService.maxBrightness = parseFloat(this.text);
            }
        }
    }
}
