import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules

// Top bar for one screen — same layout as the waybar:
// left: clock (+ window title) · centre: workspaces + media · right: status pills.
PanelWindow {
    id: bar
    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: "transparent"
    visible: Popups.barVisible

    Rectangle {
        anchors.fill: parent
        color: Theme.barBg
        bottomLeftRadius: 12
        bottomRightRadius: 12

        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            LauncherButton {}
            NotesButton {}
            Clock {}
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
            }
            Media {}
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Tray {}
            Notifications {}
            Updates {}
            Monitors {}
            Network {}
            Audio {}
            Bluetooth {}
            Battery {}
        }
    }
}
