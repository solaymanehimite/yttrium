pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

import qs.src.services

Singleton {
    FileView {
        id: themeFile
        path: Config.themeFile
        watchChanges: true
        printErrors: false
        onLoaded: {
            const value = text().trim().toLowerCase();
            if (value === "dark" || value === "light")
                Theme.dark = value === "dark";
        }
    }

    // Matugen already publishes the active palette for GTK. Reading that
    // generated file keeps the notch in sync whenever the wallpaper changes,
    // without duplicating Matugen's palette in the shell.
    FileView {
        id: matugenFile
        path: Quickshell.env("HOME") + "/.config/gtk-3.0/colors.css"
        watchChanges: true
        printErrors: false
        onLoaded: Theme.updateMatugenPalette(text())
    }

    function cssColor(contents, name, fallback) {
        const expression = new RegExp("@define-color\\s+" + name
            + "\\s+(#[0-9a-fA-F]{6,8})");
        const match = contents.match(expression);
        return match ? match[1] : fallback;
    }

    function updateMatugenPalette(contents) {
        matugenAccent = cssColor(contents, "accent_color", matugenAccent);
        matugenSurface = cssColor(contents, "window_bg_color", matugenSurface);
    }

    function save() {
        themeFile.setText(dark ? "dark\n" : "light\n");
    }

    property bool dark: false

    property color matugenAccent: "#e4c36c"
    property color matugenSurface: "#16130b"

    readonly property color barText: dark ? "#f4f5f7" : "#111827"
    readonly property color barMutedText: dark ? "#aeb8c4" : "#4b5563"
    readonly property color activeMutedText: "#4b5563"
    readonly property string topBarIconSuffix: dark ? "" : "_black"
    readonly property color barHover: dark ? "#1a4d7dff" : "#263b82f6"
    readonly property color barSelected: dark ? "#24527dff" : "#303b82f6"
    readonly property color indicatorHover: dark ? "#1affffff" : "#14000000"
    readonly property color indicatorActive: dark ? "#2bffffff" : "#24000000"

    readonly property color menuBackground: dark ? "#66000000" : "#66f2f5f9"
    readonly property color menuBorder: dark ? "#33485a" : "#c8d1dc"
    readonly property color menuText: dark ? "#f4f7fb" : "#111827"
    readonly property color menuMutedText: dark ? "#91a0ad" : "#5d6875"
    readonly property color menuDisabledText: dark ? "#71808e" : "#9aa5b1"
    readonly property color menuHover: dark ? "#263c4c" : "#dce9f8"
    readonly property color menuCheck: dark ? "#e6f0f8" : "#1f2937"

    // Shared semantic palette for the bar, notch, and panels.
    readonly property color notchBlack: "#000000"
    readonly property color panelSurface: "#191c21"
    readonly property color panelSurfaceRaised: "#20242b"
    readonly property color tileActive: "#f6f8fb"
    readonly property color tileHover: "#1c2026"
    // The notch uses a dark material in both shell variants, so its foreground
    // must not follow the light top-bar palette.
    readonly property color notchText: "#f4f5f7"
    readonly property color textPrimary: notchText
    readonly property color textMuted: "#9da4b0"
    readonly property color textQuiet: "#777e8b"
    readonly property color textOnDark: "#ffffff"
    readonly property color accent: "#4d7dff"
    readonly property color danger: "#ff6b72"
    readonly property color tileBorder: "#242831"
    readonly property color osdTrack: "#3a3a3a"
    readonly property color selection: "#557aa7"
    readonly property color batteryTrack: "#707070"
    // Use the midpoint between the Matugen surface and black as the notch
    // tint. It stays fully opaque at the top and fades to 70% at the bottom.
    readonly property color notchTint: Qt.rgba(matugenSurface.r * 0.5,
        matugenSurface.g * 0.5, matugenSurface.b * 0.5, 1.0)
    readonly property color notchGradientTop: notchTint
    readonly property color notchGradientMid: Qt.rgba(notchTint.r,
        notchTint.g, notchTint.b, 0.85)
    readonly property color notchGradientBottom: Qt.rgba(notchTint.r,
        notchTint.g, notchTint.b, 0.70)
    readonly property color notchShadow: Qt.rgba(notchTint.r,
        notchTint.g, notchTint.b, 0.35)
    readonly property color controlTile: "transparent"
    readonly property color controlTileHover: "#1affffff"
    readonly property color controlActiveTop: "#ffffffff"
    readonly property color controlActiveBottom: "#99ffffff"
    readonly property color controlTileActiveText: "#000000"
    readonly property color controlSliderTrack: "#38383f"
    readonly property color controlSliderKnob: "#e5e5e7"
    readonly property color controlSliderIcon: "#24242a"

    function toggle() {
        dark = !dark;
        save();
    }
}
