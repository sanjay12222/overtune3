import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../components"

Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitWidth: 800
    implicitHeight: 600
    clip: true

    readonly property int pageMargin: width < 700 ? 12 : 20
    readonly property real cardMax: 620
    readonly property bool compact: width < 520

    function openDocs() {
        const w = Window.window
        if (w && typeof w.navigateTo === "function") w.navigateTo(4)
    }

    function doResetDefaults() {
        theme.resetToDefaults()
        const w = Window.window
        if (w && typeof w.showNotification === "function")
            w.showNotification("Settings restored to defaults", false)
    }

    Rectangle {
        anchors.fill: parent
        color: theme.background
    }

    // ── Reusable row: label left, control right ───────────────────────────────
    component SettingRow: Item {
        id: sr
        property string label: ""
        property string hint:  ""
        default property alias content: controlSlot.data
        width: parent ? parent.width : 200
        height: Math.max(44, controlSlot.implicitHeight + 20)

        Text {
            id: srLabel
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: sr.label
            font.family: "Stack Sans Headline"
            font.pixelSize: 13
            font.weight: Font.Medium
            color: theme.primaryText
        }

        Item {
            id: controlSlot
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }

        // hairline separator
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: theme.borderColor
            opacity: 0.5
        }
    }

    // ── Page layout ───────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pageMargin
        spacing: 12

        PageHeader {
            Layout.fillWidth: true
            title: "Settings"
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: contentCol.implicitHeight + 40
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar {
                id: settingsScrollBar
                policy: flick.contentHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                width: 8
                hoverEnabled: true
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: settingsScrollBar.pressed ? theme.accent
                         : (settingsScrollBar.hovered ? theme.secondaryText : theme.borderColor)
                }
                background: Item {}
            }

            Column {
                id: contentCol
                width: Math.min(root.cardMax, flick.width)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                // ── Appearance ────────────────────────────────────────────────
                Rectangle {
                    width: parent.width
                    implicitHeight: appCol.implicitHeight + 24
                    height: implicitHeight
                    radius: 12
                    color: theme.surface
                    border.color: theme.borderColor
                    border.width: 1
                    clip: true

                    Column {
                        id: appCol
                        anchors { fill: parent; margins: 0; topMargin: 0 }
                        spacing: 0

                        // Section label
                        Text {
                            x: 16; topPadding: 16; bottomPadding: 10
                            text: "Appearance"
                            font.family: theme.headlineFont
                            font.pixelSize: 16; font.weight: Font.DemiBold
                            color: theme.primaryText
                        }

                        // Theme
                        Item {
                            width: parent.width; height: 44
                            Text {
                                anchors { left: parent.left; leftMargin: 16; right: themeControl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: "Theme"
                                font.family: "Stack Sans Headline"; font.pixelSize: 13
                                color: theme.primaryText
                                elide: Text.ElideRight
                            }
                            SegmentedButton {
                                id: themeControl
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                width: Math.min(200, parent.width * (root.compact ? 0.55 : 0.7)); implicitHeight: 28
                                model: ["System", "Light", "Dark"]
                                currentIndex: theme.themeMode
                                onActivated: function(idx) { theme.themeMode = idx }
                            }
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
                                height: 1; color: theme.borderColor; opacity: 0.5
                            }
                        }

                        // OLED Black
                        Item {
                            width: parent.width; height: 44
                            Text {
                                anchors { left: parent.left; leftMargin: 16; right: oledControl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: "OLED Black"
                                font.family: "Stack Sans Headline"; font.pixelSize: 13
                                color: theme.primaryText
                                elide: Text.ElideRight
                            }
                            SegmentedButton {
                                id: oledControl
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                width: Math.min(160, parent.width * (root.compact ? 0.55 : 0.7)); implicitHeight: 28
                                model: ["Off", "On"]
                                currentIndex: theme.oledMode ? 1 : 0
                                onActivated: function(idx) { theme.oledMode = (idx === 1) }
                            }
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
                                height: 1; color: theme.borderColor; opacity: 0.5
                            }
                        }

                        // Accent Color — only 2 options
                        Item {
                            width: parent.width; height: 52
                            Text {
                                anchors { left: parent.left; leftMargin: 16; right: accentControl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: "Accent"
                                font.family: "Stack Sans Headline"; font.pixelSize: 13
                                color: theme.primaryText
                                elide: Text.ElideRight
                            }
                            Row {
                                id: accentControl
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                spacing: 10

                                Repeater {
                                    model: [
                                        { name: "Blue",          color: "#0A84FF", idx: 0 },
                                        { name: "Spotify Green", color: "#1DB954", idx: 1 }
                                    ]
                                    delegate: Rectangle {
                                        required property int index
                                        required property var modelData
                                        width: 28; height: 28; radius: 14
                                        color: modelData.color
                                        border.color: theme.accentColorIndex === modelData.idx ? "#FFFFFF" : "transparent"
                                        border.width: 2

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 9; height: 9; radius: 5
                                            color: "#FFFFFF"
                                            visible: theme.accentColorIndex === modelData.idx
                                        }

                                        ToolTip.visible: sm.containsMouse
                                        ToolTip.text: modelData.name
                                        ToolTip.delay: 300

                                        MouseArea {
                                            id: sm
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: theme.accentColorIndex = modelData.idx
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width; height: 48
                            Text {
                                anchors { left: parent.left; leftMargin: 16; right: resetSettingsButton.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                text: "Reset settings"
                                font.family: theme.headlineFont
                                font.pixelSize: 13
                                color: theme.primaryText
                                elide: Text.ElideRight
                            }
                            StyledButton {
                                id: resetSettingsButton
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                text: "Reset"
                                primary: false
                                implicitWidth: 84
                                implicitHeight: 30
                                onClicked: root.doResetDefaults()
                            }
                        }
                    }
                }

                // ── Plot Engine ───────────────────────────────────────────────
                Rectangle {
                    width: parent.width
                    implicitHeight: plotCol.implicitHeight + 24
                    height: implicitHeight
                    radius: 12
                    color: theme.surface
                    border.color: theme.borderColor
                    border.width: 1
                    clip: true

                    Column {
                        id: plotCol
                        anchors { fill: parent; margins: 0 }
                        spacing: 0

                        Text {
                            x: 16; topPadding: 16; bottomPadding: 10
                            text: "Plots"
                            font.family: theme.headlineFont
                            font.pixelSize: 16; font.weight: Font.DemiBold
                            color: theme.primaryText
                        }

                        Item {
                            width: parent.width; height: 44
                            Text {
                                anchors { left: parent.left; leftMargin: 16; right: lineWidthControl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: "Line Width"
                                font.family: "Stack Sans Headline"; font.pixelSize: 13
                                color: theme.primaryText
                                elide: Text.ElideRight
                            }
                            SegmentedButton {
                                id: lineWidthControl
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                width: Math.min(200, parent.width * (root.compact ? 0.55 : 0.7)); implicitHeight: 28
                                model: ["Fine", "Standard", "Bold"]
                                currentIndex: {
                                    if (Math.abs(theme.plotLineWidth - 1.5) < 0.2) return 0
                                    if (Math.abs(theme.plotLineWidth - 3.2) < 0.2) return 2
                                    return 1
                                }
                                onActivated: function(idx) {
                                    theme.plotLineWidth = [1.5, 2.2, 3.2][idx]
                                }
                            }
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
                                height: 1; color: theme.borderColor; opacity: 0.5
                            }
                        }

                        Item {
                            width: parent.width; height: 44
                            Text {
                                anchors { left: parent.left; leftMargin: 16; right: resolutionControl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: "Resolution"
                                font.family: "Stack Sans Headline"; font.pixelSize: 13
                                color: theme.primaryText
                                elide: Text.ElideRight
                            }
                            SegmentedButton {
                                id: resolutionControl
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                width: Math.min(240, parent.width * (root.compact ? 0.55 : 0.7)); implicitHeight: 28
                                model: ["512", "1024", "2048", "4096"]
                                currentIndex: {
                                    if (theme.plotResolution === 512)  return 0
                                    if (theme.plotResolution === 2048) return 2
                                    if (theme.plotResolution === 4096) return 3
                                    return 1
                                }
                                onActivated: function(idx) {
                                    theme.plotResolution = [512, 1024, 2048, 4096][idx]
                                }
                            }
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
                                height: 1; color: theme.borderColor; opacity: 0.5
                            }
                        }

                        Item {
                            width: parent.width; height: 44
                            Text {
                                anchors { left: parent.left; leftMargin: 16; right: crosshairControl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: "Crosshair"
                                font.family: "Stack Sans Headline"; font.pixelSize: 13
                                color: theme.primaryText
                                elide: Text.ElideRight
                            }
                            SegmentedButton {
                                id: crosshairControl
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                width: Math.min(140, parent.width * (root.compact ? 0.55 : 0.7)); implicitHeight: 28
                                model: ["Off", "On"]
                                currentIndex: theme.showCrosshairByDefault ? 1 : 0
                                onActivated: function(idx) { theme.showCrosshairByDefault = (idx === 1) }
                            }
                        }
                    }
                }

                // ── DSP & Export ──────────────────────────────────────────────
                Rectangle {
                    width: parent.width
                    implicitHeight: dspCol2.implicitHeight + 24
                    height: implicitHeight
                    radius: 12
                    color: theme.surface
                    border.color: theme.borderColor
                    border.width: 1
                    clip: true

                    Column {
                        id: dspCol2
                        anchors { fill: parent; margins: 0 }
                        spacing: 0

                        Text {
                            x: 16; topPadding: 16; bottomPadding: 10
                            text: "DSP & Export"
                            font.family: theme.headlineFont
                            font.pixelSize: 16; font.weight: Font.DemiBold
                            color: theme.primaryText
                        }

                        Item {
                            width: parent.width; height: 44
                            Text {
                                anchors { left: parent.left; leftMargin: 16; right: sampleRateControl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: "Sample Rate"
                                font.family: "Stack Sans Headline"; font.pixelSize: 13
                                color: theme.primaryText
                                elide: Text.ElideRight
                            }
                            SegmentedButton {
                                id: sampleRateControl
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                width: Math.min(220, parent.width * (root.compact ? 0.55 : 0.7)); implicitHeight: 28
                                model: ["44.1 kHz", "48 kHz", "96 kHz"]
                                currentIndex: {
                                    if (theme.defaultSampleRate === 44100) return 0
                                    if (theme.defaultSampleRate === 96000) return 2
                                    return 1
                                }
                                onActivated: function(idx) {
                                    const rates = [44100, 48000, 96000]
                                    theme.defaultSampleRate = rates[idx]
                                    filterEngine.sampleRate = rates[idx]
                                }
                            }
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
                                height: 1; color: theme.borderColor; opacity: 0.5
                            }
                        }

                        Item {
                            width: parent.width; height: 44
                            Text {
                                anchors { left: parent.left; leftMargin: 16; right: exportControl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: "Export Language"
                                font.family: "Stack Sans Headline"; font.pixelSize: 13
                                color: theme.primaryText
                                elide: Text.ElideRight
                            }
                            StyledCombo {
                                id: exportControl
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                width: Math.min(240, parent.width * (root.compact ? 0.55 : 0.7))
                                // Order matches dsp::ExportFormat and the Export page tabs
                                model: ["C99", "C++20", "Python", "JSON", "MATLAB / Octave", "Rust", "WebAudio JS", "CSV"]
                                currentIndex: theme.defaultExportLang
                                onActivated: {
                                    theme.defaultExportLang = currentIndex
                                    exportModel.setFormat(currentIndex)
                                    exportModel.generate(filterEngine)
                                }
                            }
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
                                height: 1; color: theme.borderColor; opacity: 0.5
                            }
                        }

                        Item {
                            width: parent.width; height: 44
                            Text {
                                anchors { left: parent.left; leftMargin: 16; right: animationControl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: "Animations"
                                font.family: "Stack Sans Headline"; font.pixelSize: 13
                                color: theme.primaryText
                                elide: Text.ElideRight
                            }
                            SegmentedButton {
                                id: animationControl
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                width: Math.min(140, parent.width * (root.compact ? 0.55 : 0.7)); implicitHeight: 28
                                model: ["Off", "On"]
                                currentIndex: theme.animationsEnabled ? 1 : 0
                                onActivated: function(idx) { theme.animationsEnabled = (idx === 1) }
                            }
                        }
                    }
                }

                // ── Installation & Updates ─────────────────────────────────────
                Rectangle {
                    width: parent.width
                    implicitHeight: updateCardCol.implicitHeight + 14
                    radius: 12
                    color: "transparent"
                    border.width: 0

                    Column {
                        id: updateCardCol
                        width: parent.width
                        spacing: 0

                        Text {
                            x: 16; topPadding: 16; bottomPadding: 10
                            text: "Updates"
                            font.family: theme.headlineFont
                            font.pixelSize: 16; font.weight: Font.DemiBold
                            color: theme.primaryText
                        }

                        // Row 1: Current status + Check for Updates button
                        Item {
                            width: parent.width; height: 50
                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: "Overtune 3 · v" + updateInstaller.currentVersion
                                        font.family: theme.headlineFont; font.pixelSize: 14
                                        font.weight: Font.DemiBold; color: theme.primaryText
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: updateInstaller.hasUpdate
                                              ? ("v" + updateInstaller.currentVersion + " → v" + updateInstaller.latestVersion)
                                              : "Up to date"
                                        font.family: theme.bodyFont
                                        font.pixelSize: 12
                                        color: updateInstaller.hasUpdate ? theme.accent : theme.primaryText
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                StyledButton {
                                    text: "Check"
                                    primary: true
                                    implicitWidth: 84
                                    implicitHeight: 30
                                    onClicked: {
                                        const w = Window.window
                                        if (w && typeof w.checkUpdatesNow === "function") {
                                            w.checkUpdatesNow()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
                                height: 1; color: theme.borderColor; opacity: 0.5
                            }
                        }

                        // Row 2: Install Path & Setup Shortcuts
                        Item {
                            width: parent.width; height: 50
                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: "System Installation"
                                        font.family: theme.headlineFont; font.pixelSize: 14
                                        font.weight: Font.DemiBold; color: theme.primaryText
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: updateInstaller.installPath
                                        font.family: theme.bodyFont
                                        font.pixelSize: 12
                                        color: theme.primaryText
                                        elide: Text.ElideMiddle
                                    }
                                }

                                StyledButton {
                                    text: "Setup"
                                    primary: false
                                    implicitWidth: 84
                                    implicitHeight: 30
                                    onClicked: {
                                        const w = Window.window
                                        if (w && typeof w.showInstallerUpdater === "function") {
                                            w.showInstallerUpdater(1)
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
                                height: 1; color: theme.borderColor; opacity: 0.5
                            }
                        }
                    }
                }

                // ── About ─────────────────────────────────────────────────────
                Rectangle {
                    width: parent.width
                    implicitHeight: aboutCol2.implicitHeight + 14
                    radius: 12
                    color: "transparent"
                    border.width: 0

                    Column {
                        id: aboutCol2
                        width: parent.width
                        spacing: 0

                        Text {
                            x: 16; topPadding: 16; bottomPadding: 10
                            text: "About"
                            font.family: theme.headlineFont
                            font.pixelSize: 16; font.weight: Font.DemiBold
                            color: theme.primaryText
                        }

                        Repeater {
                            model: [
                                { label: "Application", value: "Overtune 3" },
                                { label: "Version", value: updateInstaller.currentVersion }
                            ]
                            delegate: Item {
                                width: parent.width; height: 40
                                Text {
                                    id: aboutLabel
                                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                                    text: modelData.label
                                    font.family: theme.headlineFont; font.pixelSize: 14
                                    color: theme.primaryText
                                }
                                Text {
                                    anchors { left: aboutLabel.right; leftMargin: 12; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                    text: modelData.value
                                    font.family: theme.bodyFont; font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: theme.primaryText
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideLeft
                                }
                                Rectangle {
                                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
                                    height: 1; color: theme.borderColor
                                    opacity: index < 1 ? 0.5 : 0
                                }
                            }
                        }
                    }
                }

                // ── System Integration & Uninstall Card ──────────────────────
                Rectangle {
                    width: parent.width
                    implicitHeight: maintCol.implicitHeight + 24
                    radius: 12
                    color: "transparent"
                    border.width: 0

                    Column {
                        id: maintCol
                        width: parent.width - 32
                        x: 16
                        y: 14
                        spacing: 12

                        Text {
                        text: "Uninstall"
                        font.family: theme.headlineFont
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: theme.primaryText
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 12

                            Column {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: "Remove the app and its shortcuts"
                                    font.family: theme.headlineFont
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    color: theme.primaryText
                                }

                            }

                            Rectangle {
                                implicitWidth: 88
                                implicitHeight: 30
                                radius: 7
                                color: uninsBtnMouse.pressed ? Qt.darker(theme.danger, 1.2) : (uninsBtnMouse.containsMouse ? Qt.lighter(theme.danger, 1.08) : theme.danger)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 0
                                    Text {
                                        text: "Uninstall"
                                        font.family: "Stack Sans Headline"
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: uninsBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsUninsDialog.open()
                                }
                            }
                        }
                    }
                }

                // ── Documentation ────────────────────────────────────────────
                Item {
                    width: parent.width; height: 48
                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: "DSP Theory & Tutorials"
                        font.family: theme.headlineFont; font.pixelSize: 14
                        font.weight: Font.DemiBold; color: theme.primaryText
                        elide: Text.ElideRight
                    }
                    StyledButton {
                        id: openBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: "Open"; primary: true
                        implicitWidth: 72; implicitHeight: 30
                        onClicked: root.openDocs()
                    }
                }

                Item { width: 1; height: 8 }
            }
        }
    }

    Dialog {
        id: settingsUninsDialog
        title: "Uninstall Overtune 3"
        anchors.centerIn: parent
        modal: true
        width: Math.min(440, root.width - 32)
        padding: 0
        palette.window: theme.surface
        palette.windowText: theme.primaryText
        background: Rectangle {
            color: theme.surface
            border.color: theme.borderColor
            border.width: 1
            radius: 12
            clip: true
        }
        contentItem: Column {
            spacing: 0

            Item {
                width: parent.width - 40
                height: uninstallCopy.implicitHeight + 36
                x: 20

                Column {
                    id: uninstallCopy
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 6

                    Text {
                        width: parent.width
                        text: "Uninstall Overtune 3?"
                        font.family: theme.headlineFont
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        color: theme.primaryText
                        wrapMode: Text.Wrap
                    }

                    Text {
                        width: parent.width
                        text: "The app and its shortcuts will be removed."
                        font.family: theme.bodyFont
                        font.pixelSize: 14
                        color: theme.primaryText
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: theme.borderColor }

            Item {
                width: parent.width - 40
                height: 62
                x: 20

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 10

                    StyledButton {
                        text: "Cancel"
                        primary: false
                        implicitHeight: 34
                        onClicked: settingsUninsDialog.close()
                    }

                    StyledButton {
                        text: "Uninstall"
                        primary: false
                        danger: true
                        implicitHeight: 34
                        onClicked: {
                            settingsUninsDialog.close()
                            updateInstaller.uninstallFromSystem()
                        }
                    }
                }
            }
        }
    }
}
