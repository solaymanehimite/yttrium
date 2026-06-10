import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland

import qs.src.services

RowLayout {
    height: parent.height
    spacing: 25

    Image {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        sourceSize.width: 20
        anchors.leftMargin: 10
        source: Icon.getPath("logo")
    }

    Text {
        text: ToplevelManager.activeToplevel.title
        elide: Text.ElideRight
        Layout.maximumWidth: 150
        color: "white"
        font.family: "Google Sans Flex"
        font.pointSize: 11
        font.weight: 600
    }
}
