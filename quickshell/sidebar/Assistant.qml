import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// Sidebar "Assistant" tab: local Ollama chat (replaces the eww chat).
// Streams replies, renders markdown, model picker, history kept in
// ~/.local/state/quickshell-chat.json.
// Enter sends · Shift+Enter newline.
ColumnLayout {
    id: root

    readonly property string endpoint: "http://localhost:11434"
    readonly property string home: Quickshell.env("HOME")
    readonly property string systemPrompt: "You are a concise assistant embedded in a Hyprland desktop sidebar on CachyOS. Keep answers short and direct. Markdown is rendered, so use it when it helps (lists, code blocks)."

    // only the recent part of the chat is sent: llama3.2 runs on the CPU here
    // and has a 4k context, so the full history just makes replies slow
    readonly property int contextMessages: 12
    property string model: "llama3.2"
    property var models: []
    property bool busy: false
    property string error: ""

    function focusInput() {
        input.forceActiveFocus();
    }

    function history() {
        const out = [];
        for (let i = 0; i < messages.count; i++)
            out.push({
                role: messages.get(i).role,
                content: messages.get(i).content
            });
        return out;
    }
    function save() {
        store.setText(JSON.stringify({
            model: model,
            messages: history()
        }));
    }
    function load(list) {
        messages.clear();
        for (const m of list || [])
            if (m.role === "user" || m.role === "assistant")
                messages.append({
                    role: m.role,
                    content: m.content
                });
    }

    function send() {
        const text = input.text.trim();
        if (!text || busy)
            return;
        input.text = "";
        error = "";
        messages.append({
            role: "user",
            content: text
        });
        const body = JSON.stringify({
            model: model,
            stream: true,
            messages: [{
                    role: "system",
                    content: systemPrompt
                }].concat(history().slice(-root.contextMessages))
        });
        messages.append({
            role: "assistant",
            content: ""
        });
        busy = true;
        chat.command = ["curl", "-sN", "--fail-with-body", endpoint + "/api/chat", "-H", "Content-Type: application/json", "-d", body];
        chat.running = true;
        list.positionViewAtEnd();
    }
    function stop() {
        chat.running = false;
    }
    function clearChat() {
        stop();
        messages.clear();
        save();
    }

    spacing: 10

    ListModel {
        id: messages
    }

    Process {
        id: chat
        stdout: SplitParser {
            onRead: line => {
                let d;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (d.error) {
                    root.error = d.error;
                    return;
                }
                const last = messages.count - 1;
                if (d.message && d.message.content)
                    messages.setProperty(last, "content", messages.get(last).content + d.message.content);
                if (list.atYEnd || list.contentHeight < list.height + 80)
                    list.positionViewAtEnd();
            }
        }
        onExited: code => {
            root.busy = false;
            const last = messages.count - 1;
            if (last >= 0 && messages.get(last).role === "assistant" && !messages.get(last).content) {
                messages.remove(last);
                if (!root.error)
                    root.error = code === 7 ? "Ollama isn't running — systemctl start ollama" : "No reply (curl exit " + code + ")";
            }
            root.save();
        }
    }

    Process {
        id: tags
        command: ["curl", "-s", root.endpoint + "/api/tags"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.models = JSON.parse(text).models.map(m => m.name.replace(/:latest$/, ""));
                    if (root.models.length && !root.models.includes(root.model))
                        root.model = root.models[0];
                } catch (e) {}
            }
        }
    }
    Component.onCompleted: tags.running = true

    FileView {
        id: store
        path: root.home + "/.local/state/quickshell-chat.json"
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                if (s.model)
                    root.model = s.model;
                root.load(s.messages);
                list.positionViewAtEnd();
            } catch (e) {}
        }
    }

    // ── header: model + clear ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        IconButton {
            icon: Icons.robot
            label: root.model
            size: 30
            onClicked: {
                tags.running = true;
                if (root.models.length > 1)
                    root.model = root.models[(root.models.indexOf(root.model) + 1) % root.models.length];
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: root.models.length > 1 ? "click to switch model" : "local · Ollama"
            size: Theme.fontSmall - 1
            color: Theme.subtext
        }
        IconButton {
            visible: messages.count > 0
            icon: Icons.trash
            size: 30
            onClicked: root.clearChat()
        }
    }

    // ── messages ──
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 10
        model: messages
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: msg
            required property string role
            required property string content
            required property int index
            readonly property bool mine: role === "user"
            width: ListView.view.width
            height: bubble.height

            Rectangle {
                id: bubble
                anchors.right: msg.mine ? parent.right : undefined
                width: msg.mine ? Math.min(parent.width * 0.85, userText.implicitWidth + 28) : parent.width
                height: (msg.mine ? userText.implicitHeight : Math.max(20, md.height)) + 20
                radius: 14
                color: msg.mine ? Theme.alpha(Theme.primary, 0.22) : Theme.surface
                clip: true      // long code lines don't wrap

                Text {
                    id: userText
                    visible: msg.mine
                    x: 14
                    y: 10
                    width: Math.min(msg.width * 0.85 - 28, implicitWidth)
                    text: msg.content
                    wrapMode: Text.Wrap
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSmall + 1
                    color: Theme.fg
                }

                MarkdownView {
                    id: md
                    visible: !msg.mine
                    x: 14
                    y: 10
                    width: parent.width - 28
                    spacing: 4
                    text: msg.content || (root.busy && msg.index === messages.count - 1 ? "*thinking…*" : "")
                }
            }
        }

        // empty state
        ColumnLayout {
            anchors.centerIn: parent
            visible: messages.count === 0
            spacing: 6
            Glyph {
                Layout.alignment: Qt.AlignHCenter
                text: Icons.robot
                size: 40
                color: Theme.muted
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "Ask " + root.model + " anything"
                color: Theme.subtext
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.error !== ""
        text: "⚠ " + root.error
        color: Theme.error
        size: Theme.fontSmall
        wrapMode: Text.Wrap
    }

    // ── input ──
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.min(140, input.implicitHeight + 20)
        radius: 14
        color: Theme.surface
        border.color: input.activeFocus ? Theme.alpha(Theme.primary, 0.5) : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            spacing: 8

            TextEdit {
                id: input
                Layout.fillWidth: true
                wrapMode: TextEdit.Wrap
                font.family: Theme.font
                font.pixelSize: Theme.fontSmall + 1
                color: Theme.fg
                selectionColor: Theme.alpha(Theme.primary, 0.4)
                selectByMouse: true
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !input.text
                    text: "Message " + root.model + "…"
                    size: Theme.fontSmall + 1
                    color: Theme.alpha(Theme.fg, 0.35)
                }
                Keys.onPressed: e => {
                    if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) {
                        root.send();
                        e.accepted = true;
                    }
                }
            }
            IconButton {
                icon: root.busy ? Icons.stop : Icons.send
                size: 34
                highlighted: true
                onClicked: root.busy ? root.stop() : root.send()
            }
        }
    }
}
