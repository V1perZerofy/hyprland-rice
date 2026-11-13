import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.services
import qs.components

// Title of the focused window (only when it's on this bar's monitor).
StyledText {
    id: root
    required property var screen
    readonly property var win: Hyprland.activeToplevel
    readonly property bool show: win !== null && win.workspace !== null && Hyprland.focusedWorkspace === win.workspace && win.monitor === Hyprland.monitorFor(screen)

    text: show ? (win.title || "") : ""
    visible: (text !== "") && Settings.shows("window")
    size: Theme.fontSmall + 1
    color: Theme.subtext
    Layout.maximumWidth: 340
    width: Math.min(implicitWidth, 340)
}
