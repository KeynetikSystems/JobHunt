import QtQuick 2.15
import QtQuick.Layouts 1.15

// Visually groups a labeled Settings section into its own bordered card, so
// the page reads as distinct blocks instead of one undifferentiated scroll
// of headers and fields — desktop equivalent of the mobile app's _sectionBox.
// Collapsible: clicking the header toggles `expanded`, so a heavy section
// (e.g. Personal Profile's 7 fields + 3 textareas) doesn't force everyone to
// scroll past it every time.
Rectangle {
    id: section
    property string title: ""
    property bool expanded: true
    default property alias content: innerColumn.data

    readonly property color inkPanel: "#1C212C"
    readonly property color hairline: "#2B3140"
    readonly property color parchment: "#EDE7D9"
    readonly property color slate: "#8A93A6"

    Layout.fillWidth: true
    color: inkPanel
    border.color: hairline
    border.width: 1
    implicitHeight: outerColumn.implicitHeight + 28

    ColumnLayout {
        id: outerColumn
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        MouseArea {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(headerRow.implicitHeight, 32)
            cursorShape: Qt.PointingHandCursor
            onClicked: section.expanded = !section.expanded

            RowLayout {
                id: headerRow
                anchors.fill: parent
                spacing: 8

                Text {
                    text: section.title
                    color: section.parchment
                    font.family: "Georgia"
                    font.pixelSize: 16
                    Layout.fillWidth: true
                }
                Text {
                    text: section.expanded ? "▲" : "▼"
                    color: section.slate
                    font.pixelSize: 11
                }
            }
        }

        ColumnLayout {
            id: innerColumn
            Layout.fillWidth: true
            spacing: 10
            visible: section.expanded
        }
    }
}
