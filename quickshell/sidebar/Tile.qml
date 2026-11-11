import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Quick-toggle tile. Left click: toggle · Right click: `secondary` (open the
// related app / settings).
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    signal toggled
    signal secondary

    Layout.fillWidth: true
    implicitHeight: 62
    radius: 16
    color: checked ? Theme.alpha(Theme.primary, mouse.containsMouse ? 0.32 : 0.24) : mouse.containsMouse ? Theme.surfaceHi : Theme.surface
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

        Rectangle {
            implicitWidth: 38
            implicitHeight: 38
            radius: 19
            color: root.checked ? Theme.primary : Theme.surfaceHi
            Behavior on color {
                ColorAnimation {
                    duration: Theme.anim
                }
            }
            Glyph {
                anchors.centerIn: parent
                text: root.icon
                size: 18
                color: root.checked ? Theme.bg : Theme.fg
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.title
                bold: true
                size: Theme.fontSmall + 1
            }
            StyledText {
                Layout.fillWidth: true
                text: root.subtitle
                size: Theme.fontSmall - 1
                color: Theme.subtext
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => m.button === Qt.RightButton ? root.secondary() : root.toggled()
    }
}
