import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.components

// Workspaces on this bar's monitor. Active = wide accent pill; occupied ones are
// brighter than empty ones; urgent ones turn red. Scroll to cycle.
Rectangle {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property var workspaces: Hyprland.workspaces.values.filter(w => w.id > 0 && (!root.monitor || w.monitor === root.monitor)).sort((a, b) => a.id - b.id)

    // Your config uses Lua, so dispatchers are Lua expressions.
    // (not "focus": that name is taken by Item.focus and silently shadows the function)
    function goTo(ws) {
        Hyprland.dispatch(`hl.dsp.focus({workspace="${ws}"})`);
    }

    // ── hover preview ────────────────────────────────────────────────────────
    property HyprlandWorkspace hoveredWs: null
    property bool suppress: false            // after a click, until the mouse leaves
    readonly property bool wantPreview: !suppress && (hoveredWs !== null || preview.cardHovered)

    onWantPreviewChanged: {
        if (wantPreview) {
            hideTimer.stop();
            if (!preview.shown)
                showTimer.restart();
        } else {
            showTimer.stop();
            hideTimer.restart();
        }
    }
    onHoveredWsChanged: if (hoveredWs) preview.ws = hoveredWs

    Timer {
        id: showTimer
        interval: 350
        onTriggered: preview.shown = true
    }
    Timer {
        id: hideTimer
        interval: 250
        onTriggered: preview.shown = false
    }

    WorkspacePreview {
        id: preview
        owner: root
    }

    // `qs ipc call bar peek <id>` toggles the preview without hovering
    Connections {
        target: Popups
        function onPeek(id) {
            if (!root.monitor || !Hyprland.focusedMonitor || root.monitor !== Hyprland.focusedMonitor)
                return;
            const ws = root.workspaces.find(w => w.id === id);
            if (!ws)
                return;
            const i = root.workspaces.indexOf(ws);
            const chip = row.children[i];
            if (chip)
                preview.centreX = chip.mapToItem(null, chip.width / 2, 0).x;
            preview.ws = ws;
            preview.shown = !preview.shown;
        }
    }

    implicitWidth: row.implicitWidth + 8
    implicitHeight: Theme.pillHeight
    radius: Theme.radius
    color: Theme.pillBg

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.anim
            easing.type: Easing.OutCubic
        }
    }

    MouseArea {
        anchors.fill: parent
        onWheel: w => root.goTo(w.angleDelta.y > 0 ? "m-1" : "m+1")
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.workspaces

            delegate: Rectangle {
                id: chip
                required property HyprlandWorkspace modelData
                readonly property bool isActive: root.monitor !== null && root.monitor.activeWorkspace === modelData
                readonly property bool occupied: modelData.toplevels.values.length > 0

                width: isActive ? 46 : 24
                height: Theme.pillHeight - 8
                radius: height / 2
                color: modelData.urgent ? Theme.error : isActive ? Theme.primary : hover.containsMouse ? Theme.surfaceHi : occupied ? Theme.alpha(Theme.fg, 0.10) : "transparent"

                Behavior on width {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.4
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.anim
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: chip.modelData.name
                    size: Theme.fontSmall + 1
                    bold: chip.isActive
                    color: chip.isActive || chip.modelData.urgent ? Theme.bg : chip.occupied ? Theme.fg : Theme.alpha(Theme.fg, 0.4)
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) {
                            preview.centreX = chip.mapToItem(null, chip.width / 2, 0).x;
                            root.hoveredWs = chip.modelData;
                        } else if (root.hoveredWs === chip.modelData) {
                            root.hoveredWs = null;
                            root.suppress = false;
                        }
                    }
                    onClicked: {
                        root.suppress = true;
                        preview.shown = false;
                        root.goTo(chip.modelData.id);
                    }
                }
            }
        }
    }
}
