import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: card
    property string kind: "job"
    property string title: ""
    property string subtitle: ""
    property string note: ""
    property string url: ""
    property string seenAt: ""
    property string status: "found"

    readonly property color parchment: "#EDE7D9"
    readonly property color brass: "#B08D57"
    readonly property color slate: "#8A93A6"
    readonly property color inkPanel: "#1C212C"
    readonly property color hairline: "#2B3140"

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 24
    color: inkPanel
    border.color: hairline
    border.width: 1

    ToolTip.text: card.url
    ToolTip.visible: cardArea.containsMouse && card.url.length > 0
    ToolTip.delay: 400

    MouseArea {
        id: cardArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: card.url.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (card.url) Qt.openUrlExternally(card.url)
    }

    Rectangle {
        width: 3
        height: parent.height
        color: card.kind === "job" ? brass : slate
        anchors.left: parent.left
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 14
        anchors.leftMargin: 20
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: card.kind === "job" ? "OPPORTUNITY" : "NEWS"
                color: card.kind === "job" ? brass : slate
                font.family: "Courier"
                font.pixelSize: 10
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                radius: 2
                color: card.status === "emailed" ? Qt.rgba(brass.r, brass.g, brass.b, 0.15) : Qt.rgba(slate.r, slate.g, slate.b, 0.15)
                implicitWidth: statusLabel.implicitWidth + 12
                implicitHeight: statusLabel.implicitHeight + 4
                Text {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: card.status === "emailed" ? "EMAILED" : "FOUND"
                    color: card.status === "emailed" ? brass : slate
                    font.pixelSize: 9
                    font.bold: true
                }
            }
            Text {
                text: card.seenAt
                color: slate
                font.pixelSize: 11
            }
        }

        Text {
            text: card.title
            color: parchment
            font.pixelSize: 14
            font.bold: true
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        Text {
            visible: card.subtitle.length > 0
            text: card.subtitle
            color: brass
            font.family: "Courier"
            font.pixelSize: 11
        }
        Text {
            visible: card.note.length > 0
            text: card.note
            color: slate
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
