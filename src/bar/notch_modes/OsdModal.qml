import QtQuick
import QtQuick.Layouts

// Generic OSD row shown inside the notch when volume / brightness changes.
// Same 30px height as the idle notch. Left: icon + name.
// Right: small slider track + fixed-width value text (no relayout as % changes).
RowLayout {
    id: root

    property string iconSource: ""
    property real rasterScale: 1.0
    property string title: ""
    property real value: 0 // 0..1, clamped for the bar
    property string displayText: ""
    property string statusIconSource: ""
    property bool muted: false
    readonly property int fadeDuration: 150

    opacity: root.muted ? 0.45 : 1.0
    Behavior on opacity {
        NumberAnimation {
            duration: root.fadeDuration
            easing.type: Easing.OutCubic
        }
    }

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
        width: 16
        height: 16
        sourceSize.width: 16 * root.rasterScale
        sourceSize.height: 16 * root.rasterScale
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
            color: "white"
        }
    }

    Item {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: root.muted ? 0 : 40
        Layout.preferredHeight: 16
        Behavior on Layout.preferredWidth {
            NumberAnimation {
                duration: root.fadeDuration
                easing.type: Easing.OutCubic
            }
        }

        Image {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 10
            sourceSize.width: 10 * root.rasterScale
            sourceSize.height: 10 * root.rasterScale
            source: root.statusIconSource
            opacity: root.statusIconSource === "" ? 0 : 1
            smooth: true
            asynchronous: true
            Behavior on opacity {
                NumberAnimation {
                    duration: root.fadeDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        Text {
            anchors.fill: parent
            text: root.displayText
            color: "white"
            opacity: root.muted ? 0 : 1
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font.family: "Google Sans Flex"
            font.pixelSize: 13
            font.weight: 500
            font.features: { "tnum": 1 }
            Behavior on opacity {
                NumberAnimation {
                    duration: root.fadeDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
