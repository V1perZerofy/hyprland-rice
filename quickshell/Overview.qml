import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.services
import qs.components

// Workspace overview (SUPER+Tab): every workspace as a live mini-screen,
// plus an empty one at the end.
//   click a workspace      → go there
//   click a window         → focus it
//   drag a window          → onto another workspace to move it there
//   middle-click a window  → close it
//   ←/→/↑/↓ select · Enter go · 1–9 jump · Esc / SUPER+Tab close
//   qs ipc call overview toggle
Scope {
    id: root

    IpcHandler {
        target: "overview"
        function toggle(): void {
            ov.toggle();
        }
    }

    // existing workspaces + the next free one (drop a window there to make it)
    readonly property var spaces: {
        const list = Hyprland.workspaces.values.filter(w => w.id > 0).sort((a, b) => a.id - b.id);
        const next = (list.length ? list[list.length - 1].id : 0) + 1;
        return list.map(w => ({
                    id: w.id,
                    ws: w
                })).concat([{
                    id: next,
                    ws: null
                }]);
    }
    readonly property int activeId: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace ? Hyprland.focusedMonitor.activeWorkspace.id : 1
    property int sel: 0

    // dragging a window: { addr, from, icon }, ghost position and target
    property var drag: null
    property point dragPos: Qt.point(0, 0)
    property int dropId: -1

    function addr(t) {
        const a = t.address || "";
        return a.startsWith("0x") ? a : "0x" + a;
    }
    // Hyprland ignores focus changes while this overlay holds exclusive
    // keyboard focus, so close first and dispatch once it has let go
    property string pending: ""
    function afterClose(cmd) {
        pending = cmd;
        ov.open = false;
        dispatchLater.restart();
    }
    function goTo(id) {
        afterClose(`hl.dsp.focus({workspace="${id}"})`);
    }
    function focusWindow(t) {
        afterClose(`hl.dsp.focus({window="address:${addr(t)}"})`);
    }
    Timer {
        id: dispatchLater
        interval: 120
        onTriggered: {
            if (root.pending)
                Hyprland.dispatch(root.pending);
            root.pending = "";
        }
    }
    function moveWindow(a, id) {
        Hyprland.dispatch(`hl.dsp.window.move({workspace=${id}, follow=false, window="address:${a}"})`);
        refresh.restart();
    }
    function closeWindow(t) {
        Hyprland.dispatch(`hl.dsp.window.close({window="address:${addr(t)}"})`);
        refresh.restart();
    }
    function iconFor(cls) {
        return cls ? Quickshell.iconPath(DesktopEntries.heuristicLookup(cls)?.icon ?? cls.toLowerCase(), true) : "";
    }

    // window geometry comes from lastIpcObject, which needs a refresh
    Timer {
        id: refresh
        interval: 150
        onTriggered: Hyprland.refreshToplevels()
    }

    Overlay {
        id: ov

        readonly property HyprlandMonitor mon: Hyprland.focusedMonitor
        readonly property real monW: mon ? mon.width / mon.scale : 1920
        readonly property real monH: mon ? mon.height / mon.scale : 1080
        readonly property int cols: Math.min(4, root.spaces.length)
        readonly property int rows: Math.ceil(root.spaces.length / cols)
        readonly property int gap: 18
        readonly property int pad: 24
        readonly property int labelH: 30
        readonly property int headerH: 46
        // tile width: as wide as fits, but the whole grid must fit vertically
        readonly property real tileW: {
            const byW = (Math.min(width - 80, 1700) - 2 * pad - (cols - 1) * gap) / cols;
            const byH = ((height - 100 - 2 * pad - headerH - (rows - 1) * gap) / rows - labelH) * monW / monH;
            return Math.floor(Math.max(120, Math.min(byW, byH)));
        }
        readonly property real tileH: tileW * monH / monW
        readonly property real f: tileW / monW

        cardWidth: cols * tileW + (cols - 1) * gap + 2 * pad
        cardHeight: headerH + rows * (tileH + labelH) + (rows - 1) * gap + 2 * pad
        card.color: Theme.panelBg

        onOpened: {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
            root.sel = Math.max(0, root.spaces.findIndex(s => s.id === root.activeId));
            root.drag = null;
            keys.forceActiveFocus();
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                const n = root.spaces.length, c = ov.cols;
                if (e.key === Qt.Key_Escape || e.key === Qt.Key_Tab)
                    ov.open = false;
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_L)
                    root.sel = (root.sel + 1) % n;
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_H)
                    root.sel = (root.sel - 1 + n) % n;
                else if (e.key === Qt.Key_Down || e.key === Qt.Key_J)
                    root.sel = Math.min(n - 1, root.sel + c);
                else if (e.key === Qt.Key_Up || e.key === Qt.Key_K)
                    root.sel = Math.max(0, root.sel - c);
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                    root.goTo(root.spaces[root.sel].id);
                else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9)
                    root.goTo(e.key - Qt.Key_0);
                else
                    return;
                e.accepted = true;
            }
        }

        // header
        RowLayout {
            x: ov.pad
            y: ov.pad - 4
            width: ov.cardWidth - 2 * ov.pad
            height: ov.headerH - 12
            spacing: 10
            Glyph {
                text: Icons.dashboard
                color: Theme.primary
                size: 18
            }
            StyledText {
                text: "Workspaces"
                bold: true
                size: Theme.fontSize + 2
            }
            Item {
                Layout.fillWidth: true
            }
            StyledText {
                text: root.drag ? "Drop on a workspace to move the window" : "Click to go  ·  drag a window to move it  ·  middle-click closes  ·  ←→↑↓ Enter 1–9"
                size: Theme.fontSmall - 1
                color: root.drag ? Theme.primary : Theme.subtext
            }
        }

        Grid {
            id: grid
            x: ov.pad
            y: ov.pad + ov.headerH
            columns: ov.cols
            spacing: ov.gap

            Repeater {
                id: tiles
                model: root.spaces

                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property var ws: modelData.ws
                    readonly property var wins: ws ? ws.toplevels.values : []
                    readonly property bool current: modelData.id === root.activeId
                    readonly property bool selected: index === root.sel
                    readonly property bool dropTarget: root.drag !== null && root.dropId === modelData.id && root.drag.from !== modelData.id
                    width: ov.tileW
                    height: ov.tileH + ov.labelH

                    // label
                    RowLayout {
                        width: parent.width
                        height: ov.labelH - 6
                        spacing: 8
                        Rectangle {
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 11
                            color: tile.current ? Theme.primary : Theme.surface
                            StyledText {
                                anchors.centerIn: parent
                                text: tile.modelData.id
                                bold: true
                                size: Theme.fontSmall
                                color: tile.current ? Theme.bg : Theme.fg
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: !tile.ws ? "New workspace" : tile.wins.length === 0 ? "Empty" : tile.wins.length + (tile.wins.length === 1 ? " window" : " windows")
                            size: Theme.fontSmall - 1
                            color: Theme.subtext
                        }
                    }

                    ClippingRectangle {
                        id: map
                        y: ov.labelH
                        width: ov.tileW
                        height: ov.tileH
                        radius: 12
                        color: Theme.surface
                        border.width: tile.dropTarget || tile.selected || tile.current ? 2 : 1
                        border.color: tile.dropTarget ? Theme.success : tile.selected ? Theme.fg : tile.current ? Theme.primary : Theme.border

                        Image {
                            anchors.fill: parent
                            source: Theme.wallpaper ? "file://" + Theme.wallpaper : ""
                            sourceSize.width: 640
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: tile.ws ? 0.6 : 0.25
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.success
                            opacity: tile.dropTarget ? 0.18 : 0
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: if (!root.drag) root.sel = tile.index
                            onClicked: root.goTo(tile.modelData.id)
                        }

                        Glyph {
                            anchors.centerIn: parent
                            visible: !tile.ws
                            text: "+"
                            size: 30
                            color: Theme.subtext
                        }

                        Repeater {
                            model: tile.wins

                            delegate: Item {
                                id: w
                                required property HyprlandToplevel modelData
                                readonly property var ipc: modelData.lastIpcObject
                                readonly property bool hasGeom: !!(ipc && ipc.at && ipc.size)
                                readonly property string cls: ipc && ipc.class ? ipc.class : ""
                                readonly property real mx: tile.ws && tile.ws.monitor ? tile.ws.monitor.x : 0
                                readonly property real my: tile.ws && tile.ws.monitor ? tile.ws.monitor.y : 0
                                readonly property bool dragged: root.drag !== null && root.drag.addr === root.addr(modelData)

                                visible: hasGeom
                                x: hasGeom ? (ipc.at[0] - mx) * ov.f : 0
                                y: hasGeom ? (ipc.at[1] - my) * ov.f : 0
                                width: hasGeom ? Math.max(10, ipc.size[0] * ov.f) : 0
                                height: hasGeom ? Math.max(10, ipc.size[1] * ov.f) : 0
                                z: ipc && ipc.floating ? 1 : 0
                                opacity: dragged ? 0.35 : 1

                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: Theme.alpha(Theme.bg, 0.85)
                                    border.width: w.modelData.activated || winMouse.containsMouse ? 2 : 1
                                    border.color: winMouse.containsMouse ? Theme.fg : w.modelData.activated ? Theme.primary : Theme.border

                                    ScreencopyView {
                                        id: copy
                                        anchors.fill: parent
                                        captureSource: ov.open ? w.modelData.wayland : null
                                        live: ov.open
                                        constraintSize: Qt.size(w.width * 2, w.height * 2)
                                    }
                                    IconImage {
                                        readonly property string src: root.iconFor(w.cls)
                                        anchors.centerIn: parent
                                        implicitSize: Math.min(40, Math.min(w.width, w.height) * 0.45)
                                        source: src
                                        visible: src !== "" && (!copy.hasContent || winMouse.containsMouse)
                                    }
                                }

                                MouseArea {
                                    id: winMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    cursorShape: root.drag ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    property point start
                                    onEntered: if (!root.drag) root.sel = tile.index
                                    onPressed: m => start = Qt.point(m.x, m.y)
                                    onPositionChanged: m => {
                                        if (!pressed || !(pressedButtons & Qt.LeftButton))
                                            return;
                                        if (!root.drag && Math.hypot(m.x - start.x, m.y - start.y) > 8)
                                            root.drag = {
                                                addr: root.addr(w.modelData),
                                                from: tile.modelData.id,
                                                icon: root.iconFor(w.cls),
                                                title: w.ipc && w.ipc.title ? w.ipc.title : w.cls
                                            };
                                        if (!root.drag)
                                            return;
                                        const p = mapToItem(grid, m.x, m.y);
                                        root.dragPos = mapToItem(ov.card, m.x, m.y);
                                        root.dropId = -1;
                                        for (let i = 0; i < tiles.count; i++) {
                                            const t = tiles.itemAt(i);
                                            if (t && p.x >= t.x && p.x <= t.x + t.width && p.y >= t.y && p.y <= t.y + t.height) {
                                                root.dropId = t.modelData.id;
                                                root.sel = i;
                                            }
                                        }
                                    }
                                    onReleased: m => {
                                        if (root.drag) {
                                            if (root.dropId > 0 && root.dropId !== root.drag.from)
                                                root.moveWindow(root.drag.addr, root.dropId);
                                            root.drag = null;
                                            root.dropId = -1;
                                        }
                                    }
                                    onClicked: m => {
                                        if (m.button === Qt.MiddleButton)
                                            root.closeWindow(w.modelData);
                                        else if (Math.hypot(m.x - start.x, m.y - start.y) <= 8)
                                            root.focusWindow(w.modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // the window being dragged
        Rectangle {
            visible: root.drag !== null
            x: root.dragPos.x - width / 2
            y: root.dragPos.y - height / 2
            z: 10
            width: Math.min(260, ghostRow.implicitWidth + 24)
            height: 44
            radius: 12
            color: Theme.surfaceHi
            border.color: root.dropId > 0 && root.drag && root.dropId !== root.drag.from ? Theme.success : Theme.primary
            border.width: 2
            RowLayout {
                id: ghostRow
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 8
                IconImage {
                    implicitSize: 24
                    source: root.drag ? root.drag.icon : ""
                    visible: source !== ""
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.drag ? root.drag.title : ""
                    size: Theme.fontSmall
                }
            }
        }
    }
}
