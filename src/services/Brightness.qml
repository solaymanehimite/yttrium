pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: brightnessService

    property int current: 0
    property int max: 1
    readonly property real brightness: max > 0 ? current / max : 0
    property bool _dirty: false

    // max_brightness is static — one-shot read is enough.
    FileView {
        id: maxFile
        path: "/sys/class/backlight/intel_backlight/max_brightness"
        onLoaded: brightnessService.max = parseInt(text().trim()) || 1
    }

    // One-shot reader — latest value wins.
    Process {
        id: pollProc
        command: ["cat", "/sys/class/backlight/intel_backlight/actual_brightness"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                if (!isNaN(v))
                    brightnessService.current = v;
                // An event arrived mid-read: re-read immediately so the
                // displayed value never goes stale while holding the key.
                if (brightnessService._dirty) {
                    brightnessService._dirty = false;
                    pollProc.running = true;
                }
            }
        }
    }

    function refresh() {
        if (pollProc.running)
            brightnessService._dirty = true;
        else
            pollProc.running = true;
    }

    // Instant path: the kernel emits a `change` uevent on every backlight
    // adjustment. stdbuf defeats pipe buffering so lines arrive immediately.
    Process {
        id: udevMon
        command: ["stdbuf", "-o0", "udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("change"))
                    brightnessService.refresh();
            }
        }
        onExited: restartMon.start()
    }

    Timer {
        id: restartMon
        interval: 2000
        onTriggered: udevMon.running = true
    }

    // Safety net: slow poll in case an event is ever missed.
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: brightnessService.refresh()
    }
}
