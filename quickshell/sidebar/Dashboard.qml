import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.services
import qs.components

// Sidebar "Dashboard" tab: quick toggles, sliders, media, system stats, todo.
Flickable {
    id: root

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btConnected: bt ? bt.devices.values.filter(d => d.connected) : []
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var player: Players.active
    readonly property string todoPath: Quickshell.env("HOME") + "/.local/share/todo.txt"
    readonly property var todos: todoFile.loaded ? todoFile.text().split("\n").filter(l => l.trim() !== "") : []

    readonly property var profiles: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
    readonly property var profileNames: ["Power saver", "Balanced", "Performance"]

    function setTodos(list) {
        todoFile.setText(list.length ? list.join("\n") + "\n" : "");
    }

    contentWidth: width
    contentHeight: col.implicitHeight + 8
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // keep the screen awake: hypridle honours systemd idle inhibitors
    Process {
        id: caffeine
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=Caffeine", "sleep", "infinity"]
    }

    FileView {
        id: todoFile
        path: root.todoPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    ColumnLayout {
        id: col
        width: root.width
        spacing: 14

        // ── quick toggles ──
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            Tile {
                icon: Net.wifiEnabled ? Icons.wifi[3] : Icons.wifiOff
                title: "Wi-Fi"
                subtitle: Net.current ? Net.current.ssid : Net.wifiEnabled ? "Not connected" : "Off"
                checked: Net.wifiEnabled
                onToggled: Net.setWifi(!Net.wifiEnabled)
                onSecondary: Quickshell.execDetached(["kitty", "impala"])
            }
            Tile {
                icon: root.bt && root.bt.enabled ? Icons.bt : Icons.btOff
                title: "Bluetooth"
                subtitle: !root.bt || !root.bt.enabled ? "Off" : root.btConnected.length ? root.btConnected[0].name : "On"
                checked: root.bt !== null && root.bt.enabled
                onToggled: if (root.bt) root.bt.enabled = !root.bt.enabled
                onSecondary: Quickshell.execDetached(["kitty", "bluetui"])
            }
            Tile {
                icon: Notifs.dnd ? Icons.bellOff : Icons.bell
                title: "Do not disturb"
                subtitle: Notifs.dnd ? "On" : "Off"
                checked: Notifs.dnd
                onToggled: Notifs.toggleDnd()
            }
            Tile {
                readonly property int idx: Math.max(0, root.profiles.indexOf(PowerProfiles.profile))
                icon: [Icons.leaf, Icons.balance, Icons.rocket][idx]
                title: "Power"
                subtitle: root.profileNames[idx]
                checked: PowerProfiles.profile !== PowerProfile.Balanced
                onToggled: {
                    const n = PowerProfiles.hasPerformanceProfile ? 3 : 2;
                    PowerProfiles.profile = root.profiles[(idx + 1) % n];
                }
            }
            Tile {
                readonly property bool muted: !root.source || !root.source.audio || root.source.audio.muted
                icon: muted ? Icons.micOff : Icons.mic
                title: "Microphone"
                subtitle: muted ? "Muted" : "Live"
                checked: !muted
                onToggled: if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted
                onSecondary: Quickshell.execDetached(["pavucontrol", "-t", "4"])
            }
            Tile {
                icon: Icons.coffee
                title: "Caffeine"
                subtitle: caffeine.running ? "Staying awake" : "Off"
                checked: caffeine.running
                onToggled: caffeine.running = !caffeine.running
            }
        }

        // ── sliders ──
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: sliders.implicitHeight + 24
            radius: 16
            color: Theme.surface

            ColumnLayout {
                id: sliders
                x: 14
                y: 12
                width: parent.width - 28
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    readonly property real vol: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                    readonly property bool muted: !root.sink || !root.sink.audio || root.sink.audio.muted
                    Glyph {
                        text: parent.muted ? Icons.volMute : Icons.volHigh
                        color: parent.muted ? Theme.muted : Theme.primary
                        Layout.preferredWidth: 20
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
                        }
                    }
                    Slider {
                        Layout.fillWidth: true
                        value: parent.vol
                        enabled: !parent.muted
                        onMoved: v => {
                            if (root.sink && root.sink.audio) {
                                root.sink.audio.muted = false;
                                root.sink.audio.volume = v;
                            }
                        }
                    }
                    StyledText {
                        text: Math.round(parent.vol * 100) + "%"
                        size: Theme.fontSmall
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: Brightness.available
                    Glyph {
                        text: Icons.brightness[Math.min(2, Math.floor(Brightness.value * 3))]
                        Layout.preferredWidth: 20
                    }
                    Slider {
                        Layout.fillWidth: true
                        value: Brightness.value
                        onMoved: v => Brightness.set(v)
                    }
                    StyledText {
                        text: Math.round(Brightness.value * 100) + "%"
                        size: Theme.fontSmall
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // ── media ──
        Rectangle {
            Layout.fillWidth: true
            visible: root.player !== null
            implicitHeight: 84
            radius: 16
            color: Theme.surface

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                ClippingRectangle {
                    implicitWidth: 64
                    implicitHeight: 64
                    radius: 12
                    color: Theme.surfaceHi
                    Glyph {
                        anchors.centerIn: parent
                        text: Icons.music
                        size: 26
                        visible: art.status !== Image.Ready
                    }
                    Image {
                        id: art
                        anchors.fill: parent
                        source: root.player ? root.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 128
                        asynchronous: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText {
                        Layout.fillWidth: true
                        text: root.player ? root.player.trackTitle || "Unknown" : ""
                        bold: true
                        size: Theme.fontSmall + 1
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.player ? root.player.trackArtist : ""
                        size: Theme.fontSmall
                        color: Theme.primary
                    }
                }
                IconButton {
                    icon: Icons.prev
                    size: 32
                    onClicked: root.player.previous()
                }
                IconButton {
                    icon: root.player && root.player.isPlaying ? Icons.pause : Icons.play
                    size: 38
                    highlighted: true
                    onClicked: root.player.togglePlaying()
                }
                IconButton {
                    icon: Icons.next
                    size: 32
                    onClicked: root.player.next()
                }
            }
        }

        // ── system ──
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: stats.implicitHeight + 24
            radius: 16
            color: Theme.surface

            ColumnLayout {
                id: stats
                x: 14
                y: 12
                width: parent.width - 28
                spacing: 10

                StatBar {
                    icon: Icons.cpu
                    label: "CPU"
                    value: SysStats.cpu
                    detail: Math.round(SysStats.cpu * 100) + "%"
                }
                StatBar {
                    icon: Icons.memory
                    label: "RAM"
                    value: SysStats.mem
                    detail: SysStats.memUsedGb.toFixed(1) + " / " + SysStats.memTotalGb.toFixed(0) + " GB"
                }
                StatBar {
                    icon: Icons.disk
                    label: "Disk"
                    value: SysStats.disk
                    detail: SysStats.diskText
                }
                StatBar {
                    icon: Icons.thermometer
                    label: "Temp"
                    value: SysStats.temp / 100
                    detail: Math.round(SysStats.temp) + " °C"
                }
            }
        }

        // ── todo (~/.local/share/todo.txt, one task per line) ──
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: todoCol.implicitHeight + 24
            radius: 16
            color: Theme.surface

            ColumnLayout {
                id: todoCol
                x: 14
                y: 12
                width: parent.width - 28
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: "Todo" + (root.todos.length ? "  ·  " + root.todos.length : "")
                        bold: true
                    }
                    IconButton {
                        visible: root.todos.length > 0
                        label: "Clear"
                        size: 26
                        onClicked: root.setTodos([])
                    }
                }

                Repeater {
                    model: root.todos
                    RowLayout {
                        id: item
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            implicitWidth: 18
                            implicitHeight: 18
                            radius: 5
                            color: tick.containsMouse ? Theme.alpha(Theme.primary, 0.3) : "transparent"
                            border.width: 2
                            border.color: tick.containsMouse ? Theme.primary : Theme.alpha(Theme.fg, 0.4)
                            Glyph {
                                anchors.centerIn: parent
                                visible: tick.containsMouse
                                text: Icons.check
                                size: 12
                            }
                            MouseArea {
                                id: tick
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // done = remove
                                onClicked: root.setTodos(root.todos.filter((t, i) => i !== item.index))
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: item.modelData
                            size: Theme.fontSmall + 1
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 36
                    radius: 10
                    color: Theme.surfaceHi
                    TextInput {
                        id: newTodo
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSmall + 1
                        color: Theme.fg
                        clip: true
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !newTodo.text
                            text: "Add a task…"
                            size: Theme.fontSmall + 1
                            color: Theme.alpha(Theme.fg, 0.35)
                        }
                        onAccepted: {
                            if (text.trim()) {
                                root.setTodos(root.todos.concat([text.trim()]));
                                text = "";
                            }
                        }
                    }
                }
            }
        }
    }
}
