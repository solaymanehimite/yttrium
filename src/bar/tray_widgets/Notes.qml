import Quickshell
import QtQuick

import qs.src.services

Item {
    id: quickNote

    implicitWidth: 35
    implicitHeight: 25

    property bool active: false

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            quickNote.active = !quickNote.active;
        }
    }

    Rectangle {
        id: hoverRect
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0.1 * mouseArea.containsMouse
        radius: 12

        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }
    }

    Image {
        anchors.centerIn: parent
        source: Icon.getPath("pen")
    }

    PopupWindow {
        id: popupWindow
        anchor.window: bar
        visible: quickNote.active

        grabFocus: true

        onClosed: {
            quickNote.active = false;
        }

        anchor.rect.x: bar.width - width - 20
        anchor.rect.y: 40

        width: 300
        height: 400

        color: "transparent"

        Rectangle {
            width: parent.width
            border.width: 1
            border.color: "#d9be84"
            height: quickNote.active ? 300 : 0
            radius: 7

            Behavior on height {
                SpringAnimation {
                    spring: 10
                    damping: 0.4
                }
            }

            color: "#ffe59e"

            TextEdit {
                id: myTextEdit
                anchors.fill: parent
                anchors.margins: 10
                focus: true

                Component.onCompleted: {
                    myTextEdit.forceActiveFocus();
                }
            }
        }
    }
}
