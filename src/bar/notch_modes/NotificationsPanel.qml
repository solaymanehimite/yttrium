import QtQuick
import qs.src.services

Item {
    id: root

    required property var notchWindow
    readonly property bool active: notchWindow.menuOpen
        && notchWindow.launcherMode === "notifications"

    anchors.fill: parent
    anchors.leftMargin: 280
    anchors.rightMargin: 18
    anchors.topMargin: 18
    anchors.bottomMargin: 18
    visible: active || opacity > 0
    enabled: active
    focus: active
    opacity: active ? 1 : 0
    scale: active ? 1 : 0.92

    Behavior on opacity {
        NumberAnimation {
            duration: Tokens.panelAnimation
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Tokens.panelAnimation
            easing.type: Easing.OutCubic
        }
    }

    Keys.onEscapePressed: root.notchWindow.openControlCenter()

    NotificationList {
        anchors.fill: parent
        notchWindow: root.notchWindow
    }
}
