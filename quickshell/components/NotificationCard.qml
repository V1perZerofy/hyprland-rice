import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.services

// One notification. `toast` = on-screen popup (auto-hides, countdown line);
// otherwise it's a row in the notification centre.
// Left click: default action · Right click: hide · Middle: hide all toasts.
// Swipe right to hide (toast) or dismiss (centre).
Item {
    id: root

    required property var entry
    property bool toast: true
    readonly property Notification n: entry ? entry.n : null
    readonly property bool critical: n !== null && n.urgency === NotificationUrgency.Critical
    readonly property real timeout: n ? Notifs.timeoutFor(n) : 0
    property real remaining: timeout
    property bool leaving: false

    implicitWidth: 380
    implicitHeight: card.implicitHeight

    function close(dismiss) {
        if (leaving)
            return;
        leaving = true;
        out.dismiss = dismiss;
        out.start();
    }

    Connections {
        target: root.entry
        function onShownAtChanged() {
            root.remaining = root.timeout;
        }
    }

    Timer {
        interval: 50
        repeat: true
        running: root.toast && root.timeout > 0 && !mouse.containsMouse && !root.leaving
        onTriggered: {
            root.remaining -= interval;
            if (root.remaining <= 0)
                root.close(false);
        }
    }

    // slide in
    Component.onCompleted: if (toast) inAnim.start()
    ParallelAnimation {
        id: inAnim
        NumberAnimation {
            target: card
            property: "x"
            from: 60
            to: 0
            duration: 260
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: 200
        }
    }
    // slide out, then hide / dismiss
    SequentialAnimation {
        id: out
        property bool dismiss: false
        ParallelAnimation {
            NumberAnimation {
                target: card
                property: "x"
                to: root.width + 20
                duration: 200
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: card
                property: "opacity"
                to: 0
                duration: 200
            }
        }
        ScriptAction {
            script: {
                if (out.dismiss || !root.toast)
                    Notifs.dismiss(root.entry);
                else
                    Notifs.hidePopup(root.entry);
            }
        }
    }

    Rectangle {
        id: card
        width: root.width
        implicitHeight: body.implicitHeight + 24
        radius: 14
        clip: true
        color: root.toast ? Theme.cardBg : mouse.containsMouse ? Theme.surfaceHi : Theme.surface
        border.width: root.toast || root.critical ? 1 : 0
        border.color: root.critical ? Theme.error : Theme.border

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            drag.target: card
            drag.axis: Drag.XAxis
            drag.minimumX: 0
            drag.maximumX: root.width
            onReleased: {
                if (card.x > root.width * 0.3)
                    root.close(!root.toast);
                else
                    back.start();
            }
            onClicked: m => {
                if (m.button === Qt.MiddleButton)
                    Notifs.closePopups();
                else if (m.button === Qt.RightButton)
                    root.close(!root.toast);
                else
                    Notifs.activate(root.entry);
            }
        }
        NumberAnimation {
            id: back
            target: card
            property: "x"
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }

        RowLayout {
            id: body
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 12

            ClippingRectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 40
                implicitHeight: 40
                radius: 10
                color: Theme.alpha(root.critical ? Theme.error : Theme.primary, 0.16)
                Glyph {
                    anchors.centerIn: parent
                    text: Icons.bell
                    color: root.critical ? Theme.error : Theme.primary
                    visible: img.status !== Image.Ready
                }
                Image {
                    id: img
                    anchors.fill: parent
                    source: root.n ? Notifs.iconFor(root.n) : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 80
                    sourceSize.height: 80
                    asynchronous: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    StyledText {
                        Layout.fillWidth: true
                        text: (root.n && root.n.appName ? root.n.appName : "Notification") + "  ·  " + (root.entry ? Notifs.ago(root.entry.time) : "")
                        size: Theme.fontSmall - 1
                        color: Theme.subtext
                    }
                    Glyph {
                        text: Icons.close
                        size: 14
                        color: closeMouse.containsMouse ? Theme.error : Theme.subtext
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close(true)
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.n ? root.n.summary : ""
                    bold: true
                    size: Theme.fontSmall + 1
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.n ? root.n.body.replace(/\n/g, "<br>") : ""
                    textFormat: Text.StyledText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSmall
                    color: Theme.alpha(Theme.fg, 0.8)
                    linkColor: Theme.primary
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: root.toast ? 4 : 3
                    onLinkActivated: l => Qt.openUrlExternally(l)
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 6
                    visible: actionRepeater.count > 0
                    Repeater {
                        id: actionRepeater
                        model: root.n ? root.n.actions.filter(a => a.identifier !== "default" && a.text) : []
                        IconButton {
                            required property var modelData
                            label: modelData.text
                            size: 28
                            onClicked: {
                                modelData.invoke();
                                if (!root.n.resident)
                                    root.n.dismiss();
                            }
                        }
                    }
                }
            }
        }

        // countdown line
        Rectangle {
            visible: root.toast && root.timeout > 0
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            height: 2
            width: parent.width * Math.max(0, root.remaining / Math.max(1, root.timeout))
            color: root.critical ? Theme.error : Theme.primary
            opacity: 0.7
        }
    }
}
