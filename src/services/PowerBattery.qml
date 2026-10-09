pragma Singleton

import Quickshell
import Quickshell.Services.UPower

Singleton {
    readonly property var device: UPower.displayDevice
    readonly property bool available: device && device.isLaptopBattery && device.isPresent
    readonly property real percentage: available ? Math.max(0, Math.min(100, device.percentage)) : 0
    readonly property bool charging: available && (device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.PendingCharge)
    readonly property bool fullyCharged: available && device.state === UPowerDeviceState.FullyCharged
}
