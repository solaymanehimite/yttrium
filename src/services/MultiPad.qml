pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: multipad

    property bool connected: false
    property int sliderIndex: 0
    property real value: 0
    property real delta: 0
    property string eventName: ""
    property string focusedApp: ""

    signal sliderChanged(int sliderIndex, real value, real delta, string eventName)

    function consume(line) {
        let payload;
        try {
            payload = JSON.parse(line);
        } catch (error) {
            return;
        }

        if (payload.phase !== "update")
            return;

        const zone = Number(payload.zone);
        const nextValue = Number(payload.value);
        const nextDelta = Number(payload.delta);
        if (isNaN(zone) || isNaN(nextValue) || isNaN(nextDelta))
            return;

        multipad.sliderIndex = zone + 1;
        multipad.value = Math.max(0, Math.min(1, nextValue));
        multipad.delta = nextDelta;
        multipad.eventName = payload.event || "slider";
        multipad.focusedApp = payload.focused_app || "";
        multipad.sliderChanged(
            multipad.sliderIndex,
            multipad.value,
            multipad.delta,
            multipad.eventName
        );
    }

    Process {
        id: listener
        command: ["python3", Quickshell.shellDir + "/scripts/multipad-listener.py"]
        running: true

        stdout: SplitParser {
            onRead: data => multipad.consume(data)
        }

        onStarted: multipad.connected = true
        onExited: {
            multipad.connected = false;
            reconnect.start();
        }
    }

    Timer {
        id: reconnect
        interval: 1000
        repeat: false
        onTriggered: listener.running = true
    }
}
