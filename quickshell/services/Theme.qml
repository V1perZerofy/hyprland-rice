pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Live pywal palette + shared sizes. Re-reads ~/.cache/wal/colors.json whenever
// pywal rewrites it, so the whole shell recolours with your wallpaper.
Singleton {
    id: root

    // ── palette (fallbacks until colors.json loads) ──────────────────────────
    property color bg: "#121f26"
    property color fg: "#c3c7c8"
    property color primary: "#5f9fc2"   // wal color1
    property color secondary: "#3558ad" // wal color2
    property color tertiary: "#9772b2"  // wal color5
    property color muted: "#4d575c"     // wal color8
    property string wallpaper: ""
    readonly property color error: "#e8677a"
    readonly property color warning: "#e5b567"
    readonly property color success: "#8ccf7e"

    // ── surfaces ─────────────────────────────────────────────────────────────
    readonly property color barBg: alpha(bg, Settings.barOpacity)
    readonly property color pillBg: alpha(bg, Settings.pillOpacity)
    readonly property color pillHover: alpha(mix(bg, fg, 0.12), 0.80)
    // cards (popouts, overlays, OSD, toasts) are opaque: at 94 % the windows
    // behind still showed through and small text got hard to read
    readonly property color cardBg: mix(bg, "#000000", 0.25)
    readonly property color panelBg: mix(bg, "#000000", 0.25)   // reading surfaces: fully opaque
    readonly property color surface: alpha(fg, 0.06)
    readonly property color surfaceHi: alpha(fg, 0.12)
    readonly property color border: alpha(fg, 0.08)
    readonly property color subtext: alpha(fg, 0.60)

    // ── metrics ──────────────────────────────────────────────────────────────
    readonly property string font: "JetBrainsMono Nerd Font Propo"
    // sizes follow the "Size" setting (Settings.scale)
    readonly property real s: Settings.scale
    readonly property int fontSize: Math.round(14 * s)
    readonly property int fontSmall: Math.round(12 * s)
    readonly property int iconSize: Math.round(16 * s)
    readonly property int barHeight: Math.round(38 * s)
    readonly property int pillHeight: Math.round(28 * s)
    readonly property int radius: 10
    readonly property int cardRadius: 18
    readonly property int anim: 200

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    function mix(a, b, t) {
        const x = Qt.color(a), y = Qt.color(b);
        return Qt.rgba(x.r * (1 - t) + y.r * t, x.g * (1 - t) + y.g * t, x.b * (1 - t) + y.b * t, 1);
    }

    function parse() {
        try {
            const d = JSON.parse(file.text());
            bg = d.special.background;
            fg = d.special.foreground;
            primary = d.colors.color1;
            secondary = d.colors.color2;
            tertiary = d.colors.color5;
            muted = d.colors.color8;
            wallpaper = d.wallpaper || "";
        } catch (e) {
            console.warn("Theme: could not parse colors.json:", e);
        }
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        blockLoading: true
        watchChanges: true
        onLoaded: root.parse()
        onFileChanged: reload()
    }

    Component.onCompleted: parse()
}
