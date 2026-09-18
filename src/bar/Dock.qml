import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: dock

    anchors {
        bottom: true
        left: true
        right: true
    }

    implicitHeight: 116
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    mask: Region {
        Region {
            item: revealTrigger
        }
        Region {
            x: frame.x
            y: frame.y + (dock.revealed ? 0 : dock.hiddenOffset)
            width: frame.width
            height: frame.height
            radius: frame.radius
        }
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-dock"

    readonly property int slotWidth: 50
    readonly property int slotHeight: 46
    readonly property int separatorWidth: 12
    readonly property int framePadding: 7
    readonly property int frameHeight: 60
    readonly property int frameBottomMargin: 4
    readonly property int revealZoneHeight: 32
    readonly property int peekHeight: 6
    readonly property int hiddenOffset: frameHeight + frameBottomMargin - peekHeight
    readonly property int hideDelay: 220
    readonly property string whiteSurIconRoot: Quickshell.env("HOME") + "/.local/share/icons/WhiteSur-light/apps/scalable/"
    readonly property var pinnedAppIds: [
        "vicinae",
        "org.gnome.Nautilus",
        "org.mozilla.firefox",
        "Alacritty",
        "md.obsidian.Obsidian",
        "ai.opencode.desktop",
        "graphics.friction.Friction"
    ]
    property int modelRevision: 0
    property int iconRevision: 0
    property bool bottomTriggerHovered: false
    property bool frameHovered: false
    property bool iconHovered: false
    property bool revealed: false

    readonly property var runningApps: {
        // Force this binding to refresh when the compositor changes its list.
        modelRevision;

        const windows = ToplevelManager.toplevels.values || [];
        const grouped = {};
        const apps = [];

        for (let i = 0; i < windows.length; i++) {
            const window = windows[i];
            if (!window || window.parent || !window.appId)
                continue;

            const key = dock.normalizeAppId(window.appId);
            if (!key)
                continue;

            if (!grouped[key]) {
                grouped[key] = {
                    appId: window.appId,
                    toplevels: []
                };
                apps.push(grouped[key]);
            }

            grouped[key].toplevels.push(window);
        }

        return apps;
    }

    readonly property var dockApps: {
        const running = runningApps;
        const runningById = {};

        for (let i = 0; i < running.length; i++) {
            const key = dock.normalizeAppId(running[i].appId);
            if (key)
                runningById[key] = running[i];
        }

        const pinned = [];
        const pinnedKeys = {};
        for (let i = 0; i < pinnedAppIds.length; i++) {
            const appId = pinnedAppIds[i];
            const key = dock.normalizeAppId(appId);
            if (!key || pinnedKeys[key])
                continue;

            pinnedKeys[key] = true;
            const runningApp = runningById[key];
            pinned.push({
                appId: runningApp ? runningApp.appId : appId,
                toplevels: runningApp ? runningApp.toplevels : [],
                pinned: true,
                separator: false
            });
        }

        const unpinned = [];
        for (let i = 0; i < running.length; i++) {
            const app = running[i];
            if (!pinnedKeys[dock.normalizeAppId(app.appId)]) {
                unpinned.push({
                    appId: app.appId,
                    toplevels: app.toplevels,
                    pinned: false,
                    separator: false
                });
            }
        }

        if (pinned.length === 0)
            return unpinned;
        if (unpinned.length === 0)
            return pinned;

        return pinned.concat([{ separator: true }], unpinned);
    }

    readonly property bool hasApps: dockApps.length > 0
    readonly property int maxFrameWidth: Math.max(160, width - 24)
    property var hoveredButton: null
    property string hoveredLabel: ""
    property real hoveredCenterX: 0

    visible: hasApps

    Connections {
        target: ToplevelManager.toplevels

        function onValuesChanged() {
            dock.modelRevision += 1;
        }
    }

    Connections {
        target: DesktopEntries.applications

        function onValuesChanged() {
            dock.iconRevision += 1;
        }
    }

    function normalizeAppId(appId) {
        const normalized = (appId || "").toString().toLowerCase().replace(/\.desktop$/, "");
        if (normalized === "graphics.friction.friction" || normalized === "friction")
            return "friction";
        if (normalized === "md.obsidian.obsidian" || normalized === "obsidian")
            return "obsidian";
        if (normalized === "ai.opencode")
            return "opencode";
        return normalized;
    }

    function entryFor(appId) {
        if (!appId)
            return null;

        try {
            return DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId) || null;
        } catch (error) {
            return null;
        }
    }

    function whiteSurIconFor(appId) {
        const entry = entryFor(appId);
        const iconName = entry && entry.icon ? entry.icon.toString() : "";
        const aliases = {
            "vicinae": "vicinae",
            "org.gnome.nautilus": "file-manager",
            "org.mozilla.firefox": "firefox",
            "alacritty": "alacritty",
            "md.obsidian.obsidian": "obsidian",
            "obsidian": "obsidian"
        };
        const themeIcon = aliases[normalizeAppId(appId)] || aliases[normalizeAppId(iconName)];
        return themeIcon ? "file://" + whiteSurIconRoot + themeIcon + ".svg" : "";
    }

    function iconFor(appId) {
        const entry = entryFor(appId);
        if (entry && entry.icon) {
            const icon = entry.icon.toString();
            if (icon.startsWith("/") || icon.startsWith("file://"))
                return icon.startsWith("/") ? "file://" + icon : icon;

            const entryIcon = Quickshell.iconPath(icon, true);
            if (entryIcon)
                return entryIcon;
        }

        const appIcon = Quickshell.iconPath(normalizeAppId(appId), true);
        if (appIcon)
            return appIcon;

        return Quickshell.iconPath("application-x-executable", true);
    }

    function nameFor(appData) {
        const entry = entryFor(appData.appId);
        if (entry && entry.name)
            return entry.name;

        for (let i = 0; i < appData.toplevels.length; i++) {
            const title = appData.toplevels[i].title;
            if (title)
                return title;
        }

        const words = (appData.appId || "Application").replace(/[._-]+/g, " ").trim().split(" ");
        for (let i = 0; i < words.length; i++) {
            if (words[i])
                words[i] = words[i].charAt(0).toUpperCase() + words[i].slice(1);
        }
        return words.join(" ") || "Application";
    }

    function initialsFor(label) {
        const words = label.trim().split(/\s+/).filter(word => word.length > 0);
        if (words.length > 1)
            return (words[0].charAt(0) + words[1].charAt(0)).toUpperCase();
        return label.trim().slice(0, 2).toUpperCase() || "?";
    }

    function focusApp(appData) {
        if (!appData || !appData.toplevels)
            return;

        const windows = ToplevelManager.toplevels.values || [];
        const active = ToplevelManager.activeToplevel;
        let target = null;

        for (let i = 0; i < appData.toplevels.length; i++) {
            const window = appData.toplevels[i];
            if (!window || !windows.includes(window))
                continue;

            if (window === active) {
                target = window;
                break;
            }

            if (!target || (target.minimized && !window.minimized))
                target = window;
        }

        if (target)
            target.activate();
    }

    function launchApp(appId) {
        if (normalizeAppId(appId) === "vicinae") {
            Quickshell.execDetached(["vicinae", "toggle"]);
            return;
        }

        const entry = entryFor(appId);
        if (entry)
            entry.execute();
    }

    function activateApp(appData) {
        if (!appData || appData.separator)
            return;

        if (appData.toplevels && appData.toplevels.length > 0)
            focusApp(appData);
        else if (appData.pinned)
            launchApp(appData.appId);
    }

    function showTooltip(button) {
        const point = button.mapToItem(frame, button.width / 2, 0);
        hoveredButton = button;
        hoveredLabel = button.label;
        hoveredCenterX = point.x;
        iconHovered = true;
        updateRevealState();
    }

    function hideTooltip(button) {
        if (hoveredButton === button) {
            hoveredButton = null;
            hoveredLabel = "";
            iconHovered = false;
            updateRevealState();
        }
    }

    function updateRevealState() {
        const shouldReveal = bottomTriggerHovered || frameHovered || iconHovered;
        if (shouldReveal) {
            hideTimer.stop();
            if (!revealed)
                revealed = true;
            return;
        }

        if (revealed)
            hideTimer.restart();
    }

    function hideDock() {
        if (bottomTriggerHovered || frameHovered || iconHovered)
            return;

        revealed = false;
        hoveredButton = null;
        hoveredLabel = "";
    }

    Timer {
        id: hideTimer
        interval: dock.hideDelay
        repeat: false
        onTriggered: dock.hideDock()
    }

    MouseArea {
        id: revealTrigger
        x: 0
        y: dock.implicitHeight - dock.revealZoneHeight
        width: parent.width
        height: dock.revealZoneHeight
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: {
            dock.bottomTriggerHovered = true;
            dock.updateRevealState();
        }
        onExited: {
            dock.bottomTriggerHovered = false;
            dock.updateRevealState();
        }
    }

    Rectangle {
        id: frame
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: dock.frameBottomMargin
        }
        width: Math.min(appRow.width, dock.maxFrameWidth)
        height: dock.frameHeight
        radius: 18
        color: "#8a141414"
        border.width: 2
        border.color: "#80222222"
        transform: Translate {
            y: dock.revealed ? 0 : dock.hiddenOffset
            Behavior on y {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
        }

        HoverHandler {
            id: frameHover
            onHoveredChanged: {
                dock.frameHovered = frameHover.hovered;
                dock.updateRevealState();
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Flickable {
            id: appViewport
            anchors.fill: parent
            clip: true
            contentWidth: Math.max(width, appRow.width)
            contentHeight: height
            interactive: contentWidth > width
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: appRow
                x: Math.max(0, (appViewport.contentWidth - width) / 2)
                y: 0
                width: {
                    const items = dock.dockApps;
                    let contentWidth = 0;
                    for (let i = 0; i < items.length; i++)
                        contentWidth += items[i].separator ? dock.separatorWidth : dock.slotWidth;
                    if (items.length > 0)
                        contentWidth += dock.framePadding * 2;
                    return contentWidth + Math.max(0, items.length - 1) * spacing;
                }
                height: appViewport.height
                spacing: 0

                Repeater {
                    id: appRepeater
                    model: dock.dockApps

                    delegate: Item {
                        id: appButton
                        required property var modelData
                        required property int index

                        width: appButton.isSeparator ? dock.separatorWidth : dock.slotWidth + (appButton.index === 0 ? dock.framePadding : 0) + (appButton.index === dock.dockApps.length - 1 ? dock.framePadding : 0)
                        height: parent.height
                        anchors.verticalCenter: parent.verticalCenter

                        readonly property var appData: modelData
                        readonly property bool isSeparator: appData && appData.separator === true
                        readonly property string label: {
                            if (appButton.isSeparator)
                                return "";
                            dock.iconRevision;
                            return dock.nameFor(appData);
                        }
                        readonly property bool active: {
                            if (appButton.isSeparator)
                                return false;
                            const activeWindow = ToplevelManager.activeToplevel;
                            return activeWindow !== null && appData.toplevels.includes(activeWindow);
                        }
                        readonly property string themeIconSource: {
                            if (appButton.isSeparator)
                                return "";
                            dock.iconRevision;
                            return dock.whiteSurIconFor(appData.appId);
                        }
                        readonly property string fallbackIconSource: {
                            if (appButton.isSeparator)
                                return "";
                            dock.iconRevision;
                            return dock.iconFor(appData.appId);
                        }

                        Rectangle {
                            visible: appButton.isSeparator
                            anchors.centerIn: parent
                            width: 1
                            height: 30
                            color: "#90222222"
                        }

                        Item {
                            id: iconWrap
                            visible: !appButton.isSeparator
                            width: 40
                            height: 40
                            anchors.centerIn: parent
                            transformOrigin: Item.Bottom
                            scale: appMouse.containsMouse ? 1.14 : 1.0
                            opacity: appButton.active ? 1.0 : 0.9

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 140
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.05
                                }
                            }

                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                width: 38
                                height: 38
                                sourceSize.width: 38
                                sourceSize.height: 38
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                source: appButton.themeIconSource
                            }

                            Image {
                                id: fallbackIcon
                                visible: appIcon.status !== Image.Ready
                                anchors.centerIn: parent
                                width: 38
                                height: 38
                                sourceSize.width: 38
                                sourceSize.height: 38
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                source: appButton.fallbackIconSource
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: fallbackIcon.status === Image.Error || (appButton.fallbackIconSource === "" && appIcon.status !== Image.Ready)
                                text: dock.initialsFor(appButton.label)
                                color: "white"
                                font.family: "Google Sans Flex"
                                font.pixelSize: 16
                                font.weight: 600
                            }
                        }

                        Row {
                            id: windowDots
                            visible: !appButton.isSeparator && appData.toplevels.length > 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: dock.framePadding
                            height: 3
                            spacing: 2

                            Repeater {
                                model: appButton.isSeparator ? 0 : appData.toplevels.length

                                delegate: Rectangle {
                                    width: 4
                                    height: 3
                                    radius: 1.5
                                    color: "#d9ffffff"
                                }
                            }
                        }

                        MouseArea {
                            id: appMouse
                            visible: !appButton.isSeparator
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: dock.showTooltip(appButton)
                            onExited: dock.hideTooltip(appButton)
                            onClicked: dock.activateApp(appData)
                        }
                    }
                }
            }

            WheelHandler {
                enabled: appViewport.contentWidth > appViewport.width
                onWheel: function(event) {
                    const delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
                    appViewport.contentX = Math.max(0, Math.min(appViewport.contentWidth - appViewport.width, appViewport.contentX - delta));
                    event.accepted = true;
                }
            }
        }

        Rectangle {
            id: appTooltip
            visible: dock.hoveredButton !== null
            z: 20
            x: Math.max(6, Math.min(frame.width - width - 6, dock.hoveredCenterX - width / 2))
            y: -height - 8
            width: Math.min(220, appTooltipText.implicitWidth + 16)
            height: appTooltipText.implicitHeight + 8
            radius: 8
            color: "#ed171717"
            border.width: 1
            border.color: "#35ffffff"

            Text {
                id: appTooltipText
                anchors.centerIn: parent
                width: parent.width - 12
                color: "white"
                text: dock.hoveredLabel
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                font.family: "Google Sans Flex"
                font.pixelSize: 12
                font.weight: 500
            }
        }
    }
}
