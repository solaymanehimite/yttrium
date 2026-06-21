import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

RowLayout {
    implicitWidth: 40
    Layout.fillHeight: true

    spacing: 5

    Repeater {
        model: 9

        Rectangle {
            Layout.alignment: Qt.AlignVCenter

            width: 2
            height: Mpris.players.values.length ? Mpris.players.values[0].isPlaying * 15 : 0
            color: "white"
        }
    }
}
