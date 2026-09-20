import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell

Item {
    id: row

    required property var modelData

    signal clicked(var item)
    signal submenuRequested(var item)

    readonly property bool isSeparator: modelData && modelData.type === "separator"
    readonly property bool isEnabled: modelData && modelData.enabled !== false
    readonly property bool hasChildren: modelData && modelData.children && modelData.children.length > 0
    readonly property string iconName: modelData && modelData.icon_name ? modelData.icon_name : ""
    readonly property string toggleType: modelData && modelData.toggle_type ? modelData.toggle_type : ""
    readonly property bool toggleOn: modelData && (modelData.toggle_state === true || modelData.toggle_state === 1)

    visible: !modelData || modelData.visible !== false
    width: parent ? parent.width : 0
    height: isSeparator ? 8 : 30

    Accessible.role: isSeparator ? Accessible.Separator : Accessible.MenuItem
    Accessible.name: isSeparator ? "" : String(modelData.label || "").replace(/_/g, "")
    Accessible.focusable: !isSeparator && isEnabled

    Rectangle {
        visible: row.isSeparator
        anchors.centerIn: parent
        width: parent.width - 18
        height: 1
        color: "#2affffff"
    }

    Rectangle {
        visible: !row.isSeparator
        anchors.fill: parent
        radius: 7
        color: rowMouse.containsMouse && row.isEnabled ? "#1fffffff" : "transparent"
        opacity: row.isEnabled ? 1 : 0.48

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 9
                rightMargin: 9
            }
            spacing: 7

            Item {
                visible: row.toggleType !== ""
                Layout.preferredWidth: visible ? 12 : 0
                Layout.preferredHeight: 12
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    visible: row.toggleType === "radio"
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 5
                    color: "transparent"
                    border.width: 1
                    border.color: "#99ffffff"

                    Rectangle {
                        visible: row.toggleOn
                        anchors.centerIn: parent
                        width: 4
                        height: 4
                        radius: 2
                        color: "#e6ffffff"
                    }
                }

                Item {
                    visible: row.toggleType !== "radio" && row.toggleOn
                    anchors.fill: parent

                    Rectangle {
                        x: 1
                        y: 7
                        width: 6
                        height: 1.5
                        radius: 0.75
                        rotation: 43
                        color: "#e6ffffff"
                    }

                    Rectangle {
                        x: 5
                        y: 5
                        width: 9
                        height: 1.5
                        radius: 0.75
                        rotation: -47
                        color: "#e6ffffff"
                    }
                }
            }

            Item {
                Layout.preferredWidth: 15
                Layout.preferredHeight: 15
                Layout.alignment: Qt.AlignVCenter

                Image {
                    visible: row.iconName !== "" && source.toString() !== ""
                    anchors.fill: parent
                    source: row.iconName === "" ? "" : Quickshell.iconPath(row.iconName, true)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1
                        colorizationColor: "#e6ffffff"
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: String(row.modelData.label || "").replace(/_/g, "")
                color: "#e6ffffff"
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                font.family: "Google Sans Flex"
                font.pixelSize: 14
                font.weight: 500
            }

            Item {
                visible: row.hasChildren
                Layout.preferredWidth: visible ? 12 : 0
                Layout.preferredHeight: 12
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    x: 3
                    y: 3
                    width: 6
                    height: 1.5
                    radius: 0.75
                    rotation: 45
                    color: "#99ffffff"
                }

                Rectangle {
                    x: 3
                    y: 7
                    width: 6
                    height: 1.5
                    radius: 0.75
                    rotation: -45
                    color: "#99ffffff"
                }
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: row.isEnabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            onClicked: {
                if (row.hasChildren)
                    row.submenuRequested(row.modelData);
                else
                    row.clicked(row.modelData);
            }
        }
    }
}
