import QtQuick
import Quickshell
import qs.services
import qs.components

// Opens the app launcher · right-click: wallpaper picker.
Pill {
    padding: 10
    onClicked: m => Quickshell.execDetached(["qs", "ipc", "call", m.button === Qt.RightButton ? "wallpaper" : "launcher", "toggle"])

    Glyph {
        text: Icons.apps
        size: 17
    }
}
