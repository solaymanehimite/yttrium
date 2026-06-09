import QtQuick.Layouts
import QtQuick

import qs.src.services

RowLayout {
    id: volumeIndicator
    spacing: 10

    property bool isVisible: false

    Connections {
        target: Audio

        function onVolumeChanged() {
            volumeIndicator.isVisible = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 1000
        running: true
        onTriggered: volumeIndicator.isVisible = false
    }

    Rectangle {
        Layout.preferredWidth: volumeIndicator.isVisible ? 50 : 0
        Layout.preferredHeight: 5
        color: "#444444"
        clip: true

        radius: height / 2
        opacity: volumeIndicator.isVisible ? 1 : 0

        Behavior on Layout.preferredWidth {
            NumberAnimation {
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 400
                easing.type: Easing.InOutQuad
            }
        }

        Rectangle {
            width: 50 * (Audio.volume ?? 0)
            height: parent.height

            Behavior on width {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.InOutQuad
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            }

            color: !Audio.muted ? "white" : "#666666"
            radius: parent.radius
        }
    }

    Image {
        source: Icon.getPath("volume/volume" + (Audio.muted || Audio.volume == 0 ? "_muted" : Audio.volume > 0.66 ? "_high" : Audio.volume > 0.33 ? "_medium" : "_low"))
    }
}
