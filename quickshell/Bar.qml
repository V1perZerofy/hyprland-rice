import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components
import qs.modules

// Bar for one screen (top or bottom, see Settings) — same layout as the waybar:
// left: clock (+ window title) · centre: workspaces + media · right: status pills.
PanelWindow {
    id: bar
    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: !Settings.barBottom
        bottom: Settings.barBottom
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: "transparent"
    // SUPER+O slides the bar out (towards its screen edge) and back; the
    // window (and its reserved space) stays until the slide has finished
    readonly property real hiddenOffset: Settings.barBottom ? Theme.barHeight : -Theme.barHeight
    property real offset: Popups.barVisible ? 0 : hiddenOffset
    Behavior on offset {
        Anim {}
    }
    visible: Popups.barVisible || Math.abs(offset - hiddenOffset) > 0.5

    Rectangle {
        anchors.fill: parent
        transform: Translate {
            y: bar.offset
        }
        color: Theme.barBg
        // round the corners that face the screen
        bottomLeftRadius: Settings.barBottom ? 0 : 12
        bottomRightRadius: Settings.barBottom ? 0 : 12
        topLeftRadius: Settings.barBottom ? 12 : 0
        topRightRadius: Settings.barBottom ? 12 : 0

        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            LauncherButton {
                visible: Settings.shows("launcher")
            }
            NotesButton {
                visible: Settings.shows("notes")
            }
            Clock {
                visible: Settings.shows("clock")
            }
            ActiveWindow {
                screen: bar.modelData
                Layout.maximumWidth: Math.max(0, bar.width / 2 - centre.width / 2 - 260)
            }
        }

        RowLayout {
            id: centre
            anchors.centerIn: parent
            spacing: 6

            Workspaces {
                screen: bar.modelData
                visible: Settings.shows("workspaces")
            }
            Media {}
            Weather {}
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Tray {}
            Notifications {
                visible: Settings.shows("notifications")
            }
            Updates {
                visible: Settings.shows("updates")
            }
            Monitors {
                visible: Settings.shows("monitors")
            }
            Network {
                visible: Settings.shows("network")
            }
            Audio {
                visible: Settings.shows("audio")
            }
            Bluetooth {}
            Battery {}
        }
    }
}
