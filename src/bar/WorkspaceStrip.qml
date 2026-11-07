import Quickshell
import QtQuick

import qs.src.services

Item {
    id: strip

    required property var hostWindow
    readonly property string outputName: hostWindow.screen ? hostWindow.screen.name : ""
    readonly property var visibleWorkspaces: Workspaces.workspaces
        .filter(ws => !outputName || ws.output === outputName)
        .sort((a, b) => a.idx - b.idx)
    readonly property int activeIndex: visibleWorkspaces.findIndex(ws => ws.is_active)
    readonly property int iconSize: Math.round(17 * Config.uiScale)
    readonly property int iconSpacing: 9
    readonly property int workspaceSpacing: 4
    readonly property int cellHeight: Math.round(24 * Config.uiScale)
    readonly property int containerInset: Math.round(3 * Config.uiScale)
    readonly property int containerRadius: Math.round(10 * Config.uiScale)
    readonly property int workspaceRadius: containerRadius - containerInset
    readonly property int windowRadius: workspaceRadius - (cellHeight - windowHighlightSize) / 2
    readonly property int cellPaddingX: Math.round((cellHeight - iconSize) / 2)
    readonly property int activeX: {
        let x = 0;
        for (let i = 0; i < activeIndex; i++)
            x += workspaceWidth(visibleWorkspaces[i]) + workspaceSpacing;
        return x;
    }
    readonly property int activeWidth: activeIndex < 0
        ? 0 : workspaceWidth(visibleWorkspaces[activeIndex])
    readonly property int windowHighlightSize: cellHeight - 2
    readonly property var focusedWindow: Workspaces.windows.find(
        window => window.id === Workspaces.focusedWindowId) || null
    readonly property int focusedWorkspaceIndex: focusedWindow
        ? visibleWorkspaces.findIndex(ws => ws.id === focusedWindow.workspace_id) : -1
    readonly property int focusedIconIndex: focusedWorkspaceIndex < 0 ? -1
        : windowsFor(visibleWorkspaces[focusedWorkspaceIndex].id)
            .findIndex(window => window.id === Workspaces.focusedWindowId)
    readonly property int focusedWindowX: {
        if (focusedIconIndex < 0)
            return 0;
        let x = 0;
        for (let i = 0; i < focusedWorkspaceIndex; i++)
            x += workspaceWidth(visibleWorkspaces[i]) + workspaceSpacing;
        return x + cellPaddingX + focusedIconIndex * (iconSize + iconSpacing)
            - (windowHighlightSize - iconSize) / 2;
    }

    onActiveIndexChanged: Qt.callLater(function() { workspaceViewport.revealActive(); })

    anchors.left: parent.left
    anchors.leftMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(workspaceRow.implicitWidth + 2 * containerInset,
        Math.max(0, parent.width / 2 - 110))
    height: cellHeight + 2 * containerInset
    visible: visibleWorkspaces.length > 0

    function windowsFor(id) {
        return Workspaces.windows.filter(window => window.workspace_id === id);
    }

    function workspaceWidth(ws) {
        const count = windowsFor(ws.id).length;
        return (count ? count * iconSize + (count - 1) * iconSpacing : iconSize)
            + 2 * cellPaddingX;
    }

    function windowIcon(appId) {
        if (!appId)
            return Icon.getPath("window-generic");
        const entries = DesktopEntries.applications.values || [];
        const key = String(appId).toLowerCase().replace(/\.desktop$/, "");
        const entry = entries.find(app => app && String(app.id || "")
            .toLowerCase().replace(/\.desktop$/, "") === key);
        return Quickshell.iconPath(entry && entry.icon ? entry.icon : appId, true)
            || Icon.getPath("window-generic");
    }

    Rectangle {
        anchors.fill: parent
        radius: strip.containerRadius
        color: "#99000000"
    }

    Flickable {
        id: workspaceViewport
        anchors.fill: parent
        anchors.leftMargin: strip.containerInset
        anchors.rightMargin: strip.containerInset
        contentWidth: workspaceRow.implicitWidth
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width

        function revealActive() {
            if (strip.activeIndex < 0 || width <= 0)
                return;
            if (strip.activeX < contentX)
                contentX = strip.activeX;
            else if (strip.activeX + strip.activeWidth > contentX + width)
                contentX = strip.activeX + strip.activeWidth - width;
        }

        Rectangle {
            id: activeHighlight
            x: strip.activeX
            y: (workspaceViewport.height - height) / 2
            width: strip.activeWidth
            height: strip.cellHeight
            radius: strip.workspaceRadius
            color: "#38ffffff"
            visible: strip.activeIndex >= 0
            Behavior on x {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            x: strip.focusedWindowX
            y: (workspaceViewport.height - height) / 2
            width: strip.windowHighlightSize
            height: width
            radius: strip.windowRadius
            color: "#66ffffff"
            visible: strip.focusedIconIndex >= 0
            Behavior on x {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
        }

        Row {
            id: workspaceRow
            height: parent.height
            spacing: strip.workspaceSpacing

            Repeater {
                model: strip.visibleWorkspaces

                Rectangle {
                    id: workspaceItem
                    required property var modelData
                    readonly property var openWindows: strip.windowsFor(modelData.id)
                    readonly property bool active: modelData.is_active
                    width: strip.workspaceWidth(modelData)
                    height: strip.cellHeight
                    anchors.verticalCenter: parent.verticalCenter
                    radius: strip.workspaceRadius
                    color: !active && mouse.containsMouse ? "#22ffffff" : "transparent"

                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        topPadding: 2
                        visible: workspaceItem.openWindows.length === 0
                        text: String(workspaceItem.modelData.idx)
                        color: Theme.notchText
                        renderType: Text.NativeRendering
                        font.family: Config.fontFamily
                        font.pixelSize: Math.round(15 * Config.uiScale)
                        font.weight: 550
                        font.features: { "tnum": 1 }
                    }

                    Row {
                        anchors.centerIn: parent
                        visible: workspaceItem.openWindows.length > 0
                        spacing: strip.iconSpacing

                        Repeater {
                            model: workspaceItem.openWindows
                            Item {
                                required property var modelData
                                width: strip.iconSize
                                height: strip.iconSize

                                Image {
                                    anchors.fill: parent
                                    source: strip.windowIcon(modelData.app_id)
                                    sourceSize: Qt.size(36, 36)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Workspaces.focus(workspaceItem.modelData.idx)
                    }
                }
            }
        }
    }
}
