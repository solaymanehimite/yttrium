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
    property real _targetBrightness: -1
    property int _queuedBrightness: 0
    property bool _writePending: false

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

    Process {
        id: writeProc
        command: ["brightnessctl", "set", "0%"]

        onExited: {
            if (brightnessService._writePending) {
                brightnessService._writePending = false;
                writeProc.command = [
                    "brightnessctl",
                    "set",
                    String(brightnessService._queuedBrightness) + "%"
                ];
                writeProc.running = true;
            } else {
                brightnessService._targetBrightness = -1;
                brightnessService.refresh();
            }
        }
    }

    function clamp(v) {
        return Math.max(0, Math.min(1, Number(v)));
    }

    function adjustRelative(delta) {
        if (max <= 0)
            return -1;

        const base = brightnessService._targetBrightness >= 0
            ? brightnessService._targetBrightness
            : brightnessService.brightness;
        brightnessService._targetBrightness = clamp(base + Number(delta));
        brightnessService.current = Math.round(brightnessService._targetBrightness * max);
        brightnessService._queuedBrightness = Math.round(brightnessService._targetBrightness * 100);

        if (writeProc.running) {
            brightnessService._writePending = true;
        } else {
            writeProc.command = [
                "brightnessctl",
                "set",
                String(brightnessService._queuedBrightness) + "%"
            ];
            writeProc.running = true;
        }
        return brightnessService._targetBrightness;
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
