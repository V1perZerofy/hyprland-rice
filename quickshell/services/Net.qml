pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager state via nmcli. (Quickshell.Networking finds no devices with
// NM 1.58 on qs 0.3.2, so this is the reliable path.) Refreshes on every
// `nmcli monitor` event, plus a slow safety poll.
Singleton {
    id: root

    property bool wifiEnabled: false
    property string wifiDevice: ""
    property bool wired: false
    property var current: null      // { ssid, signal, security }
    property var networks: []       // [{ ssid, signal, security, active, known }]
    property var saved: ({})        // ssid -> true
    property string busy: ""        // ssid being (dis)connected

    // nmcli -t escapes ':' as '\:' inside fields
    function fields(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                cur += line[++i];
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else
                cur += c;
        }
        out.push(cur);
        return out;
    }

    function refresh() {
        if (!status.running)
            status.running = true;
    }
    function scan() {
        run(["nmcli", "dev", "wifi", "rescan"]);
    }
    function setWifi(on) {
        run(["nmcli", "radio", "wifi", on ? "on" : "off"]);
    }
    function connect(ssid) {
        busy = ssid;
        run(["nmcli", "dev", "wifi", "connect", ssid]);
    }
    function disconnect() {
        busy = current ? current.ssid : "";
        run(["nmcli", "dev", "disconnect", wifiDevice]);
    }
    function run(cmd) {
        const p = runner.createObject(root, { command: cmd });
        p.running = true;
    }

    Component {
        id: runner
        Process {
            onExited: {
                root.busy = "";
                root.refresh();
                destroy();
            }
        }
    }

    Process {
        id: status
        command: ["sh", "-c", "nmcli radio wifi; echo '##'; nmcli -t -f DEVICE,TYPE,STATE device; echo '##'; nmcli -t -f NAME,TYPE connection show; echo '##'; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("##\n");
                if (parts.length < 4)
                    return;
                root.wifiEnabled = parts[0].trim() === "enabled";

                let wdev = "", wired = false;
                for (const l of parts[1].split("\n")) {
                    const f = root.fields(l);
                    if (f[1] === "wifi" && !wdev)
                        wdev = f[0];
                    if (f[1] === "ethernet" && f[2] === "connected")
                        wired = true;
                }
                root.wifiDevice = wdev;
                root.wired = wired;

                const saved = {};
                for (const l of parts[2].split("\n")) {
                    const f = root.fields(l);
                    if (f[1] === "802-11-wireless")
                        saved[f[0]] = true;
                }
                root.saved = saved;

                const best = {};
                let cur = null;
                for (const l of parts[3].split("\n")) {
                    if (!l.trim())
                        continue;
                    const f = root.fields(l);
                    const n = {
                        active: f[0] === "*",
                        ssid: f[1],
                        signal: (parseInt(f[2]) || 0) / 100,
                        security: f[3] || "",
                        known: !!saved[f[1]]
                    };
                    if (!n.ssid)
                        continue;
                    if (n.active)
                        cur = n;
                    const prev = best[n.ssid];
                    if (!prev || n.active || (!prev.active && n.signal > prev.signal))
                        best[n.ssid] = n;
                }
                root.current = cur;
                root.networks = Object.values(best).sort((a, b) => (b.active - a.active) || (b.known - a.known) || (b.signal - a.signal));
            }
        }
    }

    // event-driven updates
    Process {
        id: monitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: debounce.restart()
        }
        onExited: restartMonitor.start()
    }
    Timer {
        id: restartMonitor
        interval: 5000
        onTriggered: monitor.running = true
    }
    Timer {
        id: debounce
        interval: 400
        onTriggered: root.refresh()
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
