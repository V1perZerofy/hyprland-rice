import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs.services
import qs.components

// Volume / mic / brightness OSD: bottom-centre pill on the focused monitor,
// click-through, fades out after 1.5 s. Driven by ~/.config/hypr/scripts/osd.sh:
//   qs ipc call osd volume | osd mic | osd brightness <0-100>
Scope {
    id: root

    property string kind: "volume"
    property real brightness: 0
    property bool shown: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var node: kind === "mic" ? source : sink
    readonly property bool muted: kind !== "brightness" && (!node || !node.audio || node.audio.muted)
    readonly property real value: kind === "brightness" ? brightness : node && node.audio ? node.audio.volume : 0

    readonly property string icon: {
        if (kind === "brightness")
            return Icons.brightness[Math.min(2, Math.floor(value * 3))];
        if (kind === "mic")
            return muted ? Icons.micOff : Icons.mic;
        if (muted || value <= 0)
            return Icons.volMute;
        return value < 0.34 ? Icons.volLow : value < 0.67 ? Icons.volMid : Icons.volHigh;
    }

    function trigger(k) {
        kind = k;
        shown = true;
        hide.restart();
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    Timer {
        id: hide
        interval: 1500
        onTriggered: root.shown = false
    }

    IpcHandler {
        target: "osd"
        function volume(): void {
            root.trigger("volume");
        }
        function mic(): void {
            root.trigger("mic");
        }
        function brightness(percent: int): void {
            root.brightness = percent / 100;
            root.trigger("brightness");
        }
    }

    PanelWindow {
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
        anchors.bottom: true
        margins.bottom: 90
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-osd"
        color: "transparent"
        mask: Region {}

        implicitWidth: 320
        implicitHeight: 56
        visible: root.shown || pill.opacity > 0.01

        Rectangle {
            id: pill
            anchors.fill: parent
            radius: height / 2
            color: Theme.cardBg
            border.color: Theme.border
            border.width: 1

            opacity: root.shown ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
            transform: Translate {
                y: root.shown ? 0 : 16
                Behavior on y {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 20
                spacing: 14

                Glyph {
                    text: root.icon
                    size: 22
                    color: root.muted ? Theme.muted : root.kind === "mic" ? Theme.tertiary : Theme.primary
                    Layout.preferredWidth: 24
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: 4
                    color: Theme.surfaceHi
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, root.muted ? 0 : root.value))
                        height: parent.height
                        radius: 4
                        color: root.kind === "mic" ? Theme.tertiary : Theme.primary
                        Behavior on width {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                StyledText {
                    Layout.preferredWidth: 46
                    horizontalAlignment: Text.AlignRight
                    text: root.muted ? "Muted" : Math.round(root.value * 100) + "%"
                    size: Theme.fontSmall + 1
                    bold: true
                    color: root.muted ? Theme.subtext : Theme.fg
                }
            }
        }
    }
}
