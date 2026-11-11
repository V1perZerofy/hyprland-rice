import QtQuick
import QtQuick.Layouts
import qs.services

// Popout title row: icon + title on the left, optional controls on the right.
RowLayout {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    default property alias trailing: tail.data

    Layout.fillWidth: true
    spacing: 10

    Rectangle {
        implicitWidth: 34
        implicitHeight: 34
        radius: 17
        color: Theme.alpha(Theme.primary, 0.18)
        Glyph {
            anchors.centerIn: parent
            text: root.icon
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        StyledText {
            Layout.fillWidth: true
            text: root.title
            bold: true
            size: Theme.fontSize + 1
        }
        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.subtitle
            size: Theme.fontSmall
            color: Theme.subtext
        }
    }

    RowLayout {
        id: tail
        spacing: 6
    }
}
