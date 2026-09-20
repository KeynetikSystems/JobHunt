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
    title: "JobHuntAI"
    color: "#14181F"

    // -- palette --------------------------------------------------------
    readonly property color inkBg: "#14181F"
    readonly property color inkPanel: "#1C212C"
    readonly property color parchment: "#EDE7D9"
    readonly property color brass: "#B08D57"
    readonly property color slate: "#8A93A6"
    readonly property color hairline: "#2B3140"

    property string currentPage: "dashboard"
    property string feedFilter: "all"

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
                    text: "JobHuntAI"
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
                        id: historyNavBtn
                        text: "History"
                        flat: true
                        hoverEnabled: true
                        Layout.fillWidth: true
                        ToolTip.text: "Browse past opportunities and news you've already seen"
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        onClicked: root.currentPage = "history"
                        padding: 8
                        background: Rectangle {
                            color: brass
                            opacity: root.currentPage === "history" ? 0.15 : 0
                            radius: 4
                        }
                        contentItem: Text {
                            text: historyNavBtn.text
                            color: root.currentPage === "history" ? brass : slate
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

                // Text {
                //     text: "London\nPE / VC / Impact / Consulting"
                //     color: slate
                //     font.pixelSize: 11
                //     wrapMode: Text.WordWrap
                //     Layout.preferredWidth: 150
                // }
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
                        ToolTip.text: "Pulls your unseen items from the shared scan (refreshed roughly hourly) — doesn't send an email or affect what's already been sent"
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

                // feed filter / sort bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: backend.jobs.length > 0 || backend.news.length > 0

                    FilterChip {
                        label: "All"
                        selected: root.feedFilter === "all"
                        onClicked: root.feedFilter = "all"
                    }
                    FilterChip {
                        label: "Jobs (" + backend.jobs.length + ")"
                        selected: root.feedFilter === "jobs"
                        onClicked: root.feedFilter = "jobs"
                    }
                    FilterChip {
                        label: "News (" + backend.news.length + ")"
                        selected: root.feedFilter === "news"
                        onClicked: root.feedFilter = "news"
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        visible: root.feedFilter !== "news" && backend.jobs.length > 0
                        flat: true
                        padding: 4
                        hoverEnabled: true
                        ToolTip.text: backend.seniorityDescending ? "Seniority: senior first — click to reverse" : "Seniority: junior first — click to reverse"
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        onClicked: backend.toggleSenioritySort()
                        background: Rectangle { color: "transparent" }
                        contentItem: Text {
                            text: backend.seniorityDescending ? "Seniority ↓" : "Seniority ↑"
                            color: brass
                            font.pixelSize: 11
                        }
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
                            visible: root.feedFilter !== "news"

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

                                    Text {
                                        text: "✕"
                                        color: slate
                                        font.pixelSize: 13
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        z: 1

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: backend.dismissItem(modelData.url)
                                        }
                                    }

                                    ColumnLayout {
                                        id: jobCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        anchors.leftMargin: 20
                                        anchors.rightMargin: 28
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
                                            text: (modelData.firm || "") + "  ·  " + (modelData.seniority || "Unspecified")
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

                                        ApplicationMaterialsPanel {
                                            url: modelData.url || ""
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
                            visible: root.feedFilter !== "jobs"

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

                                    Text {
                                        text: "✕"
                                        color: slate
                                        font.pixelSize: 13
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        z: 1

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: backend.dismissItem(modelData.url)
                                        }
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
                                        anchors.rightMargin: 28
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

                // -- ad-hoc search, alongside the saved query-list scan above --------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Search for roles, firms, news…"
                        color: parchment
                        enabled: !backend.busy
                        font.pixelSize: 13
                        background: Rectangle {
                            color: inkPanel
                            border.color: hairline
                            border.width: 1
                            radius: 2
                        }
                        Keys.onReturnPressed: backend.runSearch(searchField.text)
                    }

                    Button {
                        text: "Search"
                        enabled: !backend.busy
                        hoverEnabled: true
                        ToolTip.text: "One-off search, separate from the saved query list above — uses your own API keys directly, no daily cap"
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        onClicked: backend.runSearch(searchField.text)
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
                }
            }

            // -- history page ---------------------------------------------------
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 32
                spacing: 20
                visible: root.currentPage === "history"

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "History"
                        color: parchment
                        font.family: "Georgia"
                        font.pixelSize: 26
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: backend.history.length + " item" + (backend.history.length === 1 ? "" : "s")
                        color: slate
                        font.pixelSize: 12
                    }
                }

                Text {
                    text: "Everything you've emailed or dismissed, newest first."
                    color: slate
                    font.pixelSize: 13
                }

                ScrollView {
                    id: historyScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: historyScroll.availableWidth - 60
                        spacing: 10

                        Repeater {
                            model: backend.history
                            delegate: HistoryCard {
                                Layout.fillWidth: true
                                kind: modelData.kind || "job"
                                title: (modelData.kind === "news" ? modelData.headline : modelData.title) || ""
                                subtitle: modelData.kind === "news"
                                    ? (modelData.source || "")
                                    : ((modelData.firm || "") + (modelData.seniority ? "  ·  " + modelData.seniority : ""))
                                note: (modelData.kind === "news" ? modelData.summary : modelData.note) || ""
                                url: modelData.url || ""
                                seenAt: modelData.seen_at || ""
                            }
                        }

                        Text {
                            visible: backend.history.length === 0
                            text: "Nothing here yet — items you email or dismiss will show up here."
                            color: slate
                            font.italic: true
                            font.pixelSize: 12
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
                        spacing: 20

                        // -- connection status -------------------------------------
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: connectionRow.implicitHeight + 24
                            color: inkPanel
                            border.color: hairline
                            border.width: 1

                            RowLayout {
                                id: connectionRow
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                Text {
                                    text: backend.connected ? "●" : "○"
                                    color: backend.connected ? brass : slate
                                    font.pixelSize: 14
                                }
                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: backend.connected
                                        ? "Connected as " + backend.email
                                        : "Not connected — connect below to share the operator's Tavily/Groq keys and your free/premium plan"
                                    color: parchment
                                    font.pixelSize: 12
                                }
                            }
                        }

                        // -- account (only once connected + loaded) -----------------
                        SettingsSection {
                            title: "Account"
                            visible: backend.connected && Object.keys(backend.account).length > 0

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Plan"; color: slate; font.pixelSize: 12; Layout.preferredWidth: 140 }
                                Text {
                                    text: backend.account.plan === "premium" ? "Premium" : "Free"
                                    color: parchment; font.pixelSize: 12; font.bold: true
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Email verified"; color: slate; font.pixelSize: 12; Layout.preferredWidth: 140 }
                                Text {
                                    text: backend.account.email_verified ? "Yes" : "No"
                                    color: parchment; font.pixelSize: 12; font.bold: true
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "AI drafts today"; color: slate; font.pixelSize: 12; Layout.preferredWidth: 140 }
                                Text {
                                    text: backend.account.materials_daily_cap
                                        ? backend.account.materials_used_today + " / " + backend.account.materials_daily_cap
                                        : backend.account.materials_used_today + " (unlimited)"
                                    color: parchment; font.pixelSize: 12; font.bold: true
                                }
                            }

                            Button {
                                visible: backend.account.email_verified === false
                                text: "Resend verification email"
                                enabled: !backend.busy
                                hoverEnabled: true
                                onClicked: backend.resendVerification()
                                background: Rectangle { color: "transparent"; border.color: brass; border.width: 1; radius: 2 }
                                contentItem: Text { text: parent.text; color: brass; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                                padding: 6
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: backend.account.plan !== "premium"
                                spacing: 8

                                SettingsField {
                                    id: upgradeNoteField
                                    label: "Request an upgrade (optional note)"
                                    tooltip: "e.g. I'm hitting the daily draft limit"
                                }
                                Button {
                                    text: "Request upgrade"
                                    enabled: !backend.busy
                                    hoverEnabled: true
                                    onClicked: { backend.requestUpgrade(upgradeNoteField.text); upgradeNoteField.text = "" }
                                    background: Rectangle { color: "transparent"; border.color: brass; border.width: 1; radius: 2 }
                                    contentItem: Text { text: parent.text; color: brass; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                                    padding: 6
                                }
                            }
                        }

                        // -- backend connection --------------------------------------
                        SettingsSection {
                            title: "Backend"

                            SettingsField {
                                label: "Backend URL"; text: backend.backendUrl; id: backendUrlField
                                tooltip: "Where your hosted backend is running, e.g. https://your-app.up.railway.app"
                            }
                            SettingsField {
                                label: "Email"; text: backend.email; id: emailField
                                tooltip: "Used to verify your account and receive emailed digests"
                            }
                            Text {
                                text: "This app no longer holds its own Tavily/Groq/SMTP keys — connecting registers " +
                                      "this email with your backend and shares its keys and your plan's usage caps."
                                color: slate
                                font.pixelSize: 11
                                font.italic: true
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        // -- Personal Profile (only once connected) --------------------
                        SettingsSection {
                            title: "Personal Profile"
                            visible: backend.connected

                            Text {
                                text: "Used to draft tailored CV highlights and cover letters, and as a quick reference when filling out application forms elsewhere. Never sent anywhere except Groq, alongside the specific role you ask to draft for."
                                color: slate
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            SettingsField {
                                id: fullNameField
                                label: "Full name"; text: backend.profile.full_name || ""
                            }
                            SettingsField {
                                id: phoneField
                                label: "Phone number"; text: backend.profile.phone || ""
                            }
                            SettingsField {
                                id: locationField
                                label: "Location / City"; text: backend.profile.location || ""
                            }
                            SettingsField {
                                id: linkedinField
                                label: "LinkedIn / portfolio URL"; text: backend.profile.linkedin_url || ""
                            }

                            Text { text: "Work history"; color: slate; font.pixelSize: 12 }
                            ScrollView {
                                id: workHistoryScroll
                                Layout.fillWidth: true
                                Layout.preferredHeight: 160
                                clip: true
                                TextArea {
                                    id: workHistoryArea
                                    width: workHistoryScroll.availableWidth
                                    text: backend.profile.work_history || ""
                                    color: parchment
                                    font.family: "Courier"
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    background: Rectangle { color: inkBg; border.color: hairline; border.width: 1 }
                                }
                            }

                            Text { text: "Education"; color: slate; font.pixelSize: 12 }
                            ScrollView {
                                id: educationScroll
                                Layout.fillWidth: true
                                Layout.preferredHeight: 100
                                clip: true
                                TextArea {
                                    id: educationArea
                                    width: educationScroll.availableWidth
                                    text: backend.profile.education || ""
                                    color: parchment
                                    font.family: "Courier"
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    background: Rectangle { color: inkBg; border.color: hairline; border.width: 1 }
                                }
                            }

                            Text { text: "Skills"; color: slate; font.pixelSize: 12 }
                            ScrollView {
                                id: skillsScroll
                                Layout.fillWidth: true
                                Layout.preferredHeight: 80
                                clip: true
                                TextArea {
                                    id: skillsArea
                                    width: skillsScroll.availableWidth
                                    text: backend.profile.skills || ""
                                    color: parchment
                                    font.family: "Courier"
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    background: Rectangle { color: inkBg; border.color: hairline; border.width: 1 }
                                }
                            }

                            Button {
                                text: "Save profile"
                                enabled: !backend.busy
                                hoverEnabled: true
                                onClicked: backend.saveProfile(
                                    fullNameField.text, phoneField.text, locationField.text, linkedinField.text,
                                    workHistoryArea.text, educationArea.text, skillsArea.text
                                )
                                background: Rectangle { color: "transparent"; border.color: brass; border.width: 1; radius: 2 }
                                contentItem: Text { text: parent.text; color: brass; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                                padding: 6
                            }
                        }
                    }
                }

                // pinned footer — always visible, no scrolling needed to connect
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Button {
                        text: backend.connected ? "Reconnect" : "Connect"
                        enabled: !backend.busy
                        hoverEnabled: true
                        onClicked: backend.connect(backendUrlField.text, emailField.text)
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

                    Button {
                        visible: backend.connected
                        text: "Disconnect"
                        enabled: !backend.busy
                        hoverEnabled: true
                        onClicked: backend.disconnect()
                        background: Rectangle { color: "transparent"; border.color: slate; border.width: 1; radius: 2 }
                        contentItem: Text {
                            text: parent.text
                            color: parchment
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        padding: 10
                    }

                    Text {
                        Layout.fillWidth: true
                        text: backend.status
                        color: brass
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    Component.onCompleted: backend.refreshAccount()
}
