import QtQuick
import qs.src.services

Row {
    spacing: 5

    Text {
        // Google Sans is not Mono so we need to give the time text a fixed width to not keep resizing.
        // To do this we create a dummy text with the maximum size the time text can be.
        anchors.verticalCenter: parent.verticalCenter
        text: "MMMMMM"
        color: "transparent"

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.time
            color: "white"

            font.pixelSize: 16
            font.family: "Google Sans Flex"
            font.weight: 500
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter

        text: Time.date
        color: "#aaaaaa"

        font.family: "Google Sans Flex"
        font.pixelSize: 13
    }
}
