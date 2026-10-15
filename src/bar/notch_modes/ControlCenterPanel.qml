import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Mpris

import qs.src.bar.notch_widgets as NotchWidgets
import qs.src.services

Item {
    id: root

    required property var notchWindow
    readonly property bool active: notchWindow.menuOpen
        && notchWindow.launcherMode === "control"

    anchors.fill: parent
    anchors.margins: Config.space18
    visible: active || opacity > 0
    enabled: active
    focus: active
    opacity: active ? 1 : 0
    scale: active ? 1 : 0.94

    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothChanging: bluetoothAdapter
        && (bluetoothAdapter.state === BluetoothAdapterState.Enabling
            || bluetoothAdapter.state === BluetoothAdapterState.Disabling)
    readonly property bool bluetoothCanToggle: bluetoothAdapter
        && bluetoothAdapter.state !== BluetoothAdapterState.Blocked
        && !bluetoothChanging
    readonly property var mediaPlayer: {
        const players = Mpris.players.values;
        let paused = null;
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying)
                return players[i];
            if (!paused && players[i].playbackState === MprisPlaybackState.Paused)
                paused = players[i];
        }
        return paused || (players.length > 0 ? players[0] : null);
    }
    readonly property string mediaTitle: mediaPlayer && mediaPlayer.trackTitle
        ? String(mediaPlayer.trackTitle) : "Not Playing"
    readonly property string mediaArtist: mediaPlayer && mediaPlayer.trackArtist
        ? String(mediaPlayer.trackArtist) : ""
    readonly property string mediaArtwork: mediaPlayer && mediaPlayer.trackArtUrl
        ? String(mediaPlayer.trackArtUrl) : ""
    readonly property int controlContentWidth: 178
    readonly property int controlContentHeight: 178

    Behavior on opacity {
        NumberAnimation { duration: Config.standardAnimation; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: Config.standardAnimation; easing.type: Easing.OutCubic }
    }

    component IconSlider: Slider {
        id: controlSlider
        required property string iconSource

        Layout.fillWidth: true
        Layout.preferredHeight: 38
        from: 0
        to: 1
        padding: 0

        background: Rectangle {
            x: 0
            y: (controlSlider.height - height) / 2
            width: controlSlider.width
            height: 34
            radius: 17
            color: Theme.controlSliderTrack

            Rectangle {
                width: controlSlider.visualPosition * (controlSlider.width - 34) + 34
                height: parent.height
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.controlActiveTop }
                    GradientStop { position: 1.0; color: Theme.controlActiveBottom }
                }
            }
        }

        handle: Rectangle {
            x: controlSlider.visualPosition
                * (controlSlider.width - width)

            y: (controlSlider.height - height) / 2
            width: 34
            height: 34
            radius: 17
            color: "transparent"

            Image {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: controlSlider.iconSource
                sourceSize: Qt.size(16, 16)
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1
                    colorizationColor: Theme.controlSliderIcon
                }
            }
        }
    }

    component QuickTile: Rectangle {
        required property string iconSource
        property bool activeState: false
        property bool available: true
        signal activated()

        Layout.preferredWidth: 54
        Layout.preferredHeight: 54
        radius: activeState ? 16 : Math.min(width, height) / 2
        color: "transparent"
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: !available ? "transparent"
                    : (activeState ? Theme.controlActiveTop
                        : (tileMouse.containsMouse ? Theme.controlTileHover : "transparent"))
                Behavior on color {
                    ColorAnimation {
                        duration: Config.standardAnimation
                        easing.type: Easing.OutCubic
                    }
                }
            }
            GradientStop {
                position: 1.0
                color: !available ? "transparent"
                    : (activeState ? Theme.controlActiveBottom
                        : (tileMouse.containsMouse ? Theme.controlTileHover : "transparent"))
                Behavior on color {
                    ColorAnimation {
                        duration: Config.standardAnimation
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
        opacity: available ? 1 : 0.35

        Behavior on color {
            ColorAnimation {
                duration: Config.standardAnimation
                easing.type: Easing.OutCubic
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: Config.standardAnimation
                easing.type: Easing.OutCubic
            }
        }

        Image {
            anchors.centerIn: parent
            width: 20
            height: 20
            source: iconSource
            sourceSize: Qt.size(20, 20)
            fillMode: Image.PreserveAspectFit
            opacity: tileMouse.containsMouse ? 1 : 0.92
            layer.enabled: activeState
            layer.effect: MultiEffect {
                colorization: 1
                colorizationColor: Theme.controlTileActiveText
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            enabled: parent.available
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: parent.activated()
        }
    }

    component MediaButton: Item {
        required property string iconName
        property bool available: true
        signal triggered()

        width: 28
        height: 28
        opacity: available ? 0.9 : 0.28

        Image {
            anchors.centerIn: parent
            width: 17
            height: 17
            source: Icon.getPath(iconName)
            sourceSize: Qt.size(17, 17)
            fillMode: Image.PreserveAspectFit
        }
        TapHandler {
            enabled: parent.available
            onTapped: parent.triggered()
        }
    }

    function themedIcon(name, active) {
        return Icon.getPath(name);
    }

    function tileIcon(index) {
        if (index === 0)
            return themedIcon(NetworkService.connectedNetwork ? "wifi/full" : "wifi/none", tileActive(index));
        if (index === 1)
            return themedIcon(bluetoothAdapter && bluetoothAdapter.enabled
                ? "bluetooth/on" : "bluetooth/off", tileActive(index));
        if (index === 2)
            return themedIcon("do-not-disturb", tileActive(index));
        if (index === 3)
            return themedIcon("theme", tileActive(index));
        if (index === 4)
            return themedIcon(Audio.muted ? "volume/volume_muted" : "volume/volume_high", tileActive(index));
        if (index === 5)
            return Icon.getPath("sun");
        if (index === 6)
            return themedIcon("wallpaper", false);
        if (index === 7)
            return Icon.getPath(mediaPlayer && mediaPlayer.isPlaying ? "media/pause" : "media/play");
        return themedIcon("settings", false);
    }

    function tileActive(index) {
        if (index === 0)
            return Networking.wifiEnabled;
        if (index === 1)
            return bluetoothAdapter && bluetoothAdapter.enabled;
        if (index === 2)
            return notchWindow.doNotDisturb;
        if (index === 3)
            return Theme.dark;
        if (index === 4)
            return !Audio.muted;
        if (index === 5)
            return Brightness.brightness > 0.5;
        if (index === 7)
            return mediaPlayer && mediaPlayer.isPlaying;
        return false;
    }

    function activateTile(index) {
        if (index === 0) {
            if (Networking.wifiHardwareEnabled)
                Networking.wifiEnabled = !Networking.wifiEnabled;
        } else if (index === 1) {
            if (bluetoothCanToggle)
                bluetoothAdapter.enabled = !bluetoothAdapter.enabled;
        } else if (index === 2) {
            notchWindow.doNotDisturb = !notchWindow.doNotDisturb;
        } else if (index === 3) {
            Theme.toggle();
        } else if (index === 4) {
            Audio.setVolume(Audio.muted ? Audio.volume : 0);
        } else if (index === 5) {
            notchWindow.show("brightness");
        } else if (index === 6) {
            notchWindow.openWallpaperMode();
        } else if (index === 7 && mediaPlayer
                && mediaPlayer.canTogglePlaying) {
            mediaPlayer.togglePlaying();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Config.space18

        Item {
            id: tileGridContainer
            Layout.preferredWidth: 1
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter

            GridLayout {
                id: tileGrid
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: root.controlContentWidth
                height: root.controlContentHeight
                columns: 3
                rows: 3
                columnSpacing: Config.space8
                rowSpacing: Config.space8

                Repeater {
                    model: 9
                    delegate: QuickTile {
                        required property int index
                        iconSource: root.tileIcon(index)
                        activeState: root.tileActive(index)
                        available: index !== 0
                            ? (index !== 1 || root.bluetoothAdapter !== null)
                            : Networking.wifiHardwareEnabled
                        onActivated: root.activateTile(index)
                    }
                }
            }
        }

        Item {
            id: rightContentContainer
            Layout.preferredWidth: 1
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                id: rightContent
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: root.controlContentWidth
                height: root.controlContentHeight
                spacing: Config.space10

            IconSlider {
                id: volumeSlider
                iconSource: notchWindow.volumeIcon
                value: Audio.volume
                onMoved: Audio.setVolume(value)
            }

            IconSlider {
                id: brightnessSlider
                iconSource: Icon.getPath("sun")
                value: Brightness.brightness
                onMoved: Brightness.setBrightness(value)
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Config.space10
                    spacing: Config.space10

                    Item {
                        Layout.preferredWidth: 62
                        Layout.fillHeight: true
                        Image {
                            id: artwork
                            anchors.fill: parent
                            source: root.mediaArtwork
                            sourceSize: Qt.size(124, 124)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            visible: status === Image.Ready
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Config.space4

                        Text {
                            Layout.fillWidth: true
                            text: root.mediaTitle
                            color: Theme.textPrimary
                            font.family: Config.fontFamily
                            font.pixelSize: Math.round(12 * Config.uiScale)
                            font.weight: 600
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.mediaArtist
                            color: Theme.textMuted
                            font.family: Config.fontFamily
                            font.pixelSize: Math.round(10 * Config.uiScale)
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignBottom
                            spacing: Config.space4
                            MediaButton {
                                Layout.alignment: Qt.AlignVCenter
                                iconName: "media/previous"
                                available: root.mediaPlayer
                                    && root.mediaPlayer.canGoPrevious
                                onTriggered: root.mediaPlayer.previous()
                            }
                            MediaButton {
                                Layout.alignment: Qt.AlignVCenter
                                iconName: root.mediaPlayer && root.mediaPlayer.isPlaying
                                    ? "media/pause" : "media/play"
                                available: root.mediaPlayer
                                    && root.mediaPlayer.canTogglePlaying
                                onTriggered: root.mediaPlayer.togglePlaying()
                            }
                            MediaButton {
                                Layout.alignment: Qt.AlignVCenter
                                iconName: "media/next"
                                available: root.mediaPlayer
                                    && root.mediaPlayer.canGoNext
                                onTriggered: root.mediaPlayer.next()
                            }
                        }
                    }
                }
            }
        }
    }

    }

    Keys.onEscapePressed: notchWindow.openAppSearch()
}
