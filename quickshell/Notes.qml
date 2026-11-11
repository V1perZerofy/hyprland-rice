import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// Markdown notes sidebar (right edge). Browses your Obsidian vault, plus the
// quickshell TODO.md pinned on top.
//  - renders markdown (tables, code, links), Obsidian [[wikilinks]] open in place
//  - task checkboxes are clickable and saved straight back to the file
//  - Edit mode for quick raw edits (Ctrl+S saves, Esc leaves edit mode)
//  - Pin: reserve screen space so windows tile next to it instead of under it
//  - follows file changes live (e.g. while you edit in Obsidian)
//   qs ipc call notes toggle | notes open <path>
Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string vault: home + "/Documents/Obsidian Vault"
    readonly property string todo: home + "/.config/quickshell/TODO.md"
    readonly property int panelWidth: 560

    property bool open: false
    property bool pinned: false
    property string current: ""          // path of the open note ("" = browser)
    property var history: []             // back stack of paths
    property bool editing: false
    property var notes: []               // [{ path, name, folder }]

    function title(p) {
        return p.split("/").pop().replace(/\.md$/i, "");
    }
    function folderOf(p) {
        if (p.startsWith(vault + "/")) {
            const rel = p.slice(vault.length + 1).split("/");
            rel.pop();
            return rel.join(" / ");
        }
        return p.replace(home, "~").split("/").slice(0, -1).join("/");
    }

    function show(path) {
        if (!path)
            return;
        if (editing)
            saveEdit();
        if (current && current !== path)
            history = history.concat([current]);
        current = path;
        open = true;
        saveState();
    }
    function back() {
        if (editing)
            saveEdit();
        if (history.length) {
            current = history[history.length - 1];
            history = history.slice(0, -1);
        } else {
            current = "";
        }
        saveState();
    }

    function resolve(link) {
        if (link.startsWith("wiki:")) {
            const target = decodeURIComponent(link.slice(5)).replace(/#.*/, "").trim().toLowerCase();
            const hit = notes.find(n => n.name.toLowerCase() === target) || notes.find(n => n.path.toLowerCase().endsWith("/" + target + ".md"));
            if (hit)
                show(hit.path);
            return;
        }
        if (/^[a-z]+:/i.test(link)) {
            Qt.openUrlExternally(link);
            return;
        }
        // relative link to another file
        const dir = current.split("/").slice(0, -1).join("/");
        const p = decodeURIComponent(link.startsWith("/") ? link : dir + "/" + link);
        if (/\.md$/i.test(p))
            show(p);
        else
            Qt.openUrlExternally("file://" + p);
    }

    function toggleTask(line) {
        const lines = noteFile.text().split("\n");
        const l = lines[line];
        if (l === undefined)
            return;
        lines[line] = l.replace(/^(\s*[-*+]\s+\[)([ xX])(\])/, (m, a, c, b) => a + (c === " " ? "x" : " ") + b);
        noteFile.setText(lines.join("\n"));
    }

    function startEdit() {
        editor.text = noteFile.text();
        editing = true;
        editor.forceActiveFocus();
    }
    function saveEdit() {
        if (editing && editor.text !== noteFile.text())
            noteFile.setText(editor.text);
        editing = false;
    }

    function openInObsidian() {
        Quickshell.execDetached(["xdg-open", "obsidian://open?path=" + encodeURIComponent(current)]);
    }
    function openInEditor() {
        Quickshell.execDetached(["kitty", "nvim", current]);
    }

    // ── state & files ───────────────────────────────────────────────────────
    function saveState() {
        stateFile.setText(JSON.stringify({
            current: current,
            pinned: pinned
        }));
    }
    FileView {
        id: stateFile
        path: root.home + "/.local/state/quickshell-notes.json"
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.current = s.current || "";
                root.pinned = !!s.pinned;
            } catch (e) {}
        }
    }

    FileView {
        id: noteFile
        path: root.current
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    Process {
        id: scan
        command: ["sh", "-c", "find \"$1\" -name '*.md' -not -path '*/.obsidian/*' -not -path '*/.trash/*' -printf '%T@\\t%p\\n' | sort -rn | cut -f2-", "scan", root.vault]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [{
                        path: root.todo,
                        name: "Quickshell TODO",
                        folder: "~/.config/quickshell",
                        pinned: true
                    }];
                for (const p of text.split("\n"))
                    if (p)
                        list.push({
                            path: p,
                            name: root.title(p),
                            folder: root.folderOf(p)
                        });
                root.notes = list;
            }
        }
    }
    onOpenChanged: if (open) scan.running = true
    Component.onCompleted: scan.running = true

    IpcHandler {
        target: "notes"
        function toggle(): void {
            if (root.open && root.editing)
                root.saveEdit();
            root.open = !root.open;
        }
        // empty path → note browser
        function open(path: string): void {
            if (path) {
                root.show(path);
            } else {
                root.saveEdit();
                root.current = "";
                root.open = true;
            }
        }
    }

    // ── UI ──────────────────────────────────────────────────────────────────
    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
        anchors {
            top: true
            bottom: true
            right: true
        }
        margins.top: (Popups.barVisible ? Theme.barHeight : 0) + 8
        margins.bottom: 8
        margins.right: 8
        implicitWidth: root.panelWidth
        exclusionMode: root.pinned ? ExclusionMode.Normal : ExclusionMode.Ignore
        exclusiveZone: root.pinned ? root.panelWidth + 8 : 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-notes"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"
        visible: root.open || panel.x < win.width

        Rectangle {
            id: panel
            width: parent.width
            height: parent.height
            x: root.open ? 0 : win.width + 10
            radius: Theme.cardRadius
            color: Theme.panelBg
            border.color: Theme.border
            border.width: 1
            clip: true

            Behavior on x {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            Keys.onEscapePressed: {
                if (root.editing)
                    root.saveEdit();
                else
                    root.open = false;
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    IconButton {
                        visible: root.current !== ""
                        icon: Icons.chevronLeft
                        size: 32
                        onClicked: root.back()
                    }
                    Rectangle {
                        visible: root.current === ""
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 16
                        color: Theme.alpha(Theme.primary, 0.18)
                        Glyph {
                            anchors.centerIn: parent
                            text: Icons.notebook
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: root.current ? root.title(root.current) : "Notes"
                            bold: true
                            size: Theme.fontSize + 1
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.current ? root.folderOf(root.current) : root.notes.length + " notes"
                            size: Theme.fontSmall - 1
                            color: Theme.subtext
                        }
                    }
                    IconButton {
                        visible: root.current !== ""
                        icon: root.editing ? Icons.check : Icons.pencil
                        size: 32
                        highlighted: root.editing
                        onClicked: root.editing ? root.saveEdit() : root.startEdit()
                    }
                    IconButton {
                        visible: root.current !== "" && root.current.startsWith(root.vault)
                        icon: Icons.obsidian
                        size: 32
                        onClicked: root.openInObsidian()
                    }
                    IconButton {
                        visible: root.current !== ""
                        icon: Icons.terminal
                        size: 32
                        onClicked: root.openInEditor()
                    }
                    IconButton {
                        icon: Icons.pin
                        size: 32
                        highlighted: root.pinned
                        onClicked: {
                            root.pinned = !root.pinned;
                            root.saveState();
                        }
                    }
                    IconButton {
                        icon: Icons.close
                        size: 32
                        onClicked: {
                            root.saveEdit();
                            root.open = false;
                        }
                    }
                }

                // ── browser ──
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.current === ""
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 12
                        color: Theme.surface
                        border.color: search.activeFocus ? Theme.alpha(Theme.primary, 0.5) : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            Glyph {
                                text: Icons.search
                            }
                            TextInput {
                                id: search
                                Layout.fillWidth: true
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                color: Theme.fg
                                clip: true
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !search.text
                                    text: "Search notes…"
                                    color: Theme.alpha(Theme.fg, 0.35)
                                }
                                onTextChanged: noteList.currentIndex = 0
                                Keys.onPressed: e => {
                                    if (e.key === Qt.Key_Down)
                                        noteList.incrementCurrentIndex();
                                    else if (e.key === Qt.Key_Up)
                                        noteList.decrementCurrentIndex();
                                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                        if (noteList.currentItem)
                                            root.show(noteList.currentItem.modelData.path);
                                    } else if (e.key === Qt.Key_Escape)
                                        root.open = false;
                                    else
                                        return;
                                    e.accepted = true;
                                }
                            }
                        }
                    }

                    ListView {
                        id: noteList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 100
                        model: {
                            const q = search.text.trim().toLowerCase();
                            if (!q)
                                return root.notes;
                            return root.notes.filter(n => (n.name + " " + n.folder).toLowerCase().includes(q));
                        }
                        highlight: Rectangle {
                            radius: 12
                            color: Theme.alpha(Theme.primary, 0.14)
                        }
                        delegate: ListRow {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            icon: modelData.pinned ? Icons.pin : Icons.noteIcon
                            title: modelData.name
                            subtitle: modelData.folder
                            onClicked: root.show(modelData.path)
                            HoverHandler {
                                onHoveredChanged: if (hovered) noteList.currentIndex = parent.index
                            }
                        }
                    }
                }

                // ── viewer ──
                Flickable {
                    id: viewer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.current !== "" && !root.editing
                    clip: true
                    contentWidth: width
                    contentHeight: md.height + 24
                    boundsBehavior: Flickable.StopAtBounds

                    MarkdownView {
                        id: md
                        width: viewer.width - 10
                        text: noteFile.loaded ? noteFile.text() : ""
                        onLinkActivated: l => root.resolve(l)
                        onTaskToggled: line => root.toggleTask(line)
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: root.current !== "" && !noteFile.loaded
                        text: "Couldn't open this note"
                        color: Theme.subtext
                    }
                }

                // ── editor ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.editing
                    radius: 12
                    color: Theme.surface

                    Flickable {
                        id: editFlick
                        anchors.fill: parent
                        anchors.margins: 12
                        clip: true
                        contentWidth: width
                        contentHeight: editor.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        function ensureVisible(r) {
                            if (contentY >= r.y)
                                contentY = r.y;
                            else if (contentY + height <= r.y + r.height)
                                contentY = r.y + r.height - height;
                        }

                        TextEdit {
                            id: editor
                            width: editFlick.width
                            wrapMode: TextEdit.Wrap
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSmall + 1
                            color: Theme.fg
                            selectionColor: Theme.alpha(Theme.primary, 0.4)
                            selectByMouse: true
                            onCursorRectangleChanged: editFlick.ensureVisible(cursorRectangle)
                            Keys.onPressed: e => {
                                if (e.key === Qt.Key_S && (e.modifiers & Qt.ControlModifier)) {
                                    root.saveEdit();
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Escape) {
                                    root.saveEdit();
                                    e.accepted = true;
                                }
                            }
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.editing ? "Ctrl+S save   Esc save & leave edit" : root.current ? "click [ ] to tick off   links open in place" : "↵ open   ↑↓ move   esc close"
                    size: Theme.fontSmall - 1
                    color: Theme.alpha(Theme.fg, 0.35)
                }
            }
        }
    }
}
