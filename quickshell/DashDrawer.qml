import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.services
import qs.components
import qs.sidebar

// Dashboard drawer from the top edge (caelestia-style): rest the mouse on the
// top-centre of the screen and it slides down; leave and it slides back.
// Click inside to keep it. Time + weather · music · system.
//   qs ipc call dash toggle
Scope {
    id: root

    property alias open: drawer.open
    readonly property var player: Players.active

    DrawerState {
        id: drawer
    }
    EdgeSensor {
        drawer: drawer
        edge: "top"
        span: 0.4
        screen: win.screen
    }
    IpcHandler {
        target: "dash"
        function toggle(): void {
            drawer.toggle();
        }
    }
    onOpenChanged: {
        if (open && Popups.current)
            Popups.close();
        if (!open)
            closing.restart();
    }
    Timer {
        id: closing
        interval: Theme.animSlow + 60
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
        anchors.top: true
        margins.top: (Popups.barVisible && !Settings.barBottom ? Theme.barHeight : 0) + 6
        implicitWidth: Math.min(900, (screen ? screen.width : 1920) - 40)
        implicitHeight: card.height + 10
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-dash"
        WlrLayershell.keyboardFocus: drawer.keyboardFocus(WlrKeyboardFocus.OnDemand, WlrKeyboardFocus.Exclusive, WlrKeyboardFocus.None)
        color: "transparent"
        // stays mapped until the slide-up has finished (no binding loop via card.y)
        visible: root.open || closing.running
        // only the card takes input while it's on screen
        mask: Region {
            item: card
        }

        Rectangle {
            id: card
            width: parent.width
            height: body.implicitHeight + 32
            // slides down from behind the top edge
            y: root.open ? 0 : -height - 10
            radius: Theme.cardRadius
            color: Theme.panelBg
            border.color: Theme.border
            border.width: 1
            clip: true
            Behavior on y {
                Anim {
                    duration: Theme.animSlow
                }
            }

            focus: root.open
            Keys.onEscapePressed: drawer.close()

            HoverHandler {
                onHoveredChanged: drawer.panelHovered = hovered
            }

            RowLayout {
                id: body
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 14

                // ── time + weather ──
                ColumnLayout {
                    Layout.preferredWidth: 230
                    Layout.alignment: Qt.AlignTop
                    spacing: 2
                    StyledText {
                        text: Qt.formatDateTime(clock.date, Settings.clock24h ? "HH:mm" : "h:mm AP")
                        bold: true
                        size: Math.round(44 * Theme.s)
                        color: Theme.primary
                    }
                    StyledText {
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                        size: Theme.fontSize
                    }
                    StyledText {
                        readonly property int h: clock.date.getHours()
                        text: (h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening") + "  ·  up " + SysStats.uptimeText()
                        size: Theme.fontSmall - 1
                        color: Theme.subtext
                    }
                    RowLayout {
                        Layout.topMargin: 10
                        visible: Weather.enabled && Weather.current !== null
                        spacing: 8
                        Glyph {
                            text: Weather.current ? Weather.glyph(Weather.current.code, Weather.current.isDay) : ""
                            size: 22
                            color: Theme.primary
                        }
                        StyledText {
                            text: Weather.current ? Math.round(Weather.current.temp) + Weather.unit + "  " + Weather.label(Weather.current.code) : ""
                            size: Theme.fontSmall + 1
                        }
                    }
                    StyledText {
                        visible: Weather.enabled && Weather.daily.length > 0
                        text: Weather.daily.length ? Settings.weatherCity + "  ·  " + Weather.deg(Weather.daily[0].min) + " – " + Weather.deg(Weather.daily[0].max) : ""
                        size: Theme.fontSmall - 1
                        color: Theme.subtext
                    }
                }

                // ── music ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 150
                    radius: 16
                    color: Theme.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 14

                        ClippingRectangle {
                            implicitWidth: 124
                            implicitHeight: 124
                            radius: 14
                            color: Theme.surfaceHi
                            Glyph {
                                anchors.centerIn: parent
                                text: Icons.music
                                size: 40
                                color: Theme.subtext
                                visible: cover.status !== Image.Ready
                            }
                            Image {
                                id: cover
                                anchors.fill: parent
                                source: root.player ? root.player.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 248
                                asynchronous: true
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity {
                                    Anim {
                                        duration: Theme.animSlow
                                    }
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            StyledText {
                                Layout.fillWidth: true
                                text: root.player && root.player.trackTitle ? root.player.trackTitle : "Nothing playing"
                                bold: true
                                size: Theme.fontSize + 2
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: root.player && root.player.trackTitle ? root.player.trackArtist : "Play shuffles your Heavy Rotation mix"
                                size: Theme.fontSmall + 1
                                color: root.player && root.player.trackTitle ? Theme.primary : Theme.subtext
                            }
                            Item {
                                Layout.fillHeight: true
                            }
                            Slider {
                                Layout.fillWidth: true
                                visible: Players.hasLength(root.player)
                                enabled: root.player !== null && root.player.canSeek
                                value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
                                onMoved: v => {
                                    if (root.player && root.player.canSeek)
                                        root.player.position = v * root.player.length;
                                }
                            }
                            RowLayout {
                                spacing: 10
                                IconButton {
                                    icon: Icons.prev
                                    size: 34
                                    onClicked: if (root.player) root.player.previous()
                                }
                                IconButton {
                                    icon: root.player && root.player.isPlaying ? Icons.pause : Icons.play
                                    size: 42
                                    iconSize: 18
                                    highlighted: true
                                    onClicked: Cider.playPause(root.player)
                                }
                                IconButton {
                                    icon: Icons.next
                                    size: 34
                                    onClicked: if (root.player) root.player.next()
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                StyledText {
                                    visible: Players.hasLength(root.player)
                                    text: root.player ? Players.fmt(root.player.position) + " / " + Players.fmt(root.player.length) : ""
                                    size: Theme.fontSmall - 1
                                    color: Theme.subtext
                                }
                            }
                        }
                    }
                }

                // ── system ──
                Rectangle {
                    Layout.preferredWidth: 240
                    Layout.fillHeight: true
                    radius: 16
                    color: Theme.surface
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
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
            }

            // any press pins a hover-opened drawer, then reaches the control below
            MouseArea {
                anchors.fill: parent
                z: 100
                acceptedButtons: Qt.AllButtons
                onPressed: m => {
                    drawer.pinFromClick();
                    m.accepted = false;
                }
            }
        }
    }
}
