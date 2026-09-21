import QtQuick
import QtQuick.Layouts

// Compact OSD for raw multipad slider updates.
RowLayout {
    id: root

    property int sliderIndex: 0
    property string title: "Slider " + root.sliderIndex
    property real value: 0

    property real smoothValue: clamped(root.value)
    Behavior on smoothValue {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    spacing: 8

    function clamped(v) {
        if (isNaN(v) || v === undefined || v === null)
            return 0;
        return Math.max(0, Math.min(1, v));
    }

    Text {
        text: root.title
        color: "white"
        Layout.alignment: Qt.AlignVCenter
        font.family: "Google Sans Flex"
        font.pixelSize: 13
        font.weight: 650
    }

    Item {
        Layout.fillWidth: true
    }

    Rectangle {
        id: track
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 80
        Layout.preferredHeight: 5
        radius: 2.5
        color: "#3a3a3a"

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(track.width * root.smoothValue)
            height: parent.height
            radius: 2.5
            color: "white"
        }
    }

    Text {
        text: Math.round(root.value * 100) + "%"
        color: "white"
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 38
        horizontalAlignment: Text.AlignRight
        font.family: "Google Sans Flex"
        font.pixelSize: 13
        font.weight: 600
        font.features: { "tnum": 1 }
    }
}
