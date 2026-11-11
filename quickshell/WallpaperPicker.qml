import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.components

// Wallpaper picker (replaces rofi/wallSelect.sh). Grid of ~/Pictures/wallpaper,
// type to filter, arrows to move, Enter to apply via ~/.config/scripts/setwall.sh
// (awww transition + wal + reloads, as before). The current wallpaper is ringed.
// Thumbnails are cached in ~/.cache/quickshell/wallthumbs.
//   qs ipc call wallpaper toggle
Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: home + "/Pictures/wallpaper"
    readonly property string thumbs: home + "/.cache/quickshell/wallthumbs"
    readonly property var exts: ["jpg", "jpeg", "png", "webp", "gif"]
    property int thumbGen: 0

    function apply(path) {
        if (!path)
            return;
        Quickshell.execDetached([home + "/.config/scripts/setwall.sh", path]);
        win.open = false;
    }

    // build any missing thumbnails (first frame for gifs)
    Process {
        id: thumbJob
        command: ["bash", "-c", `
            mkdir -p "$2"
            shopt -s nullglob nocaseglob
            for f in "$1"/*.{jpg,jpeg,png,webp,gif}; do
                o="$2/$(basename "$f").jpg"
                [[ -f "$o" && "$o" -nt "$f" ]] && continue
                magick "$f[0]" -thumbnail 480x270^ -gravity center -extent 480x270 -quality 85 "$o" 2>/dev/null
            done`, "thumbs", root.dir, root.thumbs]
        onExited: root.thumbGen++
    }
    Component.onCompleted: {
        thumbJob.running = true;
        palJob.running = true;
    }

    // pywal palettes, computed without applying (scripts/wal-palettes.py)
    readonly property string palettePath: home + "/.cache/quickshell/wallpalettes.json"
    property var palettes: ({})
    Process {
        id: palJob
        command: ["python3", root.home + "/.config/quickshell/scripts/wal-palettes.py", root.dir, root.palettePath]
    }
    FileView {
        id: palFile
        path: root.palettePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.palettes = JSON.parse(text());
            } catch (e) {}
        }
    }

    FolderListModel {
        id: folder
        folder: "file://" + root.dir
        showDirs: false
        caseSensitive: false
        sortField: FolderListModel.Name
        // filtering by search text = glob on the file name
        nameFilters: root.exts.map(e => "*" + search.text.replace(/[*?\[\]]/g, "") + "*." + e)
        onCountChanged: {
            if (!thumbJob.running)
                thumbJob.running = true;
            if (!palJob.running)
                palJob.running = true;
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            win.toggle();
        }
    }

    Overlay {
        id: win
        cardWidth: Math.min(1080, width - 80)
        cardHeight: Math.min(680, height - 120)
        onOpened: {
            search.text = "";
            // start on the current wallpaper
            for (let i = 0; i < folder.count; i++)
                if (folder.get(i, "filePath") === Theme.wallpaper)
                    grid.currentIndex = i;
            grid.positionViewAtIndex(grid.currentIndex, GridView.Center);
            search.forceActiveFocus();
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Header {
                    Layout.fillWidth: false
                    icon: Icons.image
                    title: "Wallpapers"
                    subtitle: folder.count + " in ~/Pictures/wallpaper"
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    implicitWidth: 300
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
                                text: "Filter…"
                                color: Theme.alpha(Theme.fg, 0.35)
                            }
                            onTextChanged: grid.currentIndex = 0
                            Keys.onPressed: e => {
                                if (e.key === Qt.Key_Escape)
                                    win.open = false;
                                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                                    root.apply(grid.currentItem ? grid.currentItem.path : "");
                                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab)
                                    grid.moveCurrentIndexRight();
                                else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab)
                                    grid.moveCurrentIndexLeft();
                                else if (e.key === Qt.Key_Down)
                                    grid.moveCurrentIndexDown();
                                else if (e.key === Qt.Key_Up)
                                    grid.moveCurrentIndexUp();
                                else
                                    return;
                                e.accepted = true;
                            }
                        }
                    }
                }

                IconButton {
                    icon: Icons.shuffle
                    label: "Random"
                    size: 40
                    onClicked: if (folder.count) root.apply(folder.get(Math.floor(Math.random() * folder.count), "filePath"))
                }
                IconButton {
                    icon: Icons.folder
                    size: 40
                    onClicked: {
                        win.open = false;
                        Quickshell.execDetached(["xdg-open", root.dir]);
                    }
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: folder
                readonly property int cols: 4
                cellWidth: width / cols
                cellHeight: cellWidth * 9 / 16 + 34
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: true
                keyNavigationWraps: true

                delegate: Item {
                    id: tile
                    required property string filePath
                    required property string fileName
                    required property int index
                    readonly property string path: filePath
                    readonly property bool current: GridView.isCurrentItem
                    readonly property bool active: filePath === Theme.wallpaper
                    width: grid.cellWidth
                    height: grid.cellHeight

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: width * 9 / 16
                            radius: 14
                            color: tile.current ? Theme.primary : tile.active ? Theme.alpha(Theme.primary, 0.5) : "transparent"
                            scale: tile.current ? 1 : hover.containsMouse ? 0.98 : 0.95
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 160
                                }
                            }

                            ClippingRectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: 11
                                color: Theme.surface

                                Image {
                                    id: img
                                    anchors.fill: parent
                                    property bool useOriginal: false
                                    // thumbGen in the binding re-checks once thumbnails exist
                                    source: root.thumbGen >= 0 && !useOriginal ? "file://" + root.thumbs + "/" + tile.fileName + ".jpg" : "file://" + tile.filePath
                                    sourceSize.width: 480
                                    sourceSize.height: 270
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                        }
                                    }
                                    onStatusChanged: if (status === Image.Error && !useOriginal) useOriginal = true
                                }

                                // palette strip (color0..7)
                                Row {
                                    readonly property var pal: root.palettes[tile.fileName]
                                    visible: pal !== undefined && pal.colors !== undefined
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: tile.current ? 10 : 6
                                    Behavior on height {
                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }
                                    Repeater {
                                        model: 8
                                        Rectangle {
                                            required property int index
                                            width: parent.width / 8
                                            height: parent.height
                                            color: parent.pal && parent.pal.colors ? parent.pal.colors[index] : "transparent"
                                        }
                                    }
                                }

                                // "current" badge
                                Rectangle {
                                    visible: tile.active
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 8
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: 13
                                    color: Theme.primary
                                    Glyph {
                                        anchors.centerIn: parent
                                        text: Icons.check
                                        size: 14
                                        color: Theme.bg
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.fileName.replace(/\.[^.]+$/, "")
                            size: Theme.fontSmall - 1
                            color: tile.current ? Theme.fg : Theme.subtext
                            elide: Text.ElideMiddle
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: grid.currentIndex = tile.index
                        onClicked: {
                            grid.currentIndex = tile.index;
                            root.apply(tile.filePath);
                        }
                    }
                }
            }

            // ── palette preview of the selected wallpaper ──
            Rectangle {
                id: preview
                readonly property string file: grid.currentItem ? grid.currentItem.fileName : ""
                readonly property var pal: root.palettes[file]
                readonly property bool ok: pal !== undefined && pal.colors !== undefined
                readonly property bool isCurrent: grid.currentItem !== null && grid.currentItem.active

                Layout.fillWidth: true
                implicitHeight: 74
                radius: 16
                color: Theme.surface

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 16

                    // mock of the bar in the new colours
                    Rectangle {
                        visible: preview.ok
                        implicitWidth: 300
                        Layout.fillHeight: true
                        radius: 10
                        color: preview.ok ? preview.pal.bg : "transparent"
                        border.color: preview.ok ? Theme.alpha(Qt.color(preview.pal.fg), 0.15) : "transparent"

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Repeater {
                                model: ["1", "2", "3"]
                                Rectangle {
                                    required property string modelData
                                    required property int index
                                    width: index === 1 ? 46 : 24
                                    height: 22
                                    radius: 11
                                    color: !preview.ok ? "transparent" : index === 1 ? preview.pal.colors[1] : Theme.alpha(Qt.color(preview.pal.fg), 0.12)
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: modelData
                                        size: Theme.fontSmall
                                        bold: index === 1
                                        color: !preview.ok ? "transparent" : index === 1 ? preview.pal.bg : preview.pal.fg
                                    }
                                }
                            }
                            Rectangle {
                                width: 92
                                height: 22
                                radius: 8
                                color: preview.ok ? Theme.alpha(Qt.color(preview.pal.fg), 0.08) : "transparent"
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Glyph {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Icons.wifi[3]
                                        size: 13
                                        color: preview.ok ? preview.pal.colors[1] : "transparent"
                                    }
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "13:37"
                                        size: Theme.fontSmall
                                        color: preview.ok ? preview.pal.fg : "transparent"
                                    }
                                }
                            }
                        }
                    }

                    // all 16 colours
                    GridLayout {
                        visible: preview.ok
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 8
                        rowSpacing: 4
                        columnSpacing: 4
                        Repeater {
                            model: 16
                            Rectangle {
                                required property int index
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 5
                                color: preview.ok ? preview.pal.colors[index] : "transparent"
                                border.color: Theme.border
                                border.width: 1
                            }
                        }
                    }

                    StyledText {
                        visible: !preview.ok
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: preview.pal && preview.pal.error ? "No palette: " + preview.pal.error : palJob.running ? "Computing palette…" : "No palette yet"
                        color: Theme.subtext
                    }

                    IconButton {
                        icon: preview.isCurrent ? Icons.check : Icons.image
                        label: preview.isCurrent ? "Current" : "Apply"
                        size: 40
                        highlighted: !preview.isCurrent
                        onClicked: root.apply(grid.currentItem ? grid.currentItem.path : "")
                    }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "↵ apply   ←↑↓→ move   type to filter   esc close"
                size: Theme.fontSmall - 1
                color: Theme.alpha(Theme.fg, 0.35)
            }
        }
    }
}
