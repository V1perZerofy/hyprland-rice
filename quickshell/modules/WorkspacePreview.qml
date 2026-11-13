import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.services
import qs.components

// Live mini-map of a workspace, shown under the bar while hovering its chip.
// Windows are drawn at their real positions (scaled) with live screencopy
// content; click a window to focus it, click the background to switch.
PanelWindow {
    id: root

    required property Item owner              // the Workspaces item
    property HyprlandWorkspace ws: null        // workspace being shown
    property real centreX: 0                   // chip centre, window coords
    property bool shown: false

    readonly property HyprlandMonitor mon: ws && ws.monitor ? ws.monitor : Hyprland.focusedMonitor
    readonly property real monW: mon ? mon.width / mon.scale : 1920
    readonly property real monH: mon ? mon.height / mon.scale : 1080
    readonly property real mapW: 360
    readonly property real f: mapW / monW
    readonly property real mapH: monH * f
    readonly property var wins: ws ? ws.toplevels.values : []
    readonly property bool cardHovered: hover.hovered

    function addr(t) {
        const a = t.address || "";
        return a.startsWith("0x") ? a : "0x" + a;
    }

    onShownChanged: if (shown) Hyprland.refreshToplevels()
    onWsChanged: if (shown) Hyprland.refreshToplevels()

    screen: owner.QsWindow.window ? owner.QsWindow.window.screen : null
    anchors {
        top: !Settings.barBottom
        bottom: Settings.barBottom
        left: true
        right: true
    }
    margins.top: Settings.barBottom ? 0 : Theme.barHeight
    margins.bottom: Settings.barBottom ? Theme.barHeight : 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-wspreview"
    color: "transparent"
    implicitHeight: card.height + 20
    // only the card takes input; the rest of the strip is click-through
    mask: Region {
        item: card
    }
    visible: shown || card.opacity > 0.01

    Rectangle {
        id: card
        width: root.mapW + 20
        height: root.mapH + 52
        y: Settings.barBottom ? 12 : 8
        x: Math.max(8, Math.min(root.width - width - 8, root.centreX - width / 2))
        radius: Theme.cardRadius
        color: Theme.cardBg
        border.color: Theme.border
        border.width: 1

        Behavior on x {
            enabled: root.shown && card.opacity > 0.5
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        opacity: root.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        transform: Translate {
            y: root.shown ? 0 : (Settings.barBottom ? 8 : -8)
            Behavior on y {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        HoverHandler {
            id: hover
        }

        // header
        RowLayout {
            x: 12
            y: 8
            width: parent.width - 24
            height: 24
            StyledText {
                text: root.ws ? "Workspace " + root.ws.name : ""
                bold: true
                size: Theme.fontSmall + 1
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: root.wins.length === 0 ? "empty" : root.wins.length + (root.wins.length === 1 ? " window" : " windows")
                size: Theme.fontSmall - 1
                color: Theme.subtext
            }
        }

        // the mini monitor
        ClippingRectangle {
            id: map
            x: 10
            y: 40
            width: root.mapW
            height: root.mapH
            radius: 10
            color: Theme.surface

            Image {
                anchors.fill: parent
                source: Theme.wallpaper ? "file://" + Theme.wallpaper : ""
                sourceSize.width: 480
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.55
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.ws)
                        Hyprland.dispatch(`hl.dsp.focus({workspace="${root.ws.id}"})`);
                    root.shown = false;
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.wins.length === 0
                text: "Empty"
                color: Theme.subtext
            }

            Repeater {
                model: root.wins

                delegate: Item {
                    id: w
                    required property HyprlandToplevel modelData
                    readonly property var ipc: modelData.lastIpcObject
                    readonly property bool hasGeom: !!(ipc && ipc.at && ipc.size)
                    readonly property string cls: ipc && ipc.class ? ipc.class : ""
                    readonly property bool focused: modelData.activated

                    visible: hasGeom
                    x: hasGeom ? (ipc.at[0] - (root.mon ? root.mon.x : 0)) * root.f : 0
                    y: hasGeom ? (ipc.at[1] - (root.mon ? root.mon.y : 0)) * root.f : 0
                    width: hasGeom ? Math.max(8, ipc.size[0] * root.f) : 0
                    height: hasGeom ? Math.max(8, ipc.size[1] * root.f) : 0
                    z: ipc && ipc.floating ? 1 : 0

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 5
                        color: Theme.alpha(Theme.bg, 0.85)
                        border.width: w.focused || winMouse.containsMouse ? 2 : 1
                        border.color: winMouse.containsMouse ? Theme.fg : w.focused ? Theme.primary : Theme.border

                        ScreencopyView {
                            id: copy
                            anchors.fill: parent
                            captureSource: root.shown ? w.modelData.wayland : null
                            live: root.shown
                            constraintSize: Qt.size(w.width * 2, w.height * 2)
                        }

                        // fallback / overlay: app icon
                        IconImage {
                            readonly property string src: w.cls ? Quickshell.iconPath(DesktopEntries.heuristicLookup(w.cls)?.icon ?? w.cls.toLowerCase(), true) : ""
                            anchors.centerIn: parent
                            implicitSize: Math.min(28, Math.min(w.width, w.height) * 0.5)
                            source: src
                            visible: src !== "" && (!copy.hasContent || winMouse.containsMouse)
                        }
                    }

                    MouseArea {
                        id: winMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Hyprland.dispatch(`hl.dsp.focus({window="address:${root.addr(w.modelData)}"})`);
                            root.shown = false;
                        }
                    }
                }
            }
        }
    }
}
