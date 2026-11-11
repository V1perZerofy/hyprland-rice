import QtQuick
import Quickshell
import qs.services
import qs.components

// Toggles the markdown notes sidebar.
Pill {
    padding: 10
    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "notes", "toggle"])

    Glyph {
        text: Icons.notebook
        size: 16
    }
}
