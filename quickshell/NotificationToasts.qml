import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// Toast stack, top-right under the bar, on the focused monitor.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
    anchors {
        top: true
        right: true
    }
    margins.top: (Popups.barVisible && !Settings.barBottom ? Theme.barHeight : 0) + 8
    margins.right: 10
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notifications"
    color: "transparent"

    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight)
    visible: Notifs.popups.length > 0

    Column {
        id: stack
        width: parent.width
        spacing: 6

        move: Transition {
            NumberAnimation {
                properties: "y"
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: Notifs.popups
            NotificationCard {
                required property var modelData
                entry: modelData
                width: stack.width
                toast: true
            }
        }
    }
}
