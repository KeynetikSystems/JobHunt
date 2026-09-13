import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ColumnLayout {
    id: control
    property alias label: fieldLabel.text
    property alias text: fieldInput.text
    property bool masked: false
    property string tooltip: ""
    Layout.fillWidth: true
    spacing: 4

    Text {
        id: fieldLabel
        color: "#8A93A6"
        font.pixelSize: 11
    }
    TextField {
        id: fieldInput
        Layout.fillWidth: true
        color: "#EDE7D9"
        echoMode: control.masked ? TextInput.Password : TextInput.Normal
        font.pixelSize: 13
        hoverEnabled: true
        ToolTip.text: control.tooltip
        ToolTip.visible: control.tooltip.length > 0 && hovered
        ToolTip.delay: 400
        background: Rectangle {
            color: "#1C212C"
            border.color: "#2B3140"
            border.width: 1
            radius: 2
        }
    }
}
