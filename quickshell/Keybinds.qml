import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// Keybind cheatsheet (SUPER+H): every hl.bind in ~/.config/hypr/hyprland.lua,
// grouped, with keycaps. Read fresh on each open (scripts/keybinds.py), so
// edits to the config show up without restarting. Type to filter · Esc closes.
//   qs ipc call keybinds toggle
Scope {
    id: root

    property var groups: []      // [{ group, binds: [{ keys, desc, cmd }] }]
    property string filter: ""

    readonly property var icons: ({
            "Apps": Icons.apps,
            "Shell": Icons.dashboard,
            "Windows": Icons.windows,
            "Workspaces": Icons.monitor,
            "Mouse": Icons.mouse,
            "Media & hardware": Icons.music,
            "Session": Icons.power
        })

    // filtered groups, spread over 3 columns by row count (masonry)
    readonly property var columns: {
        const q = filter.trim().toLowerCase();
        const gs = groups.map(g => ({
                    group: g.group,
                    binds: q ? g.binds.filter(b => (b.desc + " " + b.keys.join(" ") + " " + b.cmd + " " + g.group).toLowerCase().includes(q)) : g.binds
                })).filter(g => g.binds.length);
        const cols = [[], [], []], h = [0, 0, 0];
        for (const g of gs) {
            const i = h.indexOf(Math.min(...h));
            cols[i].push(g);
            h[i] += g.binds.length + 2.5;
        }
        return cols;
    }
    readonly property int total: groups.reduce((n, g) => n + g.binds.length, 0)
    readonly property int shown: columns.reduce((n, c) => n + c.reduce((m, g) => m + g.binds.length, 0), 0)

    IpcHandler {
        target: "keybinds"
        function toggle(): void {
            overlay.toggle();
        }
    }

    Process {
        id: load
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/keybinds.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.groups = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Overlay {
        id: overlay
        cardWidth: Math.min(1480, width - 80)
        cardHeight: Math.min(height - 100, body.implicitHeight + 48)
        // keep the top edge where the unfiltered list puts it, so filtering
        // shrinks the card upwards instead of re-centring it
        property real fullHeight: 0
        cardY: Math.max(50, (height - Math.max(fullHeight, cardHeight)) / 2)
        onCardHeightChanged: if (!root.filter) fullHeight = cardHeight

        card.color: Theme.panelBg      // opaque: lots of small text on top
        onOpened: {
            load.running = true;
            field.text = "";
            field.forceActiveFocus();
        }

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 24
            spacing: 18

            // header
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Rectangle {
                    implicitWidth: 42
                    implicitHeight: 42
                    radius: 12
                    color: Theme.alpha(Theme.primary, 0.18)
                    Glyph {
                        anchors.centerIn: parent
                        text: Icons.keyboard
                        size: 22
                        color: Theme.primary
                    }
                }
                ColumnLayout {
                    spacing: 0
                    StyledText {
                        text: "Keybinds"
                        bold: true
                        size: Theme.fontSize + 4
                    }
                    StyledText {
                        text: (root.filter ? root.shown + " of " : "") + root.total + " binds  ·  from hyprland.lua"
                        size: Theme.fontSmall - 1
                        color: Theme.subtext
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                Rectangle {
                    implicitWidth: 340
                    implicitHeight: 40
                    radius: 12
                    color: Theme.surface
                    border.color: field.activeFocus ? Theme.alpha(Theme.primary, 0.5) : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        Glyph {
                            text: Icons.search
                            color: Theme.subtext
                        }
                        TextInput {
                            id: field
                            Layout.fillWidth: true
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSmall + 2
                            color: Theme.fg
                            selectionColor: Theme.alpha(Theme.primary, 0.4)
                            clip: true
                            onTextChanged: root.filter = text
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !field.text
                                text: "Filter keybinds…"
                                size: Theme.fontSmall + 2
                                color: Theme.alpha(Theme.fg, 0.35)
                            }
                            Keys.onEscapePressed: {
                                if (text)
                                    text = "";
                                else
                                    overlay.open = false;
                            }
                        }
                    }
                }
                IconButton {
                    icon: Icons.close
                    size: 36
                    onClicked: overlay.open = false
                }
            }

            // columns
            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: grid.implicitHeight
                contentWidth: width
                contentHeight: grid.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                RowLayout {
                    id: grid
                    width: flick.width
                    spacing: 18

                    Repeater {
                        model: root.columns
                        ColumnLayout {
                            id: col
                            required property var modelData
                            Layout.preferredWidth: (grid.width - 36) / 3
                            Layout.alignment: Qt.AlignTop
                            spacing: 18

                            Repeater {
                                model: col.modelData
                                ColumnLayout {
                                    id: grp
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 4

                                    RowLayout {
                                        Layout.bottomMargin: 4
                                        spacing: 8
                                        Glyph {
                                            text: root.icons[grp.modelData.group] || Icons.keyboard
                                            color: Theme.primary
                                            size: 15
                                        }
                                        StyledText {
                                            text: grp.modelData.group
                                            bold: true
                                            color: Theme.primary
                                        }
                                    }

                                    Repeater {
                                        model: grp.modelData.binds
                                        Rectangle {
                                            id: bindRow
                                            required property var modelData
                                            Layout.fillWidth: true
                                            implicitHeight: 34
                                            radius: 8
                                            color: hover.hovered ? Theme.surface : "transparent"
                                            HoverHandler {
                                                id: hover
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 12

                                                Row {
                                                    Layout.preferredWidth: 200
                                                    spacing: 4
                                                    Repeater {
                                                        model: bindRow.modelData.keys
                                                        Rectangle {
                                                            required property string modelData
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            width: Math.max(24, cap.implicitWidth + 14)
                                                            height: 24
                                                            radius: 6
                                                            color: Theme.surfaceHi
                                                            border.color: Theme.border
                                                            // keycap "depth"
                                                            Rectangle {
                                                                anchors.left: parent.left
                                                                anchors.right: parent.right
                                                                anchors.bottom: parent.bottom
                                                                height: 3
                                                                radius: 6
                                                                color: Theme.alpha("#000000", 0.25)
                                                            }
                                                            StyledText {
                                                                id: cap
                                                                anchors.centerIn: parent
                                                                anchors.verticalCenterOffset: -1
                                                                text: parent.modelData
                                                                size: Theme.fontSmall - 1
                                                                bold: true
                                                            }
                                                        }
                                                    }
                                                }
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: bindRow.modelData.desc
                                                    size: Theme.fontSmall + 1
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.shown === 0 && root.groups.length > 0
                    text: "No keybind matches “" + root.filter + "”"
                    color: Theme.subtext
                }
            }
        }
    }
}
