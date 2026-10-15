import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs.src.bar.notch_widgets as NotchWidgets
import qs.src.services

Item {
    id: root

    required property var notchWindow
    readonly property bool active: notchWindow.menuOpen
        && notchWindow.launcherMode === "control"

    anchors.fill: parent
    anchors.margins: 16
    visible: active || opacity > 0
    enabled: active
    focus: active
    opacity: active ? 1 : 0
    scale: active ? 1 : 0.88

    Behavior on opacity {
        SpringAnimation {
            spring: 11
            damping: 0.75
            mass: 1.6
            epsilon: 0.01
        }
    }
    Behavior on scale {
        SpringAnimation {
            spring: 14
            damping: 0.72
            mass: 1.4
            epsilon: 0.01
        }
    }

    component ControlTile: Rectangle {
        id: tile

        property bool activeState: false
        property bool clickable: true
        property string hoverColor: Theme.tileHover
        signal activated()
        default property alias content: tileContent.data

        radius: Config.tileRadius
        color: tileHover.hovered
            ? hoverColor
            : (activeState ? Theme.tileActive : "transparent")
        border.width: activeState ? 0 : 1
        border.color: activeState ? "transparent" : Theme.tileBorder

        RowLayout {
            id: tileContent
            anchors.fill: parent
            anchors.margins: 12
            spacing: Config.space10
        }

        HoverHandler {
            id: tileHover
            enabled: tile.clickable
            cursorShape: tile.clickable
                ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        MouseArea {
            anchors.fill: parent
            enabled: tile.clickable
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.activated()
        }
    }

    component MediaButton: Item {
        id: mediaButton
        required property string iconName
        property bool activeState: false
        signal triggered()

        width: 28
        height: 28
        opacity: enabled ? (activeState || hover.hovered ? 1 : 0.72) : 0.28

        Image {
            anchors.centerIn: parent
            width: 18
            height: 18
            source: Icon.getPath(mediaButton.iconName)
            sourceSize: Qt.size(18, 18)
            fillMode: Image.PreserveAspectFit
        }

        HoverHandler {
            id: hover
            cursorShape: mediaButton.enabled
                ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: mediaButton.enabled
            onTapped: mediaButton.triggered()
        }
    }

    Keys.onEscapePressed: root.notchWindow.toggleMenu()

    RowLayout {
        anchors.fill: parent
        spacing: Config.space14

        NotificationList {
            Layout.preferredWidth: 218
            Layout.fillHeight: true
            notchWindow: root.notchWindow
            heading: "Notifications"
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Config.space6

            ControlTile {
                id: wifiTile
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                activeState: Networking.wifiEnabled
                opacity: Networking.wifiHardwareEnabled ? 1 : 0.55
                onActivated: Networking.wifiEnabled = !Networking.wifiEnabled

                NotchWidgets.Network {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignVCenter
                    darkIcon: wifiTile.activeState
                    rasterScale: 18 / 15
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Config.space1
                    Text {
                        Layout.fillWidth: true
                        text: "Wi-Fi"
                        color: wifiTile.activeState
                            ? Theme.notchBlack : Theme.textPrimary
                        font.family: Config.fontFamily
                        font.pixelSize: Math.round(12 * Config.uiScale)
                        font.weight: 600
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.notchWindow.wifiStatus
                        color: wifiTile.activeState
                            ? Theme.activeMutedText : Theme.textMuted
                        font.family: Config.fontFamily
                        font.pixelSize: Math.round(11 * Config.uiScale)
                    }
                }
            }

            ControlTile {
                id: bluetoothTile
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                activeState: root.notchWindow.bluetoothAdapter
                    && (root.notchWindow.bluetoothAdapter.enabled
                        || root.notchWindow.bluetoothChanging)
                opacity: root.notchWindow.bluetoothAdapter ? 1 : 0.55
                onActivated: {
                    if (root.notchWindow.bluetoothCanToggle)
                        root.notchWindow.bluetoothAdapter.enabled =
                            !root.notchWindow.bluetoothAdapter.enabled;
                }

                Image {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignVCenter
                    source: Icon.getPath(root.notchWindow.bluetoothIconName
                        + (bluetoothTile.activeState ? "_black" : ""))
                    sourceSize: Qt.size(18, 18)
                    fillMode: Image.PreserveAspectFit
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Config.space1
                    Text {
                        Layout.fillWidth: true
                        text: "Bluetooth"
                        color: bluetoothTile.activeState
                            ? Theme.notchBlack : Theme.textPrimary
                        font.family: Config.fontFamily
                        font.pixelSize: Math.round(12 * Config.uiScale)
                        font.weight: 600
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.notchWindow.bluetoothStatus
                        color: bluetoothTile.activeState
                            ? Theme.activeMutedText : Theme.textMuted
                        font.family: Config.fontFamily
                        font.pixelSize: Math.round(11 * Config.uiScale)
                    }
                }
            }

            ControlTile {
                id: mediaTile
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                clickable: false
                Text {
                    Layout.fillWidth: true
                    text: root.notchWindow.mediaTitle
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    font.family: Config.fontFamily
                    font.pixelSize: Math.round(12 * Config.uiScale)
                    font.weight: 600
                }

                RowLayout {
                    Layout.preferredWidth: 94
                    Layout.fillHeight: true
                    spacing: Config.space4

                    MediaButton {
                        iconName: "media/previous"
                        enabled: root.notchWindow.mediaPlayer
                            && root.notchWindow.mediaPlayer.canGoPrevious
                        onTriggered: root.notchWindow.mediaPlayer.previous()
                    }
                    MediaButton {
                        iconName: root.notchWindow.mediaPlayer
                            && root.notchWindow.mediaPlayer.isPlaying
                            ? "media/pause" : "media/play"
                        enabled: root.notchWindow.mediaPlayer
                            && root.notchWindow.mediaPlayer.canTogglePlaying
                        activeState: root.notchWindow.mediaPlayer
                            && root.notchWindow.mediaPlayer.isPlaying
                        onTriggered: root.notchWindow.mediaPlayer.togglePlaying()
                    }
                    MediaButton {
                        iconName: "media/next"
                        enabled: root.notchWindow.mediaPlayer
                            && root.notchWindow.mediaPlayer.canGoNext
                        onTriggered: root.notchWindow.mediaPlayer.next()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Config.space6

                ControlTile {
                    id: dndTile
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    activeState: root.notchWindow.doNotDisturb
                    onActivated: root.notchWindow.doNotDisturb =
                        !root.notchWindow.doNotDisturb

                    Image {
                        Layout.preferredWidth: 17
                        Layout.preferredHeight: 17
                        source: Icon.getPath(root.notchWindow.doNotDisturb
                            ? "do-not-disturb_black" : "do-not-disturb")
                        sourceSize: Qt.size(17, 17)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.notchWindow.doNotDisturbError
                            ? "Unavailable" : "Do not disturb"
                        color: dndTile.activeState
                            ? Theme.notchBlack : Theme.textPrimary
                        elide: Text.ElideRight
                        font.family: Config.fontFamily
                        font.pixelSize: Math.round(11 * Config.uiScale)
                    }
                }

                ControlTile {
                    id: themeTile
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    activeState: Theme.dark
                    onActivated: Theme.toggle()

                    Image {
                        Layout.preferredWidth: 17
                        Layout.preferredHeight: 17
                        source: Icon.getPath(Theme.dark
                            ? "theme_black" : "theme")
                        sourceSize: Qt.size(17, 17)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Theme.dark ? "Dark" : "Light"
                        color: themeTile.activeState
                            ? Theme.notchBlack : Theme.textPrimary
                        font.family: Config.fontFamily
                        font.pixelSize: Math.round(11 * Config.uiScale)
                    }
                }
            }
        }
    }
}
