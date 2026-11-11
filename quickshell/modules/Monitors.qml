import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.components

// Connected monitor count. Click opens hyprmon.
Pill {
    onClicked: Quickshell.execDetached(["kitty", "hyprmon"])

    Glyph {
        text: Icons.monitor
    }
    StyledText {
        text: Hyprland.monitors.values.length
        size: Theme.fontSmall + 1
    }
}
