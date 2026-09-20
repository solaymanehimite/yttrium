import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Pane {
    id: globalMenuPane

    required property var barWindow

    padding: 0
    height: parent ? parent.height : 30
    width: Math.min(implicitWidth, parent ? Math.max(220, parent.width / 2 - 220) : implicitWidth)
    implicitWidth: menuRow.implicitWidth + 22
    clip: true

    background: null

    property var snapshot: null
    property var pendingSnapshot: undefined
    property var pendingExpandItem: null
    property var pendingExpandAnchor: null

    readonly property string bridgeBin: Quickshell.env("HOME") + "/.local/bin/noctalia-appmenu-bridge"
    readonly property string activeAppId: snapshot && snapshot.app_id
        ? snapshot.app_id
        : (ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.appId : "")
    readonly property string activeAppName: appNameForId(activeAppId)
    readonly property var topLevelMenus: snapshot && snapshot.menu && snapshot.menu.children
        ? snapshot.menu.children
        : []
    readonly property var appMenuNode: {
        if (topLevelMenus.length === 0)
            return null;
        const first = topLevelMenus[0];
        return normalizedLabel(first.label) === normalizedLabel(activeAppName) ? first : null;
    }
    readonly property var nativeMenus: appMenuNode ? topLevelMenus.slice(1) : topLevelMenus
    readonly property int focusWindowId: snapshot && snapshot.focus_winid ? snapshot.focus_winid : 0

    Accessible.role: Accessible.MenuBar
    Accessible.name: "Application menu"

    function normalizedLabel(value) {
        return String(value || "").replace(/_/g, "").trim().toLowerCase();
    }

    function cleanLabel(value) {
        return String(value || "").replace(/_/g, "");
    }

    function itemKey(item) {
        if (!item)
            return "";
        return String(item.service || "") + "|" + String(item.path || "") + "|" + cleanLabel(item.label);
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

    function appNameForId(appId) {
        if (!appId)
            return "Fedora";

        const entry = entryFor(appId);
        if (entry && entry.name)
            return entry.name;

        const rawId = String(appId).replace(/\.desktop$/i, "");
        const parts = rawId.split(/[._-]+/).filter(part => part.length > 0);
        const ignored = ["com", "org", "net", "io", "desktop"];
        while (parts.length > 1 && ignored.indexOf(parts[0].toLowerCase()) !== -1)
            parts.shift();

        for (let i = 0; i < parts.length; i++)
            parts[i] = parts[i].charAt(0).toUpperCase() + parts[i].slice(1);

        return parts.join(" ") || "Application";
    }

    function queueSnapshot(value) {
        pendingSnapshot = value;
        Qt.callLater(applyPendingSnapshot);
    }

    function applyPendingSnapshot() {
        if (pendingSnapshot === undefined)
            return;

        const nextSnapshot = pendingSnapshot;
        pendingSnapshot = undefined;
        menuOverlay.close();

        if (!nextSnapshot || nextSnapshot.v !== 1) {
            snapshot = null;
            return;
        }

        snapshot = nextSnapshot;
    }

    function openTopMenu(anchorItem, menuItem) {
        if (!anchorItem || !menuItem || menuItem.enabled === false)
            return;

        if (menuOverlay.isOpen && itemKey(menuOverlay.rootMenu) === itemKey(menuItem)) {
            menuOverlay.close();
            return;
        }

        if (menuItem.children && menuItem.children.length > 0) {
            menuOverlay.openAt(anchorItem, menuItem);
            return;
        }

        if (menuItem.type === "submenu" && menuItem.service && menuItem.service !== "::synthetic") {
            expandTopMenu(anchorItem, menuItem);
            return;
        }

        activateMenuItem(menuItem);
    }

    function switchTopMenuOnHover(anchorItem, menuItem) {
        if (!menuOverlay.isOpen || !anchorItem || !menuItem)
            return;
        if (itemKey(menuOverlay.rootMenu) === itemKey(menuItem))
            return;

        openTopMenu(anchorItem, menuItem);
    }

    function topMenuButtonAt(globalX, globalY) {
        const items = menuRow.children;
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (!item.isTopMenuButton || !item.visible || !item.menuEntry)
                continue;

            const point = item.mapFromGlobal(globalX, globalY);
            if (point.x >= 0 && point.x <= item.width
                    && point.y >= -4 && point.y <= item.height + 4)
                return item;
        }
        return null;
    }

    function hoverTopMenuAt(globalX, globalY) {
        const button = topMenuButtonAt(globalX, globalY);
        if (button)
            switchTopMenuOnHover(button, button.menuEntry);
    }

    function clickTopMenuAt(globalX, globalY) {
        const button = topMenuButtonAt(globalX, globalY);
        if (button)
            openTopMenu(button, button.menuEntry);
    }

    function expandTopMenu(anchorItem, menuItem) {
        if (expandProcess.running)
            return;

        pendingExpandAnchor = anchorItem;
        pendingExpandItem = menuItem;
        const command = [bridgeBin, "atspi-expand", menuItem.service, menuItem.path];
        if (focusWindowId > 0)
            command.push("--winid", String(focusWindowId));
        expandProcess.command = command;
        expandProcess.running = true;
    }

    function activateMenuItem(item) {
        if (!item || !item.service || !item.path || item.enabled === false)
            return;

        menuOverlay.close();
        const command = [bridgeBin, "atspi-click", item.service, item.path];
        if (focusWindowId > 0)
            command.push("--winid", String(focusWindowId));

        Qt.callLater(function() {
            clickProcess.exec(command);
        });
    }

    IpcHandler {
        target: "appmenu"

        function update(json: string): void {
            try {
                globalMenuPane.queueSnapshot(JSON.parse(json));
            } catch (error) {
                console.warn("[appmenu] Ignored malformed bridge update:", error);
            }
        }
    }

    FileView {
        id: activeMenuFile
        path: {
            const cacheHome = Quickshell.env("XDG_CACHE_HOME");
            const base = cacheHome && cacheHome.length > 0
                ? cacheHome
                : Quickshell.env("HOME") + "/.cache";
            return base + "/noctalia-appmenu/active.json";
        }
        watchChanges: true
        blockLoading: false
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            try {
                const content = text();
                if (content && content.length > 0)
                    globalMenuPane.queueSnapshot(JSON.parse(content));
            } catch (error) {
                console.warn("[appmenu] Waiting for a complete menu snapshot:", error);
            }
        }
    }

    Process {
        id: clickProcess
    }

    Process {
        id: expandProcess

        stdout: StdioCollector {
            id: expandOutput

            onStreamFinished: {
                const anchorItem = globalMenuPane.pendingExpandAnchor;
                const original = globalMenuPane.pendingExpandItem;
                globalMenuPane.pendingExpandAnchor = null;
                globalMenuPane.pendingExpandItem = null;

                if (!anchorItem || !original)
                    return;

                let children = [];
                try {
                    children = JSON.parse(expandOutput.text || "[]");
                } catch (error) {
                    console.warn("[appmenu] Could not read expanded menu:", error);
                }

                if (children && children.length > 0) {
                    const expanded = {
                        id: original.id,
                        label: original.label,
                        type: original.type,
                        enabled: original.enabled,
                        visible: original.visible,
                        icon_name: original.icon_name,
                        toggle_type: original.toggle_type,
                        toggle_state: original.toggle_state,
                        service: original.service,
                        path: original.path,
                        children: children
                    };
                    menuOverlay.openAt(anchorItem, expanded);
                }
            }
        }
    }

    Connections {
        target: ToplevelManager

        function onActiveToplevelChanged() {
            menuOverlay.close();
        }
    }

    Row {
        id: menuRow
        x: 15
        height: globalMenuPane.height
        spacing: 1

        Item {
            id: appButton
            readonly property bool isTopMenuButton: true
            readonly property var menuEntry: globalMenuPane.appMenuNode
            y: 1
            width: Math.min(appLabel.implicitWidth + 16, 148)
            height: menuRow.height - 1

            readonly property bool interactive: globalMenuPane.appMenuNode !== null
            readonly property bool selected: menuOverlay.isOpen
                && globalMenuPane.itemKey(menuOverlay.rootMenu) === globalMenuPane.itemKey(globalMenuPane.appMenuNode)

            Accessible.role: interactive ? Accessible.MenuItem : Accessible.StaticText
            Accessible.name: globalMenuPane.activeAppName
            Accessible.focusable: interactive

            Rectangle {
                anchors {
                    fill: parent
                    topMargin: 3
                    bottomMargin: 3
                }
                radius: 8
                color: appButton.selected
                    ? "#32ffffff"
                    : (appMouse.containsMouse && appButton.interactive ? "#1cffffff" : "transparent")
            }

            Text {
                id: appLabel
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                text: globalMenuPane.activeAppName
                color: "white"
                elide: Text.ElideRight
                font.family: "Google Sans Flex"
                font.pixelSize: 15
                font.weight: 650
            }

            MouseArea {
                id: appMouse
                anchors {
                    fill: parent
                    topMargin: -4
                    bottomMargin: -4
                }
                enabled: appButton.interactive
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onEntered: globalMenuPane.switchTopMenuOnHover(appButton, globalMenuPane.appMenuNode)
                onClicked: globalMenuPane.openTopMenu(appButton, globalMenuPane.appMenuNode)
            }
        }

        Repeater {
            model: globalMenuPane.nativeMenus

            delegate: Item {
                id: menuButton
                required property var modelData
                readonly property bool isTopMenuButton: true
                readonly property var menuEntry: modelData

                visible: modelData && modelData.visible !== false && modelData.type !== "separator"
                y: 1
                width: visible ? Math.min(menuLabel.implicitWidth + 16, 116) : 0
                height: menuRow.height - 1

                readonly property bool itemEnabled: modelData && modelData.enabled !== false
                readonly property bool selected: menuOverlay.isOpen
                    && globalMenuPane.itemKey(menuOverlay.rootMenu) === globalMenuPane.itemKey(modelData)

                Accessible.role: Accessible.MenuItem
                Accessible.name: globalMenuPane.cleanLabel(modelData ? modelData.label : "")
                Accessible.focusable: itemEnabled

                Rectangle {
                    anchors {
                        fill: parent
                        topMargin: 3
                        bottomMargin: 3
                    }
                    radius: 8
                    color: menuButton.selected
                        ? "#32ffffff"
                        : (buttonMouse.containsMouse && menuButton.itemEnabled ? "#1cffffff" : "transparent")
                }

                Text {
                    id: menuLabel
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 8
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: globalMenuPane.cleanLabel(menuButton.modelData ? menuButton.modelData.label : "")
                    color: menuButton.itemEnabled ? "white" : "#78ffffff"
                    elide: Text.ElideRight
                    font.family: "Google Sans Flex"
                    font.pixelSize: 15
                    font.weight: 500
                }

                MouseArea {
                    id: buttonMouse
                    anchors {
                        fill: parent
                        topMargin: -4
                        bottomMargin: -4
                    }
                    enabled: menuButton.itemEnabled
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: globalMenuPane.switchTopMenuOnHover(menuButton, menuButton.modelData)
                    onClicked: globalMenuPane.openTopMenu(menuButton, menuButton.modelData)
                }
            }
        }
    }

    AppMenuOverlay {
        id: menuOverlay
        hostWindow: globalMenuPane.barWindow
        menuController: globalMenuPane
        onItemActivated: function(item) {
            globalMenuPane.activateMenuItem(item);
        }
    }

    opacity: 0
    Component.onCompleted: entrance.start()

    NumberAnimation {
        id: entrance
        target: globalMenuPane
        property: "opacity"
        from: 0
        to: 1
        duration: 220
        easing.type: Easing.OutCubic
    }
}
