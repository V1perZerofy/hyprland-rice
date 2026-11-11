import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// Time + date pill. Click: calendar card (Monday-first, ISO week numbers on the right).
Pill {
    id: root
    padding: 18
    spacing: 10
    active: pop.open
    onClicked: pop.toggle()

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    StyledText {
        text: Qt.formatDateTime(clock.date, "HH:mm")
        bold: true
        color: Theme.primary
    }
    StyledText {
        text: Qt.formatDateTime(clock.date, "ddd d MMM")
        size: Theme.fontSmall + 1
        color: Theme.subtext
    }

    Popout {
        id: pop
        owner: root
        name: "calendar"
        cardWidth: 330

        // month being viewed
        property int viewYear: clock.date.getFullYear()
        property int viewMonth: clock.date.getMonth()
        onOpenChanged: if (open) {
            viewYear = clock.date.getFullYear();
            viewMonth = clock.date.getMonth();
        }

        function shift(d) {
            let m = viewMonth + d, y = viewYear;
            if (m < 0) { m = 11; y--; }
            if (m > 11) { m = 0; y++; }
            viewMonth = m;
            viewYear = y;
        }
        function isoWeek(d) {
            const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
            const day = t.getUTCDay() || 7;
            t.setUTCDate(t.getUTCDate() + 4 - day);
            const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
            return Math.ceil(((t - y0) / 86400000 + 1) / 7);
        }
        // 6 rows × 7 days starting on the Monday on/before the 1st
        readonly property var cells: {
            const first = new Date(viewYear, viewMonth, 1);
            const offset = (first.getDay() + 6) % 7;
            const out = [];
            for (let i = 0; i < 42; i++)
                out.push(new Date(viewYear, viewMonth, 1 - offset + i));
            return out;
        }

        // big clock
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                size: 34
                bold: true
                color: Theme.primary
            }
            StyledText {
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                color: Theme.subtext
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
        }

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: Qt.formatDate(new Date(pop.viewYear, pop.viewMonth, 1), "MMMM yyyy")
                bold: true
            }
            IconButton {
                icon: Icons.chevronLeft
                size: 28
                onClicked: pop.shift(-1)
            }
            IconButton {
                icon: Icons.calendar
                size: 28
                iconSize: 14
                onClicked: {
                    pop.viewYear = clock.date.getFullYear();
                    pop.viewMonth = clock.date.getMonth();
                }
            }
            IconButton {
                icon: Icons.chevronRight
                size: 28
                onClicked: pop.shift(1)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 8
            rowSpacing: 2
            columnSpacing: 2

            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su", "Wk"]
                StyledText {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    size: Theme.fontSmall - 1
                    bold: true
                    color: index === 7 ? Theme.tertiary : index >= 5 ? Theme.primary : Theme.subtext
                }
            }

            Repeater {
                // 6 rows of (7 days + week number)
                model: 48
                Rectangle {
                    id: cell
                    required property int index
                    readonly property int row: Math.floor(index / 8)
                    readonly property int col: index % 8
                    readonly property bool isWeek: col === 7
                    readonly property var day: isWeek ? null : pop.cells[row * 7 + col]
                    readonly property bool inMonth: day !== null && day.getMonth() === pop.viewMonth
                    readonly property bool isToday: day !== null && day.toDateString() === clock.date.toDateString()

                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: 16
                    color: isToday ? Theme.primary : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: cell.isWeek ? pop.isoWeek(pop.cells[cell.row * 7]) : cell.day.getDate()
                        size: Theme.fontSmall
                        bold: cell.isToday
                        color: cell.isToday ? Theme.bg : cell.isWeek ? Theme.alpha(Theme.tertiary, 0.8) : cell.inMonth ? (cell.col >= 5 ? Theme.primary : Theme.fg) : Theme.alpha(Theme.fg, 0.25)
                    }
                }
            }
        }
    }
}
