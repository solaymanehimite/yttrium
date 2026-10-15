import QtQuick
import QtQuick.Layouts
import qs.src.services

Item {
    id: root

    required property var notchWindow
    property var events: []
    property bool eventsAvailable: false
    readonly property int calendarFirstDay:
        (new Date(Time.year, Time.month, 1).getDay() + 6) % 7
    readonly property int calendarDays:
        new Date(Time.year, Time.month + 1, 0).getDate()
    readonly property bool active: notchWindow.menuOpen
        && notchWindow.launcherMode === "calendar"

    anchors.fill: parent
    anchors.margins: Config.space18
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

    Keys.onEscapePressed: root.notchWindow.toggleMenu()

    RowLayout {
        anchors.fill: parent
        spacing: Config.space28

        ColumnLayout {
            Layout.preferredWidth: 210
            Layout.fillHeight: true
            spacing: Config.space8

            Text {
                Layout.fillWidth: true
                text: Qt.formatDate(
                    new Date(Time.year, Time.month, 1), "MMMM yyyy")
                    .toUpperCase()
                color: Theme.accent
                leftPadding: 5
                bottomPadding: 5
                font.family: Config.fontFamily
                font.pixelSize: Math.round(13 * Config.uiScale)
                font.weight: 600
            }

            Row {
                spacing: Config.space8
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    Text {
                        required property string modelData
                        width: 24
                        text: modelData
                        color: Theme.textMuted
                        font.family: Config.fontFamily
                        font.pixelSize: Math.round(12 * Config.uiScale)
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Grid {
                columns: 7
                columnSpacing: 8
                rowSpacing: 6

                Repeater {
                    model: 42
                    Text {
                        required property int index
                        property int day: index - root.calendarFirstDay + 1
                        width: 24
                        height: 24
                        visible: day > 0 && day <= root.calendarDays
                        text: visible ? day : ""
                        color: day === Time.day
                            ? Theme.notchBlack : Theme.textMuted
                        font.family: Config.fontFamily
                        font.pixelSize: Math.round(13 * Config.uiScale)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Rectangle {
                            visible: day === root.notchWindow.timeDay
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            radius: width / 2
                            color: Theme.accent
                            z: -1
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Config.space10

            Text {
                Layout.fillWidth: true
                text: "Today's events"
                color: Theme.textPrimary
                font.family: Config.fontFamily
                font.pixelSize: Math.round(16 * Config.uiScale)
                font.weight: 600
            }

            Text {
                Layout.fillWidth: true
                text: Qt.formatDate(new Date(), "dddd, MMMM d")
                color: Theme.textMuted
                font.family: Config.fontFamily
                font.pixelSize: Math.round(12 * Config.uiScale)
            }

            ListView {
                id: eventList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.eventsAvailable && root.events.length > 0
                model: root.events
                spacing: Config.space6
                clip: true

                delegate: Rectangle {
                    required property var modelData
                    width: eventList.width
                    height: 48
                    radius: Config.tileRadius
                    color: Theme.panelSurface

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: Config.space1
                        Text {
                            text: modelData.title || "Untitled event"
                            color: Theme.textPrimary
                            font.family: Config.fontFamily
                            font.pixelSize: Math.round(12 * Config.uiScale)
                            font.weight: 600
                        }
                        Text {
                            text: modelData.time || "All day"
                            color: Theme.textMuted
                            font.family: Config.fontFamily
                            font.pixelSize: Math.round(11 * Config.uiScale)
                        }
                    }
                }
            }

            StatusMessage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.eventsAvailable
                title: "Calendar unavailable"
                detail: "No calendar source is connected yet."
            }

            StatusMessage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.eventsAvailable && root.events.length === 0
                title: "No events today"
                detail: "Your day is clear."
            }

            Item { Layout.fillHeight: true }
        }
    }
}
