import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// "CPU  ▓▓▓░░░  34%" row; turns warning/error colour when high.
RowLayout {
    id: root
    property string icon: ""
    property string label: ""
    property real value: 0          // 0..1
    property string detail: ""
    readonly property color tint: value > 0.9 ? Theme.error : value > 0.75 ? Theme.warning : Theme.primary

    Layout.fillWidth: true
    spacing: 10

    Glyph {
        text: root.icon
        size: 15
        color: root.tint
        Layout.preferredWidth: 18
    }
    StyledText {
        text: root.label
        size: Theme.fontSmall
        Layout.preferredWidth: 42
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 6
        radius: 3
        color: Theme.surfaceHi
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: 3
            color: root.tint
            Behavior on width {
                NumberAnimation {
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    StyledText {
        text: root.detail
        size: Theme.fontSmall - 1
        color: Theme.subtext
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 96
    }
}
