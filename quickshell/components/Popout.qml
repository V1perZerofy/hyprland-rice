import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// A card that drops down from a bar pill.
// It lives on a transparent layer-shell surface covering the screen *below*
// the bar: clicks outside the card close it, the bar stays clickable, and
// Escape closes it too. (A PopupWindow + HyprlandFocusGrab swallowed input.)
// Children go into a ColumnLayout; give them Layout.fillWidth as needed.
PanelWindow {
    id: root

    required property Item owner
    property bool open: false
    property string name: ""
    property int padding: 16
    property int cardWidth: 320
    property real anchorX: 0
    default property alias content: column.data

    function toggle() {
        open = !open;
    }

    onOpenChanged: {
        if (open) {
            if (Popups.current && Popups.current !== root)
                Popups.current.open = false;
            Popups.current = root;
            // remember where the pill is; card.x binds to it once the window has a size
            anchorX = owner.mapToItem(null, owner.width / 2, 0).x;
            keys.forceActiveFocus();
        } else if (Popups.current === root) {
            Popups.current = null;
        }
    }

    Connections {
        target: Popups
        function onRequested(n) {
            if (n === root.name && Hyprland.focusedMonitor && root.screen && root.screen.name === Hyprland.focusedMonitor.name)
                root.toggle();
        }
    }

    screen: owner.QsWindow.window ? owner.QsWindow.window.screen : null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    margins.top: Settings.barBottom ? 0 : Theme.barHeight
    margins.bottom: Settings.barBottom ? Theme.barHeight : 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-popout"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    visible: open || card.opacity > 0.01

    // outside click → close
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.open = false
    }

    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: root.open = false
    }

    Rectangle {
        id: card
        x: Math.max(8, Math.min(root.width - root.cardWidth - 8, root.anchorX - root.cardWidth / 2))
        y: Settings.barBottom ? root.height - height - 8 : 8
        width: root.cardWidth
        height: column.implicitHeight + root.padding * 2
        radius: Theme.cardRadius
        color: Theme.cardBg
        border.color: Theme.border
        border.width: 1
        clip: true      // content stays inside while the height animates

        // open: fade + slight zoom out of the bar; content changes (tabs,
        // search results…) resize smoothly once the card is fully shown
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.97
        transformOrigin: Settings.barBottom ? Item.Bottom : Item.Top
        Behavior on opacity {
            Anim {
                duration: Theme.animFast
            }
        }
        Behavior on scale {
            Anim {}
        }
        Behavior on height {
            enabled: root.open && card.opacity > 0.99
            Anim {}
        }
        transform: Translate {
            y: root.open ? 0 : (Settings.barBottom ? 8 : -8)
            Behavior on y {
                Anim {}
            }
        }

        // eat clicks on the card's background so they don't close it
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        ColumnLayout {
            id: column
            x: root.padding
            y: root.padding
            width: root.cardWidth - root.padding * 2
            spacing: 12
        }
    }
}
