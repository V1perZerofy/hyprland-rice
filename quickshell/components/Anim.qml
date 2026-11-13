import QtQuick
import qs.services

// The shell's one motion style: Theme.anim duration, "emphasized decelerate"
// curve (fast start, soft landing). Use in Behaviors / transitions:
//   Behavior on x { Anim {} }      Behavior on opacity { Anim { duration: Theme.animFast } }
NumberAnimation {
    duration: Theme.anim
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
