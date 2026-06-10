import QtQuick.Layouts
import QtQuick
import Quickshell.Networking

import qs.src.services

// TODO:
RowLayout {
    id: network
    spacing: 0

    property string networkState: "connected"
    property bool isExpanded: false

    // states: conected, disconnected, connecting, scanning, disconnecting

    Timer {
        id: stateChangeTimer
        interval: 1000
        onTriggered: {
            network.isExpanded = false;
        }
    }

    Connections {
        target: NetworkService
        function onDevicesChanged() {
        }
    }

    Image {
        source: Networking.wifiEnabled ? Icon.getPath("wifi/full") : Icon.getPath("wifi/none")
        sourceSize.width: 15
        opacity: 0.7
    }
}
