import QtQuick
import qs.src.services

Item {
    id: root

    readonly property real faceSize: Math.min(width, height)
    readonly property real hourAngle: (Time.hour % 12) * 30 + Time.minute * 0.5 + Time.second / 120
    readonly property real minuteAngle: Time.minute * 6 + Time.second * 0.1

    Rectangle {
        id: face
        width: root.faceSize
        height: root.faceSize
        anchors.centerIn: parent
        radius: width / 2
        color: "transparent"
        border.width: 0

        Rectangle {
            anchors.fill: parent
            anchors.margins: 7
            radius: width / 2
            color: "transparent"
            border.width: 0
        }

        Repeater {
            model: 12

            Rectangle {
                id: tick
                property int tickIndex: index

                width: tickIndex % 3 === 0 ? 3 : 2
                height: tickIndex % 3 === 0 ? 13 : 7
                x: face.width / 2 - width / 2
                y: 5
                radius: width / 2
                color: tickIndex % 3 === 0 ? "#dce2eb" : "#69717e"
                transform: Rotation {
                    origin.x: tick.width / 2
                    origin.y: face.height / 2 - tick.y
                    angle: tickIndex * 30
                }
            }
        }

        Rectangle {
            id: hourHand
            width: 4
            height: face.height * 0.24
            x: face.width / 2 - width / 2
            y: face.height / 2 - height
            radius: width / 2
            color: "#f6f8fb"
            transformOrigin: Item.Bottom
            rotation: root.hourAngle

            Behavior on rotation {
                NumberAnimation {
                    duration: 450
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            id: minuteHand
            width: 3
            height: face.height * 0.38
            x: face.width / 2 - width / 2
            y: face.height / 2 - height
            radius: width / 2
            color: "#f6f8fb"
            transformOrigin: Item.Bottom
            rotation: root.minuteAngle

            Behavior on rotation {
                NumberAnimation {
                    duration: 450
                    easing.type: Easing.OutCubic
                }
            }
        }


    }
}
