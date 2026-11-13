import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.services
import qs.components

// Battery + power centre (replaces the wlogout click):
// charge details, power profile, lock / suspend / logout / reboot / shutdown.
// Logout, reboot and shutdown need a second click to confirm.
// Low battery: notification at 15 % (normal) and 5 % (critical, shows even in
// Do Not Disturb); the pill pulses red below 15 %, faster below 5 %.
// Each warning fires once per discharge; plugging in resets them.
Pill {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property real pct: dev && dev.ready ? dev.percentage : 0   // 0..1
    readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge)
    readonly property color levelColor: charging ? Theme.success : pct <= 0.15 ? Theme.error : pct <= 0.30 ? Theme.warning : Theme.primary

    function icon() {
        if (charging)
            return Icons.batteryCharging;
        if (pct <= 0.05)
            return Icons.batteryAlert;
        return Icons.battery[Math.max(0, Math.min(9, Math.ceil(pct * 10) - 1))];
    }
    function duration(secs) {
        if (!secs || secs <= 0)
            return "";
        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }

    visible: (dev !== null && dev.isPresent) && Settings.shows("battery")

    // pct reads 0 for a moment while UPower is still loading: never trust 0
    readonly property bool known: dev !== null && dev.ready && dev.isPresent && pct > 0
    readonly property int level: Math.round(pct * 100)
    property int warned: 101        // lowest threshold already warned about

    alert: !known || charging ? 0 : level <= 5 ? 2 : level <= 15 ? 1 : 0

    function checkLow() {
        if (!known)
            return;
        if (charging) {
            warned = 101;
            return;
        }
        const left = dev.timeToEmpty > 0 ? " About " + duration(dev.timeToEmpty) + " left." : "";
        if (level <= 5 && warned > 5) {
            warned = 5;
            Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", "critical", "-i", "battery-caution", "Battery at " + level + " %", "Plug in now, the laptop will shut down soon." + left]);
        } else if (level <= 15 && warned > 15) {
            warned = 15;
            Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", "normal", "-i", "battery-low", "Battery low: " + level + " %", "Time to find a charger." + left]);
        }
    }
    onLevelChanged: checkLow()
    onChargingChanged: checkLow()
    onKnownChanged: checkLow()
    // also when the shell starts on a low battery (no change signal then);
    // wait a moment so UPower has real numbers
    Timer {
        running: true
        interval: 4000
        onTriggered: root.checkLow()
    }
    active: pop.open
    onClicked: pop.toggle()

    Glyph {
        text: root.icon()
        color: root.levelColor
    }
    StyledText {
        text: Math.round(root.pct * 100) + "%"
        size: Theme.fontSmall + 1
        color: root.pct <= 0.15 && !root.charging ? Theme.error : Theme.fg
    }

    Popout {
        id: pop
        owner: root
        name: "power"
        cardWidth: 340
        property string armed: ""   // action awaiting confirmation
        onOpenChanged: armed = ""

        function act(name, cmd, confirm) {
            if (confirm && armed !== name) {
                armed = name;
                disarm.restart();
                return;
            }
            open = false;
            Quickshell.execDetached(cmd);
        }

        Timer {
            id: disarm
            interval: 3000
            onTriggered: pop.armed = ""
        }

        Header {
            icon: root.icon()
            title: Math.round(root.pct * 100) + "%  ·  " + (root.dev ? UPowerDeviceState.toString(root.dev.state).replace(/([a-z])([A-Z])/g, "$1 $2") : "")
            subtitle: {
                if (!root.dev)
                    return "";
                if (root.dev.state === UPowerDeviceState.Charging && root.dev.timeToFull > 0)
                    return root.duration(root.dev.timeToFull) + " until full";
                if (root.dev.state === UPowerDeviceState.Discharging && root.dev.timeToEmpty > 0)
                    return root.duration(root.dev.timeToEmpty) + " remaining";
                return UPower.onBattery ? "On battery" : "Plugged in";
            }
        }

        // charge bar
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 8
            radius: 4
            color: Theme.surfaceHi
            Rectangle {
                width: parent.width * root.pct
                height: parent.height
                radius: 4
                color: root.levelColor
                Behavior on width {
                    NumberAnimation {
                        duration: 400
                    }
                }
            }
        }

        StyledText {
            text: "Power profile"
            size: Theme.fontSmall
            bold: true
            color: Theme.subtext
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { p: PowerProfile.PowerSaver, icon: Icons.leaf, label: "Saver" },
                    { p: PowerProfile.Balanced, icon: Icons.balance, label: "Balanced" },
                    { p: PowerProfile.Performance, icon: Icons.rocket, label: "Perf" }
                ]
                IconButton {
                    required property var modelData
                    Layout.fillWidth: true
                    visible: modelData.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                    icon: modelData.icon
                    label: modelData.label
                    highlighted: PowerProfiles.profile === modelData.p
                    onClicked: PowerProfiles.profile = modelData.p
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Repeater {
                model: [
                    { name: "lock", icon: Icons.lockScreen, cmd: ["hyprlock"], confirm: false },
                    { name: "suspend", icon: Icons.sleep, cmd: ["systemctl", "suspend"], confirm: false },
                    { name: "logout", icon: Icons.logout, cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"], confirm: true },
                    { name: "reboot", icon: Icons.reboot, cmd: ["systemctl", "reboot"], confirm: true },
                    { name: "shutdown", icon: Icons.power, cmd: ["systemctl", "poweroff"], confirm: true }
                ]
                IconButton {
                    required property var modelData
                    icon: modelData.icon
                    size: 46
                    iconSize: 20
                    highlighted: pop.armed === modelData.name
                    accent: Theme.error
                    onClicked: pop.act(modelData.name, modelData.cmd, modelData.confirm)
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: pop.armed !== ""
            text: "Click again to " + pop.armed
            size: Theme.fontSmall
            color: Theme.error
        }
    }
}
