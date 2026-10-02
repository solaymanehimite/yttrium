import Quickshell
import QtQuick
import QtQuick.Layouts

import qs.src.bar.notch_widgets
import qs.src.bar.notch_modes
import qs.src.services

PopupWindow {
    id: notch

    anchor.window: bar
    anchor.rect.x: bar.width / 2 - width / 2
    anchor.rect.y: 0

    // The notch has three intentional resting states: compact, a small
    // hover lift, and a full control surface after a click.
    property real showcaseScale: 1.0
    property bool hovered: false
    property bool expanded: false
    property real targetWidth: expanded ? 500 : (hovered ? 412 : (osdActive ? 320 : 400))
    property real targetHeight: expanded ? 210 : (hovered ? 33 : 30)

    // Keep the popup window stable. Only the visible panel morphs, which is
    // the same animation strategy as the original notch and avoids compositor
    // relayout glitches while the pointer is over it.
    implicitWidth: 560
    implicitHeight: 250

    property bool osdActive: osdMode !== ""
    property string osdMode: "" // "", "volume", "brightness"
    property bool _ready: false
    property bool multipadSuppressExternalOsd: false

    visible: true
    color: "transparent"

    // Auto-hide the OSD shortly after the last change.
    Timer {
        id: hideTimer
        interval: 800
        repeat: false
        onTriggered: notch.osdMode = ""
    }

    Timer {
        id: multipadGuard
        interval: 1000
        repeat: false
        onTriggered: notch.multipadSuppressExternalOsd = false
    }

    function poke(mode) {
        if (!notch._ready || notch.multipadSuppressExternalOsd)
            return;
        notch.osdMode = mode;
        hideTimer.restart();
    }

    function pokeMultipad(sliderIndex, value, delta, eventName) {
        if (!notch._ready)
            return;

        if (eventName !== "volume" && eventName !== "brightness")
            return;

        notch.multipadSuppressExternalOsd = true;
        multipadGuard.restart();

        if (eventName === "volume") {
            Audio.adjustRelative(delta);
            notch.osdMode = "volume";
        } else {
            Brightness.adjustRelative(delta);
            notch.osdMode = "brightness";
        }
        hideTimer.restart();
    }

    Component.onCompleted: _initTimer.start()

    Timer {
        id: _initTimer
        interval: 800
        repeat: false
        onTriggered: notch._ready = true
    }

    Connections {
        target: Audio
        function onVolumeChanged() {
            if (!notch.multipadSuppressExternalOsd)
                poke("volume");
        }
        function onMutedChanged() {
            if (!notch.multipadSuppressExternalOsd)
                poke("volume");
        }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged() {
            if (!notch.multipadSuppressExternalOsd)
                poke("brightness");
        }
    }

    Connections {
        target: MultiPad
        function onSliderChanged(sliderIndex, value, delta, eventName) {
            notch.pokeMultipad(sliderIndex, value, delta, eventName);
        }
    }

    property string volumeIcon: {
        if (Audio.muted)
            return Icon.getPath("volume/volume_muted_red");
        const v = Audio.volume ?? 0;
        if (v < 0.33)
            return Icon.getPath("volume/volume_low");
        if (v < 0.66)
            return Icon.getPath("volume/volume_medium");
        return Icon.getPath("volume/volume_high");
    }
    property string volumeText: Math.round((Audio.volume ?? 0) * 100)
    property real volumeFrac: Audio.volume ?? 0

    property real brightnessFrac: {
        const b = Brightness.brightness;
        if (isNaN(b) || b === undefined || b === null)
            return 0;
        return Math.max(0, Math.min(1, b));
    }
    property string brightnessText: Math.round(brightnessFrac * 100)

    readonly property int wifiPercent: {
        const network = NetworkService.connectedNetwork;
        if (!network)
            return 0;
        const strength = Number(network.signalStrength);
        if (isNaN(strength))
            return 0;
        return Math.round(Math.max(0, Math.min(1, strength)) * 100);
    }
    readonly property string wifiValue: NetworkService.connectedNetwork
        ? wifiPercent + "%"
        : "Offline"
    readonly property string wifiDetail: NetworkService.connectedNetwork
        ? "Signal strength"
        : (NetworkService.connectedDevice ? "Connected" : "Not connected")

    // A hidden instance keeps the existing network icon selection logic in one
    // place, including wired and transitional network states.
    Network {
        id: wifiIconProbe
        visible: false
        width: 0
        height: 0
    }

    Item {
        id: surface
        anchors.fill: parent

        Rectangle {
            id: panel
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: notch.targetWidth
            height: notch.targetHeight
            z: 1
            clip: true
            color: "#000000"
            border.width: 0
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: notch.expanded ? 42 : height / 2
            bottomRightRadius: notch.expanded ? 42 : height / 2
            opacity: 0

            Behavior on width {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                id: interaction
                anchors.fill: parent
                z: 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: notch.hovered = true
                onExited: notch.hovered = false
                onClicked: notch.expanded = !notch.expanded
            }

            Component.onCompleted: entrance.start()

            NumberAnimation {
                id: entrance
                target: panel
                property: "opacity"
                from: 0
                to: 1
                duration: 500
                easing.type: Easing.OutCubic
            }

            RowLayout {
                id: idleRow
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 15
                opacity: !notch.expanded && !notch.osdActive ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Clock {}
                Item {
                    Layout.fillWidth: true
                }
                Volume {
                    source: notch.volumeIcon
                    rasterScale: notch.showcaseScale
                }
                Network {
                    rasterScale: notch.showcaseScale
                }
            }

            Item {
                id: osdWrap
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                opacity: !notch.expanded && notch.osdActive ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                OsdModal {
                    anchors.fill: parent
                    visible: notch.osdMode !== "multipad"
                    iconSource: notch.osdMode === "brightness" ? Icon.getPath("sun") : notch.volumeIcon
                    title: notch.osdMode === "brightness" ? "Brightness" : (Audio.muted ? "Muted" : "Volume")
                    value: notch.osdMode === "brightness" ? notch.brightnessFrac : notch.volumeFrac
                    displayText: notch.osdMode === "brightness" ? notch.brightnessText : notch.volumeText
                    statusIconSource: ""
                    muted: notch.osdMode === "volume" && Audio.muted
                    rasterScale: notch.showcaseScale
                }
            }

            Item {
                id: expandedContent
                anchors.fill: parent
                opacity: notch.expanded ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    id: clockSection
                    x: 18
                    y: 16
                    width: 230
                    height: 162

                    Text {
                        id: monthLabel
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        text: Time.monthYear
                        color: "#f6f8fb"
                        font.family: "Google Sans Flex"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }

                    Row {
                        anchors.top: monthLabel.bottom
                        anchors.topMargin: 10
                        width: parent.width
                        height: 16
                        spacing: 0

                        Repeater {
                            model: ["S", "M", "T", "W", "T", "F", "S"]

                            Text {
                                width: 30
                                height: 16
                                text: modelData
                                horizontalAlignment: Text.AlignHCenter
                                color: "#727b89"
                                font.family: "Google Sans Flex"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                        }
                    }

                    Grid {
                        anchors.top: monthLabel.bottom
                        anchors.topMargin: 30
                        width: parent.width
                        columns: 7
                        rowSpacing: 2
                        columnSpacing: 0

                        Repeater {
                            model: 42

                            Item {
                                id: dayCell
                                property int calendarDay: index - new Date(Time.year, Time.month, 1).getDay() + 1
                                property bool isCurrentDay: calendarDay === Time.day
                                width: 30
                                height: 22
                                visible: calendarDay > 0 && calendarDay <= new Date(Time.year, Time.month + 1, 0).getDate()

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 22
                                    radius: width / 2
                                    color: dayCell.isCurrentDay ? "#f6f8fb" : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: dayCell.calendarDay
                                    color: dayCell.isCurrentDay ? "#111318" : "#c1c7d0"
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: 12
                                    font.weight: dayCell.isCurrentDay ? Font.Medium : Font.Normal
                                }
                            }
                        }
                    }
                }

                Column {
                    id: statsColumn
                    x: 252
                    y: 18
                    width: parent.width - x - 18
                    spacing: 2

                    StatusPill {
                        width: statsColumn.width
                        height: 56
                        title: "Wi-Fi"
                        detail: notch.wifiDetail
                        value: notch.wifiValue
                        iconSource: Icon.getPath(wifiIconProbe.currentIcon)
                        accentColor: "#f6f8fb"
                        showProgress: false
                    }

                    StatusPill {
                        width: statsColumn.width
                        height: 56
                        title: "Volume"
                        detail: Audio.muted ? "Output muted" : "System output"
                        value: Audio.muted ? "Muted" : notch.volumeText + "%"
                        iconSource: notch.volumeIcon
                        accentColor: "#f6f8fb"
                        progress: Audio.muted ? 0 : notch.volumeFrac
                    }
                }


            }
        }
    }
}
