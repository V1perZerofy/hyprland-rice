import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import qs.services
import qs.components

// Now playing. Hidden with no player, except while Cider runs: Electron apps
// only register an MPRIS player once something plays, so the pill also shows
// whenever Cider's API answers ("Cider", with search + play ready).
// Left: media card · Middle: play/pause · Scroll: next / previous.
// Play with nothing loaded in Cider shuffles your recently played songs.
// With Cider running, the card has an Apple Music search (services/Cider.qml):
// type to search, Enter plays the first song, click a song to play it,
// albums / playlists / artists open their tracks; hover a row for
// "play next" / "add to queue". Esc clears the search, then closes.
Pill {
    id: root
    readonly property var player: Players.active

    visible: player !== null || Cider.available
    active: pop.open
    progress: player && player.lengthSupported && player.length > 0 ? player.position / player.length : -1

    onClicked: m => {
        if (m.button === Qt.MiddleButton)
            Cider.playPause(player);
        else
            pop.toggle();
    }
    onWheel: w => {
        if (!player)
            return;
        if (w.angleDelta.y > 0)
            player.next();
        else
            player.previous();
    }

    // cava runs only while something plays (and the pill is on screen)
    readonly property bool playing: player !== null && player.isPlaying
    onPlayingChanged: Cava.active = playing
    Component.onCompleted: Cava.active = playing
    Component.onDestruction: Cava.active = false

    // paused: icon · playing: live visualiser
    Glyph {
        visible: !root.playing
        text: Icons.play
    }
    Row {
        visible: root.playing
        spacing: 2
        Layout.preferredHeight: 18
        Repeater {
            model: Cava.bars.length
            Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: Math.max(3, 18 * (Cava.bars[index] || 0))
                radius: 1.5
                color: Theme.primary
                Behavior on height {
                    NumberAnimation {
                        duration: 60
                    }
                }
            }
        }
    }
    StyledText {
        Layout.maximumWidth: 260
        text: {
            if (!root.player)
                return "Cider";
            if (!root.player.trackTitle && root.player.playbackState === MprisPlaybackState.Stopped)
                return root.player.identity || "Nothing playing";
            const t = root.player.trackTitle || "Unknown";
            const a = root.player.trackArtist || "";
            return a ? t + " — " + a : t;
        }
        size: Theme.fontSmall + 1
    }

    component ResultRow: Rectangle {
        id: row
        required property var modelData
        readonly property bool openable: modelData.kind !== "songs"
        Layout.fillWidth: true
        implicitHeight: 50
        radius: 10
        color: hover.hovered ? Theme.surfaceHi : "transparent"

        HoverHandler {
            id: hover
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.openable ? Cider.open(row.modelData) : Cider.play(row.modelData)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 10

            ClippingRectangle {
                implicitWidth: 38
                implicitHeight: 38
                radius: row.modelData.kind === "artists" ? 19 : 7
                color: Theme.surface
                Glyph {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: ({
                            songs: Icons.musicNote,
                            albums: Icons.album,
                            playlists: Icons.playlist,
                            artists: Icons.artist
                        })[row.modelData.kind] || Icons.music
                    color: Theme.subtext
                }
                Image {
                    id: cover
                    anchors.fill: parent
                    source: row.modelData.art
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 76
                    sourceSize.height: 76
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: row.modelData.title
                    size: Theme.fontSmall + 1
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.modelData.subtitle
                    size: Theme.fontSmall - 1
                    color: Theme.subtext
                }
            }
            IconButton {
                visible: hover.hovered && row.modelData.kind !== "artists"
                icon: Icons.next
                size: 28
                iconSize: 13
                onClicked: Cider.playNext(row.modelData)
            }
            IconButton {
                visible: hover.hovered && row.modelData.kind !== "artists"
                icon: Icons.queueAdd
                size: 28
                iconSize: 13
                onClicked: Cider.playLater(row.modelData)
            }
            Glyph {
                visible: row.openable && !hover.hovered
                text: "›"
                color: Theme.subtext
            }
        }
    }

    Popout {
        id: pop
        owner: root
        name: "media"
        cardWidth: 400
        readonly property var p: root.player
        readonly property bool searching: Cider.query !== "" || Cider.detail !== null

        // `qs ipc call music search` (SUPER+U): open on this monitor, focus the field
        Connections {
            target: Popups
            function onRequested(n) {
                if (n !== "media-search" || !Hyprland.focusedMonitor || !pop.screen || pop.screen.name !== Hyprland.focusedMonitor.name)
                    return;
                pop.open = true;
                Qt.callLater(() => field.forceActiveFocus());
            }
        }

        onOpenChanged: {
            if (open) {
                Cider.ping();
                Qt.callLater(() => {
                    if (Cider.available)
                        field.forceActiveFocus();
                });
            } else {
                // reopen on "now playing"
                field.text = "";
                Cider.search("");
            }
        }

        // player switcher, only with more than one
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: Players.list.length > 1
            Repeater {
                model: Players.list
                IconButton {
                    required property var modelData
                    label: modelData.identity || "Player"
                    size: 26
                    highlighted: modelData === pop.p
                    onClicked: Players.pinned = modelData
                }
            }
        }


        // ── Apple Music search (Cider) ──
        Rectangle {
            Layout.fillWidth: true
            visible: Cider.available
            implicitHeight: 40
            radius: 12
            color: Theme.surface
            border.color: field.activeFocus ? Theme.alpha(Theme.primary, 0.5) : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 4
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
                    onTextEdited: Cider.search(text)
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !field.text
                        text: Cider.library ? "Search your library…" : "Search Apple Music…"
                        size: Theme.fontSmall + 2
                        color: Theme.alpha(Theme.fg, 0.35)
                    }
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Escape) {
                            if (Cider.detail)
                                Cider.detail = null;
                            else if (text) {
                                text = "";
                                Cider.search("");
                            } else
                                pop.open = false;
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            const list = Cider.detail ? Cider.detail.items : (Cider.results.find(r => r.kind === "songs") || Cider.results[0] || {}).items;
                            if (list && list.length) {
                                if (list[0].kind === "songs" || list[0].kind === "albums" || list[0].kind === "playlists")
                                    Cider.play(list[0]);
                                else
                                    Cider.open(list[0]);
                            }
                            e.accepted = true;
                        }
                    }
                }
                StyledText {
                    visible: Cider.searching
                    text: "…"
                    color: Theme.subtext
                }
                IconButton {
                    visible: field.text !== ""
                    icon: Icons.close
                    size: 28
                    iconSize: 13
                    onClicked: {
                        field.text = "";
                        Cider.search("");
                        field.forceActiveFocus();
                    }
                }
                // catalog ⇄ library
                IconButton {
                    icon: Cider.library ? Icons.album : Icons.apple
                    label: Cider.library ? "Library" : "Catalog"
                    size: 32
                    iconSize: 14
                    onClicked: {
                        Cider.library = !Cider.library;
                        field.forceActiveFocus();
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: pop.searching && Cider.error !== ""
            text: "⚠ " + Cider.error
            size: Theme.fontSmall
            color: Theme.error
            wrapMode: Text.Wrap
        }

        // results / drill-in
        Flickable {
            id: resultsFlick
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(resultsCol.implicitHeight, 460)
            visible: pop.searching
            clip: true
            contentWidth: width
            contentHeight: resultsCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: resultsCol
                width: resultsFlick.width
                spacing: 2

                // drill-in header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    visible: Cider.detail !== null
                    spacing: 8
                    IconButton {
                        icon: Icons.back
                        size: 30
                        iconSize: 14
                        onClicked: Cider.detail = null
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Cider.detail ? Cider.detail.title : ""
                        bold: true
                    }
                    IconButton {
                        visible: Cider.detail !== null && Cider.detail.parent.kind !== "artists"
                        icon: Icons.play
                        label: "Play"
                        size: 30
                        iconSize: 14
                        highlighted: true
                        onClicked: Cider.play(Cider.detail.parent)
                    }
                    IconButton {
                        visible: Cider.detail !== null && Cider.detail.parent.kind !== "artists"
                        icon: Icons.shuffle
                        size: 30
                        iconSize: 14
                        onClicked: Cider.play(Cider.detail.parent, true)
                    }
                }

                Repeater {
                    model: Cider.detail ? [{
                            kind: "",
                            items: Cider.detail.items
                        }] : Cider.results
                    ColumnLayout {
                        id: section
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText {
                            visible: section.modelData.kind !== ""
                            Layout.topMargin: 6
                            Layout.leftMargin: 4
                            text: ({
                                    songs: "Songs",
                                    albums: "Albums",
                                    playlists: "Playlists",
                                    artists: "Artists"
                                })[section.modelData.kind] || ""
                            size: Theme.fontSmall - 1
                            bold: true
                            color: Theme.subtext
                        }
                        Repeater {
                            model: section.modelData.items
                            ResultRow {}
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    visible: !Cider.searching && !Cider.detail && Cider.results.length === 0 && Cider.query.trim() !== "" && Cider.error === ""
                    horizontalAlignment: Text.AlignHCenter
                    text: "Nothing found"
                    color: Theme.subtext
                }
            }
        }


        // ── now playing (hidden while searching) ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            visible: !pop.searching

            ClippingRectangle {
                implicitWidth: 96
                implicitHeight: 96
                radius: 14
                color: Theme.surface
                Glyph {
                    anchors.centerIn: parent
                    text: Icons.music
                    size: 36
                    visible: art.status !== Image.Ready
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: pop.p ? pop.p.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 192
                    sourceSize.height: 192
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: pop.p ? pop.p.trackTitle || (pop.p.playbackState === MprisPlaybackState.Stopped ? "Nothing playing" : "Unknown title") : ""
                    bold: true
                    size: Theme.fontSize + 1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: pop.p ? pop.p.trackArtist : ""
                    visible: text !== ""
                    color: Theme.primary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: pop.p ? pop.p.trackAlbum : ""
                    visible: text !== ""
                    size: Theme.fontSmall
                    color: Theme.subtext
                    font.italic: true
                }
                StyledText {
                    Layout.fillWidth: true
                    text: pop.p ? pop.p.identity : ""
                    size: Theme.fontSmall - 1
                    color: Theme.alpha(Theme.fg, 0.4)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: !pop.searching && pop.p !== null && pop.p.lengthSupported && pop.p.length > 0

            Slider {
                Layout.fillWidth: true
                enabled: pop.p !== null && pop.p.canSeek
                value: pop.p && pop.p.length > 0 ? pop.p.position / pop.p.length : 0
                onMoved: v => {
                    if (pop.p && pop.p.canSeek)
                        pop.p.position = v * pop.p.length;
                }
            }
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: pop.p ? Players.fmt(pop.p.position) : ""
                    size: Theme.fontSmall - 1
                    color: Theme.subtext
                }
                StyledText {
                    text: pop.p ? Players.fmt(pop.p.length) : ""
                    size: Theme.fontSmall - 1
                    color: Theme.subtext
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: !pop.searching
            spacing: 16
            IconButton {
                icon: Icons.prev
                size: 40
                iconSize: 20
                onClicked: if (pop.p) pop.p.previous()
            }
            IconButton {
                icon: pop.p && pop.p.isPlaying ? Icons.pause : Icons.play
                size: 52
                iconSize: 24
                highlighted: true
                onClicked: Cider.playPause(pop.p)
            }
            IconButton {
                icon: Icons.next
                size: 40
                iconSize: 20
                onClicked: if (pop.p) pop.p.next()
            }
        }
    }
}
