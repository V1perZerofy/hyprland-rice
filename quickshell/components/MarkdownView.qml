import QtQuick
import QtQuick.Layouts
import qs.services

// Renders a markdown string. Most of it goes through Qt's own markdown engine
// (tables, lists, code, emphasis, links); a light block parser in front adds:
//  - themed headings and rules
//  - task items as clickable checkboxes → taskToggled(line) with the 0-based
//    source line, so the owner can write the change back
//  - Obsidian [[wikilinks]] / [[note|alias]] → links "wiki:note"
//  - YAML frontmatter is hidden
Column {
    id: root

    property string text: ""
    signal linkActivated(string link)
    signal taskToggled(int line)

    spacing: 8

    // Inline pass for one non-code line: wikilinks → links, then every link
    // gets an explicit colour (Qt's markdown engine paints links with the app
    // palette's blue and ignores linkColor / palette.link). `code` is left alone.
    function inline(line) {
        const hex = Theme.primary.toString();
        return line.split("`").map((seg, i) => i % 2 ? seg : root.wiki(seg).replace(/(^|[^!])\[([^\]]+)\]\(([^)\s]+)\)/g, (m, pre, t, u) => `${pre}<a href="${u}"><span style="color:${hex}">${t}</span></a>`)).join("`");
    }

    function wiki(s) {
        return s.replace(/!\[\[([^\]|]+)(\|[^\]]*)?\]\]/g, "*$1*").replace(/\[\[([^\]|]+)\|([^\]]+)\]\]/g, (m, t, a) => `[${a}](wiki:${encodeURIComponent(t)})`).replace(/\[\[([^\]]+)\]\]/g, (m, t) => `[${t.replace(/#.*/, "")}](wiki:${encodeURIComponent(t)})`);
    }

    readonly property var blocks: {
        const lines = text.split("\n");
        const out = [];
        let buf = [];
        const flush = () => {
            if (buf.join("").trim())
                out.push({
                    type: "md",
                    text: buf.join("\n")
                });
            buf = [];
        };
        let i = 0, fence = false;
        // frontmatter
        if (lines[0] && lines[0].trim() === "---") {
            const end = lines.indexOf("---", 1);
            if (end > 0)
                i = end + 1;
        }
        for (; i < lines.length; i++) {
            const l = lines[i];
            if (/^\s*(```|~~~)/.test(l)) {
                fence = !fence;
                buf.push(l);
                continue;
            }
            if (fence) {
                buf.push(l);
                continue;
            }
            let m;
            if ((m = l.match(/^(#{1,6})\s+(.*?)\s*#*\s*$/))) {
                flush();
                out.push({
                    type: "h",
                    level: m[1].length,
                    text: root.inline(m[2])
                });
            } else if (/^\s{0,3}([-*_])(\s*\1){2,}\s*$/.test(l)) {
                flush();
                out.push({
                    type: "hr"
                });
            } else if ((m = l.match(/^(\s*)[-*+]\s+\[([ xX])\]\s+(.*)$/))) {
                flush();
                const indent = m[1].replace(/\t/g, "    ").length;
                let body = m[3];
                const line = i;
                // indented continuation lines belong to the task
                while (i + 1 < lines.length && /^\s+\S/.test(lines[i + 1]) && lines[i + 1].replace(/\t/g, "    ").search(/\S/) > indent && !/^\s*([-*+]|\d+\.)\s/.test(lines[i + 1])) {
                    body += " " + lines[++i].trim();
                }
                out.push({
                    type: "task",
                    indent: indent,
                    checked: m[2] !== " ",
                    text: root.inline(body),
                    line: line
                });
            } else {
                buf.push(root.inline(l));
            }
        }
        flush();
        return out;
    }

    Repeater {
        model: root.blocks

        Loader {
            id: block
            required property var modelData
            width: root.width
            sourceComponent: modelData.type === "h" ? heading : modelData.type === "hr" ? rule : modelData.type === "task" ? task : md
        }
    }

    // ── block types ─────────────────────────────────────────────────────────
    component LinkText: Text {
        textFormat: Text.MarkdownText
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: Theme.fontSmall + 1
        color: Theme.fg
        linkColor: Theme.primary
        palette.link: Theme.primary      // MarkdownText ignores linkColor
        onLinkActivated: l => root.linkActivated(l)
        HoverHandler {
            cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
        }
    }

    Component {
        id: md
        LinkText {
            text: parent ? parent.modelData.text : ""
            lineHeight: 1.15
        }
    }

    Component {
        id: heading
        ColumnLayout {
            readonly property var b: parent ? parent.modelData : ({})
            spacing: 4
            LinkText {
                Layout.fillWidth: true
                Layout.topMargin: b.level <= 2 ? 10 : 4
                text: b.text || ""
                font.pixelSize: [26, 21, 18, 16, 15, 14][(b.level || 1) - 1]
                font.weight: Font.Bold
                color: b.level <= 2 ? Theme.primary : b.level === 3 ? Theme.tertiary : Theme.fg
            }
            Rectangle {
                visible: b.level === 1
                Layout.fillWidth: true
                implicitHeight: 2
                radius: 1
                color: Theme.alpha(Theme.primary, 0.35)
            }
        }
    }

    Component {
        id: rule
        Item {
            implicitHeight: 13
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: Theme.border
            }
        }
    }

    Component {
        id: task
        Item {
            id: t
            readonly property var b: parent ? parent.modelData : ({})
            implicitHeight: Math.max(22, label.implicitHeight + 2)

            Rectangle {
                id: box
                x: (t.b.indent || 0) * 6
                y: 2
                width: 18
                height: 18
                radius: 5
                color: t.b.checked ? Theme.primary : boxMouse.containsMouse ? Theme.surfaceHi : "transparent"
                border.width: t.b.checked ? 0 : 2
                border.color: boxMouse.containsMouse ? Theme.primary : Theme.alpha(Theme.fg, 0.4)
                Glyph {
                    anchors.centerIn: parent
                    visible: t.b.checked
                    text: Icons.check
                    size: 13
                    color: Theme.bg
                }
                MouseArea {
                    id: boxMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.taskToggled(t.b.line)
                }
            }

            LinkText {
                id: label
                x: box.x + 28
                width: t.width - x
                text: t.b.text || ""
                color: t.b.checked ? Theme.subtext : Theme.fg
                font.strikeout: t.b.checked
            }
        }
    }
}
