pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen backlight via brightnessctl. `value` is 0..1.
Singleton {
    id: root

    property real value: 0
    property bool available: true

    function refresh() {
        if (!get.running)
            get.running = true;
    }
    property real pending: -1      // latest value requested while a set is running

    function set(v) {
        v = Math.max(0.01, Math.min(1, v));
        value = v;
        if (setter.running)
            pending = v;
        else
            run(v);
    }
    function run(v) {
        setter.command = ["brightnessctl", "-q", "set", Math.round(v * 100) + "%"];
        setter.running = true;
    }

    Process {
        id: get
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // device,class,current,percent%,max
                const f = text.trim().split("\n")[0].split(",");
                root.available = f.length >= 4;
                if (root.available)
                    root.value = parseInt(f[3]) / 100;
            }
        }
    }
    Process {
        id: setter
        onExited: {
            if (root.pending >= 0) {
                const v = root.pending;
                root.pending = -1;
                root.run(v);
            }
        }
    }

    Component.onCompleted: refresh()
}
