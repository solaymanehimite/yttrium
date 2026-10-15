pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: brightnessService

    property string backlightPath: ""
    property int current: 0
    property int max: 1
    readonly property real brightness: max > 0 ? current / max : 0
    property real _targetBrightness: -1
    property int _queuedBrightness: 0
    property bool _writePending: false

    Process {
        id: deviceScan
        command: ["sh", "-c", "for path in /sys/class/backlight/*; do [ -f \"$path/actual_brightness\" ] && printf '%s' \"$path\" && break; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path)
                    brightnessService.backlightPath = path;
            }
        }
    }

    FileView {
        id: maxFile
        path: brightnessService.backlightPath ? brightnessService.backlightPath + "/max_brightness" : ""
        watchChanges: true
        onLoaded: brightnessService.max = parseInt(text().trim()) || 1
    }

    FileView {
        id: actualFile
        path: brightnessService.backlightPath ? brightnessService.backlightPath + "/actual_brightness" : ""
        watchChanges: true
        onLoaded: {
            const value = parseInt(text().trim());
            if (!isNaN(value))
                brightnessService.current = value;
        }
    }

    Process {
        id: writeProc
        onExited: {
            if (brightnessService._writePending) {
                brightnessService._writePending = false;
                writeProc.command = ["brightnessctl", "set",
                    String(brightnessService._queuedBrightness) + "%"];
                writeProc.running = true;
            } else {
                brightnessService._targetBrightness = -1;
            }
        }
    }

    function clamp(value) {
        return Math.max(0, Math.min(1, Number(value)));
    }

    function setBrightness(value) {
        const next = clamp(value);
        return adjustRelative(next - brightness);
    }

    function adjustRelative(delta) {
        if (!backlightPath || max <= 0)
            return -1;

        const base = _targetBrightness >= 0 ? _targetBrightness : brightness;
        _targetBrightness = clamp(base + Number(delta));
        current = Math.round(_targetBrightness * max);
        _queuedBrightness = Math.round(_targetBrightness * 100);

        if (writeProc.running) {
            _writePending = true;
        } else {
            writeProc.command = ["brightnessctl", "set",
                String(_queuedBrightness) + "%"];
            writeProc.running = true;
        }
        return _targetBrightness;
    }
}
