import QtQuick.Layouts
import QtQuick

import qs.src.bar.tray_widgets

RowLayout {
    anchors.rightMargin: 20
    anchors.right: parent.right
    implicitWidth: 300
    height: parent.height

    layoutDirection: Qt.RightToLeft

    Notes {}
}
