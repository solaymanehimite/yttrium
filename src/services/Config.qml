pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property string fontFamily: "Inter"
    readonly property real uiScale: 1.08
    readonly property string iconDirectory: Quickshell.shellDir + "/assets/icons"
    readonly property string wallpaperDirectory: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string themeFile: Quickshell.shellDir + "/theme.conf"

    readonly property int barGap: 10
    readonly property int barHeight: Math.round(27 * uiScale)
    readonly property int menuRadius: Math.round(12 * uiScale)
    readonly property int standardAnimation: 180
    readonly property int menuAnimation: 220
}
