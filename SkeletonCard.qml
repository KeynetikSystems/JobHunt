import QtQuick 2.15
import QtQuick.Layouts 1.15

// Placeholder shown in place of a job/news card while a scan or search is in
// flight and nothing has loaded yet, so a multi-second live Tavily+Groq round
// trip reads as "working" rather than "did this do anything?".
Rectangle {
    id: skeleton
    Layout.fillWidth: true
    implicitHeight: 84
    color: "#1C212C"
    border.color: "#2B3140"
    border.width: 1

    Rectangle {
        width: 3
        height: parent.height
        color: "#2B3140"
        anchors.left: parent.left
    }

    SequentialAnimation on opacity {
        loops: Animation.Infinite
        NumberAnimation { from: 0.4; to: 0.8; duration: 700; easing.type: Easing.InOutQuad }
        NumberAnimation { from: 0.8; to: 0.4; duration: 700; easing.type: Easing.InOutQuad }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        anchors.leftMargin: 20
        anchors.rightMargin: 28
        spacing: 8

        Rectangle { Layout.preferredWidth: 220; Layout.preferredHeight: 14; color: "#8A93A6"; radius: 2 }
        Rectangle { Layout.preferredWidth: 130; Layout.preferredHeight: 11; color: "#8A93A6"; radius: 2 }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 12; color: "#8A93A6"; radius: 2 }
    }
}
