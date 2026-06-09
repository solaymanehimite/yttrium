import QtQuick
import QtQuick.Layouts
import qs.src.services

Row {
    spacing: 10

    Text {
        anchors.verticalCenter: parent.verticalCenter

        text: Time.time
        color: "white"

        font.pixelSize: 16
        font.family: "Google Sans Flex"
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter

        text: Time.date
        color: "#aaaaaa"

        font.family: "Google Sans Flex"
        font.pixelSize: 13
    }
}
