pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property real volume: {
        Pipewire.defaultAudioSink?.audio.volume ?? 0;
    }

    readonly property bool muted: {
        Pipewire.defaultAudioSink?.audio.muted ?? false;
    }

    function adjustRelative(delta) {
        const sink = Pipewire.defaultAudioSink;
        if (!sink || !sink.ready || !sink.audio)
            return -1;

        const current = Number(sink.audio.volume) || 0;
        const next = Math.max(0, Math.min(1, current + Number(delta)));
        sink.audio.muted = false;
        sink.audio.volume = next;
        return next;
    }
}
