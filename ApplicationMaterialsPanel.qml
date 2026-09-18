import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ColumnLayout {
    id: panel
    property string url: ""
    readonly property var result: backend.materials[panel.url]

    readonly property color parchment: "#EDE7D9"
    readonly property color brass: "#B08D57"
    readonly property color slate: "#8A93A6"
    readonly property color inkBg: "#14181F"
    readonly property color hairline: "#2B3140"

    Layout.fillWidth: true
    Layout.topMargin: 6
    spacing: 8

    Button {
        text: panel.result ? "Regenerate application materials" : "Draft CV highlights & cover letter"
        enabled: !backend.busy
        hoverEnabled: true
        ToolTip.text: "Uses your CV/background from Settings to draft materials tailored to this role"
        ToolTip.visible: hovered
        ToolTip.delay: 400
        onClicked: backend.draftApplicationMaterials(panel.url)
        padding: 6
        background: Rectangle {
            color: "transparent"
            border.color: brass
            border.width: 1
            radius: 2
        }
        contentItem: Text {
            text: parent.text
            color: brass
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: panel.result !== undefined && panel.result !== null
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text { text: "CV highlights for this role"; color: slate; font.pixelSize: 11; font.bold: true }
            TextArea {
                id: highlightsArea
                Layout.fillWidth: true
                readOnly: true
                selectByMouse: true
                wrapMode: Text.WordWrap
                text: panel.result ? panel.result.cv_highlights : ""
                color: parchment
                font.pixelSize: 12
                background: Rectangle { color: inkBg; border.color: hairline; border.width: 1 }
            }
            Button {
                text: "Copy highlights"
                flat: true
                padding: 4
                onClicked: { highlightsArea.selectAll(); highlightsArea.copy(); highlightsArea.deselect() }
                background: Rectangle { color: "transparent" }
                contentItem: Text { text: parent.text; color: slate; font.pixelSize: 10 }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text { text: "Cover letter"; color: slate; font.pixelSize: 11; font.bold: true }
            TextArea {
                id: letterArea
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                readOnly: true
                selectByMouse: true
                wrapMode: Text.WordWrap
                text: panel.result ? panel.result.cover_letter : ""
                color: parchment
                font.pixelSize: 12
                background: Rectangle { color: inkBg; border.color: hairline; border.width: 1 }
            }
            Button {
                text: "Copy cover letter"
                flat: true
                padding: 4
                onClicked: { letterArea.selectAll(); letterArea.copy(); letterArea.deselect() }
                background: Rectangle { color: "transparent" }
                contentItem: Text { text: parent.text; color: slate; font.pixelSize: 10 }
            }
        }
    }
}
