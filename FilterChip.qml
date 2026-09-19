import QtQuick 2.15

// Small tappable pill used for the Dashboard's All/Jobs/News feed filter —
// desktop equivalent of the mobile app's ChoiceChip row.
Rectangle {
    id: chip
    property string label: ""
    property bool selected: false
    signal clicked()

    readonly property color brass: "#B08D57"
    readonly property color inkBg: "#14181F"
    readonly property color inkPanel: "#1C212C"
    readonly property color parchment: "#EDE7D9"
    readonly property color hairline: "#2B3140"

    implicitWidth: chipText.implicitWidth + 20
    implicitHeight: 26
    radius: 2
    color: chip.selected ? chip.brass : chip.inkPanel
    border.color: chip.hairline
    border.width: 1

    Text {
        id: chipText
        anchors.centerIn: parent
        text: chip.label
        color: chip.selected ? chip.inkBg : chip.parchment
        font.pixelSize: 11
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
