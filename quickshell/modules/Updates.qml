import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// Pending updates. Left: list card with "Update now" · Right: re-check.
Pill {
    id: root
    active: pop.open
    onClicked: m => {
        if (m.button === Qt.RightButton)
            Updates.refresh();
        else
            pop.toggle();
    }

    Glyph {
        text: Updates.count > 0 ? Icons.packageIcon : Icons.check
        color: Updates.count > 0 ? Theme.tertiary : Theme.muted
    }
    StyledText {
        text: Updates.checking && Updates.count === 0 ? "…" : Updates.count
        size: Theme.fontSmall + 1
    }

    Popout {
        id: pop
        owner: root
        name: "updates"
        cardWidth: 380

        Header {
            icon: Icons.packageIcon
            title: Updates.count > 0 ? Updates.count + " update" + (Updates.count === 1 ? "" : "s") + " available" : "System is up to date"
            subtitle: Updates.checking ? "Checking…" : Updates.lastCheck.getTime() ? "Checked " + Qt.formatDateTime(Updates.lastCheck, "HH:mm") : ""
            IconButton {
                icon: Icons.refresh
                size: 30
                onClicked: Updates.refresh()
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 320)
            visible: Updates.count > 0
            clip: true
            spacing: 2
            model: Updates.packages
            boundsBehavior: Flickable.StopAtBounds

            delegate: RowLayout {
                required property var modelData
                width: ListView.view.width
                spacing: 8
                StyledText {
                    Layout.fillWidth: true
                    text: modelData.name
                    size: Theme.fontSmall
                }
                Rectangle {
                    visible: modelData.aur
                    implicitWidth: aurLabel.implicitWidth + 10
                    implicitHeight: 16
                    radius: 8
                    color: Theme.alpha(Theme.tertiary, 0.25)
                    StyledText {
                        id: aurLabel
                        anchors.centerIn: parent
                        text: "AUR"
                        size: 9
                        bold: true
                        color: Theme.tertiary
                    }
                }
                StyledText {
                    Layout.maximumWidth: 150
                    text: modelData.to
                    size: Theme.fontSmall - 1
                    color: Theme.subtext
                }
            }
        }

        IconButton {
            Layout.fillWidth: true
            visible: Updates.count > 0
            icon: Icons.packageIcon
            label: "Update now"
            highlighted: true
            onClicked: {
                pop.open = false;
                Updates.upgrade();
            }
        }
    }
}
