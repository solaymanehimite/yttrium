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
}
