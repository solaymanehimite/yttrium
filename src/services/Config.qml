pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property string fontFamily: "Satoshi"
    readonly property real uiScale: 1.08
    readonly property string iconDirectory: Quickshell.shellDir + "/assets/icons"
    readonly property string wallpaperDirectory: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string themeFile: Quickshell.shellDir + "/theme.conf"

    // Shared layout, shape, and motion tokens.
    readonly property int barGap: 10
    readonly property int barHeight: Math.round(27 * uiScale)
    readonly property int menuRadius: 44
    readonly property int tileRadius: 18
    readonly property int space0: 0
    readonly property int space1: 1
    readonly property int space2: 2
    readonly property int space3: 3
    readonly property int space4: 4
    readonly property int space6: 6
    readonly property int space7: 7
    readonly property int space8: 8
    readonly property int space10: 10
    readonly property int space12: 12
    readonly property int space14: 14
    readonly property int space16: 16
    readonly property int space18: 18
    readonly property int space24: 24
    readonly property int space28: 28
    readonly property int standardAnimation: 180
    readonly property int menuAnimation: 220
}
