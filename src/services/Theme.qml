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

    function save() {
        themeFile.setText(dark ? "dark\n" : "light\n");
    }

    // The notch deliberately does not use these colors. This palette is only
    // for the top menu bar and its popup menus.
    property bool dark: false

    readonly property color barText: dark ? "#f4f5f7" : "#111827"
    readonly property color barMutedText: dark ? "#aeb8c4" : "#4b5563"
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

    function toggle() {
        dark = !dark;
        save();
    }
}
