import QtQuick
import qs.services

// Round (or pill-shaped, if `label` is set) button with a glyph.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property int size: 34
    property int iconSize: 16
    property bool highlighted: false
    property color accent: Theme.primary
    signal clicked

    implicitWidth: label ? row.implicitWidth + 24 : size
    implicitHeight: size
    radius: label ? Theme.radius : size / 2
    color: highlighted ? accent : mouse.containsMouse ? Theme.surfaceHi : Theme.surface

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: root.iconSize
            visible: root.icon !== ""
            color: root.highlighted ? Theme.bg : Theme.fg
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            size: Theme.fontSmall + 1
            color: root.highlighted ? Theme.bg : Theme.fg
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
