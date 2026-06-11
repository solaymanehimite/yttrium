import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.DBusMenu
import Quickshell.Wayland

import qs.src.services

Pane {
    id: globalMenuPane
    padding: 0

    leftPadding: 15
    topPadding: 5
    background: null
    clip: true

    NumberAnimation on height {
        from: 0
        to: globalMenuPane.parent.height
        duration: 500
    }

    NumberAnimation on opacity {
        from: 0
        to: 1
        duration: 1000
    }

    RowLayout {
        id: globalMenu
        height: parent.height
        spacing: 20

        property string windowTitle: {
            if (ToplevelManager.activeToplevel) {
                const appId = ToplevelManager.activeToplevel.appId;
                if (appId.includes(".")) {
                    const parts = appId.split(".");
                    const name = parts[parts.length - 1];
                    return name.charAt(0).toUpperCase() + name.slice(1);
                }
                return appId;
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
