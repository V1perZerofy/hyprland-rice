import QtQuick
import qs.services

Text {
    property int size: Theme.fontSize
    property bool bold: false
    font.family: Theme.font
    font.pixelSize: size
    font.weight: bold ? Font.Bold : Font.Normal
    color: Theme.fg
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
}
