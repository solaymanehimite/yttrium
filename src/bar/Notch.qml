import Quickshell
import QtQuick
import QtQuick.Layouts

import qs.src.bar.notch_widgets

PopupWindow {
    anchor.window: bar
    anchor.rect.x: bar.width / 2 - width / 2
    anchor.rect.y: bar.height / 2 - height / 2

    implicitWidth: 400
    implicitHeight: 30

    visible: true
    color: "transparent" // Use a Rect instead

    Rectangle {
        anchors.fill: parent
        color: "black"

        bottomLeftRadius: height / 2
        bottomRightRadius: height / 2

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
