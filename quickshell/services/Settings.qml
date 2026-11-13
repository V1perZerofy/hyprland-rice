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
    // { name, lat, lon } as ONE value: setting name/lat/lon one by one raced
    // with the saves and kept a stale latitude
    property alias weatherPlace: adapter.weatherPlace
    readonly property string weatherCity: weatherPlace && weatherPlace.name ? weatherPlace.name : ""   // "" = off
    readonly property real weatherLat: weatherPlace && weatherPlace.lat ? weatherPlace.lat : 0
    readonly property real weatherLon: weatherPlace && weatherPlace.lon ? weatherPlace.lon : 0
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

    Timer {
        id: saveLater
        interval: 300
        onTriggered: file.writeAdapter()
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/quickshell-settings.json"
        blockLoading: true      // settings before the first frame: no bar jumping
        printErrors: false
        // no watchChanges (our own writes would be read back mid-update), and
        // several changes in a row (Reset, picking a place) are saved once
        blockWrites: true
        atomicWrites: true
        onAdapterUpdated: saveLater.restart()
        onLoadFailed: writeAdapter()        // first run: create it with defaults

        JsonAdapter {
            id: adapter
            property string barPosition: "top"
            property real barOpacity: 0.30
            property real pillOpacity: 0.70
            property real scale: 1.0
            property bool clock24h: true
            property var hidden: []
            property var weatherPlace: ({})
            property bool weatherFahrenheit: false
        }
    }
}
