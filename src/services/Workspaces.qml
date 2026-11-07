pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: service

    property var workspaces: []
    property var windows: []
    property var focusedWindowId: null

    function consume(line) {
        let event;
        try {
            event = JSON.parse(line);
        } catch (error) {
            return;
        }

        if (event.WorkspacesChanged) {
            workspaces = event.WorkspacesChanged.workspaces;
        } else if (event.WorkspaceActivated) {
            const change = event.WorkspaceActivated;
            const current = workspaces.find(ws => ws.id === change.id);
            workspaces = workspaces.map(ws => Object.assign({}, ws, {
                is_active: ws.id === change.id ? true
                    : (current && ws.output === current.output ? false : ws.is_active),
                is_focused: change.focused ? ws.id === change.id : ws.is_focused
            }));
        } else if (event.WorkspaceActiveWindowChanged) {
            const change = event.WorkspaceActiveWindowChanged;
            workspaces = workspaces.map(ws => ws.id === change.workspace_id
                ? Object.assign({}, ws, { active_window_id: change.active_window_id }) : ws);
        } else if (event.WorkspaceUrgencyChanged) {
            const change = event.WorkspaceUrgencyChanged;
            workspaces = workspaces.map(ws => ws.id === change.id
                ? Object.assign({}, ws, { is_urgent: change.urgent }) : ws);
        } else if (event.WindowsChanged) {
            windows = event.WindowsChanged.windows;
            const focused = windows.find(window => window.is_focused);
            focusedWindowId = focused ? focused.id : null;
        } else if (event.WindowOpenedOrChanged) {
            const window = event.WindowOpenedOrChanged.window;
            const index = windows.findIndex(item => item.id === window.id);
            if (index < 0) {
                windows = windows.concat([window]);
            } else {
                const next = windows.slice();
                next[index] = window;
                windows = next;
            }
            if (window.is_focused)
                focusedWindowId = window.id;
        } else if (event.WindowFocusChanged) {
            focusedWindowId = event.WindowFocusChanged.id;
        } else if (event.WindowClosed) {
            const id = event.WindowClosed.id;
            windows = windows.filter(window => window.id !== id);
            if (focusedWindowId === id)
                focusedWindowId = null;
        }
    }

    function focus(index) {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(index)]);
    }

    Process {
        id: events
        command: ["niri", "msg", "-j", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => service.consume(data)
        }
        onExited: reconnect.start()
    }

    Timer {
        id: reconnect
        interval: 1000
        onTriggered: events.running = true
    }

}
