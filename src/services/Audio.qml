pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    PwObjectTracker {
        objects: (Pipewire.nodes.values || []).concat([
            Pipewire.defaultAudioSink,
            Pipewire.defaultAudioSource
        ])
    }

    readonly property var appStreams: {
        const nodes = Pipewire.nodes.values || [];
        return nodes.filter(node => node && node.isStream && node.isSink
            && node.audio && node.ready);
    }

    readonly property bool microphoneMuted: {
        Pipewire.defaultAudioSource?.audio.muted ?? false;
    }

    readonly property real volume: {
        Pipewire.defaultAudioSink?.audio.volume ?? 0;
    }

    readonly property bool muted: {
        Pipewire.defaultAudioSink?.audio.muted ?? false;
    }

    function toggleMicrophone() {
        const source = Pipewire.defaultAudioSource;
        if (!source || !source.ready || !source.audio)
            return false;
        source.audio.muted = !source.audio.muted;
        return source.audio.muted;
    }

    function setVolume(value) {
        const sink = Pipewire.defaultAudioSink;
        if (!sink || !sink.ready || !sink.audio)
            return -1;
        const next = Math.max(0, Math.min(1, Number(value)));
        sink.audio.muted = false;
        sink.audio.volume = next;
        return next;
    }

    function setStreamVolume(stream, value) {
        if (!stream || !stream.ready || !stream.audio)
            return -1;
        const next = Math.max(0, Math.min(1, Number(value)));
        stream.audio.muted = false;
        stream.audio.volume = next;
        return next;
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
