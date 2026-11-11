pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// VPN state for the Wi-Fi card's VPN tab and the bar's lock badge.
//  profiles  – NetworkManager VPN / WireGuard connections (OpenVPN imports, Proton app…)
//  tailscale – tailscaled state, peers, exit node; needs `tailscale set --operator=$USER` once
//  manual    – openvpn processes started by hand (not via NetworkManager)
//  importable – .ovpn files in ~, ~/Downloads, ~/.config/openvpn not imported yet
// Polls every 3 s while `fast` (tab open), otherwise every 15 s.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string authFile: home + "/auth.txt"

    property bool fast: false
    property var profiles: []        // [{ name, uuid, type, active, activating }]
    property var manual: []          // [{ pid, config }]
    property var ovpnFiles: []       // paths
    property var ts: ({
            state: "Unknown",
            ips: [],
            peers: [],
            exitNode: "",
            operator: false,
            installed: true
        })
    property string busy: ""         // uuid / "tailscale" / path being worked on
    property string error: ""

    readonly property var importable: ovpnFiles.filter(p => !profiles.some(c => c.name === p.split("/").pop().replace(/\.ovpn$/i, "")))
    readonly property bool tailscaleUp: ts.state === "Running"
    readonly property bool anyActive: tailscaleUp || manual.length > 0 || profiles.some(p => p.active)
    readonly property string summary: {
        const on = profiles.filter(p => p.active).map(p => p.name);
        if (manual.length)
            on.push("openvpn");
        if (tailscaleUp)
            on.push("Tailscale");
        return on.join(", ");
    }

    function refresh() {
        if (!poll.running)
            poll.running = true;
    }

    function run(cmd, tag) {
        busy = tag || "";
        error = "";
        const p = runner.createObject(root, {
            command: cmd
        });
        p.running = true;
    }

    function toggleProfile(p) {
        run(["nmcli", "connection", p.active ? "down" : "up", "uuid", p.uuid], p.uuid);
    }
    function importOvpn(path) {
        run([home + "/.config/quickshell/scripts/vpn-import.sh", path, authFile], path);
    }
    function deleteProfile(p) {
        run(["nmcli", "connection", "delete", "uuid", p.uuid], p.uuid);
    }
    function toggleTailscale() {
        run(["tailscale", tailscaleUp ? "down" : "up"], "tailscale");
    }
    function setExitNode(host) {
        run(["tailscale", "set", "--exit-node=" + (host || "")], "tailscale");
    }
    function stopManual(m) {
        // started with sudo, so stopping it needs root: polkit asks for the password
        run(["pkexec", "kill", String(m.pid)], "manual");
    }

    Component {
        id: runner
        Process {
            stderr: StdioCollector {
                onStreamFinished: {
                    const t = text.trim();
                    if (t)
                        root.error = t.split("\n").filter(l => l.trim()).pop();
                }
            }
            onExited: code => {
                if (code === 0)
                    root.error = "";
                root.busy = "";
                root.refresh();
                destroy();
            }
        }
    }

    Process {
        id: poll
        command: ["sh", "-c", `
            nmcli -t -f NAME,UUID,TYPE connection show
            echo '##'
            nmcli -t -f UUID,STATE connection show --active
            echo '##'
            command -v tailscale >/dev/null && tailscale status --json 2>/dev/null | tr -d '\\n'
            echo
            echo '##'
            command -v tailscale >/dev/null && tailscale debug prefs 2>/dev/null | tr -d '\\n'
            echo
            echo '##'
            pgrep -a -x openvpn | grep -- '--config' || true
            echo '##'
            find "$HOME" "$HOME/Downloads" "$HOME/.config/openvpn" -maxdepth 1 -iname '*.ovpn' 2>/dev/null
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const part = text.split("##\n");
                if (part.length < 6)
                    return;
                const fields = l => {
                    // nmcli -t escapes ':' as '\:'
                    const out = [];
                    let cur = "";
                    for (let i = 0; i < l.length; i++) {
                        if (l[i] === "\\" && i + 1 < l.length)
                            cur += l[++i];
                        else if (l[i] === ":") {
                            out.push(cur);
                            cur = "";
                        } else
                            cur += l[i];
                    }
                    out.push(cur);
                    return out;
                };

                const active = {};
                for (const l of part[1].split("\n")) {
                    const f = fields(l);
                    if (f[0])
                        active[f[0]] = f[1];
                }
                const profiles = [];
                for (const l of part[0].split("\n")) {
                    const f = fields(l);
                    if (f[2] === "vpn" || f[2] === "wireguard")
                        profiles.push({
                            name: f[0],
                            uuid: f[1],
                            type: f[2] === "vpn" ? "OpenVPN" : "WireGuard",
                            active: active[f[1]] === "activated",
                            activating: active[f[1]] === "activating"
                        });
                }
                root.profiles = profiles;

                const ts = {
                    state: "Unknown",
                    ips: [],
                    peers: [],
                    exitNode: "",
                    operator: false,
                    installed: part[2].trim() !== "" || part[3].trim() !== ""
                };
                try {
                    const s = JSON.parse(part[2]);
                    ts.state = s.BackendState;
                    ts.ips = (s.Self && s.Self.TailscaleIPs) || [];
                    ts.peers = Object.values(s.Peer || {}).map(p => ({
                                host: p.HostName,
                                dns: (p.DNSName || "").replace(/\.$/, ""),
                                ip: (p.TailscaleIPs || [])[0] || "",
                                online: !!p.Online,
                                os: p.OS || "",
                                exitOption: !!p.ExitNodeOption,
                                exitNode: !!p.ExitNode
                            })).sort((a, b) => (b.online - a.online) || a.host.localeCompare(b.host));
                    const ex = ts.peers.find(p => p.exitNode);
                    ts.exitNode = ex ? ex.host : "";
                } catch (e) {}
                try {
                    const pr = JSON.parse(part[3]);
                    ts.operator = !!pr.OperatorUser;
                } catch (e) {}
                root.ts = ts;

                root.manual = part[4].split("\n").filter(l => l.trim()).map(l => {
                    const m = l.match(/^(\d+)\s.*--config\s+(\S+)/);
                    return m ? {
                        pid: parseInt(m[1]),
                        config: m[2]
                    } : null;
                }).filter(x => x);

                root.ovpnFiles = part[5].split("\n").filter(l => l.trim());
            }
        }
    }

    Timer {
        interval: root.fast ? 3000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    onFastChanged: if (fast) refresh()
}
