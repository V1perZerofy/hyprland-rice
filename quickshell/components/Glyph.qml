import QtQuick
import qs.services

// A Nerd Font icon.
Text {
    property int size: Theme.iconSize
    font.family: Theme.font
    font.pixelSize: size
    color: Theme.primary
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }
}
