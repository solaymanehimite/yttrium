import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.src.services

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
    property int focusRevision: 0
    property int pendingExpandRevision: -1

    readonly property string bridgeBin: Quickshell.env("HOME") + "/.local/bin/noctalia-appmenu-bridge"
    readonly property string activeAppId: ToplevelManager.activeToplevel
        ? ToplevelManager.activeToplevel.appId
        : ""
    readonly property string activeAppName: appNameForId(activeAppId)
    // Some bridge fallbacks add a synthetic application-menu wrapper around
    // the real top-level entries. For example: Phi -> [Phi, Window]. Keep the
    // wrapper out of the rendered menu or the app menu contains a duplicate
    // "Phi" submenu and the native entries appear in the wrong place.
    readonly property var topLevelMenus: {
        const children = snapshot && snapshot.menu && snapshot.menu.children
            ? snapshot.menu.children
            : [];
        if (children.length > 0 && children[0].children
                && children[0].children.length > 0
                && normalizedLabel(children[0].label) === normalizedLabel(children[0].children[0].label))
            return children[0].children.concat(children.slice(1));
        return children;
    }
    readonly property var appMenuNode: {
        for (let i = 0; i < topLevelMenus.length; i++) {
            const item = topLevelMenus[i];
            if (item && isApplicationMenuLabel(item.label))
                return item;
        }
        return null;
    }
    readonly property var nativeMenus: appMenuNode
        ? topLevelMenus.filter(item => item !== appMenuNode)
        : topLevelMenus
    readonly property int focusWindowId: snapshot && snapshot.focus_winid ? snapshot.focus_winid : 0

    Accessible.role: Accessible.MenuBar
    Accessible.name: "Application menu"

    function normalizedLabel(value) {
        return String(value || "").replace(/[\s_\-–—:]+/g, "").trim().toLowerCase();
    }

    function isApplicationMenuLabel(label) {
        const candidate = normalizedLabel(label);
        if (!candidate)
            return false;

        const values = [
            activeAppName,
            snapshot ? snapshot.title : "",
            snapshot ? snapshot.app_id : ""
        ];
        for (let i = 0; i < values.length; i++) {
            const value = normalizedLabel(values[i]);
            if (!value)
                continue;
            // Desktop entries commonly say "Firefox" while the window or
            // bridge identifies it as "Mozilla Firefox" (and vice versa).
            if (candidate === value
                    || (candidate.length >= 4 && value.indexOf(candidate) !== -1)
                    || (value.length >= 4 && candidate.indexOf(value) !== -1))
                return true;
        }
        return false;
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

    function appIdKey(appId) {
        return String(appId || "").replace(/\.desktop$/i, "").toLowerCase();
    }

    // A snapshot is only useful while it belongs to the currently focused
    // toplevel. The bridge can be slow (or stop receiving compositor events),
    // so keeping its last successful payload would otherwise pin the menu of
    // an old window indefinitely.
    function snapshotBelongsToActiveWindow(value) {
        if (!value || value.v !== 1)
            return false;

        const active = ToplevelManager.activeToplevel;
        if (!active)
            return !value.app_id && (!value.menu || !value.menu.children
                    || value.menu.children.length === 0);

        const snapshotAppId = appIdKey(value.app_id);
        const activeAppId = appIdKey(active.appId);
        if (!snapshotAppId || !activeAppId || snapshotAppId !== activeAppId)
            return false;

        // Firefox, Electron, and document-based GTK apps can expose different
        // title strings through AT-SPI and the compositor. The app id is the
        // stable association; rejecting on title mismatch leaves the bar empty.
        return true;
    }

    function queueSnapshot(value) {
        pendingSnapshot = {
            value: value,
            revision: focusRevision
        };
        Qt.callLater(applyPendingSnapshot);
    }

    function applyPendingSnapshot() {
        if (pendingSnapshot === undefined)
            return;

        const pending = pendingSnapshot;
        pendingSnapshot = undefined;
        if (pending.revision !== focusRevision)
            return;

        const nextSnapshot = pending.value;
        if (!nextSnapshot || nextSnapshot.v !== 1) {
            snapshot = null;
            return;
        }

        // FileView can replay an old active.json after focus changes. Ignore
        // it rather than allowing it to resurrect the previous app's menu.
        if (!snapshotBelongsToActiveWindow(nextSnapshot))
            return;

        menuOverlay.close();
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
        pendingExpandRevision = focusRevision;
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
                const expandRevision = globalMenuPane.pendingExpandRevision;
                globalMenuPane.pendingExpandAnchor = null;
                globalMenuPane.pendingExpandItem = null;
                globalMenuPane.pendingExpandRevision = -1;

                if (!anchorItem || !original
                        || expandRevision !== globalMenuPane.focusRevision
                        || !globalMenuPane.snapshotBelongsToActiveWindow(globalMenuPane.snapshot))
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
            const pending = globalMenuPane.pendingSnapshot;
            const pendingBelongs = pending !== undefined
                && globalMenuPane.snapshotBelongsToActiveWindow(pending.value);
            const currentBelongs = globalMenuPane.snapshot !== null
                && globalMenuPane.snapshotBelongsToActiveWindow(globalMenuPane.snapshot);

            globalMenuPane.focusRevision += 1;
            globalMenuPane.pendingExpandRevision = -1;
            globalMenuPane.pendingExpandAnchor = null;
            globalMenuPane.pendingExpandItem = null;
            menuOverlay.close();

            // Keep a payload that arrived just before the compositor's focus
            // notification, but never keep data belonging to the old window.
            if (!currentBelongs)
                globalMenuPane.snapshot = null;

            if (pendingBelongs) {
                pending.revision = globalMenuPane.focusRevision;
                globalMenuPane.pendingSnapshot = pending;
            } else {
                globalMenuPane.pendingSnapshot = undefined;
            }
        }
    }

    Row {
        id: menuRow
        x: 15
        anchors.verticalCenter: parent.verticalCenter
        height: globalMenuPane.height
        spacing: Config.space1

        Item {
            id: appButton
            readonly property bool isTopMenuButton: true
            readonly property var menuEntry: globalMenuPane.appMenuNode
            y: 0
            width: Math.min(appLabel.implicitWidth + 18, 148)
            height: menuRow.height

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
                    ? Theme.barSelected
                    : (appMouse.containsMouse && appButton.interactive ? Theme.barHover : "transparent")
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
                color: Theme.barText
                elide: Text.ElideRight
                font.family: Config.fontFamily
                font.pixelSize: Math.round(17 * Config.uiScale)
                font.weight: 700
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
                y: 0
                width: visible ? Math.min(menuLabel.implicitWidth + 18, 116) : 0
                height: menuRow.height

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
                        ? Theme.barSelected
                        : (buttonMouse.containsMouse && menuButton.itemEnabled ? Theme.barHover : "transparent")
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
                    color: menuButton.itemEnabled ? Theme.barText : Theme.barMutedText
                    elide: Text.ElideRight
                    font.family: Config.fontFamily
                    font.pixelSize: Math.round(16 * Config.uiScale)
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
        duration: Config.menuAnimation
        easing.type: Easing.OutCubic
    }
}
