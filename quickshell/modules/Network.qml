import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// Network pill + card with two tabs. Left: card · Right: impala.
//  Wi-Fi – click a saved/open network to connect, the current one to disconnect;
//          unknown secured networks open impala to enter the password.
//  VPN   – Tailscale (on/off, peers, exit node), NetworkManager VPN profiles
//          (OpenVPN imports, WireGuard, Proton app), hand-started openvpn,
//          and one-click import for .ovpn files found in ~ / ~/Downloads.
// A lock badge on the pill shows while any VPN is up.
Pill {
    id: root

    function strength(s) {
        return Icons.wifi[Math.max(0, Math.min(3, Math.floor(s * 4 - 0.01)))];
    }
    function impala() {
        pop.open = false;
        Quickshell.execDetached(["kitty", "impala"]);
    }
    function osIcon(os) {
        return /windows/i.test(os) ? Icons.windows : /ios|macos/i.test(os) ? Icons.apple : /android/i.test(os) ? Icons.phone : /linux/i.test(os) ? Icons.linux : Icons.lan;
    }

    active: pop.open
    onClicked: m => {
        if (m.button === Qt.RightButton)
            impala();
        else
            pop.toggle();
    }

    Glyph {
        text: Net.wired ? Icons.ethernet : Net.current ? root.strength(Net.current.signal) : Icons.wifiOff
        color: Net.current || Net.wired ? Theme.primary : Theme.muted
    }
    StyledText {
        Layout.maximumWidth: 140
        visible: text !== ""
        text: Net.wired ? "Wired" : Net.current ? Net.current.ssid : ""
        size: Theme.fontSmall + 1
    }
    Glyph {
        visible: Vpn.anyActive
        text: Icons.lock
        size: 13
        color: Theme.tertiary
    }

    Popout {
        id: pop
        owner: root
        name: "network"
        cardWidth: 380
        property int tab: 0
        onOpenChanged: if (open && tab === 0) Net.scan()

        Binding {
            target: Vpn
            property: "fast"
            value: pop.open && pop.tab === 1
        }

        // ── tabs ──
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 36
            radius: 11
            color: Theme.surface

            Rectangle {
                width: (parent.width - 8) / 2
                height: parent.height - 8
                x: 4 + pop.tab * width
                y: 4
                radius: 8
                color: Theme.alpha(Theme.primary, 0.25)
                Behavior on x {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Row {
                anchors.fill: parent
                anchors.margins: 4
                Repeater {
                    model: [
                        { icon: Icons.wifi[3], label: "Wi-Fi" },
                        { icon: Icons.lock, label: "VPN" }
                    ]
                    Item {
                        required property var modelData
                        required property int index
                        width: parent.width / 2
                        height: parent.height
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                size: 14
                                color: pop.tab === index ? Theme.primary : Theme.subtext
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label + (index === 1 && Vpn.anyActive ? " ·  on" : "")
                                size: Theme.fontSmall + 1
                                bold: pop.tab === index
                                color: pop.tab === index ? Theme.fg : Theme.subtext
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                pop.tab = index;
                                if (index === 0)
                                    Net.scan();
                            }
                        }
                    }
                }
            }
        }

        // ════ Wi-Fi ════
        ColumnLayout {
            Layout.fillWidth: true
            visible: pop.tab === 0
            spacing: 12

            Header {
                icon: Net.wifiEnabled ? Icons.wifi[3] : Icons.wifiOff
                title: "Wi-Fi"
                subtitle: Net.current ? "Connected · " + Math.round(Net.current.signal * 100) + "%" : Net.wifiEnabled ? "Not connected" : "Off"
                IconButton {
                    visible: Net.wifiEnabled
                    icon: Icons.refresh
                    size: 30
                    onClicked: Net.scan()
                }
                Switch {
                    checked: Net.wifiEnabled
                    onToggled: Net.setWifi(!Net.wifiEnabled)
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 300)
                visible: Net.wifiEnabled && count > 0
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: Net.networks

                delegate: ListRow {
                    required property var modelData
                    width: ListView.view.width
                    icon: root.strength(modelData.signal)
                    title: modelData.ssid
                    subtitle: (modelData.security ? Icons.lock + " " + modelData.security : "open") + "  ·  " + Math.round(modelData.signal * 100) + "%"
                    trailing: modelData.active ? "Connected" : modelData.known ? "Saved" : " "
                    selected: modelData.active
                    busy: Net.busy === modelData.ssid
                    onClicked: {
                        if (modelData.active)
                            Net.disconnect();
                        else if (modelData.known || !modelData.security)
                            Net.connect(modelData.ssid);
                        else
                            root.impala();
                    }
                }
            }

            IconButton {
                Layout.fillWidth: true
                icon: Icons.wifi[3]
                label: "Open impala"
                onClicked: root.impala()
            }
        }

        // ════ VPN ════
        Flickable {
            id: vpnFlick
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(vpnCol.implicitHeight, 520)
            visible: pop.tab === 1
            clip: true
            contentWidth: width
            contentHeight: vpnCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: vpnCol
                width: vpnFlick.width
                spacing: 10

                // ── Tailscale ──
                Header {
                    visible: Vpn.ts.installed
                    icon: Icons.lan
                    title: "Tailscale"
                    subtitle: Vpn.busy === "tailscale" ? "…" : Vpn.tailscaleUp ? (Vpn.ts.ips[0] || "Connected") + (Vpn.ts.exitNode ? "  ·  exit via " + Vpn.ts.exitNode : "") : Vpn.ts.state === "NeedsLogin" ? "Needs login — run: tailscale up" : "Off"
                    Switch {
                        checked: Vpn.tailscaleUp
                        onToggled: Vpn.toggleTailscale()
                    }
                }

                // one-time permission so tailscale up/down works without sudo
                Rectangle {
                    Layout.fillWidth: true
                    visible: Vpn.ts.installed && !Vpn.ts.operator
                    implicitHeight: opCol.implicitHeight + 20
                    radius: 12
                    color: Theme.alpha(Theme.warning, 0.12)
                    border.color: Theme.alpha(Theme.warning, 0.4)
                    ColumnLayout {
                        id: opCol
                        x: 12
                        y: 10
                        width: parent.width - 24
                        spacing: 6
                        StyledText {
                            Layout.fillWidth: true
                            text: "One-time setup so the bar can switch Tailscale without sudo:"
                            size: Theme.fontSmall
                            wrapMode: Text.Wrap
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: "sudo tailscale set --operator=$USER"
                                size: Theme.fontSmall
                                color: Theme.warning
                            }
                            IconButton {
                                label: "Copy"
                                size: 26
                                onClicked: Quickshell.execDetached(["wl-copy", "sudo tailscale set --operator=$USER"])
                            }
                        }
                    }
                }

                Repeater {
                    model: Vpn.tailscaleUp ? Vpn.ts.peers : []
                    ListRow {
                        required property var modelData
                        icon: root.osIcon(modelData.os)
                        title: modelData.host
                        subtitle: (modelData.online ? "online" : "offline") + (modelData.ip ? "  ·  " + modelData.ip : "")
                        trailing: modelData.exitNode ? "Exit node ✓" : modelData.exitOption ? "Use as exit" : ""
                        selected: modelData.exitNode
                        opacity: modelData.online ? 1 : 0.5
                        onClicked: {
                            if (modelData.exitOption)
                                Vpn.setExitNode(modelData.exitNode ? "" : modelData.host);
                            else if (modelData.ip)
                                Quickshell.execDetached(["wl-copy", modelData.ip]);
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.border
                }

                // ── NetworkManager VPNs / openvpn ──
                Header {
                    icon: Icons.lock
                    title: "OpenVPN · WireGuard"
                    subtitle: Vpn.summary ? "Active: " + Vpn.summary : Vpn.profiles.length ? "Not connected" : "No profiles yet"
                }

                Repeater {
                    model: Vpn.profiles
                    ListRow {
                        required property var modelData
                        icon: Icons.lock
                        title: modelData.name
                        subtitle: modelData.type
                        trailing: modelData.active ? "Connected" : modelData.activating ? "Connecting…" : "Connect"
                        selected: modelData.active
                        busy: Vpn.busy === modelData.uuid
                        onClicked: Vpn.toggleProfile(modelData)
                    }
                }

                Repeater {
                    model: Vpn.manual
                    ListRow {
                        required property var modelData
                        icon: Icons.terminal
                        title: "openvpn (started by hand)"
                        subtitle: modelData.config.replace(Vpn.home, "~")
                        trailing: "Stop"
                        selected: true
                        busy: Vpn.busy === "manual"
                        onClicked: Vpn.stopManual(modelData)
                    }
                }

                Repeater {
                    model: Vpn.importable
                    ListRow {
                        required property var modelData
                        icon: Icons.download
                        title: modelData.split("/").pop()
                        subtitle: "Import into NetworkManager" + (modelData.startsWith(Vpn.home + "/") ? "  ·  " + modelData.replace(Vpn.home, "~").split("/").slice(0, -1).join("/") : "")
                        trailing: "Import"
                        busy: Vpn.busy === modelData
                        onClicked: Vpn.importOvpn(modelData)
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Vpn.error !== ""
                    text: "⚠ " + Vpn.error
                    size: Theme.fontSmall
                    color: Theme.error
                    wrapMode: Text.Wrap
                }

                IconButton {
                    Layout.fillWidth: true
                    icon: Icons.lock
                    label: "Open Proton VPN"
                    onClicked: {
                        pop.open = false;
                        Quickshell.execDetached(["protonvpn-app"]);
                    }
                }
            }
        }
    }
}
