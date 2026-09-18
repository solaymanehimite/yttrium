import Quickshell
import QtQuick
import QtQuick.Layouts

import qs.src.bar.notch_widgets
import qs.src.bar.notch_modes
import qs.src.services

PopupWindow {
    id: notch
    anchor.window: bar
    anchor.rect.x: bar.width / 2 - width / 2
    anchor.rect.y: 0

    // Showcase mode renders the notch at 3x its normal size, giving screen
    // recordings enough pixels to preserve the small type and icons.
    // Set to 1.0 when you want the compact everyday bar again.
    property real showcaseScale: 1.0

    // Window geometry NEVER changes — only the inner pill morphs.
    // This keeps Niri from relayouting the popup every animation frame.
    implicitWidth: 560 * notch.showcaseScale
    implicitHeight: 30 * notch.showcaseScale

    property bool osdActive: osdMode !== ""
    property string osdMode: "" // "", "volume", "brightness"
    property bool _ready: false

    visible: true
    color: "transparent"

    // Auto-hide the OSD shortly after the last change
    Timer {
        id: hideTimer
        interval: 800
        repeat: false
        onTriggered: notch.osdMode = ""
    }

    function poke(mode) {
        if (!notch._ready)
            return;
        // Switching mode while already shown: swap content without
        // restarting the width animation (width only depends on osdActive).
        notch.osdMode = mode;
        hideTimer.restart();
    }

    Component.onCompleted: _initTimer.start()
    Timer {
        id: _initTimer
        interval: 800
        repeat: false
        onTriggered: notch._ready = true
    }

    // Any external change (e.g. fn volume / brightness keys handled by
    // the compositor / wireplumber / brightnessctl) flows through these
    // reactive services, so we just watch them.
    Connections {
        target: Audio
        function onVolumeChanged() {
            poke("volume");
        }
        function onMutedChanged() {
            poke("volume");
        }
    }
    Connections {
        target: Brightness
        function onBrightnessChanged() {
            poke("brightness");
        }
    }

    // ---- OSD derived values ----
    property string volumeIcon: {
        if (Audio.muted)
            return Icon.getPath("volume/volume_muted");
        const v = Audio.volume ?? 0;
        if (v <= 0.01)
            return Icon.getPath("volume/volume_muted");
        if (v < 0.33)
            return Icon.getPath("volume/volume_low");
        if (v < 0.66)
            return Icon.getPath("volume/volume_medium");
        return Icon.getPath("volume/volume_high");
    }
    property string volumeText: Math.round((Audio.volume ?? 0) * 100)
    property real volumeFrac: Audio.volume ?? 0

    property real brightnessFrac: {
        const b = Brightness.brightness;
        if (isNaN(b) || b === undefined || b === null)
            return 0;
        return Math.max(0, Math.min(1, b));
    }
    property string brightnessText: Math.round(brightnessFrac * 100)

    // Keep layout in the original 560x30 coordinate space, then scale the
    // complete stage as one unit. The popup is enlarged too, so the scaled
    // content is never clipped at the window edges.
    Item {
        id: stage
        anchors.centerIn: parent
        width: 560
        height: 30
        scale: notch.showcaseScale

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: notch.osdActive ? (notch.osdMode === "volume" && Audio.muted ? 270 : 320) : 400
            height: 30
            color: "black"
            clip: true

            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: height / 2
            bottomRightRadius: height / 2

            Behavior on width {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.OutCubic
                }
            }

            // One-time entrance only — never re-runs on morph.
            opacity: 0
            Component.onCompleted: entrance.start()
            NumberAnimation {
                id: entrance
                target: pill
                property: "opacity"
                from: 0
                to: 1
                duration: 500
                easing.type: Easing.OutCubic
            }

            // Idle notch content
            RowLayout {
                id: idleRow
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 15
                opacity: notch.osdActive ? 0 : 1
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Clock {}
                Item {
                    Layout.fillWidth: true
                }
                Battery {
                    rasterScale: notch.showcaseScale
                }
                Network {
                    rasterScale: notch.showcaseScale
                }
            }

            // Expanded OSD content (same height, just wider)
            Item {
                id: osdWrap
                anchors {
                    fill: parent
                    leftMargin: 14
                    rightMargin: 14
                }
                opacity: notch.osdActive ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                OsdModal {
                    anchors.fill: parent
                    iconSource: notch.osdMode === "brightness" ? Icon.getPath("sun") : notch.volumeIcon
                    title: notch.osdMode === "brightness" ? "Brightness" : (Audio.muted ? "Muted" : "Volume")
                    value: notch.osdMode === "brightness" ? notch.brightnessFrac : notch.volumeFrac
                    displayText: notch.osdMode === "brightness" ? notch.brightnessText : notch.volumeText
                    statusIconSource: ""
                    muted: notch.osdMode === "volume" && Audio.muted
                    rasterScale: notch.showcaseScale
                }
            }
        }
    }
}
