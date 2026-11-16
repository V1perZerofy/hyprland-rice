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

// Dashboard that grows out of the bar's dynamic island (modules/Island.qml):
// hover the island and it widens + unfolds from it; leave and it folds back.
// Click inside to keep it. Time + weather · music · system.
//   qs ipc call dash toggle
Scope {
    id: root

    property alias open: drawer.open
    readonly property var player: Players.active

    DrawerState {
        id: drawer
    }
    // the island is the trigger (instead of a screen edge)
    Binding {
        target: drawer
        property: "edgeHovered"
        value: Popups.islandHovered
    }
    Binding {
        target: Popups
        property: "dashOpen"
        value: root.open
    }
    // a bar card opening (music search, weather…) replaces the dashboard
    Connections {
        target: Popups
        function onCurrentChanged() {
            if (Popups.current)
                drawer.close();
        }
    }
    readonly property real fullHeight: body.implicitHeight + 32
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
        anchors.top: !Settings.barBottom
        anchors.bottom: Settings.barBottom
        // flush against the bar, right under (or above) the island
        margins.top: Settings.barBottom ? 0 : (Popups.barVisible ? Theme.barHeight - 2 : 6)
        margins.bottom: Settings.barBottom ? (Popups.barVisible ? Theme.barHeight - 2 : 6) : 0
        implicitWidth: Math.min(900, (screen ? screen.width : 1920) - 40)
        implicitHeight: root.fullHeight + 4
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
            // grows out of the island: from its width and zero height to full size
            width: root.open ? win.width : Math.max(40, Popups.islandWidth)
            height: root.open ? root.fullHeight : 0
            x: (win.width - width) / 2
            y: Settings.barBottom ? win.height - height : 0
            radius: Theme.cardRadius
            // the edge joined to the island is flatter
            topLeftRadius: Settings.barBottom ? Theme.cardRadius : 8
            topRightRadius: Settings.barBottom ? Theme.cardRadius : 8
            bottomLeftRadius: Settings.barBottom ? 8 : Theme.cardRadius
            bottomRightRadius: Settings.barBottom ? 8 : Theme.cardRadius
            color: Theme.panelBg
            border.color: Theme.border
            border.width: 1
            clip: true
            opacity: root.open ? 1 : 0
            Behavior on width {
                Anim {
                    duration: Theme.animSlow
                }
            }
            Behavior on height {
                Anim {
                    duration: Theme.animSlow
                }
            }
            Behavior on opacity {
                Anim {
                    duration: Theme.anim
                }
            }

            focus: root.open
            Keys.onEscapePressed: drawer.close()

            HoverHandler {
                onHoveredChanged: drawer.panelHovered = hovered
            }

            RowLayout {
                id: body
                // full size from the start, centred: the growing card reveals it
                x: (card.width - win.width) / 2 + 16
                y: Settings.barBottom ? card.height - root.fullHeight + 16 : 16
                width: win.width - 32
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
                        // click: the full weather card (12 h + 5 days)
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: Popups.requested("weather")
                        }
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
                                // Apple Music search (the music card, now opened from the island)
                                IconButton {
                                    visible: Cider.available
                                    icon: Icons.search
                                    size: 34
                                    onClicked: Popups.requested("media-search")
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
