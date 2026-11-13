pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User preferences, edited in the settings overlay (SUPER+comma).
// Saved to ~/.local/state/quickshell-settings.json, outside ~/.config, so
// personal bits like the weather city never land in the dotfiles repo.
// Every property change is written back automatically (JsonAdapter).
Singleton {
    id: root

    // bar modules in bar order: [id, label]
    readonly property var modules: [
        ["launcher", "Launcher"], ["notes", "Notes"], ["clock", "Clock"], ["window", "Window title"],
        ["workspaces", "Workspaces"], ["media", "Media"], ["weather", "Weather"],
        ["tray", "Tray"], ["notifications", "Notifications"], ["updates", "Updates"], ["monitors", "Monitors"],
        ["network", "Network"], ["audio", "Audio"], ["bluetooth", "Bluetooth"], ["battery", "Battery"]
    ]

    property alias barPosition: adapter.barPosition       // "top" | "bottom"
    property alias barOpacity: adapter.barOpacity         // 0..1
    property alias pillOpacity: adapter.pillOpacity       // 0..1
    property alias scale: adapter.scale                   // 0.85..1.3
    property alias clock24h: adapter.clock24h
    property alias hidden: adapter.hidden                 // module ids
    property alias weatherCity: adapter.weatherCity       // display name, "" = off
    property alias weatherLat: adapter.weatherLat
    property alias weatherLon: adapter.weatherLon
    property alias weatherFahrenheit: adapter.weatherFahrenheit

    readonly property bool barBottom: barPosition === "bottom"

    function shows(id) {
        return !hidden.includes(id);
    }
    function setShown(id, on) {
        const h = hidden.filter(x => x !== id);
        if (!on)
            h.push(id);
        hidden = h;
    }
    function reset() {
        barPosition = "top";
        barOpacity = 0.30;
        pillOpacity = 0.70;
        scale = 1.0;
        clock24h = true;
        hidden = [];
        weatherFahrenheit = false;
        // the weather city is left alone on purpose
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/quickshell-settings.json"
        blockLoading: true      // settings before the first frame: no bar jumping
        printErrors: false
        // no watchChanges: our own writes would be re-read mid-update (setting
        // city, lat, lon one after another lost the lat). Edit via the overlay.
        onAdapterUpdated: writeAdapter()
        onLoadFailed: writeAdapter()        // first run: create it with defaults

        JsonAdapter {
            id: adapter
            property string barPosition: "top"
            property real barOpacity: 0.30
            property real pillOpacity: 0.70
            property real scale: 1.0
            property bool clock24h: true
            property var hidden: []
            property string weatherCity: ""
            property real weatherLat: 0
            property real weatherLon: 0
            property bool weatherFahrenheit: false
        }
    }
}
