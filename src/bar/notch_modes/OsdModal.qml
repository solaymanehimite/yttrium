import QtQuick
import QtQuick.Layouts

// Generic OSD row shown inside the notch when volume / brightness changes.
// Same 30px height as the idle notch. Left: icon + name.
// Right: small slider track + fixed-width value text (no relayout as % changes).
RowLayout {
    id: root

    property string iconSource: ""
    property string title: ""
    property real value: 0 // 0..1, clamped for the bar
    property string displayText: ""

    spacing: 8

    function clamped(v) {
        if (isNaN(v) || v === undefined || v === null)
            return 0;
        return Math.max(0, Math.min(1, v));
    }

    // Animated copy of the value. The fill tracks track.width instantly
    // (so the pill morph doesn't lag) but value changes glide.
    property real smoothValue: clamped(root.value)
    Behavior on smoothValue {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }



    Image {
        source: root.iconSource
        sourceSize.width: 16
        sourceSize.height: 16
        Layout.preferredWidth: 16
        Layout.preferredHeight: 16
        Layout.alignment: Qt.AlignVCenter
        smooth: true
        asynchronous: true
    }

    Text {
        text: root.title
        color: "white"
        Layout.alignment: Qt.AlignVCenter
        font.family: "Google Sans Flex"
        font.pixelSize: 14
        font.weight: 600
    }

    Item {
        Layout.fillWidth: true
    }

    // Small slider indicator — fixed size so value changes never move it.
    Rectangle {
        id: track
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 80
        Layout.preferredHeight: 5
        radius: 2.5
        color: "#3a3a3a"

        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(track.width * root.smoothValue)
            height: parent.height
            radius: 2.5
            color: "#30d158"
        }
    }

    Text {
        text: root.displayText
        color: "white"
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: -5
        Layout.preferredWidth: 40
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        font.family: "Google Sans Flex"
        font.pixelSize: 13
        font.weight: 500
        font.features: { "tnum": 1 }
    }
}
