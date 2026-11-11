pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Audio visualiser data from cava (scripts/cava.conf, raw ascii output).
// cava only runs while `active` — the media pill sets it while playing.
Singleton {
    id: root

    property bool active: false
    property var bars: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]     // 0..1

    Process {
        running: root.active
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/quickshell/scripts/cava.conf"]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(x => x !== "").map(x => parseInt(x) / 100);
                if (v.length)
                    root.bars = v;
            }
        }
        onRunningChanged: if (!running) root.bars = root.bars.map(() => 0)
    }
}
