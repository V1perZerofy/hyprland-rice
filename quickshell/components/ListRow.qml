import QtQuick
import QtQuick.Layouts
import qs.services

// Clickable row for device / network / sink lists.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property bool selected: false
    property bool busy: false
    signal clicked

    Layout.fillWidth: true
    implicitHeight: 44
    radius: 12
    color: selected ? Theme.alpha(Theme.primary, 0.18) : mouse.containsMouse ? Theme.surfaceHi : "transparent"
    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        Glyph {
            text: root.icon
            color: root.selected ? Theme.primary : Theme.fg
            Layout.preferredWidth: 20
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.title
                size: Theme.fontSmall + 1
                bold: root.selected
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                size: Theme.fontSmall - 1
                color: Theme.subtext
            }
        }

        StyledText {
            visible: text !== ""
            text: root.busy ? "…" : root.trailing
            size: Theme.fontSmall
            color: root.selected ? Theme.primary : Theme.subtext
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
