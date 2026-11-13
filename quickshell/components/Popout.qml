import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.services

// A bar pill's card. Not a window of its own: the content lives here and is
// shown by the screen's shared PopoutHost while open, which slides it out of
// the bar and morphs size/position when you move between pills.
// Children go into a ColumnLayout; give them Layout.fillWidth as needed.
//   open      – shown (set by hover, click or IPC)
//   toggle()  – click on the pill: open + pin, or close if already pinned
Item {
    id: root

    required property Item owner
    property bool open: false
    property string name: ""
    property int padding: 16
    property int cardWidth: 320
    property real anchorX: 0                     // pill centre, screen coords
    readonly property var screen: owner.QsWindow.window ? owner.QsWindow.window.screen : null
    readonly property alias column: column
    default property alias content: column.data

    // takes no space in the pill's row
    visible: false
    Layout.preferredWidth: 0

    function toggle() {
        if (open && Popups.pinned)
            open = false;
        else
            Popups.show(root, true);
    }

    onOpenChanged: {
        if (open) {
            if (Popups.current && Popups.current !== root)
                Popups.current.open = false;
            anchorX = owner.mapToItem(null, owner.width / 2, 0).x;
            Popups.current = root;
        } else if (Popups.current === root) {
            Popups.current = null;
        }
    }

    // let the pill report hover to Popups
    Component.onCompleted: if (owner && owner.popout !== undefined) owner.popout = root

    Connections {
        target: Popups
        function onRequested(n) {
            if (n === root.name && Hyprland.focusedMonitor && root.screen && root.screen.name === Hyprland.focusedMonitor.name)
                root.toggle();
        }
    }

    // the content; PopoutHost reparents this into its card while open
    ColumnLayout {
        id: column
        x: root.padding
        y: root.padding
        width: root.cardWidth - root.padding * 2
        spacing: 12
    }
}
