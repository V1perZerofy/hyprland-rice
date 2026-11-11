pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon (replaces dunst).
//  list    – history, newest first (everything still tracked)
//  popups  – what's currently shown as toasts, newest first
// Toast timeouts follow the old dunstrc: low 4 s, normal 8 s, critical sticky.
Singleton {
    id: root

    property var list: []
    property var popups: []
    property bool dnd: false
    property bool centreOpen: false     // no toasts while the centre is showing
    property int unread: 0
    readonly property int maxPopups: 5
    readonly property int maxHistory: 50
    readonly property date now: clock.date

    function ago(t) {
        const m = Math.floor((now - t) / 60000);
        if (m < 1)
            return "now";
        if (m < 60)
            return m + " min";
        if (m < 1440)
            return Math.floor(m / 60) + " h";
        return Qt.formatDateTime(t, "d MMM");
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function timeoutFor(n) {
        if (n.expireTimeout > 0)
            return n.expireTimeout * 1000;
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        return n.urgency === NotificationUrgency.Low ? 4000 : 8000;
    }

    function iconFor(n) {
        const src = n.image || n.appIcon || "";
        if (!src)
            return "";
        if (src.startsWith("/"))
            return "file://" + src;
        // icon-theme URLs: resolve with a check so a missing icon falls back to the bell
        if (src.startsWith("image://icon/"))
            return Quickshell.iconPath(src.slice(13), true);
        if (src.includes("://"))
            return src;
        return Quickshell.iconPath(src, true);
    }

    function show(e) {
        // critical ones (e.g. battery at 5 %) still show during Do Not Disturb
        const critical = e.n && e.n.urgency === NotificationUrgency.Critical;
        if ((dnd && !critical) || centreOpen)
            return;
        let p = popups.filter(x => x !== e);
        p.unshift(e);
        if (p.length > maxPopups)
            p = p.slice(0, maxPopups);
        popups = p;
        e.shownAt = Date.now();
    }

    function hidePopup(e) {
        popups = popups.filter(x => x !== e);
        if (e.n && e.n.transient)
            e.n.expire();
    }

    function drop(e) {
        popups = popups.filter(x => x !== e);
        list = list.filter(x => x !== e);
        e.destroy();
    }

    // click on a notification: run its default action if it has one
    function activate(e) {
        const a = e.n.actions.find(x => x.identifier === "default");
        if (a) {
            a.invoke();
            if (!e.n.resident)
                e.n.dismiss();
        } else {
            hidePopup(e);
        }
    }

    function dismiss(e) {
        e.n.dismiss();
    }
    function clearHistory() {
        for (const e of list.slice())
            e.n.dismiss();
    }
    function closePopups() {
        popups = [];
    }
    function restoreLast() {
        const e = list.find(x => !popups.includes(x));
        if (e) {
            const was = dnd;
            dnd = false;
            show(e);
            dnd = was;
        }
    }
    function toggleDnd() {
        dnd = !dnd;
        if (dnd)
            popups = [];
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const e = entry.createObject(root, {
                n: n
            });
            let l = root.list.slice();
            l.unshift(e);
            root.list = l;
            for (const old of l.slice(root.maxHistory))
                old.n.dismiss();
            if (!root.centreOpen)
                root.unread++;
            root.show(e);
        }
    }

    Component {
        id: entry
        QtObject {
            id: e
            required property Notification n
            property date time: new Date()
            property real shownAt: Date.now()
            // bumped when the app replaces the notification's content
            property int revision: 0

            readonly property Connections conn: Connections {
                target: e.n
                function onClosed() {
                    root.drop(e);
                }
                function onSummaryChanged() {
                    e.refresh();
                }
                function onBodyChanged() {
                    e.refresh();
                }
            }
            function refresh() {
                time = new Date();
                revision++;
                if (!root.popups.includes(e))
                    root.show(e);
                else
                    shownAt = Date.now();
            }
        }
    }
}
