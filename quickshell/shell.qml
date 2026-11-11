//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Entry point: one bar per monitor.
//   qs ipc call bar toggle    show / hide the bar
//   qs ipc call bar updates   re-check for package updates
//   qs ipc call bar peek N    toggle the live preview of workspace N
//   qs ipc call bar popout X  toggle a card: calendar media updates network audio bluetooth power notifications
//   qs ipc call notifs dnd | restore | closeAll | clear | centre
//   qs ipc call osd volume | mic | brightness <0-100>
//   qs ipc call launcher toggle
//   qs ipc call wallpaper toggle
//   qs ipc call notes toggle | notes open <path>
//   qs ipc call sidebar toggle | sidebar assistant
ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    NotificationToasts {}
    Osd {}
    Launcher {}
    Keybinds {}
    Overview {}
    WallpaperPicker {}
    Notes {}
    Sidebar {}

    IpcHandler {
        target: "bar"
        function toggle(): void {
            Popups.barVisible = !Popups.barVisible;
        }
        function updates(): void {
            Updates.refresh();
        }
        function popout(name: string): void {
            Popups.requested(name);
        }
        function peek(id: int): void {
            Popups.peek(id);
        }
    }

    // music search in the media card (SUPER+U); starts Cider if no player is running
    IpcHandler {
        target: "music"
        // media keys: play/pause, or shuffle Heavy Rotation if nothing is loaded
        function play(): void {
            Cider.playPause(Players.active);
        }
        // Cider not running: start it, open the search once its API is up
        function search(): void {
            if (!Cider.available && Players.list.length === 0) {
                Quickshell.execDetached(["cider"]);
                searchWait.tries = 0;
                searchWait.start();
            } else
                Popups.requested("media-search");
        }
    }

    // after SUPER+U started Cider: poll (up to ~45 s) until its API answers,
    // then open the search; the short extra wait lets the music pill appear
    // and settle so the card lines up under it
    Timer {
        id: searchWait
        property int tries: 0
        property bool ready: false
        interval: 500
        repeat: true
        onRunningChanged: if (running) ready = false
        onTriggered: {
            if (++tries > 90) {
                stop();
                return;
            }
            if (ready) {
                stop();
                Popups.requested("media-search");
                return;
            }
            Cider.ping();
            if (Cider.available) {
                ready = true;
                interval = 800;
            }
        }
        onReadyChanged: if (!ready) interval = 500
    }

    IpcHandler {
        target: "notifs"
        function dnd(): void {
            Notifs.toggleDnd();
        }
        function restore(): void {
            Notifs.restoreLast();
        }
        function closeAll(): void {
            Notifs.closePopups();
        }
        function clear(): void {
            Notifs.clearHistory();
        }
        function centre(): void {
            Popups.requested("notifications");
        }
    }
}
