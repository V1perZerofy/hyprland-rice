import QtQuick
import qs.services

// Thin horizontal slider. `value` is 0..1; emits moved(v) while dragging.
Item {
    id: root

    property real value: 0
    property color accent: Theme.primary
    property bool enabled: true
    signal moved(real v)

    implicitHeight: 18
    implicitWidth: 200

    readonly property real shown: mouse.pressed ? mouse.dragValue : Math.max(0, Math.min(1, value))

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surfaceHi

        Rectangle {
            width: Math.max(height, parent.width * root.shown)
            height: parent.height
            radius: 3
            color: root.enabled ? root.accent : Theme.muted
        }
    }

    Rectangle {
        x: Math.max(0, Math.min(root.width - width, root.width * root.shown - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        width: mouse.pressed || mouse.containsMouse ? 16 : 12
        height: width
        radius: width / 2
        color: root.enabled ? root.accent : Theme.muted
        border.color: Theme.cardBg
        border.width: 2
        Behavior on width {
            NumberAnimation {
                duration: 120
            }
        }
    }

    MouseArea {
        id: mouse
        property real dragValue: 0
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        function update(x) {
            dragValue = Math.max(0, Math.min(1, (x - 4) / root.width));
            root.moved(dragValue);
        }
        onPressed: m => update(m.x)
        onPositionChanged: m => {
            if (pressed)
                update(m.x);
        }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.02 : -0.02))))
    }
}
