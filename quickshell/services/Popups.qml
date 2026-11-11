pragma Singleton

import QtQuick
import Quickshell

// Keeps only one popout open at a time, across all monitors.
Singleton {
    property var current: null
    property bool barVisible: true

    // `qs ipc call bar popout <name>` → the matching Popout on the focused monitor toggles
    signal requested(string name)
    // `qs ipc call bar peek <workspace id>` → toggle that workspace's preview
    signal peek(int id)
}
