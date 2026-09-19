import QtQuick 2.15
import QtQuick.Layouts 1.15

// Visually groups a labeled Settings section into its own bordered card, so
// the page reads as distinct blocks instead of one undifferentiated scroll
// of headers and fields — desktop equivalent of the mobile app's _sectionBox.
Rectangle {
    id: section
    property string title: ""
    default property alias content: contentColumn.data

    readonly property color inkPanel: "#1C212C"
    readonly property color hairline: "#2B3140"
    readonly property color parchment: "#EDE7D9"

    Layout.fillWidth: true
    color: inkPanel
    border.color: hairline
    border.width: 1
    implicitHeight: contentColumn.implicitHeight + 28

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Text {
            text: section.title
            color: section.parchment
            font.family: "Georgia"
            font.pixelSize: 16
        }
    }
}
