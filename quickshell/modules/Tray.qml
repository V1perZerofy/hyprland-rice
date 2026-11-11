import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.services
import qs.components

// System tray (hidden when empty). Left: activate · Right: menu.
Rectangle {
    id: root
    visible: SystemTray.items.values.length > 0
    implicitWidth: row.implicitWidth + 16
    implicitHeight: Theme.pillHeight
    radius: Theme.radius
    color: Theme.pillBg

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: SystemTray.items

            IconImage {
                id: icon
                required property SystemTrayItem modelData
                implicitSize: 16
                source: modelData.icon
                opacity: mouse.containsMouse ? 1 : 0.85

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: m => {
                        const it = icon.modelData;
                        if (m.button === Qt.MiddleButton)
                            it.secondaryActivate();
                        else if (m.button === Qt.RightButton || it.onlyMenu) {
                            if (it.hasMenu) {
                                const p = icon.mapToItem(null, 0, icon.height + 12);
                                it.display(icon.QsWindow.window, p.x, p.y);
                            }
                        } else
                            it.activate();
                    }
                    onWheel: w => icon.modelData.scroll(w.angleDelta.y, false)
                }
            }
        }
    }
}
