pragma Singleton

import Quickshell
import Quickshell.Networking
import QtQuick

Singleton {
    id: networkService

    property list<NetworkDevice> devices: []
    property NetworkDevice connectedDevice: null
    property Network connectedNetwork: null

    signal checkedDevices

    function checkDevices() {
        networkService.devices = [];
        networkService.devices = Networking.devices.values;

        for (var i = 0; i < networkService.devices.length; i++) {
            if (networkService.devices[i].connected) {
                networkService.connectedDevice = networkService.devices[i];
                networkService.connectedNetwork = networkService.devices[i].networks.values[0];
                break;
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            networkService.checkDevices();
            networkService.checkedDevices();
        }
    }
}
