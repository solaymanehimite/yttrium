pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property string fontFamily: "Google Sans Flex"
    readonly property string iconDirectory: Quickshell.shellDir + "/assets/icons"
    readonly property string wallpaperDirectory: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string backlightDirectory: "/sys/class/backlight"
    readonly property string themeFile: Quickshell.shellDir + "/theme.conf"

    readonly property int barGap: 6
    readonly property int barHeight: 30
    readonly property int menuRadius: 12
    readonly property int standardAnimation: 180
    readonly property int mediumAnimation: 140
    readonly property int shortAnimation: 100
    readonly property int menuAnimation: 220
}
