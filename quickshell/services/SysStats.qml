pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU / RAM / disk / temperature / uptime. Polls every 2 s, but only while
// something sets `active` (the sidebar does while it's open).
Singleton {
    id: root

    property bool active: false
    property real cpu: 0          // 0..1
    property real mem: 0          // 0..1
    property real memUsedGb: 0
    property real memTotalGb: 0
    property real disk: 0         // 0..1, root filesystem
    property string diskText: ""
    property real temp: 0         // °C, hottest thermal zone
    property real uptime: 0       // seconds

    property var lastCpu: null

    function uptimeText() {
        const m = Math.floor(uptime / 60), h = Math.floor(m / 60), d = Math.floor(h / 24);
        if (d > 0)
            return d + "d " + (h % 24) + "h";
        if (h > 0)
            return h + "h " + (m % 60) + "m";
        return m + "m";
    }

    Process {
        id: poll
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; df -Pk / | tail -1; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1; cut -d' ' -f1 /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                if (l.length < 6)
                    return;
                // cpu  user nice system idle iowait irq softirq steal
                const c = l[0].trim().split(/\s+/).slice(1).map(Number);
                const idle = c[3] + (c[4] || 0), total = c.reduce((a, b) => a + b, 0);
                if (root.lastCpu) {
                    const dt = total - root.lastCpu.total, di = idle - root.lastCpu.idle;
                    root.cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0;
                }
                root.lastCpu = {
                    total,
                    idle
                };
                const memTotal = parseInt(l[1].split(/\s+/)[1]), memAvail = parseInt(l[2].split(/\s+/)[1]);
                root.mem = 1 - memAvail / memTotal;
                root.memTotalGb = memTotal / 1048576;
                root.memUsedGb = (memTotal - memAvail) / 1048576;
                const d = l[3].trim().split(/\s+/);
                root.disk = parseInt(d[2]) / parseInt(d[1]);
                root.diskText = (parseInt(d[2]) / 1048576).toFixed(0) + " / " + (parseInt(d[1]) / 1048576).toFixed(0) + " GB";
                root.temp = parseInt(l[4]) / 1000;
                root.uptime = parseFloat(l[5]);
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }
}
