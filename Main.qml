import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: root
    visible: true
    width: 1080
    height: 680
    minimumWidth: 760
    minimumHeight: 520
    title: "Ledger — PE / VC / Impact / Consulting"
    color: "#14181F"

    // -- palette --------------------------------------------------------
    readonly property color inkBg: "#14181F"
    readonly property color inkPanel: "#1C212C"
    readonly property color parchment: "#EDE7D9"
    readonly property color brass: "#B08D57"
    readonly property color slate: "#8A93A6"
    readonly property color hairline: "#2B3140"

    property string currentPage: "dashboard"

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // -- left spine ---------------------------------------------------
        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: inkPanel

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 28

                Text {
                    text: "LEDGER"
                    color: parchment
                    font.family: "Georgia"
                    font.pixelSize: 20
                    font.letterSpacing: 2
                }

                ColumnLayout {
                    spacing: 6
                    Button {
                        id: dashboardNavBtn
                        text: "Dashboard"
                        flat: true
                        hoverEnabled: true
                        Layout.fillWidth: true
                        ToolTip.text: "View today's scan results"
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        onClicked: root.currentPage = "dashboard"
                        padding: 8
                        background: Rectangle {
                            color: brass
                            opacity: root.currentPage === "dashboard" ? 0.15 : 0
                            radius: 4
                        }
                        contentItem: Text {
                            text: dashboardNavBtn.text
                            color: root.currentPage === "dashboard" ? brass : slate
                            font.pixelSize: 14
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    Button {
                        id: settingsNavBtn
                        text: "Settings"
                        flat: true
                        hoverEnabled: true
                        Layout.fillWidth: true
                        ToolTip.text: "Configure email delivery, API keys, and search queries"
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        onClicked: root.currentPage = "settings"
                        padding: 8
                        background: Rectangle {
                            color: brass
                            opacity: root.currentPage === "settings" ? 0.15 : 0
                            radius: 4
                        }
                        contentItem: Text {
                            text: settingsNavBtn.text
                            color: root.currentPage === "settings" ? brass : slate
                            font.pixelSize: 14
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: "London\nPE / VC / Impact / Consulting"
                    color: slate
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    Layout.preferredWidth: 150
                }
            }
        }

        // -- main content ---------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: inkBg

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 32
                spacing: 20
                visible: root.currentPage === "dashboard"

                // header row
                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: 4
                        Text {
                            text: "Today's entries"
                            color: parchment
                            font.family: "Georgia"
                            font.pixelSize: 26
                        }
                        Text {
                            text: backend.dateLabel
                            color: slate
                            font.pixelSize: 13
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: backend.busy ? "Working…" : "Run scan now"
                        enabled: !backend.busy
                        hoverEnabled: true
                        ToolTip.text: "Search for new listings and news — doesn't send an email or affect what's already been sent"
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        onClicked: backend.runScan()
                        background: Rectangle {
                            color: brass
                            radius: 2
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#14181F"
                            font.pixelSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        padding: 10
                    }

                    Button {
                        text: "Email me this"
                        enabled: !backend.busy && (backend.jobs.length > 0 || backend.news.length > 0)
                        hoverEnabled: true
                        ToolTip.text: backend.busy
                            ? "Working…"
                            : (backend.jobs.length > 0 || backend.news.length > 0)
                                ? "Email the results shown below and mark them as seen, so they won't appear again"
                                : "Run a scan first — there's nothing to email yet"
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        onClicked: backend.sendEmail()
                        background: Rectangle {
                            color: "transparent"
                            border.color: slate
                            border.width: 1
                            radius: 2
                        }
                        contentItem: Text {
                            text: parent.text
                            color: parchment
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        padding: 10
                    }
                }

                // status line
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    BusyIndicator {
                        running: backend.busy
                        visible: backend.busy
                        implicitWidth: 18
                        implicitHeight: 18
                    }
                    Text {
                        text: backend.status
                        color: brass
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }
                }

                // scrollable ledger feed
                ScrollView {
                    id: dashboardScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: dashboardScroll.availableWidth - 60
                        spacing: 24

                        // -- opportunities section -----------------------------
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "New opportunities (" + backend.jobs.length + ")"
                                color: parchment
                                font.family: "Georgia"
                                font.pixelSize: 16
                            }

                            Repeater {
                                model: backend.jobs
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: jobCol.implicitHeight + 24
                                    color: inkPanel
                                    border.color: hairline
                                    border.width: 1

                                    ToolTip.text: modelData.url || ""
                                    ToolTip.visible: jobCardArea.containsMouse && (modelData.url || "").length > 0
                                    ToolTip.delay: 400

                                    MouseArea {
                                        id: jobCardArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: (modelData.url || "").length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: if (modelData.url) Qt.openUrlExternally(modelData.url)
                                    }

                                    Rectangle {
                                        width: 3
                                        height: parent.height
                                        color: brass
                                        anchors.left: parent.left
                                    }

                                    ColumnLayout {
                                        id: jobCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        anchors.leftMargin: 20
                                        spacing: 4

                                        Text {
                                            text: modelData.title || ""
                                            color: parchment
                                            font.pixelSize: 14
                                            font.bold: true
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                        }
                                        Text {
                                            text: (modelData.firm || "") + "  ·  " + (modelData.seniority || "n/a")
                                            color: brass
                                            font.family: "Courier"
                                            font.pixelSize: 11
                                        }
                                        Text {
                                            text: modelData.note || ""
                                            color: slate
                                            font.pixelSize: 12
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: backend.jobs.length === 0
                                text: "Nothing new yet. Run a scan to check for fresh listings."
                                color: slate
                                font.italic: true
                                font.pixelSize: 12
                            }
                        }

                        // -- news section ---------------------------------------
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "Market news (" + backend.news.length + ")"
                                color: parchment
                                font.family: "Georgia"
                                font.pixelSize: 16
                            }

                            Repeater {
                                model: backend.news
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: newsCol.implicitHeight + 24
                                    color: inkPanel
                                    border.color: hairline
                                    border.width: 1

                                    ToolTip.text: modelData.url || ""
                                    ToolTip.visible: newsCardArea.containsMouse && (modelData.url || "").length > 0
                                    ToolTip.delay: 400

                                    MouseArea {
                                        id: newsCardArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: (modelData.url || "").length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: if (modelData.url) Qt.openUrlExternally(modelData.url)
                                    }

                                    Rectangle {
                                        width: 3
                                        height: parent.height
                                        color: slate
                                        anchors.left: parent.left
                                    }

                                    ColumnLayout {
                                        id: newsCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        anchors.leftMargin: 20
                                        spacing: 4

                                        Text {
                                            text: modelData.headline || ""
                                            color: parchment
                                            font.pixelSize: 14
                                            font.bold: true
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                        }
                                        Text {
                                            text: modelData.source || ""
                                            color: brass
                                            font.family: "Courier"
                                            font.pixelSize: 11
                                        }
                                        Text {
                                            text: modelData.summary || ""
                                            color: slate
                                            font.pixelSize: 12
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: backend.news.length === 0
                                text: "No notable news yet. Run a scan to check for updates."
                                color: slate
                                font.italic: true
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            // -- settings page -------------------------------------------------
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 32
                spacing: 20
                visible: root.currentPage === "settings"

                Text {
                    text: "Settings"
                    color: parchment
                    font.family: "Georgia"
                    font.pixelSize: 26
                }

                ScrollView {
                    id: settingsScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        id: settingsColumn
                        width: settingsScroll.availableWidth - 60
                        spacing: 28

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "Email delivery"
                                color: parchment
                                font.family: "Georgia"
                                font.pixelSize: 16
                            }

                            SettingsField {
                                label: "Send digest to"; text: backend.recipientEmail; id: recipientField
                                tooltip: "The email address that receives the daily digest"
                            }
                            SettingsField {
                                label: "SMTP host"; text: backend.smtpHost; id: smtpHostField
                                tooltip: "Your email provider's outgoing mail server, e.g. smtp.gmail.com"
                            }
                            SettingsField {
                                label: "SMTP port"; text: backend.smtpPort; id: smtpPortField
                                tooltip: "Usually 587 (STARTTLS)"
                            }
                            SettingsField {
                                label: "SMTP username"; text: backend.smtpUser; id: smtpUserField
                                tooltip: "Your full email address, used to log in to the SMTP server"
                            }
                            SettingsField {
                                label: "SMTP password"; text: backend.smtpPass; id: smtpPassField; masked: true
                                tooltip: "For Gmail/Outlook, use an app password, not your regular login password"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "API keys"
                                color: parchment
                                font.family: "Georgia"
                                font.pixelSize: 16
                            }

                            SettingsField {
                                label: "Tavily API key"; text: backend.tavilyKey; id: tavilyField; masked: true
                                tooltip: "From app.tavily.com — used to search the web for listings and news"
                            }
                            SettingsField {
                                label: "Groq API key"; text: backend.groqKey; id: groqField; masked: true
                                tooltip: "From console.groq.com — used to summarize search results"
                            }
                            SettingsField {
                                label: "Groq model"; text: backend.groqModel; id: groqModelField
                                tooltip: "Groq model id used for summarization, e.g. openai/gpt-oss-120b"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "Search queries (one per line)"
                                color: parchment
                                font.family: "Georgia"
                                font.pixelSize: 16
                            }

                            Text { text: "Job queries"; color: slate; font.pixelSize: 12 }
                            ScrollView {
                                id: jobQueriesScroll
                                Layout.fillWidth: true
                                Layout.preferredHeight: 160
                                clip: true
                                TextArea {
                                    id: jobQueriesArea
                                    width: jobQueriesScroll.availableWidth
                                    text: backend.jobQueriesText
                                    color: parchment
                                    font.family: "Courier"
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    hoverEnabled: true
                                    ToolTip.text: "One search query per line — each runs as a separate Tavily search"
                                    ToolTip.visible: hovered
                                    ToolTip.delay: 400
                                    background: Rectangle {
                                        color: inkPanel
                                        border.color: hairline
                                        border.width: 1
                                    }
                                }
                            }

                            Text { text: "News queries"; color: slate; font.pixelSize: 12 }
                            ScrollView {
                                id: newsQueriesScroll
                                Layout.fillWidth: true
                                Layout.preferredHeight: 160
                                clip: true
                                TextArea {
                                    id: newsQueriesArea
                                    width: newsQueriesScroll.availableWidth
                                    text: backend.newsQueriesText
                                    color: parchment
                                    font.family: "Courier"
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    hoverEnabled: true
                                    ToolTip.text: "One search query per line — each runs as a separate Tavily search"
                                    ToolTip.visible: hovered
                                    ToolTip.delay: 400
                                    background: Rectangle {
                                        color: inkPanel
                                        border.color: hairline
                                        border.width: 1
                                    }
                                }
                            }
                        }
                    }
                }

                // pinned footer — always visible, no scrolling needed to save
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Button {
                        text: "Save settings"
                        hoverEnabled: true
                        ToolTip.text: "Writes these values to .env and queries.json"
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        onClicked: backend.saveSettings(
                            recipientField.text, smtpHostField.text, smtpPortField.text,
                            smtpUserField.text, smtpPassField.text,
                            tavilyField.text, groqField.text, groqModelField.text,
                            jobQueriesArea.text, newsQueriesArea.text
                        )
                        background: Rectangle { color: brass; radius: 2 }
                        contentItem: Text {
                            text: parent.text
                            color: "#14181F"
                            font.pixelSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        padding: 10
                    }

                    Text {
                        text: backend.status
                        color: brass
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
