import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// Full-screen modal on the focused monitor: dimmed backdrop (click to close),
// exclusive keyboard focus while open, centred card that scales/fades in.
// Children go into the card; set cardWidth / cardHeight.
PanelWindow {
    id: root

    property bool open: false
    property int cardWidth: 640
    property int cardHeight: 480
    property real cardY: (height - cardHeight) / 2
    default property alias content: card.data
    readonly property alias card: card

    signal opened

    function toggle() {
        open = !open;
    }

    onOpenChanged: {
        if (open) {
            if (Popups.current)
                Popups.current.open = false;
            opened();
        }
    }

    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: open || card.opacity > 0.01

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        opacity: root.open ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
        MouseArea {
            anchors.fill: parent
            onPressed: root.open = false
        }
    }

    Rectangle {
        id: card
        x: (root.width - width) / 2
        y: root.cardY
        width: root.cardWidth
        height: root.cardHeight
        radius: 22
        color: Theme.cardBg
        border.color: Theme.border
        border.width: 1
        clip: true

        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        // swallow clicks on the card itself
        MouseArea {
            anchors.fill: parent
        }
    }
}
