import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// Bell + notification centre.
// Left: centre · Right: do-not-disturb · Middle: hide on-screen toasts.
Pill {
    id: root
    active: pop.open
    onClicked: m => {
        if (m.button === Qt.RightButton)
            Notifs.toggleDnd();
        else if (m.button === Qt.MiddleButton)
            Notifs.closePopups();
        else
            pop.toggle();
    }

    Glyph {
        text: Notifs.dnd ? Icons.bellOff : Icons.bell
        color: Notifs.dnd ? Theme.muted : Notifs.unread > 0 ? Theme.tertiary : Theme.primary
    }
    StyledText {
        visible: Notifs.unread > 0
        text: Notifs.unread
        size: Theme.fontSmall + 1
    }

    Popout {
        id: pop
        owner: root
        name: "notifications"
        cardWidth: 400
        onOpenChanged: {
            Notifs.centreOpen = open;
            if (open) {
                Notifs.unread = 0;
                Notifs.closePopups();
            }
        }

        Header {
            icon: Notifs.dnd ? Icons.bellOff : Icons.bell
            title: "Notifications"
            subtitle: Notifs.dnd ? "Do not disturb" : Notifs.list.length ? Notifs.list.length + " in history" : ""
            IconButton {
                visible: Notifs.list.length > 0
                label: "Clear"
                size: 28
                onClicked: Notifs.clearHistory()
            }
            Switch {
                checked: Notifs.dnd
                onToggled: Notifs.toggleDnd()
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 520)
            visible: count > 0
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: Notifs.list

            delegate: NotificationCard {
                required property var modelData
                entry: modelData
                toast: false
                width: ListView.view.width
            }

            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: 150
                }
            }
            displaced: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        // empty state
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            visible: Notifs.list.length === 0
            spacing: 6
            Glyph {
                Layout.alignment: Qt.AlignHCenter
                text: Icons.bellOff
                size: 36
                color: Theme.muted
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "All caught up"
                color: Theme.subtext
            }
        }
    }
}
