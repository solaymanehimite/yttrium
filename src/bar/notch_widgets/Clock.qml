import QtQuick
import QtQuick.Layouts
import qs.src.services

// Time digits use tabular figures so the width is identical every second
// (no more wobble from proportional digits). No dummy-text hack needed.
RowLayout {
    spacing: 6

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: Time.time
        color: "white"
        font.family: "Google Sans Flex"
        font.pixelSize: 16
        font.weight: 600
        font.features: { "tnum": 1 }
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: Time.date
        color: "#aaaaaa"
        font.family: "Google Sans Flex"
        font.pixelSize: 13
    }
}
