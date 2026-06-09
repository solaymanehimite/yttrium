import QtQuick.Layouts
import QtQuick

import qs.src.services

RowLayout {
    id: brightnessIndicator

    spacing: 5
    Layout.leftMargin: 0

    property bool isVisible: false

    Connections {
        target: Brightness

        function onBrightnessChanged() {
            brightnessIndicator.isVisible = true;
            console.log(Brightness.brightness);
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 1000
        running: true
        onTriggered: brightnessIndicator.isVisible = false
    }

    Rectangle {
        Layout.preferredWidth: brightnessIndicator.isVisible ? 50 : 0
        Layout.preferredHeight: 5
        color: "#444444"

        clip: true

        opacity: brightnessIndicator.isVisible ? 1 : 0
        radius: height / 2

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
            width: 50 * (Brightness.brightness ?? 0)
            height: parent.height

            Behavior on width {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.InOutQuad
                }
            }

            color: "white"
            radius: parent.radius
        }
    }

    Image {
        source: Icon.getPath("sun")
        opacity: brightnessIndicator.isVisible ? 1 : 0.5
    }
}
