import QtQuick
import qs.services

// Colour version of Anim.
ColorAnimation {
    duration: Theme.anim
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
