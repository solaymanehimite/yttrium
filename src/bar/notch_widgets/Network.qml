import QtQuick.Layouts
import QtQuick
import Quickshell.Networking

import qs.src.services

Image {
    id: network

    property real rasterScale: 1.0
    property string currentIcon: {
        const dev = NetworkService.connectedDevice;
        if (!dev) {
            return "wifi/none";
        }

        if (dev.type === DeviceType.Wifi) {
            if (!dev.connected) { return "wifi/none"; }
            if (dev.state == ConnectionState.Unknown) { return "wifi/unknown"; }
            if (dev.stateChanging) { return "wifi/portal"; }
            if (dev.state == ConnectionState.Disconnected) { return "wifi/no_signal"; }

            // if device is connected, check signal strength
            if (NetworkService.connectedNetwork != null) {
                const strength = NetworkService.connectedNetwork.signalStrength;;
                const roundedStrength = Math.round(strength * 4);
                if (roundedStrength <= 1) { return "wifi/no_signal"; }
                if (roundedStrength <= 2) { return "wifi/weak"; }
                if (roundedStrength <= 3) { return "wifi/half_full"; }
                return "wifi/full";
            }

            return "wifi/unknown";

        } else if (dev.type === DeviceType.Wired) {
            if (dev.hasLink || dev.network) {return "lan/connected"; }
            return "lan/no_internet";
        }
    }

        source: Icon.getPath(network.currentIcon)
        width: 15
        height: 15
        sourceSize.width: 15 * network.rasterScale
        sourceSize.height: 15 * network.rasterScale
        Layout.preferredWidth: 15
        Layout.preferredHeight: 15
        smooth: true
}
