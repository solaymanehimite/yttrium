import QtQuick
import QtQuick.Layouts
import qs.src.services

// Time digits use tabular figures so the width is identical every second
// (no more wobble from proportional digits). No dummy-text hack needed.
RowLayout {
    spacing: 8

    TextMetrics {
        id: clockWidth
        text: "00:00"
        font.family: "Google Sans Flex"
        font.pixelSize: 14
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        Layout.minimumWidth: clockWidth.width
        Layout.preferredWidth: clockWidth.width
        Layout.maximumWidth: clockWidth.width
        text: Time.time
        color: Theme.barText
        font.family: "Google Sans Flex"
        font.pixelSize: 14
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: Time.date
        color: Theme.barText
        font.family: "Google Sans Flex"
        font.pixelSize: 14
        font.weight: Font.Medium
    }
}
