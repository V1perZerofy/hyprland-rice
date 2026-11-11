pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pending package updates: official repos (checkupdates) + AUR (paru -Qua).
// Shared by every bar so the check only runs once.
Singleton {
    id: root

    property var packages: []       // [{ name, from, to, aur }]
    readonly property int count: packages.length
    property bool checking: false
    property date lastCheck

    function refresh() {
        if (proc.running)
            return;
        checking = true;
        proc.running = true;
    }

    function upgrade() {
        Quickshell.execDetached(["kitty", "sh", "-c", "paru -Syu; echo; read -n1 -s -r -p 'Done — press any key to close.'"]);
    }

    Process {
        id: proc
        // Prefix AUR lines so they can be tagged in the list.
        command: ["sh", "-c", "checkupdates 2>/dev/null; paru -Qua 2>/dev/null | sed 's/^/aur:/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (let line of text.split("\n")) {
                    line = line.trim();
                    if (!line)
                        continue;
                    const aur = line.startsWith("aur:");
                    if (aur)
                        line = line.slice(4);
                    // "name old -> new"
                    const p = line.split(/\s+/);
                    out.push({
                        name: p[0],
                        from: p[1] || "",
                        to: p[3] || "",
                        aur: aur
                    });
                }
                root.packages = out;
                root.checking = false;
                root.lastCheck = new Date();
            }
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
