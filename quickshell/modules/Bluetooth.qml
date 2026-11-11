import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.components

// Bluetooth. Left: device card · Right: bluetui.
// In the card: click to connect / disconnect, unpaired devices get paired.
Pill {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter !== null && adapter.enabled
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var connected: devices.filter(d => d.connected)

    function battery(d) {
        return d.batteryAvailable ? Math.round(d.battery * 100) + "%" : "";
    }

    visible: adapter !== null
    active: pop.open
    onClicked: m => {
        if (m.button === Qt.RightButton)
            Quickshell.execDetached(["kitty", "bluetui"]);
        else
            pop.toggle();
    }

    Glyph {
        text: !root.on ? Icons.btOff : root.connected.length ? Icons.btConnected : Icons.bt
        color: root.on ? Theme.primary : Theme.muted
    }
    StyledText {
        Layout.maximumWidth: 120
        visible: root.connected.length > 0
        text: root.connected.length === 1 ? root.connected[0].name : root.connected.length + " devices"
        size: Theme.fontSmall + 1
    }

    Popout {
        id: pop
        owner: root
        name: "bluetooth"
        cardWidth: 340

        onOpenChanged: if (!open && root.adapter && root.adapter.discovering) root.adapter.discovering = false

        Header {
            icon: root.on ? Icons.bt : Icons.btOff
            title: "Bluetooth"
            subtitle: !root.on ? "Off" : root.connected.length ? root.connected.length + " connected" : root.adapter && root.adapter.discovering ? "Scanning…" : "On"
            IconButton {
                visible: root.on
                icon: Icons.refresh
                size: 30
                highlighted: root.adapter && root.adapter.discovering
                onClicked: root.adapter.discovering = !root.adapter.discovering
            }
            Switch {
                checked: root.on
                onToggled: root.adapter.enabled = !root.adapter.enabled
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 300)
            visible: root.on && count > 0
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.devices.filter(d => d.name && d.name !== d.address.replace(/:/g, "-")).sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

            delegate: ListRow {
                required property var modelData
                width: ListView.view.width
                icon: modelData.connected ? Icons.btConnected : Icons.bt
                title: modelData.name
                subtitle: modelData.paired ? (modelData.connected ? "Connected" : "Paired") : "Not paired"
                trailing: root.battery(modelData)
                selected: modelData.connected
                busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                onClicked: {
                    if (modelData.connected)
                        modelData.disconnect();
                    else if (modelData.paired)
                        modelData.connect();
                    else {
                        modelData.trusted = true;
                        modelData.pair();
                    }
                }
            }
        }

        IconButton {
            Layout.fillWidth: true
            icon: Icons.bt
            label: "Open bluetui"
            onClicked: {
                pop.open = false;
                Quickshell.execDetached(["kitty", "bluetui"]);
            }
        }
    }
}
