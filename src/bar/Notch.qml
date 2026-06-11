import Quickshell
import QtQuick
import QtQuick.Layouts

import qs.src.bar.notch_widgets

PopupWindow {
    anchor.window: bar
    anchor.rect.x: bar.width / 2 - width / 2
    anchor.rect.y: 0

    implicitWidth: 400
    implicitHeight: 30

    visible: true
    color: "transparent" // Use a Rect instead

    Rectangle {
        anchors.top: parent.top
        implicitWidth: parent.width
        implicitHeight: parent.height
        color: "black"
        clip: true

        bottomLeftRadius: height / 2
        bottomRightRadius: height / 2

        NumberAnimation on implicitHeight {
            from: 1
            to: 30
            duration: 1000
            easing.type: Easing.OutCubic
        }

        NumberAnimation on opacity {
            from: 0
            to: 1
            duration: 500
            easing.type: Easing.OutCubic
        }

        NumberAnimation on scale {
            from: 0.9
            to: 1
            duration: 500
            easing.type: Easing.OutCubic
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 10
            }
            spacing: 15

            Clock {}
            Item { // Spacer
                Layout.fillWidth: true
            }
            Battery {}
            Network {}
        }
    }
}
