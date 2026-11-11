import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.components

// App launcher (replaces `rofi -show drun`).
//  - fuzzy search over name, generic name, keywords and command
//  - most-used apps float to the top (counts in ~/.local/state/quickshell-launcher.json)
//  - maths via qalc: type "2^10", "80*15%", "=sqrt(2)" ("=" forces qalc);
//    Enter copies the result
//  ↑/↓ Tab Ctrl+J/K move · Enter open · Esc close
//   qs ipc call launcher toggle
Scope {
    id: root

    property var usage: ({})
    property string calcResult: ""

    // ── data ────────────────────────────────────────────────────────────────
    readonly property var apps: {
        const seen = {};
        return DesktopEntries.applications.values.filter(a => {
            if (a.noDisplay || seen[a.name])
                return false;
            seen[a.name] = true;
            return true;
        });
    }

    function fuzzy(q, s) {
        if (!s)
            return -1;
        s = s.toLowerCase();
        const i = s.indexOf(q);
        if (i === 0)
            return 1000 - s.length;
        if (i > 0)
            return (" -_.".includes(s[i - 1]) ? 800 : 600) - i;
        let from = 0, last = -2, score = 0;
        for (const c of q) {
            const f = s.indexOf(c, from);
            if (f < 0)
                return -1;
            score += f === last + 1 ? 6 : 1;
            last = f;
            from = f + 1;
        }
        return 100 + score * 4 - s.length;
    }

    function results(query) {
        const q = query.trim().toLowerCase();
        const use = id => Math.min(200, (usage[id] || 0) * 10);
        if (!q)
            return apps.slice().sort((a, b) => (use(b.id) - use(a.id)) || a.name.localeCompare(b.name));
        const out = [];
        for (const a of apps) {
            const s = Math.max(fuzzy(q, a.name), fuzzy(q, a.genericName) * 0.7, fuzzy(q, (a.keywords || []).join(" ")) * 0.6, fuzzy(q, a.execString) * 0.5);
            if (s > 0)
                out.push({
                    a,
                    s: s + use(a.id)
                });
        }
        return out.sort((x, y) => y.s - x.s).slice(0, 60).map(x => x.a);
    }

    function isMath(q) {
        q = q.trim();
        return q.startsWith("=") || (/^[\d\s.+\-*/^%()x×÷]+$/.test(q) && /\d/.test(q) && /[+\-*/^%×÷]/.test(q));
    }

    function launch(app) {
        if (!app)
            return;
        const u = Object.assign({}, usage);
        u[app.id] = (u[app.id] || 0) + 1;
        usage = u;
        usageFile.setText(JSON.stringify(u));
        if (app.runInTerminal)
            Quickshell.execDetached(["kitty"].concat(app.command));
        else
            app.execute();
        win.open = false;
    }

    function accept() {
        if (calcResult && isMath(search.text)) {
            Quickshell.execDetached(["wl-copy", calcResult]);
            win.open = false;
        } else {
            launch(list.currentItem ? list.currentItem.modelData : null);
        }
    }

    FileView {
        id: usageFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell-launcher.json"
        printErrors: false
        onLoaded: {
            try {
                root.usage = JSON.parse(text());
            } catch (e) {}
        }
    }

    Process {
        id: calc
        stdout: StdioCollector {
            onStreamFinished: root.calcResult = text.trim()
        }
    }
    Timer {
        id: calcDebounce
        interval: 120
        onTriggered: {
            const q = search.text.trim().replace(/^=/, "");
            if (!q)
                return;
            calc.running = false;
            calc.command = ["qalc", "-t", q];
            calc.running = true;
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            win.toggle();
        }
    }

    // ── UI ──────────────────────────────────────────────────────────────────
    Overlay {
        id: win
        cardWidth: 620
        cardHeight: 540
        cardY: height * 0.16
        onOpened: {
            search.text = "";
            list.currentIndex = 0;
            list.positionViewAtBeginning();
            search.forceActiveFocus();
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // search field
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 50
                radius: 14
                color: Theme.surface
                border.color: search.activeFocus ? Theme.alpha(Theme.primary, 0.5) : "transparent"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12
                    Glyph {
                        text: Icons.search
                        size: 20
                    }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        font.family: Theme.font
                        font.pixelSize: 17
                        color: Theme.fg
                        selectionColor: Theme.alpha(Theme.primary, 0.4)
                        clip: true

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !search.text
                            text: "Search apps, or calculate…"
                            size: 17
                            color: Theme.alpha(Theme.fg, 0.35)
                        }

                        onTextChanged: {
                            list.currentIndex = 0;
                            root.calcResult = "";
                            if (root.isMath(text))
                                calcDebounce.restart();
                        }

                        Keys.onPressed: e => {
                            const ctrl = e.modifiers & Qt.ControlModifier;
                            if (e.key === Qt.Key_Escape)
                                win.open = false;
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                                root.accept();
                            else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab || (ctrl && (e.key === Qt.Key_J || e.key === Qt.Key_N)))
                                list.incrementCurrentIndex();
                            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (ctrl && (e.key === Qt.Key_K || e.key === Qt.Key_P)))
                                list.decrementCurrentIndex();
                            else if (e.key === Qt.Key_PageDown)
                                list.currentIndex = Math.min(list.count - 1, list.currentIndex + 8);
                            else if (e.key === Qt.Key_PageUp)
                                list.currentIndex = Math.max(0, list.currentIndex - 8);
                            else
                                return;
                            e.accepted = true;
                        }
                    }
                }
            }

            // calculator result
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 56
                radius: 14
                visible: root.calcResult !== "" && root.isMath(search.text)
                color: Theme.alpha(Theme.primary, 0.16)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12
                    Glyph {
                        text: Icons.calculator
                        size: 22
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.calcResult
                        size: 18
                        bold: true
                    }
                    StyledText {
                        text: "↵ copy"
                        size: Theme.fontSmall
                        color: Theme.subtext
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: win.open ? root.results(search.text) : []
                highlightMoveDuration: 120
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationWraps: true

                highlight: Rectangle {
                    radius: 12
                    color: Theme.alpha(Theme.primary, 0.18)
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    width: ListView.view.width
                    height: 54

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 14

                        Item {
                            implicitWidth: 34
                            implicitHeight: 34
                            readonly property string src: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                            IconImage {
                                anchors.fill: parent
                                source: parent.src
                                visible: parent.src !== ""
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: parent.src === ""
                                radius: 10
                                color: Theme.alpha(Theme.primary, 0.2)
                                StyledText {
                                    anchors.centerIn: parent
                                    text: row.modelData.name.charAt(0).toUpperCase()
                                    bold: true
                                    color: Theme.primary
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                bold: row.current
                                color: row.current ? Theme.primary : Theme.fg
                            }
                            StyledText {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.modelData.comment || row.modelData.genericName || ""
                                size: Theme.fontSmall - 1
                                color: Theme.subtext
                            }
                        }

                        Glyph {
                            visible: row.modelData.runInTerminal
                            text: Icons.terminal
                            size: 14
                            color: Theme.subtext
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: list.currentIndex = row.index
                        onClicked: root.launch(row.modelData)
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: list.count === 0 && !(root.calcResult && root.isMath(search.text))
                    text: "No matches"
                    color: Theme.subtext
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "↵ open   ↑↓ move   = calculate   esc close"
                size: Theme.fontSmall - 1
                color: Theme.alpha(Theme.fg, 0.35)
            }
        }
    }
}
