import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components
// explicit prefix: inside modules/, "Weather" would also name the weather service
import qs.modules as M

// Centre "dynamic island": just the workspaces. Hover it and the dashboard
// (DashDrawer) grows out of it; the island then joins the dashboard's card
// (same colour, square corners towards it).
// The music and weather pills live here invisibly: they only anchor their
// cards (music search on SUPER+U / the dashboard's search button, the weather
// card from the dashboard) to the island's centre.
Rectangle {
    id: root

    required property ShellScreen screen
    readonly property bool joined: Popups.dashOpen
    readonly property real r: height / 2

    implicitWidth: ws.implicitWidth + 8
    implicitHeight: Theme.pillHeight + 6
    radius: r
    // flat edge towards the dashboard while it's open
    topLeftRadius: joined && Settings.barBottom ? 6 : r
    topRightRadius: joined && Settings.barBottom ? 6 : r
    bottomLeftRadius: joined && !Settings.barBottom ? 6 : r
    bottomRightRadius: joined && !Settings.barBottom ? 6 : r
    color: joined ? Theme.panelBg : Theme.pillBg
    Behavior on color {
        CAnim {}
    }

    onWidthChanged: Popups.islandWidth = width
    Component.onCompleted: Popups.islandWidth = width

    HoverHandler {
        onHoveredChanged: Popups.islandHovered = hovered
    }

    M.Workspaces {
        id: ws
        anchors.centerIn: parent
        screen: root.screen
        visible: Settings.shows("workspaces")
    }

    // card anchors (not shown): their Popouts open centred on the island
    M.Media {
        visible: false
        anchors.centerIn: parent
    }
    M.Weather {
        visible: false
        anchors.centerIn: parent
    }
}
