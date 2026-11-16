import QtQuick
import qs.services

// Open/pinned logic shared by the edge drawers (sidebar, notes, dashboard).
//  - mouse rests on the drawer's screen edge (EdgeSensor) → opens after a
//    short dwell, unpinned; leaving edge + panel closes it again
//  - keybind / IPC (openPinned / toggle) or a click inside → pinned: stays
//    until closed (keybind, Esc, its close button)
// Panels bind: panelHovered (HoverHandler on the panel), and use
// keyboardFocus() for WlrLayershell.keyboardFocus.
Item {
    id: st

    property bool open: false
    property bool pinned: false
    property bool panelHovered: false
    property bool edgeHovered: false
    // briefly true after a click pinned it: grab the keyboard once so the
    // first click into a text field can type
    property bool grabbing: false

    function openPinned() {
        pinned = true;
        open = true;
    }
    function toggle() {
        if (open && pinned)
            close();
        else
            openPinned();
    }
    function close() {
        open = false;
        pinned = false;
    }
    // call on any press inside the panel
    function pinFromClick() {
        if (!open || pinned)
            return;
        pinned = true;
        grabbing = true;
        ungrab.restart();
    }
    // value for WlrLayershell.keyboardFocus
    function keyboardFocus(onDemand, exclusive, none) {
        if (!open || !pinned)
            return none;          // hover-opened: never steal the keyboard
        return grabbing ? exclusive : onDemand;
    }

    onEdgeHoveredChanged: {
        if (edgeHovered && !open && Settings.edgeDrawers)
            dwell.restart();
        else
            dwell.stop();
        check();
    }
    onPanelHoveredChanged: check()
    onPinnedChanged: check()
    function check() {
        if (open && !pinned && !panelHovered && !edgeHovered)
            leave.restart();
        else
            leave.stop();
    }

    Timer {
        id: dwell
        interval: 180
        onTriggered: if (st.edgeHovered) {
            st.pinned = false;
            st.open = true;
        }
    }
    Timer {
        id: leave
        interval: 400
        onTriggered: if (!st.pinned && !st.panelHovered && !st.edgeHovered) st.close()
    }
    Timer {
        id: ungrab
        interval: 300
        onTriggered: st.grabbing = false
    }
}
