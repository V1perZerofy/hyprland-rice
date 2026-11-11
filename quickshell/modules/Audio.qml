import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.services
import qs.components

// Volume. Scroll ±1% · Left: mixer card · Right: mute · Middle: pavucontrol.
Pill {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: !sink || !sink.audio || sink.audio.muted
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio && n.description !== "Easy Effects Sink")

    function volIcon(v, m) {
        if (m || v <= 0)
            return Icons.volMute;
        return v < 0.34 ? Icons.volLow : v < 0.67 ? Icons.volMid : Icons.volHigh;
    }
    function setVol(node, v) {
        if (node && node.audio) {
            node.audio.muted = false;
            node.audio.volume = Math.max(0, Math.min(1, v));
        }
    }
    // Sinks on one card share a long prefix ("500 Series Chipset … (HD Audio) ");
    // drop it so the list reads "Speaker", "HDMI / DisplayPort 1 Output", …
    readonly property string sinkPrefix: {
        const ds = sinks.map(n => n.description || "");
        if (ds.length < 2)
            return "";
        let pre = ds[0];
        for (const d of ds)
            while (!d.startsWith(pre))
                pre = pre.slice(0, -1);
        const cut = pre.lastIndexOf(" ");
        return cut > 0 ? pre.slice(0, cut + 1) : "";
    }
    function name(n) {
        if (!n)
            return "—";
        let d = n.description || n.nickname || n.name;
        if (sinkPrefix && d.startsWith(sinkPrefix))
            d = d.slice(sinkPrefix.length);
        return d.replace(/ \(Stereo\)$/, "");
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    active: pop.open
    onClicked: m => {
        if (m.button === Qt.RightButton && sink)
            sink.audio.muted = !sink.audio.muted;
        else if (m.button === Qt.MiddleButton)
            Quickshell.execDetached(["pavucontrol"]);
        else
            pop.toggle();
    }
    onWheel: w => setVol(sink, Math.round(volume * 100 + (w.angleDelta.y > 0 ? 1 : -1)) / 100)

    Glyph {
        text: root.volIcon(root.volume, root.muted)
        color: root.muted ? Theme.muted : Theme.primary
    }
    StyledText {
        visible: !root.muted
        text: Math.round(root.volume * 100) + "%"
        size: Theme.fontSmall + 1
    }

    Popout {
        id: pop
        owner: root
        name: "audio"
        cardWidth: 340

        Header {
            icon: Icons.speaker
            title: "Sound"
            subtitle: root.name(root.sink)
        }

        // output
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            IconButton {
                icon: root.volIcon(root.volume, root.muted)
                size: 32
                highlighted: !root.muted
                onClicked: if (root.sink) root.sink.audio.muted = !root.sink.audio.muted
            }
            Slider {
                Layout.fillWidth: true
                value: root.volume
                enabled: !root.muted
                onMoved: v => root.setVol(root.sink, v)
            }
            StyledText {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.volume * 100) + "%"
                size: Theme.fontSmall
            }
        }

        // input
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: root.source !== null && root.source.audio !== null
            readonly property bool micMuted: root.source && root.source.audio ? root.source.audio.muted : true
            readonly property real micVol: root.source && root.source.audio ? root.source.audio.volume : 0
            IconButton {
                icon: parent.micMuted ? Icons.micOff : Icons.mic
                size: 32
                highlighted: !parent.micMuted
                accent: Theme.tertiary
                onClicked: root.source.audio.muted = !root.source.audio.muted
            }
            Slider {
                Layout.fillWidth: true
                value: parent.micVol
                accent: Theme.tertiary
                enabled: !parent.micMuted
                onMoved: v => root.setVol(root.source, v)
            }
            StyledText {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: Math.round(parent.micVol * 100) + "%"
                size: Theme.fontSmall
            }
        }

        StyledText {
            visible: root.sinks.length > 1
            text: "Output device"
            size: Theme.fontSmall
            bold: true
            color: Theme.subtext
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: root.sinks.length > 1
            Repeater {
                model: root.sinks
                ListRow {
                    required property var modelData
                    icon: /headphone|headset|bluez/i.test(modelData.name + modelData.description) ? Icons.headphones : Icons.speaker
                    title: root.name(modelData)
                    selected: modelData === root.sink
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }
        }

        IconButton {
            Layout.fillWidth: true
            icon: Icons.volHigh
            label: "Open mixer"
            onClicked: {
                pop.open = false;
                Quickshell.execDetached(["pavucontrol"]);
            }
        }
    }
}
