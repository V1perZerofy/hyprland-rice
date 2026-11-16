import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components
// explicit prefix: inside modules/, "Weather" would also name the weather service
import qs.modules as M

// Centre "dynamic island". Collapsed it only shows the workspaces; hover it
// and music (left) and weather (right) slide out of it. It stays open briefly
// after the mouse leaves and while one of their cards is open.
Rectangle {
    id: root

    required property ShellScreen screen

    readonly property bool cardOpen: Popups.current !== null && (Popups.current.owner === media || Popups.current.owner === weather)
    property bool hold: false
    readonly property bool expanded: hover.hovered || hold || cardOpen
    // both sides open to the same width, so the workspaces never move under
    // the mouse (music is usually much wider than the weather pill)
    readonly property real sideWidth: Math.max(media.visible ? media.implicitWidth + 6 : 0, weather.visible ? weather.implicitWidth + 6 : 0)

    implicitWidth: row.implicitWidth + 6
    implicitHeight: Theme.pillHeight + 6
    radius: height / 2
    color: Theme.pillBg

    HoverHandler {
        id: hover
        // leaving: stay open a moment so moving down into a card doesn't flicker
        onHoveredChanged: if (!hovered) {
            root.hold = true;
            holdTimer.restart();
        }
    }
    Timer {
        id: holdTimer
        interval: 350
        onTriggered: root.hold = false
    }

    // a side that slides open: width animates, the pill fades in from the centre
    component Reveal: Item {
        id: rev
        required property Item pill
        property bool leftSide: true
        Layout.preferredWidth: root.expanded ? root.sideWidth : 0
        Layout.preferredHeight: Theme.pillHeight
        Behavior on Layout.preferredWidth {
            Anim {
                duration: Theme.animSlow
            }
        }
        clip: true
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Reveal {
            id: leftSide
            pill: media
            M.Media {
                id: media
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                height: implicitHeight
                opacity: root.expanded ? 1 : 0
                Behavior on opacity {
                    Anim {}
                }
            }
        }

        M.Workspaces {
            screen: root.screen
            visible: Settings.shows("workspaces")
        }

        Reveal {
            id: rightSide
            pill: weather
            leftSide: false
            M.Weather {
                id: weather
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                height: implicitHeight
                opacity: root.expanded ? 1 : 0
                Behavior on opacity {
                    Anim {}
                }
            }
        }
    }
}
