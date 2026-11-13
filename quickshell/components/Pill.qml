import QtQuick
import QtQuick.Layouts
import qs.services

// Rounded bar segment. Children go into a centred RowLayout.
// `active` tints it while its popout is open; `progress` (0..1) draws a thin
// bar along the bottom edge (used by media).
Rectangle {
    id: root

    default property alias content: row.data
    property alias spacing: row.spacing
    property int padding: 12
    property bool active: false
    property real progress: -1
    // 0 = off, 1 = slow red pulse, 2 = fast (e.g. battery at 15 % / 5 %)
    property int alert: 0
    readonly property bool hovered: mouse.containsMouse

    signal clicked(var mouse)
    signal wheel(var wheel)

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.pillHeight
    radius: Theme.radius
    clip: true
    color: active ? Theme.alpha(Theme.mix(Theme.bg, Theme.fg, 0.22), 0.85) : hovered ? Theme.pillHover : Theme.pillBg

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }
    // fade in whenever the pill (re)appears: media starts, weather loads…
    onVisibleChanged: if (visible) appear.restart()
    NumberAnimation {
        id: appear
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: Theme.anim
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curve
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.anim
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.error
        visible: root.alert > 0
        opacity: 0
        SequentialAnimation on opacity {
            running: root.alert > 0
            loops: Animation.Infinite
            NumberAnimation {
                to: 0.45
                duration: root.alert > 1 ? 350 : 900
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 0.08
                duration: root.alert > 1 ? 350 : 900
                easing.type: Easing.InOutSine
            }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }

    Rectangle {
        visible: root.progress >= 0
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        height: 2
        width: parent.width * Math.max(0, Math.min(1, root.progress))
        color: Theme.primary
        opacity: 0.8
        Behavior on width {
            NumberAnimation {
                duration: 900
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => root.clicked(m)
        onWheel: w => root.wheel(w)
    }
}
