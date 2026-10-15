import QtQuick
import QtQuick.Layouts
import qs.src.services

Item {
    id: root

    signal clicked()

    implicitWidth: clockRow.implicitWidth
    implicitHeight: clockRow.implicitHeight
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.fillHeight: true

    RowLayout {
        id: clockRow
        anchors.fill: parent
        spacing: Config.space8

        TextMetrics {
            id: clockWidth
            text: "00:00"
            font.family: Config.fontFamily
            font.pixelSize: Math.round(15 * Config.uiScale)
            font.weight: 550
            font.features: { "tnum": 1 }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: clockWidth.width
            Layout.preferredWidth: clockWidth.width
            Layout.maximumWidth: clockWidth.width
            text: Time.time
            color: Theme.barText
            font.family: Config.fontFamily
            font.pixelSize: Math.round(15 * Config.uiScale)
            font.weight: 550
            font.features: { "tnum": 1 }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Time.date
            color: Theme.barText
            font.family: Config.fontFamily
            font.pixelSize: Math.round(15 * Config.uiScale)
            font.weight: 550
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
