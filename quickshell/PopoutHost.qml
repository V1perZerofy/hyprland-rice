import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// The one popout surface per screen. Shows Popups.current's content in a card
// that grows out of the bar and morphs (position, size, content crossfade)
// when you move from one pill to the next.
//  - hover-opened: only the card takes input (desktop stays clickable), no
//    keyboard
//  - pinned (clicked / used): full-screen backdrop closes on outside click,
//    keyboard on demand, Esc closes
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    readonly property var target: Popups.current && Popups.current.screen === modelData ? Popups.current : null
    // what the card is showing; outlives `target` until the close animation ends
    property var shown: null
    readonly property bool open: target !== null

    // ── content handover ──
    onTargetChanged: {
        if (target) {
            if (shown && shown !== target)
                give(shown);
            take(target);             // closed card is height 0 → it grows from the bar
            contentFade.restart();
        }
        wasOpen = target !== null;
    }
    property bool wasOpen: false

    function take(p) {
        shown = p;
        p.column.parent = content;
    }
    function give(p) {
        p.column.parent = p;          // back into its (hidden) Popout
    }

    // geometry the card morphs to
    readonly property real tw: shown ? shown.cardWidth : 0
    readonly property real th: shown ? shown.column.implicitHeight + shown.padding * 2 : 0
    readonly property real tx: shown ? Math.max(8, Math.min(width - tw - 8, shown.anchorX - tw / 2)) : 0

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
    // keyboard only once pinned (then all of it until closed, so the first
    // click into a search field can type). Hover never touches focus: switching
    // keyboard modes under the pointer made the compositor send bogus leaves.
    WlrLayershell.keyboardFocus: open && Popups.pinned ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: open || card.height > 0.5
    // hover-opened: only the card is solid, the rest clicks through
    mask: Popups.pinned ? null : cardRegion
    Region {
        id: cardRegion
        item: card
    }

    // pinned: click outside → close
    MouseArea {
        anchors.fill: parent
        enabled: Popups.pinned
        acceptedButtons: Qt.AllButtons
        onPressed: Popups.close()
    }

    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: Popups.close()
    }
    onOpenChanged: if (open && Popups.pinned) keys.forceActiveFocus()

    Rectangle {
        id: card
        x: root.tx
        y: Settings.barBottom ? root.height - height - 6 : 6
        width: root.tw
        height: root.open ? root.th : 0
        radius: Theme.cardRadius
        color: Theme.cardBg
        border.color: Theme.border
        border.width: 1
        clip: true
        opacity: root.open ? 1 : 0

        // morph between pills / grow out of the bar / content changes
        Behavior on x {
            enabled: root.wasOpen
            Anim {
                duration: Theme.animSlow
            }
        }
        Behavior on width {
            enabled: root.wasOpen
            Anim {
                duration: Theme.animSlow
            }
        }
        Behavior on height {
            Anim {
                duration: Theme.animSlow
            }
        }
        Behavior on opacity {
            Anim {
                duration: Theme.anim
            }
        }
        onHeightChanged: if (!root.open && height < 0.5 && root.shown) {
            root.give(root.shown);
            root.shown = null;
        }

        HoverHandler {
            onHoveredChanged: Popups.cardHovered = hovered
        }
        // eat clicks on the card background so the backdrop doesn't close it
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        // content sits at the card's top (bottom bar: bottom) so the grow
        // reveals it from the bar side
        // on top of everything: any press pins the card, then the press goes
        // on to the control underneath (accepted = false)
        MouseArea {
            anchors.fill: parent
            z: 100
            acceptedButtons: Qt.AllButtons
            onPressed: m => {
                if (!Popups.pinned)
                    Popups.pinned = true;
                m.accepted = false;
            }
        }

        Item {
            id: content
            width: root.tw
            height: root.th
            y: Settings.barBottom ? card.height - height : 0
            opacity: 1
            NumberAnimation on opacity {
                id: contentFade
                running: false
                from: 0
                to: 1
                duration: Theme.anim
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve
            }
        }
    }
}
