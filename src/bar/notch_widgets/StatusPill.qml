import QtQuick
import qs.src.services

Item {
    id: root

    property string title: ""
    property string detail: ""
    property string value: ""
    property string iconSource: ""
    property color accentColor: "#f6f8fb"
    property real progress: 0
    property bool showProgress: true

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: "transparent"
        border.width: 0
    }

    Rectangle {
        x: 0
        y: 10
        width: Math.round(38 * Config.uiScale)
        height: Math.round(38 * Config.uiScale)
        radius: 0
        color: "transparent"

        Image {
            anchors.centerIn: parent
            width: 22
            height: 22
            source: root.iconSource
            sourceSize.width: 50
            sourceSize.height: 50
            smooth: true
            asynchronous: true
        }
    }

    Column {
        x: Math.round(50 * Config.uiScale)
        y: Math.round(9 * Config.uiScale)
        spacing: 0

        Text {
            text: root.title
            color: "#f6f8fb"
            font.family: Config.fontFamily
            font.pixelSize: Math.round(15 * Config.uiScale)
            font.weight: 600
        }

        Text {
            text: root.detail
            color: "#9da5b2"
            font.family: Config.fontFamily
            font.pixelSize: Math.round(12 * Config.uiScale)
            font.weight: 500
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        color: root.accentColor
        font.family: Config.fontFamily
        font.pixelSize: Math.round((root.value === "Muted" ? 16 : 25) * Config.uiScale)
        font.weight: 650
        font.features: { "tnum": 1 }
    }

    Rectangle {
        visible: root.showProgress
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.right: parent.right
        anchors.rightMargin: 0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        height: 2
        radius: 1
        color: Qt.rgba(1, 1, 1, 0.2)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.progress))
            height: parent.height
            radius: 1
            color: "#ffffff"
            opacity: 1
        }
    }
}
