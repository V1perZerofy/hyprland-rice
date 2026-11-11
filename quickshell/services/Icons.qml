pragma Singleton

import QtQuick
import Quickshell

// Nerd Font (Material Design) glyphs by name, so modules never embed raw codepoints.
Singleton {
    function g(cp) {
        return String.fromCodePoint(cp);
    }

    readonly property string bell: g(0xF009A)
    readonly property string bellOff: g(0xF009B)
    readonly property string packageIcon: g(0xF03D7)
    readonly property string check: g(0xF012C)
    readonly property string refresh: g(0xF0450)
    readonly property string monitor: g(0xF0379)
    readonly property string calendar: g(0xF00ED)
    readonly property string chevronLeft: g(0xF0141)
    readonly property string chevronRight: g(0xF0142)
    readonly property string close: g(0xF0156)

    readonly property var wifi: [g(0xF091F), g(0xF0922), g(0xF0925), g(0xF0928)]
    readonly property string wifiOff: g(0xF092D)
    readonly property string ethernet: g(0xF0200)
    readonly property string lock: g(0xF033E)

    readonly property string volHigh: g(0xF057E)
    readonly property string volMid: g(0xF0580)
    readonly property string volLow: g(0xF057F)
    readonly property string volMute: g(0xF075F)
    readonly property string mic: g(0xF036C)
    readonly property string micOff: g(0xF036D)
    readonly property string speaker: g(0xF04C3)
    readonly property string headphones: g(0xF02CB)

    readonly property string bt: g(0xF00AF)
    readonly property string btConnected: g(0xF00B1)
    readonly property string btOff: g(0xF00B2)

    // battery_10 .. battery (100)
    readonly property var battery: [g(0xF007A), g(0xF007B), g(0xF007C), g(0xF007D), g(0xF007E), g(0xF007F), g(0xF0080), g(0xF0081), g(0xF0082), g(0xF0079)]
    readonly property string batteryCharging: g(0xF0084)
    readonly property string batteryAlert: g(0xF0083)
    readonly property string plug: g(0xF06A5)

    readonly property string play: g(0xF040A)
    readonly property string pause: g(0xF03E4)
    readonly property string next: g(0xF04AD)
    readonly property string prev: g(0xF04AE)
    readonly property string music: g(0xF075A)
    readonly property string musicNote: g(0xF0387)
    readonly property string album: g(0xF0025)
    readonly property string artist: g(0xF0803)       // account-music
    readonly property string playlist: g(0xF0CB8)     // playlist-music
    readonly property string queueAdd: g(0xF0412)     // playlist-plus
    readonly property string back: g(0xF004D)         // arrow-left

    readonly property string power: g(0xF0425)
    readonly property string reboot: g(0xF0709)
    readonly property string sleep: g(0xF04B2)
    readonly property string logout: g(0xF0343)
    readonly property string lockScreen: g(0xF033E)

    // brightness_5 / 6 / 7
    readonly property var brightness: [g(0xF00DE), g(0xF00DF), g(0xF00E0)]

    readonly property string search: g(0xF0349)
    readonly property string calculator: g(0xF00EC)
    readonly property string apps: g(0xF003B)
    readonly property string image: g(0xF02E9)
    readonly property string shuffle: g(0xF049D)
    readonly property string folder: g(0xF024B)
    readonly property string terminal: g(0xF018D)

    readonly property string notebook: g(0xF05DA)   // book-open-variant
    readonly property string noteIcon: g(0xF0219)   // file-document
    readonly property string pencil: g(0xF03EB)
    readonly property string pin: g(0xF0403)
    readonly property string obsidian: g(0xF03CC)   // open-in-new

    readonly property string coffee: g(0xF0176)
    readonly property string cpu: g(0xF0EE0)        // cpu-64-bit
    readonly property string memory: g(0xF035B)
    readonly property string disk: g(0xF02CA)       // harddisk
    readonly property string thermometer: g(0xF050F)
    readonly property string robot: g(0xF06A9)
    readonly property string trash: g(0xF0A7A)      // trash-can-outline
    readonly property string send: g(0xF048A)
    readonly property string stop: g(0xF04DB)
    readonly property string dashboard: g(0xF056E)  // view-dashboard

    readonly property string lan: g(0xF0318)
    readonly property string linux: g(0xF033D)
    readonly property string apple: g(0xF0035)
    readonly property string windows: g(0xF05B3)    // microsoft-windows
    readonly property string phone: g(0xF011C)      // cellphone
    readonly property string download: g(0xF01DA)

    readonly property string leaf: g(0xF032A)
    readonly property string balance: g(0xF05D1)
    readonly property string rocket: g(0xF0463)

    readonly property string keyboard: g(0xF030C)
    readonly property string mouse: g(0xF037D)
}
