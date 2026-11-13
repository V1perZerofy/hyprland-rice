import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// Settings overlay (SUPER+comma, the gear in the sidebar or weather card).
// Changes apply live and are saved by services/Settings.qml.
//   qs ipc call settings toggle
Scope {
    id: root

    IpcHandler {
        target: "settings"
        function toggle(): void {
            ov.toggle();
        }
    }
    Connections {
        target: Popups
        function onRequested(n) {
            if (n === "settings")
                ov.open = true;
        }
    }

    // small building blocks ───────────────────────────────────────────────────
    component Section: StyledText {
        Layout.topMargin: 8
        bold: true
        color: Theme.primary
    }
    component Row_: RowLayout {
        property string label: ""
        property string hint: ""
        Layout.fillWidth: true
        spacing: 14
        ColumnLayout {
            Layout.preferredWidth: 170
            spacing: 0
            StyledText {
                text: parent.parent.label
                size: Theme.fontSmall + 1
            }
            StyledText {
                visible: text !== ""
                text: parent.parent.hint
                size: Theme.fontSmall - 2
                color: Theme.subtext
            }
        }
    }
    // two-or-more-way choice
    component Segmented: Rectangle {
        id: seg
        property var options: []        // [[value, label]]
        property var value
        signal picked(var v)
        implicitWidth: segRow.implicitWidth + 8
        implicitHeight: 32
        radius: 10
        color: Theme.surface
        Row {
            id: segRow
            anchors.centerIn: parent
            spacing: 2
            Repeater {
                model: seg.options
                Rectangle {
                    required property var modelData
                    readonly property bool on: seg.value === modelData[0]
                    width: Math.max(64, t.implicitWidth + 24)
                    height: 26
                    radius: 8
                    color: on ? Theme.alpha(Theme.primary, 0.25) : m.containsMouse ? Theme.surfaceHi : "transparent"
                    StyledText {
                        id: t
                        anchors.centerIn: parent
                        text: modelData[1]
                        size: Theme.fontSmall
                        bold: parent.on
                        color: parent.on ? Theme.fg : Theme.subtext
                    }
                    MouseArea {
                        id: m
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seg.picked(modelData[0])
                    }
                }
            }
        }
    }

    Overlay {
        id: ov
        cardWidth: Math.min(640, width - 60)
        cardHeight: Math.min(height - 80, body.implicitHeight + 48)
        card.color: Theme.panelBg
        onOpened: keys.forceActiveFocus()

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: ov.open = false
        }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 24
            contentWidth: width
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body
                width: flick.width
                spacing: 12

                // header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: 12
                        color: Theme.alpha(Theme.primary, 0.18)
                        Glyph {
                            anchors.centerIn: parent
                            text: Icons.settings
                            size: 20
                            color: Theme.primary
                        }
                    }
                    ColumnLayout {
                        spacing: 0
                        StyledText {
                            text: "Settings"
                            bold: true
                            size: Theme.fontSize + 3
                        }
                        StyledText {
                            text: "Applied live, saved automatically"
                            size: Theme.fontSmall - 1
                            color: Theme.subtext
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    IconButton {
                        icon: Icons.refresh
                        label: "Reset"
                        size: 32
                        iconSize: 13
                        onClicked: Settings.reset()
                    }
                    IconButton {
                        icon: Icons.close
                        size: 32
                        onClicked: ov.open = false
                    }
                }

                // ── bar ──
                Section {
                    text: "Bar"
                }
                Row_ {
                    label: "Position"
                    Segmented {
                        options: [["top", "Top"], ["bottom", "Bottom"]]
                        value: Settings.barPosition
                        onPicked: v => Settings.barPosition = v
                    }
                }
                Row_ {
                    label: "Bar background"
                    hint: "0 % = see-through"
                    Slider {
                        Layout.fillWidth: true
                        value: Settings.barOpacity
                        onMoved: v => Settings.barOpacity = Math.round(v * 100) / 100
                    }
                    StyledText {
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(Settings.barOpacity * 100) + "%"
                        size: Theme.fontSmall
                    }
                }
                Row_ {
                    label: "Pill background"
                    Slider {
                        Layout.fillWidth: true
                        value: Settings.pillOpacity
                        onMoved: v => Settings.pillOpacity = Math.round(v * 100) / 100
                    }
                    StyledText {
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(Settings.pillOpacity * 100) + "%"
                        size: Theme.fontSmall
                    }
                }
                Row_ {
                    label: "Size"
                    hint: "text, icons and bar height"
                    // 85 % … 130 %, in 5 % steps
                    Slider {
                        Layout.fillWidth: true
                        value: (Settings.scale - 0.85) / 0.45
                        onMoved: v => {
                            const s = Math.round((0.85 + v * 0.45) * 20) / 20;
                            if (s !== Settings.scale)
                                Settings.scale = s;
                        }
                    }
                    StyledText {
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(Settings.scale * 100) + "%"
                        size: Theme.fontSmall
                    }
                }
                Row_ {
                    label: "24-hour clock"
                    Item {
                        Layout.fillWidth: true
                    }
                    Switch {
                        checked: Settings.clock24h
                        onToggled: Settings.clock24h = !Settings.clock24h
                    }
                }
                Row_ {
                    label: "Open cards on hover"
                    hint: "off = click the pills"
                    Item {
                        Layout.fillWidth: true
                    }
                    Switch {
                        checked: Settings.hoverPopouts
                        onToggled: Settings.hoverPopouts = !Settings.hoverPopouts
                    }
                }
                Row_ {
                    label: "Animations"
                    hint: "off = everything instant"
                    Item {
                        Layout.fillWidth: true
                    }
                    Switch {
                        checked: Settings.animations
                        onToggled: Settings.animations = !Settings.animations
                    }
                }

                // ── modules ──
                Section {
                    text: "Modules"
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Click to show or hide. Some also hide on their own (no media playing, no tray icons…)."
                    size: Theme.fontSmall - 1
                    color: Theme.subtext
                    wrapMode: Text.Wrap
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: Settings.modules
                        Rectangle {
                            required property var modelData
                            readonly property bool on: Settings.shows(modelData[0])
                            width: chipRow.implicitWidth + 22
                            height: 30
                            radius: 15
                            color: on ? Theme.alpha(Theme.primary, 0.22) : chipMouse.containsMouse ? Theme.surfaceHi : Theme.surface
                            border.color: on ? Theme.alpha(Theme.primary, 0.5) : "transparent"
                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6
                                Glyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.parent.on ? "✓" : "+"
                                    size: 12
                                    color: parent.parent.on ? Theme.primary : Theme.subtext
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData[1]
                                    size: Theme.fontSmall
                                    color: parent.parent.on ? Theme.fg : Theme.subtext
                                }
                            }
                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Settings.setShown(modelData[0], !parent.on)
                            }
                        }
                    }
                }

                // ── weather ──
                Section {
                    text: "Weather"
                }
                Row_ {
                    label: "Place"
                    hint: Settings.weatherCity ? "shown in the bar" : "off until you pick one"
                    StyledText {
                        Layout.fillWidth: true
                        text: Settings.weatherCity || "—"
                        color: Settings.weatherCity ? Theme.fg : Theme.subtext
                    }
                    IconButton {
                        visible: Settings.weatherCity !== ""
                        icon: Icons.close
                        label: "Remove"
                        size: 30
                        iconSize: 12
                        onClicked: Weather.clear()
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 11
                    color: Theme.surface
                    border.color: place.activeFocus ? Theme.alpha(Theme.primary, 0.5) : "transparent"
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
                            id: place
                            Layout.fillWidth: true
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSmall + 1
                            color: Theme.fg
                            selectionColor: Theme.alpha(Theme.primary, 0.4)
                            clip: true
                            onTextEdited: placeDebounce.restart()
                            // Enter: take the first match (or search right away)
                            Keys.onReturnPressed: {
                                if (Weather.matches.length) {
                                    Weather.choose(Weather.matches[0]);
                                    text = "";
                                } else {
                                    Weather.search(text);
                                }
                            }
                            Keys.onEscapePressed: {
                                if (text) {
                                    text = "";
                                    Weather.matches = [];
                                } else
                                    ov.open = false;
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !place.text
                                text: "Search a city…"
                                size: Theme.fontSmall + 1
                                color: Theme.alpha(Theme.fg, 0.35)
                            }
                            Timer {
                                id: placeDebounce
                                interval: 400
                                onTriggered: Weather.search(place.text)
                            }
                        }
                        StyledText {
                            visible: Weather.searching
                            text: "…"
                            color: Theme.subtext
                        }
                    }
                }
                Repeater {
                    model: Weather.matches
                    ListRow {
                        required property var modelData
                        icon: Icons.mapMarker
                        title: modelData.name
                        subtitle: [modelData.region, modelData.country].filter(x => x).join(", ")
                        trailing: "Use"
                        // clear first: choose() empties the list, which destroys this row
                        onClicked: {
                            const m = modelData;
                            place.text = "";
                            Weather.choose(m);
                        }
                    }
                }
                Row_ {
                    label: "Units"
                    Segmented {
                        options: [[false, "°C · km/h"], [true, "°F · mph"]]
                        value: Settings.weatherFahrenheit
                        onPicked: v => Settings.weatherFahrenheit = v
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Data from Open-Meteo (no account). Only the search text and the chosen coordinates are sent. Settings live in ~/.local/state/quickshell-settings.json, outside the dotfiles repo."
                    size: Theme.fontSmall - 2
                    color: Theme.subtext
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
