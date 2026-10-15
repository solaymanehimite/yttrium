pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property color notchBlack: "#000000"
    readonly property color panelSurface: "#191c21"
    readonly property color panelSurfaceRaised: "#20242b"
    readonly property color tileActive: "#f6f8fb"
    readonly property color tileHover: "#1c2026"
    readonly property color textPrimary: "#f4f5f7"
    readonly property color textMuted: "#9da4b0"
    readonly property color textQuiet: "#777e8b"
    readonly property color accent: "#4d7dff"
    readonly property color danger: "#ff6b72"

    readonly property int menuRadius: 44
    readonly property int tileRadius: 18
    readonly property int panelInset: 18
    readonly property int controlGap: 8
    readonly property int compactGap: 6
    readonly property int panelAnimation: 220
}
