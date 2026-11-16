import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Invisible 2 px strip on a screen edge; reports hover to a DrawerState.
// `span` = how much of the edge it covers (centred), e.g. 0.4 for top-centre.
PanelWindow {
    id: root

    required property var drawer          // DrawerState
    property string edge: "left"          // left | right | top | bottom
    property real span: 1.0
    readonly property bool horizontal: edge === "top" || edge === "bottom"

    anchors {
        left: root.edge === "left" || (root.horizontal && root.span >= 1)
        right: root.edge === "right" || (root.horizontal && root.span >= 1)
        top: root.edge === "top" || (!root.horizontal && root.span >= 1)
        bottom: root.edge === "bottom" || (!root.horizontal && root.span >= 1)
    }
    implicitWidth: horizontal ? Math.round((screen ? screen.width : 1920) * span) : 2
    implicitHeight: horizontal ? 2 : Math.round((screen ? screen.height : 1080) * span)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-edge"
    color: "transparent"
    visible: Settings.edgeDrawers

    HoverHandler {
        onHoveredChanged: root.drawer.edgeHovered = hovered
    }
}
