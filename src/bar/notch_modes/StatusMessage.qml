import QtQuick
import QtQuick.Layouts
import qs.src.services

Item {
    id: root

    property string title: ""
    property string detail: ""

    implicitHeight: messageColumn.implicitHeight

    ColumnLayout {
        id: messageColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 3

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Tokens.textMuted
            font.family: Config.fontFamily
            font.pixelSize: Math.round(13 * Config.uiScale)
            font.weight: 600
        }

        Text {
            Layout.fillWidth: true
            text: root.detail
            color: Tokens.textQuiet
            wrapMode: Text.WordWrap
            font.family: Config.fontFamily
            font.pixelSize: Math.round(11 * Config.uiScale)
        }
    }
}
