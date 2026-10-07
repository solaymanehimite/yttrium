pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

import qs.src.services

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
        multipad.eventName = String(payload.event || "slider");
        multipad.focusedApp = String(payload.focused_app || "");

        // cleartouchd sends relative, normalized deltas. Apply those to the
        // real system controls rather than treating its value as absolute.
        if (multipad.eventName === "volume")
            Audio.adjustRelative(nextDelta);
        else if (multipad.eventName === "brightness")
            Brightness.adjustRelative(nextDelta);

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
