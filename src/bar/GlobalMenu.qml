import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Wayland

import qs.src.services

Pane {
    anchors.fill: parent
    padding: 0

    leftPadding: 15
    topPadding: 5
    background: null

    RowLayout {
        id: globalMenu
        height: parent.height
        spacing: 20

        property string windowTitle: {
            if (ToplevelManager.activeToplevel) {
                return ToplevelManager.activeToplevel.title;
            }
            return "";
        }

        Image {
            sourceSize.width: 18
            source: Icon.getPath("logo")
        }

        Text {
            text: globalMenu.windowTitle
            color: "white"
            elide: Text.ElideRight

            font.family: "Google Sans Flex"
            font.pointSize: 11
            font.weight: 600
        }
    }
}
