pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The "current" MPRIS player: a playing one if any, otherwise the one picked
// last in the media card, otherwise the first.
Singleton {
    id: root

    property var pinned: null
    readonly property var list: Mpris.players.values
    readonly property var active: {
        const ps = list;
        if (ps.length === 0)
            return null;
        const playing = ps.find(p => p.isPlaying);
        if (playing)
            return playing;
        if (pinned && ps.includes(pinned))
            return pinned;
        return ps[0];
    }

    function fmt(secs) {
        if (!isFinite(secs) || secs < 0)
            return "0:00";
        const s = Math.floor(secs % 60), m = Math.floor(secs / 60) % 60, h = Math.floor(secs / 3600);
        const ss = s < 10 ? "0" + s : "" + s;
        if (h > 0)
            return h + ":" + (m < 10 ? "0" + m : m) + ":" + ss;
        return m + ":" + ss;
    }

    // MPRIS position isn't pushed; poke it so bindings update while playing.
    Timer {
        interval: 1000
        repeat: true
        running: root.active !== null && root.active.isPlaying
        onTriggered: root.active.positionChanged()
    }
}
