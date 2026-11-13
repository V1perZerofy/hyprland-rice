import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components
import qs.sidebar

// Left sidebar on SUPER+A (replaces the eww Ollama sidebar).
// Tabs: Dashboard (toggles, sliders, media, stats, todo) · Assistant (Ollama).
//   qs ipc call sidebar toggle | sidebar assistant
Scope {
    id: root

    property bool open: false
    property int tab: 0

    IpcHandler {
        target: "sidebar"
        function toggle(): void {
            root.open = !root.open;
        }
        // open straight into the chat
        function assistant(): void {
            root.tab = 1;
            root.open = true;
            chatTab.focusInput();
        }
    }

    onOpenChanged: {
        SysStats.active = open;
        if (open) {
            Brightness.refresh();
            if (Popups.current)
                Popups.current.open = false;
        }
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
        anchors {
            top: true
            bottom: true
            left: true
        }
        margins.top: (Popups.barVisible && !Settings.barBottom ? Theme.barHeight : 0) + 8
        margins.bottom: (Popups.barVisible && Settings.barBottom ? Theme.barHeight : 0) + 8
        margins.left: 8
        implicitWidth: 440
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-sidebar"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"
        visible: root.open || panel.x > -win.width

        Rectangle {
            id: panel
            width: parent.width
            height: parent.height
            x: root.open ? 0 : -win.width - 10
            radius: Theme.cardRadius
            color: Theme.panelBg
            border.color: Theme.border
            border.width: 1
            clip: true

            Behavior on x {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            Keys.onEscapePressed: root.open = false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                // header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: 22
                        color: Theme.primary
                        StyledText {
                            anchors.centerIn: parent
                            text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
                            bold: true
                            size: 18
                            color: Theme.bg
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        SystemClock {
                            id: clock
                            precision: SystemClock.Minutes
                        }
                        StyledText {
                            readonly property int h: clock.date.getHours()
                            text: (h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening") + ", " + Quickshell.env("USER")
                            bold: true
                            size: Theme.fontSize + 1
                        }
                        StyledText {
                            text: Qt.formatDateTime(clock.date, "dddd, d MMMM") + "  ·  up " + SysStats.uptimeText()
                            size: Theme.fontSmall - 1
                            color: Theme.subtext
                        }
                    }
                    IconButton {
                        icon: Icons.settings
                        size: 34
                        onClicked: {
                            root.open = false;
                            Popups.requested("settings");
                        }
                    }
                    IconButton {
                        icon: Icons.power
                        size: 34
                        onClicked: {
                            root.open = false;
                            Popups.requested("power");
                        }
                    }
                    IconButton {
                        icon: Icons.close
                        size: 34
                        onClicked: root.open = false
                    }
                }

                // tabs
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 12
                    color: Theme.surface

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: parent.height - 8
                        y: 4
                        x: 4 + root.tab * width
                        radius: 9
                        color: Theme.alpha(Theme.primary, 0.25)
                        Behavior on x {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        Repeater {
                            model: [
                                { icon: Icons.dashboard, label: "Dashboard" },
                                { icon: Icons.robot, label: "Assistant" }
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
                                        color: root.tab === index ? Theme.primary : Theme.subtext
                                    }
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        bold: root.tab === index
                                        size: Theme.fontSmall + 1
                                        color: root.tab === index ? Theme.fg : Theme.subtext
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.tab = index;
                                        if (index === 1)
                                            chatTab.focusInput();
                                    }
                                }
                            }
                        }
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.tab

                    Dashboard {}
                    Assistant {
                        id: chatTab
                    }
                }
            }
        }
    }
}
