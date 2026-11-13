pragma Singleton

import QtQuick
import Quickshell

// Bar popouts: one at a time, shown in a shared PopoutHost window that morphs
// between them (caelestia-style).
//  - hover a pill → opens after a short delay; hovering the next pill switches
//    instantly; leaving pill + card closes it again
//  - click a pill (or click/type inside the card) → pinned: stays until
//    clicked again, Esc or a click outside. Only pinned cards take keyboard.
Singleton {
    id: root

    property var current: null          // the open Popout
    property bool pinned: false
    property bool barVisible: true

    // `qs ipc call bar popout <name>` → the matching Popout on the focused monitor toggles
    signal requested(string name)
    // `qs ipc call bar peek <workspace id>` → toggle that workspace's preview
    signal peek(int id)

    function show(p, pin) {
        hoverTarget = null;
        openDelay.stop();
        closeDelay.stop();
        if (pin)
            pinned = true;
        p.open = true;
    }
    function close() {
        openDelay.stop();
        closeDelay.stop();
        if (current)
            current.open = false;
    }

    // ── hover ──
    property var hoverTarget: null
    property bool cardHovered: false

    function hoverEnter(p) {
        if (!Settings.hoverPopouts || pinned)
            return;
        closeDelay.stop();
        if (current === p)
            return;
        if (current) {
            show(p, false);         // already open: morph straight to the next one
        } else {
            hoverTarget = p;
            openDelay.restart();
        }
    }
    function hoverLeave(p) {
        if (hoverTarget === p) {
            hoverTarget = null;
            openDelay.stop();
        }
        if (current === p && !pinned)
            closeDelay.restart();
    }
    onCardHoveredChanged: {
        if (cardHovered)
            closeDelay.stop();
        else if (current && !pinned)
            closeDelay.restart();
    }
    onCurrentChanged: if (!current)
        pinned = false

    Timer {
        id: openDelay
        interval: 160
        onTriggered: if (root.hoverTarget) root.show(root.hoverTarget, false)
    }
    Timer {
        id: closeDelay
        interval: 300
        onTriggered: if (!root.pinned && !root.cardHovered) root.close()
    }
}
