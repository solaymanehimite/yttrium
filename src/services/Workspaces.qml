pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: service

    property var workspaces: []
    property var windows: []
    property var focusedWindowId: null

    function refresh() {
        const workspaceObjects = Hyprland.workspaces.values || [];
        workspaces = workspaceObjects
            .filter(ws => ws.id > 0)
            .map(ws => ({
                id: ws.id,
                idx: ws.id,
                name: ws.name,
                output: ws.monitor ? ws.monitor.name : "",
                is_active: ws.active,
                is_focused: ws.focused,
                is_urgent: ws.urgent
            }))
            .sort((a, b) => a.idx - b.idx);

        const toplevelObjects = Hyprland.toplevels.values || [];
        windows = toplevelObjects.map(window => {
            const raw = window.lastIpcObject || {};
            const workspace = window.workspace;
            return {
                id: window.address,
                app_id: raw.class || raw.initialClass || "",
                workspace_id: workspace ? workspace.id : -1,
                is_focused: window.activated,
                title: window.title
            };
        }).filter(window => window.workspace_id > 0);

        const focused = windows.find(window => window.is_focused);
        focusedWindowId = focused ? focused.id : null;
    }

    function focus(index) {
        Hyprland.dispatch("workspace " + String(index));
        refresh();
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: service.refresh()
    }
}
