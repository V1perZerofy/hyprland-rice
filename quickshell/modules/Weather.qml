import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// Weather pill (Open-Meteo, services/Weather.qml). Hidden until a place is
// set in the settings overlay (SUPER+comma).
// Left: card with now / next 12 h / 5 days · Right: refresh.
Pill {
    id: root

    visible: Weather.enabled && Settings.shows("weather")
    active: pop.open
    onClicked: m => {
        if (m.button === Qt.RightButton)
            Weather.refresh();
        else
            pop.toggle();
    }

    Glyph {
        text: Weather.current ? Weather.glyph(Weather.current.code, Weather.current.isDay) : Icons.thermometer
        color: Theme.primary
    }
    StyledText {
        text: Weather.current ? Weather.deg(Weather.current.temp) : "…"
        size: Theme.fontSmall + 1
    }

    Popout {
        id: pop
        owner: root
        name: "weather"
        cardWidth: 380
        // refresh on open when older than 5 min (never loaded: getTime() is NaN → refresh)
        onOpenChanged: if (open && !(Date.now() - Weather.updated.getTime() < 5 * 60 * 1000)) Weather.refresh()

        // ── now ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Glyph {
                text: Weather.current ? Weather.glyph(Weather.current.code, Weather.current.isDay) : Icons.thermometer
                size: Math.round(46 * Theme.s)
                color: Theme.primary
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: Weather.current ? Math.round(Weather.current.temp) + Weather.unit : "–"
                    bold: true
                    size: Math.round(26 * Theme.s)
                }
                StyledText {
                    text: Weather.current ? Weather.label(Weather.current.code) + "  ·  feels " + Weather.deg(Weather.current.feels) : Weather.error || "Loading…"
                    color: Theme.subtext
                    size: Theme.fontSmall
                }
            }
            ColumnLayout {
                spacing: 2
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 6
                    Glyph {
                        text: Icons.mapMarker
                        size: 13
                        color: Theme.subtext
                    }
                    StyledText {
                        text: Settings.weatherCity
                        size: Theme.fontSmall
                        color: Theme.subtext
                    }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 6
                    visible: Weather.current !== null
                    Glyph {
                        text: Icons.humidity
                        size: 13
                        color: Theme.subtext
                    }
                    StyledText {
                        text: Weather.current ? Weather.current.humidity + "%" : ""
                        size: Theme.fontSmall
                    }
                    Glyph {
                        text: Icons.wind
                        size: 13
                        color: Theme.subtext
                    }
                    StyledText {
                        text: Weather.current ? Math.round(Weather.current.wind) + " " + Weather.current.windUnit : ""
                        size: Theme.fontSmall
                    }
                }
            }
        }

        // ── next 12 hours ──
        Rectangle {
            Layout.fillWidth: true
            visible: Weather.hourly.length > 0
            implicitHeight: hours.implicitHeight + 16
            radius: 12
            color: Theme.surface
            Flickable {
                id: hoursFlick
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: hours.implicitWidth
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: hours
                    spacing: 4
                    Repeater {
                        model: Weather.hourly
                        ColumnLayout {
                            required property var modelData
                            required property int index
                            width: Math.max(38, (hoursFlick.width - 4 * 6) / 7)
                            spacing: 3
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: index === 0 ? "Now" : Qt.formatDateTime(new Date(modelData.time), Settings.clock24h ? "HH" : "h AP")
                                size: Theme.fontSmall - 2
                                color: Theme.subtext
                            }
                            Glyph {
                                Layout.alignment: Qt.AlignHCenter
                                text: Weather.glyph(modelData.code, modelData.isDay)
                                color: Theme.fg
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Weather.deg(modelData.temp)
                                size: Theme.fontSmall
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.rain >= 20 ? modelData.rain + "%" : " "
                                size: Theme.fontSmall - 3
                                color: Theme.primary
                            }
                        }
                    }
                }
            }
        }

        // ── 5 days ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: Weather.daily.length > 0
            readonly property real lo: Math.min(...Weather.daily.map(d => d.min))
            readonly property real hi: Math.max(...Weather.daily.map(d => d.max))
            id: days

            Repeater {
                model: Weather.daily
                RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 30
                    spacing: 10
                    StyledText {
                        Layout.preferredWidth: 46
                        text: index === 0 ? "Today" : Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd")
                        size: Theme.fontSmall
                        bold: index === 0
                    }
                    Glyph {
                        Layout.preferredWidth: 20
                        text: Weather.glyph(modelData.code, true)
                        color: Theme.fg
                    }
                    StyledText {
                        Layout.preferredWidth: 34
                        text: modelData.rain >= 20 ? modelData.rain + "%" : ""
                        size: Theme.fontSmall - 2
                        color: Theme.primary
                    }
                    StyledText {
                        Layout.preferredWidth: 30
                        horizontalAlignment: Text.AlignRight
                        text: Weather.deg(modelData.min)
                        size: Theme.fontSmall
                        color: Theme.subtext
                    }
                    // min–max range bar on the week's scale
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Theme.surfaceHi
                        }
                        Rectangle {
                            readonly property real span: Math.max(1, days.hi - days.lo)
                            x: parent.width * (modelData.min - days.lo) / span
                            width: Math.max(6, parent.width * (modelData.max - modelData.min) / span)
                            height: parent.height
                            radius: 3
                            color: Theme.primary
                        }
                    }
                    StyledText {
                        Layout.preferredWidth: 30
                        text: Weather.deg(modelData.max)
                        size: Theme.fontSmall
                    }
                }
            }
        }

        // ── footer ──
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: (Weather.error ? "⚠ " + Weather.error + "  ·  " : "") + (Weather.updated.getTime() ? "Updated " + Qt.formatTime(Weather.updated, Settings.clock24h ? "HH:mm" : "h:mm AP") + "  ·  " : "") + "Open-Meteo"
                size: Theme.fontSmall - 2
                color: Weather.error ? Theme.error : Theme.subtext
            }
            IconButton {
                icon: Icons.refresh
                size: 28
                iconSize: 13
                onClicked: Weather.refresh()
            }
            IconButton {
                icon: Icons.settings
                size: 28
                iconSize: 13
                onClicked: {
                    pop.open = false;
                    Popups.requested("settings");
                }
            }
        }
    }
}
