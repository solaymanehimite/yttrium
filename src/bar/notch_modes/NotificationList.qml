import QtQuick
import QtQuick.Layouts
import qs.src.services

Item {
    id: root

    required property var notchWindow
    property string heading: "Notifications"

    ColumnLayout {
        anchors.fill: parent
        spacing: Config.space8

        Text {
            Layout.fillWidth: true
            text: root.heading
            color: Theme.accent
            font.family: Config.fontFamily
            font.pixelSize: Math.round(13 * Config.uiScale)
            font.weight: 600
        }

        ListView {
            id: notificationList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Config.space6
            model: root.notchWindow.notifications
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                width: notificationList.width
                height: 54
                radius: 14
                color: Theme.panelSurface

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: Config.space8

                    Image {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        source: modelData.image || Icon.getPath("bell")
                        sourceSize: Qt.size(18, 18)
                        fillMode: Image.PreserveAspectFit
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Config.space1

                        Text {
                            Layout.fillWidth: true
                            text: modelData.appName || modelData.summary || "Notification"
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            font.family: Config.fontFamily
                            font.pixelSize: Math.round(12 * Config.uiScale)
                            font.weight: 600
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.body || modelData.summary || ""
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            font.family: Config.fontFamily
                            font.pixelSize: Math.round(11 * Config.uiScale)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.dismiss()
                }
            }

            StatusMessage {
                anchors.centerIn: parent
                width: parent.width - 28
                visible: root.notchWindow.notificationCount === 0
                title: "No notifications"
                detail: "New notifications will appear here."
            }
        }
    }
}
