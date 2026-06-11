pragma Singleton
import Quickshell
import Quickshell.Networking
import QtQuick

Singleton {
    id: networkService

    // Automatically tracks system device lists reactively
    readonly property var devices: Networking.devices.values

    // Automatically tracks connected device changes
    readonly property NetworkDevice connectedDevice: {
        const devList = devices;
        for (let i = 0; i < devList.length; i++) {
            if (devList[i].connected) return devList[i];
        }
        return null;
    }

    // Automatically tracks connected Wi-Fi networks
    readonly property Network connectedNetwork: {
        const dev = connectedDevice;
        if (dev && dev.type === DeviceType.Wifi) {
            const nets = dev.networks.values;
            for (let i = 0; i < nets.length; i++) {
                if (nets[i].connected) return nets[i];
            }
        }
        return null;
    }
}
