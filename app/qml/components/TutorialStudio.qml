import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Dialogs

// TutorialStudio.qml — Student Tutorial Creator, Sharing & Interactive Player
Rectangle {
    id: root
    width: parent ? parent.width : 700
    implicitHeight: mainCol.implicitHeight + 36
    radius: 8
    color: theme.isDark ? "#1B1D1F" : "#F4F6F8"
    border.color: theme.borderColor
    border.width: 1
    clip: true

    property var tutorialsList: []
    property int selectedTutIndex: 0
    property bool isEditing: false
    property bool isPlaying: false
    property int playerStep: 0

    // Editor Form State
    property string edId: ""
    property string edTitle: "My Audio Filter Tutorial"
    property string edAuthor: "DSP Student"
    property string edCategory: "Audio Production"
    property string edDifficulty: "Beginner"
    property string edDuration: "4 min"
    property string edGoal: "Cleanly remove high-frequency hiss while keeping vocal clarity."
    property int edType: 0
    property int edResponse: 0
    property int edOrder: 4
    property double edFc: 10000.0
    property double edFc2: 0.0
    property double edFs: 48000.0
    property double edRp: 1.0
    property double edRs: 40.0
    property string edStep1: "This filter uses a 4th-order Butterworth lowpass. All frequencies below 10 kHz pass without alteration, while hiss above 10 kHz is rolled off at -24 dB/octave."
    property int edStep1Tab: 0 // 0: Design
    property string edStep2: "Look at the magnitude response: at 10 kHz, the curve is at -3 dB. At 20 kHz, it drops below -24 dB."
    property int edStep2Tab: 1 // 1: Analysis
    property string edStep3: "Observe the group delay: it remains virtually constant across the speech range, preserving sharp vocal consonants."
    property int edStep3Tab: 1
    property string edStep4: "Check the poles in the Z-plane: all poles are safely clustered at radius ~0.6 within the unit circle (|p| < 1), guaranteeing BIBO stability."
    property int edStep4Tab: 1
    property string edStep5: "Run a frequency sweep chirp in Simulation Studio: watch the high end vanish smoothly without clicks."
    property int edStep5Tab: 2 // 2: Simulation

    Component.onCompleted: refreshTutorials()

    function refreshTutorials() {
        if (typeof filterEngine !== "undefined" && typeof filterEngine.loadTutorials === "function") {
            root.tutorialsList = filterEngine.loadTutorials()
        }
    }

    function notify(msg) {
        const w = Window.window
        if (w && typeof w.showNotification === "function")
            w.showNotification(msg, false)
    }

    function goPage(idx) {
        const w = Window.window
        if (w && typeof w.navigateTo === "function")
            w.navigateTo(idx)
    }

    function startNewTutorial() {
        root.edId = "tut_custom_" + Date.now()
        root.edTitle = "Custom Filter Study Guide"
        root.edAuthor = "Student Author"
        root.edCategory = "Audio Engineering"
        root.edDifficulty = "Beginner"
        root.edDuration = "4 min"
        root.edGoal = "Explain filter rolloff and phase behavior in simple language."
        if (typeof filterEngine !== "undefined") {
            root.edType = filterEngine.filterType
            root.edResponse = filterEngine.filterResponse
            root.edOrder = filterEngine.order
            root.edFc = filterEngine.cutoffFreq
            root.edFc2 = filterEngine.cutoffFreq2
            root.edFs = filterEngine.sampleRate
            root.edRp = filterEngine.rippleDb
            root.edRs = filterEngine.stopbandDb
        }
        root.isEditing = true
        root.isPlaying = false
    }

    function loadTutorialForEdit(tut) {
        root.edId = tut.id || ("tut_" + Date.now())
        root.edTitle = tut.title || ""
        root.edAuthor = tut.author || "Student"
        root.edCategory = tut.category || "General DSP"
        root.edDifficulty = tut.difficulty || "Beginner"
        root.edDuration = tut.duration || "3 min"
        root.edGoal = tut.goal || ""
        if (tut.spec) {
            root.edType = tut.spec.filterType || 0
            root.edResponse = tut.spec.filterResponse || 0
            root.edOrder = tut.spec.order || 4
            root.edFc = tut.spec.cutoffFreq || 1000.0
            root.edFc2 = tut.spec.cutoffFreq2 || 0.0
            root.edFs = tut.spec.sampleRate || 48000.0
            root.edRp = tut.spec.rippleDb || 1.0
            root.edRs = tut.spec.stopbandDb || 40.0
        }
        if (tut.steps && tut.steps.length >= 5) {
            root.edStep1 = tut.steps[0].explanation || ""
            root.edStep1Tab = tut.steps[0].targetTab !== undefined ? tut.steps[0].targetTab : 0
            root.edStep2 = tut.steps[1].explanation || ""
            root.edStep2Tab = tut.steps[1].targetTab !== undefined ? tut.steps[1].targetTab : 1
            root.edStep3 = tut.steps[2].explanation || ""
            root.edStep3Tab = tut.steps[2].targetTab !== undefined ? tut.steps[2].targetTab : 1
            root.edStep4 = tut.steps[3].explanation || ""
            root.edStep4Tab = tut.steps[3].targetTab !== undefined ? tut.steps[3].targetTab : 1
            root.edStep5 = tut.steps[4].explanation || ""
            root.edStep5Tab = tut.steps[4].targetTab !== undefined ? tut.steps[4].targetTab : 2
        }
        root.isEditing = true
        root.isPlaying = false
    }

    function buildTutorialJson() {
        const topNames = ["Lowpass (LPF)", "Highpass (HPF)", "Bandpass (BPF)", "Bandstop (Notch)"]
        const respNames = ["Butterworth", "Chebyshev I", "Chebyshev II", "Elliptic", "Bessel", "FIR"]
        const obj = {
            overtune_version: "3.2",
            type: "overtune_interactive_tutorial",
            id: root.edId.length > 0 ? root.edId : ("tut_student_" + Date.now()),
            title: root.edTitle,
            author: root.edAuthor,
            category: root.edCategory,
            difficulty: root.edDifficulty,
            duration: root.edDuration,
            goal: root.edGoal,
            spec: {
                filterType: root.edType,
                filterResponse: root.edResponse,
                order: root.edOrder,
                cutoffFreq: root.edFc,
                cutoffFreq2: root.edFc2,
                sampleRate: root.edFs,
                rippleDb: root.edRp,
                stopbandDb: root.edRs,
                typeName: topNames[root.edType] || "Lowpass",
                responseName: respNames[root.edResponse] || "Butterworth"
            },
            steps: [
                {
                    title: "1. Signal Architecture & How It Works",
                    explanation: root.edStep1,
                    highlight: "Architecture: " + (topNames[root.edType] || "LPF") + " · " + (respNames[root.edResponse] || "Butterworth") + " · Order " + root.edOrder,
                    targetTab: root.edStep1Tab
                },
                {
                    title: "2. What to Observe in Magnitude Plot",
                    explanation: root.edStep2,
                    highlight: "Cutoff Corner: " + root.edFc + " Hz · Rolloff: -" + (root.edOrder * 6) + " dB/octave",
                    targetTab: root.edStep2Tab
                },
                {
                    title: "3. What to Observe in Phase & Group Delay",
                    explanation: root.edStep3,
                    highlight: "Phase Continuity & Transient Timing",
                    targetTab: root.edStep3Tab
                },
                {
                    title: "4. What to Observe in Z-Plane Poles",
                    explanation: root.edStep4,
                    highlight: "All poles strictly inside |z| < 1 (BIBO Stable)",
                    targetTab: root.edStep4Tab
                },
                {
                    title: "5. Real-Time Signal Audition & Simulation",
                    explanation: root.edStep5,
                    highlight: "Audible verification in Signal Simulation Studio",
                    targetTab: root.edStep5Tab
                }
            ]
        }
        return JSON.stringify(obj, null, 2)
    }

    function saveCurrentTutorial() {
        const jsonStr = buildTutorialJson()
        if (typeof filterEngine !== "undefined" && typeof filterEngine.saveTutorial === "function") {
            const ok = filterEngine.saveTutorial(jsonStr)
            if (ok) {
                notify("Tutorial saved to local student library: " + root.edTitle)
                refreshTutorials()
                root.isEditing = false
                root.isPlaying = true
                root.playerStep = 0
            } else {
                notify("Failed to save tutorial")
            }
        }
    }

    function applySpecToEngine(spec) {
        if (typeof filterEngine !== "undefined") {
            filterEngine.filterType = spec.filterType || 0
            filterEngine.filterResponse = spec.filterResponse || 0
            filterEngine.order = spec.order || 4
            filterEngine.sampleRate = spec.sampleRate || 48000.0
            filterEngine.cutoffFreq = spec.cutoffFreq || 1000.0
            filterEngine.cutoffFreq2 = spec.cutoffFreq2 || 0.0
            filterEngine.rippleDb = spec.rippleDb || 1.0
            filterEngine.stopbandDb = spec.stopbandDb || 40.0
            filterEngine.design()
            notify("Tutorial Parameters Loaded: " + (spec.typeName || "Filter") + " at " + spec.cutoffFreq + " Hz")
        }
    }

    function exportMarkdown(tut) {
        let md = "# " + tut.title + "\n\n"
        md += "**Author**: " + (tut.author || "Student") + " | **Category**: " + (tut.category || "DSP") + " | **Difficulty**: " + (tut.difficulty || "Beginner") + "\n\n"
        md += "### Target Goal\n" + (tut.goal || "") + "\n\n"
        if (tut.spec) {
            md += "### Filter Specifications\n"
            md += "- **Topology**: " + (tut.spec.typeName || "Lowpass") + "\n"
            md += "- **Approximation**: " + (tut.spec.responseName || "Butterworth") + "\n"
            md += "- **Order**: " + tut.spec.order + " (-" + (tut.spec.order * 6) + " dB/octave)\n"
            md += "- **Cutoff Frequency (Fc)**: " + tut.spec.cutoffFreq + " Hz\n"
            md += "- **Sampling Rate (Fs)**: " + tut.spec.sampleRate + " Hz\n\n"
        }
        if (tut.steps) {
            md += "### Step-by-Step Learning Guide\n"
            for (let i = 0; i < tut.steps.length; ++i) {
                md += "#### " + tut.steps[i].title + "\n"
                md += tut.steps[i].explanation + "\n\n"
            }
        }
        md += "---\n*Designed with Overtune 3 Student Tutorial Studio*\n"
        if (typeof filterEngine !== "undefined") {
            filterEngine.copyText(md)
            notify("Copied tutorial markdown guide to clipboard!")
        }
    }

    // Native File Dialogs for Export / Import
    FileDialog {
        id: exportFileDialog
        title: "Export Tutorial Package (.json)"
        options: FileDialog.DontUseNativeDialog
        fileMode: FileDialog.SaveFile
        nameFilters: ["Overtune Tutorial (*.json)", "JSON Files (*.json)"]
        onAccepted: {
            const path = exportFileDialog.selectedFile.toString()
            const jsonStr = buildTutorialJson()
            if (typeof filterEngine !== "undefined" && typeof filterEngine.writeTextFile === "function") {
                if (filterEngine.writeTextFile(path, jsonStr)) {
                    notify("Tutorial package exported to: " + path)
                }
            }
        }
    }

    FileDialog {
        id: importFileDialog
        title: "Import Student Tutorial (.json)"
        options: FileDialog.DontUseNativeDialog
        fileMode: FileDialog.OpenFile
        nameFilters: ["Overtune Tutorial (*.json)", "JSON Files (*.json)"]
        onAccepted: {
            const path = importFileDialog.selectedFile.toString()
            if (typeof filterEngine !== "undefined" && typeof filterEngine.readTextFile === "function") {
                const content = filterEngine.readTextFile(path)
                if (content && content.length > 0) {
                    try {
                        const parsed = JSON.parse(content)
                        if (parsed.title) {
                            filterEngine.saveTutorial(content)
                            notify("Imported tutorial: " + parsed.title)
                            refreshTutorials()
                            loadTutorialForEdit(parsed)
                            root.isPlaying = true
                            root.isEditing = false
                        }
                    } catch (e) {
                        notify("Failed to parse tutorial JSON file")
                    }
                }
            }
        }
    }

    Column {
        id: mainCol
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 18
        }
        spacing: 16

        // ─── Header Bar ────────────────────────────────────────────────────────
        RowLayout {
            width: parent.width
            spacing: 12

            Row {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: 30
                    height: 30
                    radius: 6
                    color: "#8A3FFC"
                    Codicon {
                        anchors.centerIn: parent
                        icon: "mortar-board"
                        iconSize: 16
                        iconColor: "#FFFFFF"
                    }
                }

                Column {
                    spacing: 2
                    Text {
                        text: "Student Tutorial Creator & Sharing Studio"
                        font.family: "Stack Sans Headline"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: theme.primaryText
                    }
                    Text {
                        text: "Author custom filter tutorials in plain English, guide peers on what to observe, and export shareable JSON packages."
                        font.family: "Stack Sans Headline"
                        font.pixelSize: 11
                        color: theme.secondaryText
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Action: Create New Tutorial
            Rectangle {
                width: newTutRow.implicitWidth + 18
                height: 28
                radius: 4
                color: newTutHov.hovered ? (theme.isDark ? "#3A2A54" : "#EBE3FA") : (theme.isDark ? "#2A1D3D" : "#F4EAFF")
                border.color: "#8A3FFC"
                border.width: 1

                Row {
                    id: newTutRow
                    anchors.centerIn: parent
                    spacing: 6
                    Codicon { icon: "add"; iconSize: 13; iconColor: "#8A3FFC"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Create Tutorial"; font.family: "Stack Sans Headline"; font.pixelSize: 11; font.weight: Font.DemiBold; color: theme.isDark ? "#D2A8FF" : "#8A3FFC"; anchors.verticalCenter: parent.verticalCenter }
                }

                HoverHandler { id: newTutHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.startNewTutorial() }
            }

            // Action: Import Shared Tutorial File
            Rectangle {
                width: impRow.implicitWidth + 16
                height: 28
                radius: 4
                color: impHov.hovered ? (theme.isDark ? "#2A2D2E" : "#EAEAEA") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Row {
                    id: impRow
                    anchors.centerIn: parent
                    spacing: 6
                    Codicon { icon: "folder-opened"; iconSize: 13; iconColor: theme.secondaryText; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Import .json"; font.family: "Stack Sans Headline"; font.pixelSize: 11; font.weight: Font.Medium; color: theme.primaryText; anchors.verticalCenter: parent.verticalCenter }
                }

                HoverHandler { id: impHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: importFileDialog.open() }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // MODE A: INTERACTIVE TUTORIAL PLAYER / RUNNER
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            visible: root.isPlaying && !root.isEditing
            width: parent.width
            implicitHeight: playerCol.implicitHeight + 24
            radius: 6
            color: theme.isDark ? "#161617" : "#FFFFFF"
            border.color: theme.borderColor
            border.width: 1

            Column {
                id: playerCol
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 16
                }
                spacing: 14

                // Top bar of player: Title, Author, Close/Edit buttons
                RowLayout {
                    width: parent.width

                    Column {
                        spacing: 3
                        Text {
                            text: root.tutorialsList.length > root.selectedTutIndex ? root.tutorialsList[root.selectedTutIndex].title : root.edTitle
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: theme.primaryText
                        }
                        Text {
                            text: "Author: " + (root.tutorialsList.length > root.selectedTutIndex ? root.tutorialsList[root.selectedTutIndex].author : root.edAuthor) +
                                  "  •  " + (root.tutorialsList.length > root.selectedTutIndex ? root.tutorialsList[root.selectedTutIndex].category : root.edCategory) +
                                  "  •  Difficulty: " + (root.tutorialsList.length > root.selectedTutIndex ? root.tutorialsList[root.selectedTutIndex].difficulty : root.edDifficulty)
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 11
                            color: theme.secondaryText
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Apply to Engine
                    Rectangle {
                        width: playApplyRow.implicitWidth + 14
                        height: 26
                        radius: 4
                        color: Qt.darker(theme.accent, 1.1)

                        Row {
                            id: playApplyRow
                            anchors.centerIn: parent
                            spacing: 6
                            Codicon { icon: "zap"; iconSize: 12; iconColor: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Load Parameters"; font.family: "Stack Sans Headline"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                const t = root.tutorialsList[root.selectedTutIndex]
                                if (t && t.spec) root.applySpecToEngine(t.spec)
                            }
                        }
                    }

                    // Edit
                    Rectangle {
                        width: 26; height: 26; radius: 4; color: "transparent"; border.color: theme.borderColor; border.width: 1
                        Codicon { anchors.centerIn: parent; icon: "edit"; iconSize: 13; iconColor: theme.secondaryText }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                const t = root.tutorialsList[root.selectedTutIndex]
                                if (t) root.loadTutorialForEdit(t)
                            }
                        }
                    }

                    // Back to list
                    Rectangle {
                        width: 26; height: 26; radius: 4; color: "transparent"; border.color: theme.borderColor; border.width: 1
                        Codicon { anchors.centerIn: parent; icon: "close"; iconSize: 13; iconColor: theme.secondaryText }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.isPlaying = false }
                    }
                }

                // Goal Callout Box
                Rectangle {
                    width: parent.width
                    implicitHeight: goalCol.implicitHeight + 16
                    radius: 4
                    color: theme.isDark ? "#1A1A1A" : "#F6F8FA"
                    border.color: theme.borderColor
                    border.width: 1

                    Column {
                        id: goalCol
                        anchors { left: parent.left; right: parent.right; margins: 12; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Text { text: "Problem / Learning Goal:"; font.family: "Stack Sans Headline"; font.pixelSize: 11; font.weight: Font.DemiBold; color: theme.secondaryText }
                        Text {
                            width: parent.width
                            text: root.tutorialsList.length > root.selectedTutIndex ? root.tutorialsList[root.selectedTutIndex].goal : root.edGoal
                            font.family: "Stack Sans Headline"; font.pixelSize: 12; color: theme.primaryText; wrapMode: Text.WordWrap
                        }
                    }
                }

                // Stepper tabs (1 to 5)
                Row {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: [
                            { idx: 0, label: "1. Signal Path" },
                            { idx: 1, label: "2. Magnitude" },
                            { idx: 2, label: "3. Phase & Delay" },
                            { idx: 3, label: "4. Z-Plane Poles" },
                            { idx: 4, label: "5. Simulation" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: root.playerStep === modelData.idx
                            width: (parent.width - 16) / 5
                            height: 28
                            radius: 4
                            color: active ? theme.accent : (pStepHov.hovered ? (theme.isDark ? "#282C34" : "#EAEAEA") : "transparent")
                            border.color: active ? theme.accent : theme.borderColor
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: "Stack Sans Headline"
                                font.pixelSize: 11
                                font.weight: parent.active ? Font.DemiBold : Font.Normal
                                color: parent.active ? "#FFFFFF" : theme.primaryText
                            }

                            HoverHandler { id: pStepHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.playerStep = modelData.idx }
                        }
                    }
                }

                // Step Detailed Observation Box
                Rectangle {
                    width: parent.width
                    implicitHeight: stepBodyCol.implicitHeight + 20
                    radius: 4
                    color: theme.isDark ? "#1C2025" : "#EDF3FA"
                    border.color: theme.accent
                    border.width: 1

                    Column {
                        id: stepBodyCol
                        anchors { left: parent.left; right: parent.right; margins: 14; verticalCenter: parent.verticalCenter }
                        spacing: 8

                        Text {
                            text: {
                                const t = root.tutorialsList[root.selectedTutIndex]
                                if (t && t.steps && t.steps.length > root.playerStep)
                                    return t.steps[root.playerStep].title
                                return "Step " + (root.playerStep + 1)
                            }
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: theme.accent
                        }

                        Text {
                            width: parent.width
                            text: {
                                const t = root.tutorialsList[root.selectedTutIndex]
                                if (t && t.steps && t.steps.length > root.playerStep)
                                    return t.steps[root.playerStep].explanation
                                return ""
                            }
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 12
                            color: theme.primaryText
                            wrapMode: Text.WordWrap
                            lineHeight: 1.45
                        }

                        Rectangle {
                            width: parent.width
                            height: 28
                            radius: 3
                            color: theme.isDark ? "#14171A" : "#FFFFFF"
                            border.color: theme.borderColor
                            border.width: 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Codicon { icon: "eye"; iconSize: 12; iconColor: theme.accent; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: {
                                        const t = root.tutorialsList[root.selectedTutIndex]
                                        if (t && t.steps && t.steps.length > root.playerStep)
                                            return t.steps[root.playerStep].highlight
                                        return ""
                                    }
                                    font.family: "Stack Sans Headline"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: theme.accent
                                }
                            }
                        }
                    }
                }

                // Player Footer Stepper & Jump Links
                RowLayout {
                    width: parent.width

                    Rectangle {
                        visible: root.playerStep > 0
                        width: pPrevRow.implicitWidth + 14
                        height: 26
                        radius: 4
                        color: "transparent"
                        border.color: theme.borderColor
                        border.width: 1

                        Row {
                            id: pPrevRow
                            anchors.centerIn: parent
                            spacing: 4
                            Codicon { icon: "chevron-left"; iconSize: 12; iconColor: theme.secondaryText; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Prev"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.primaryText; anchors.verticalCenter: parent.verticalCenter }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.playerStep = Math.max(0, root.playerStep - 1) }
                    }

                    Item { Layout.fillWidth: true }

                    // Direct Jump Links
                    Row {
                        spacing: 8
                        Rectangle {
                            id: jumpBtn
                            property int tgtTab: {
                                const t = root.tutorialsList[root.selectedTutIndex]
                                if (t && t.steps && t.steps.length > root.playerStep) {
                                    if (t.steps[root.playerStep].targetTab !== undefined)
                                        return t.steps[root.playerStep].targetTab
                                }
                                return 5 // None
                            }
                            property string tabName: tgtTab === 0 ? "Design Studio" : (tgtTab === 1 ? "Analysis/Poles" : (tgtTab === 2 ? "Simulation" : "Open Tab"))
                            visible: tgtTab < 3
                            width: j1.implicitWidth + 12; height: 26; radius: 4; color: "transparent"; border.color: theme.borderColor; border.width: 1
                            Row { 
                                id: j1; anchors.centerIn: parent; spacing: 4 
                                Codicon { icon: "link-external"; iconSize: 11; iconColor: theme.accent } 
                                Text { text: "Go to " + jumpBtn.tabName; font.pixelSize: 10; font.family: "Stack Sans Headline"; color: theme.accent } 
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.goPage(jumpBtn.tgtTab) }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        visible: root.playerStep < 4
                        width: pNextRow.implicitWidth + 14
                        height: 26
                        radius: 4
                        color: theme.accent

                        Row {
                            id: pNextRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "Next"; font.family: "Stack Sans Headline"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                            Codicon { icon: "chevron-right"; iconSize: 12; iconColor: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.playerStep = Math.min(4, root.playerStep + 1) }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // MODE B: TUTORIAL CREATOR / EDITOR (Visual Wizard in Simple Language)
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            visible: root.isEditing
            width: parent.width
            implicitHeight: editorCol.implicitHeight + 24
            radius: 6
            color: theme.isDark ? "#161617" : "#FFFFFF"
            border.color: "#8A3FFC"
            border.width: 1.5

            Column {
                id: editorCol
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 16
                }
                spacing: 12

                RowLayout {
                    width: parent.width
                    Text { text: "Tutorial Creator: Design in Simple Language"; font.family: "Stack Sans Headline"; font.pixelSize: 14; font.weight: Font.Bold; color: theme.primaryText }
                    Item { Layout.fillWidth: true }
                    // Load current settings from filter engine
                    Rectangle {
                        width: curEngineRow.implicitWidth + 14
                        height: 24
                        radius: 4
                        color: theme.isDark ? "#282C34" : "#EAEAEA"
                        border.color: theme.borderColor
                        border.width: 1

                        Row {
                            id: curEngineRow
                            anchors.centerIn: parent
                            spacing: 4
                            Codicon { icon: "refresh"; iconSize: 11; iconColor: theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Grab Current Studio Specs"; font.family: "Stack Sans Headline"; font.pixelSize: 10; color: theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (typeof filterEngine !== "undefined") {
                                    root.edType = filterEngine.filterType
                                    root.edResponse = filterEngine.filterResponse
                                    root.edOrder = filterEngine.order
                                    root.edFc = filterEngine.cutoffFreq
                                    root.edFc2 = filterEngine.cutoffFreq2
                                    root.edFs = filterEngine.sampleRate
                                    root.edRp = filterEngine.rippleDb
                                    root.edRs = filterEngine.stopbandDb
                                    root.notify("Copied current Filter Designer Studio parameters into tutorial editor!")
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: 22; height: 22; radius: 3; color: "transparent"; border.color: theme.borderColor; border.width: 1
                        Codicon { anchors.centerIn: parent; icon: "close"; iconSize: 11; iconColor: theme.secondaryText }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.isEditing = false }
                    }
                }

                // Grid of inputs: Title, Author, Category, Difficulty
                GridLayout {
                    width: parent.width
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 14

                    Column {
                        Layout.fillWidth: true; spacing: 3
                        Text { text: "Tutorial Title (Clear & Descriptive):"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.secondaryText }
                        TextField {
                            width: parent.width; height: 30; text: root.edTitle; font.family: "Stack Sans Headline"; font.pixelSize: 12
                            color: theme.primaryText; background: Rectangle { color: theme.isDark ? "#202020" : "#F0F0F0"; radius: 4; border.color: theme.borderColor; border.width: 1 }
                            onTextChanged: root.edTitle = text
                        }
                    }

                    Column {
                        Layout.fillWidth: true; spacing: 3
                        Text { text: "Your Name / Student ID:"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.secondaryText }
                        TextField {
                            width: parent.width; height: 30; text: root.edAuthor; font.family: "Stack Sans Headline"; font.pixelSize: 12
                            color: theme.primaryText; background: Rectangle { color: theme.isDark ? "#202020" : "#F0F0F0"; radius: 4; border.color: theme.borderColor; border.width: 1 }
                            onTextChanged: root.edAuthor = text
                        }
                    }

                    Column {
                        Layout.fillWidth: true; spacing: 3
                        Text { text: "Category (e.g. Audio, Speech, Bio-Med, Sensors):"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.secondaryText }
                        TextField {
                            width: parent.width; height: 30; text: root.edCategory; font.family: "Stack Sans Headline"; font.pixelSize: 12
                            color: theme.primaryText; background: Rectangle { color: theme.isDark ? "#202020" : "#F0F0F0"; radius: 4; border.color: theme.borderColor; border.width: 1 }
                            onTextChanged: root.edCategory = text
                        }
                    }

                    Column {
                        Layout.fillWidth: true; spacing: 3
                        Text { text: "Problem Goal in Simple Words:"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.secondaryText }
                        TextField {
                            width: parent.width; height: 30; text: root.edGoal; font.family: "Stack Sans Headline"; font.pixelSize: 12
                            color: theme.primaryText; background: Rectangle { color: theme.isDark ? "#202020" : "#F0F0F0"; radius: 4; border.color: theme.borderColor; border.width: 1 }
                            onTextChanged: root.edGoal = text
                        }
                    }
                }

                // Step explanations
                Column {
                    width: parent.width
                    spacing: 8

                    Text { text: "Guided Explanations for Peers (Tell them what to observe!):"; font.family: "Stack Sans Headline"; font.pixelSize: 12; font.weight: Font.DemiBold; color: theme.primaryText }

                    Column {
                        width: parent.width; spacing: 3
                        Text { text: "1. How the filter works in plain language:"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.secondaryText }
                        TextArea {
                            width: parent.width; height: 50; text: root.edStep1; font.family: "Stack Sans Headline"; font.pixelSize: 11
                            color: theme.primaryText; wrapMode: Text.WordWrap; background: Rectangle { color: theme.isDark ? "#202020" : "#F0F0F0"; radius: 4; border.color: theme.borderColor; border.width: 1 }
                            onTextChanged: root.edStep1 = text
                        }
                    }

                    Column {
                        width: parent.width; spacing: 3
                        Text { text: "2. What to observe in the Magnitude Plot (Cutoff & slope):"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.secondaryText }
                        TextArea {
                            width: parent.width; height: 46; text: root.edStep2; font.family: "Stack Sans Headline"; font.pixelSize: 11
                            color: theme.primaryText; wrapMode: Text.WordWrap; background: Rectangle { color: theme.isDark ? "#202020" : "#F0F0F0"; radius: 4; border.color: theme.borderColor; border.width: 1 }
                            onTextChanged: root.edStep2 = text
                        }
                    }

                    Column {
                        width: parent.width; spacing: 3
                        Text { text: "3. What to observe in Phase & Group Delay (Timing):"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.secondaryText }
                        TextArea {
                            width: parent.width; height: 46; text: root.edStep3; font.family: "Stack Sans Headline"; font.pixelSize: 11
                            color: theme.primaryText; wrapMode: Text.WordWrap; background: Rectangle { color: theme.isDark ? "#202020" : "#F0F0F0"; radius: 4; border.color: theme.borderColor; border.width: 1 }
                            onTextChanged: root.edStep3 = text
                        }
                    }

                    Column {
                        width: parent.width; spacing: 3
                        Text { text: "4. What to observe in Z-Plane Poles (Stability check):"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.secondaryText }
                        TextArea {
                            width: parent.width; height: 46; text: root.edStep4; font.family: "Stack Sans Headline"; font.pixelSize: 11
                            color: theme.primaryText; wrapMode: Text.WordWrap; background: Rectangle { color: theme.isDark ? "#202020" : "#F0F0F0"; radius: 4; border.color: theme.borderColor; border.width: 1 }
                            onTextChanged: root.edStep4 = text
                        }
                    }

                    Column {
                        width: parent.width; spacing: 3
                        Text { text: "5. Real-Time Signal Audition (What sound changes to listen for):"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.secondaryText }
                        TextArea {
                            width: parent.width; height: 46; text: root.edStep5; font.family: "Stack Sans Headline"; font.pixelSize: 11
                            color: theme.primaryText; wrapMode: Text.WordWrap; background: Rectangle { color: theme.isDark ? "#202020" : "#F0F0F0"; radius: 4; border.color: theme.borderColor; border.width: 1 }
                            onTextChanged: root.edStep5 = text
                        }
                    }
                }

                // Action buttons: Save, Export .json, Copy Markdown, Cancel
                RowLayout {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: saveTutRow.implicitWidth + 16; height: 28; radius: 4; color: "#8A3FFC"
                        Row { 
                            id: saveTutRow; anchors.centerIn: parent; spacing: 6 
                            Codicon { icon: "save"; iconSize: 12; iconColor: "#FFFFFF" } 
                            Text { text: "Save & Play Tutorial"; font.family: "Stack Sans Headline"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#FFFFFF" } 
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.saveCurrentTutorial() }
                    }

                    Rectangle {
                        width: expJsonRow.implicitWidth + 14; height: 28; radius: 4; color: "transparent"; border.color: theme.borderColor; border.width: 1
                        Row { 
                            id: expJsonRow; anchors.centerIn: parent; spacing: 6 
                            Codicon { icon: "export"; iconSize: 12; iconColor: theme.secondaryText } 
                            Text { text: "Export .json File"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.primaryText } 
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: exportFileDialog.open() }
                    }

                    Rectangle {
                        width: copyJsonRow.implicitWidth + 14; height: 28; radius: 4; color: "transparent"; border.color: theme.borderColor; border.width: 1
                        Row { 
                            id: copyJsonRow; anchors.centerIn: parent; spacing: 6 
                            Codicon { icon: "copy"; iconSize: 12; iconColor: theme.secondaryText } 
                            Text { text: "Copy JSON"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.primaryText } 
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (typeof filterEngine !== "undefined") {
                                    filterEngine.copyText(root.buildTutorialJson())
                                    root.notify("Copied tutorial JSON package to clipboard!")
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: copyMdRow.implicitWidth + 14; height: 28; radius: 4; color: "transparent"; border.color: theme.borderColor; border.width: 1
                        Row { 
                            id: copyMdRow; anchors.centerIn: parent; spacing: 6 
                            Codicon { icon: "book"; iconSize: 12; iconColor: theme.secondaryText } 
                            Text { text: "Copy Markdown"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.primaryText } 
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                const tut = JSON.parse(root.buildTutorialJson())
                                root.exportMarkdown(tut)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 70; height: 28; radius: 4; color: "transparent"; border.color: theme.borderColor; border.width: 1
                        Text { anchors.centerIn: parent; text: "Cancel"; font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.secondaryText }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.isEditing = false }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // MODE C: TUTORIALS REPOSITORY (Cards list for selection & sharing)
        // ═════════════════════════════════════════════════════════════════════
        Column {
            width: parent.width
            spacing: 10
            visible: !root.isEditing && !root.isPlaying

            Text {
                text: "Student & Community Tutorials Library (" + root.tutorialsList.length + " available)"
                font.family: "Stack Sans Headline"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: theme.primaryText
            }

            Repeater {
                model: root.tutorialsList
                delegate: Rectangle {
                    id: tutCard
                    required property int index
                    required property var modelData

                    width: parent.width
                    implicitHeight: cardCol.implicitHeight + 20
                    radius: 6
                    color: theme.surface
                    border.color: theme.borderColor
                    border.width: 1

                    Column {
                        id: cardCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 8

                        RowLayout {
                            width: parent.width

                            Row {
                                spacing: 8
                                Rectangle {
                                    width: diffTag.implicitWidth + 8; height: 20; radius: 3
                                    color: modelData.difficulty === "Beginner" ? (theme.isDark ? "#1C3D27" : "#E6F4EA") : (theme.isDark ? "#3D2B1C" : "#FFF3E6")
                                    Text {
                                        id: diffTag; anchors.centerIn: parent; text: modelData.difficulty || "Beginner"
                                        font.family: "Stack Sans Headline"; font.pixelSize: 10; font.weight: Font.Medium
                                        color: modelData.difficulty === "Beginner" ? "#30D158" : "#FF9500"
                                    }
                                }
                                Text {
                                    text: modelData.category || "Audio DSP"
                                    font.family: "Stack Sans Headline"; font.pixelSize: 11; color: theme.secondaryText; anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "by " + (modelData.author || "Student")
                                font.family: "Stack Sans Headline"; font.pixelSize: 11; font.weight: Font.Medium; color: theme.accent
                            }
                        }

                        Text {
                            text: modelData.title || "Custom Tutorial"
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: theme.primaryText
                        }

                        Text {
                            width: parent.width
                            text: modelData.goal || "Guided digital filter study."
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 11
                            color: theme.secondaryText
                            wrapMode: Text.WordWrap
                            lineHeight: 1.35
                        }

                        // Bottom Actions: Play, Load Spec, Copy Markdown, Delete
                        RowLayout {
                            width: parent.width

                            // Play Tutorial
                            Rectangle {
                                width: playRow.implicitWidth + 14
                                height: 24
                                radius: 4
                                color: playHov.hovered ? Qt.darker(theme.accent, 1.1) : theme.accent

                                Row {
                                    id: playRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Codicon { icon: "play"; iconSize: 11; iconColor: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Interactive Run"; font.family: "Stack Sans Headline"; font.pixelSize: 10; font.weight: Font.DemiBold; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                                }
                                HoverHandler { id: playHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        root.selectedTutIndex = index
                                        root.isPlaying = true
                                        root.playerStep = 0
                                        if (modelData.spec) root.applySpecToEngine(modelData.spec)
                                    }
                                }
                            }

                            // Quick-Load Spec
                            Rectangle {
                                width: qLoadRow.implicitWidth + 12
                                height: 24
                                radius: 4
                                color: "transparent"
                                border.color: theme.borderColor
                                border.width: 1

                                Row {
                                    id: qLoadRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Codicon { icon: "zap"; iconSize: 11; iconColor: theme.secondaryText; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Load Spec"; font.family: "Stack Sans Headline"; font.pixelSize: 10; color: theme.primaryText; anchors.verticalCenter: parent.verticalCenter }
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        if (modelData.spec) root.applySpecToEngine(modelData.spec)
                                    }
                                }
                            }

                            // Copy Markdown
                            Rectangle {
                                width: cMdRow.implicitWidth + 12
                                height: 24
                                radius: 4
                                color: "transparent"
                                border.color: theme.borderColor
                                border.width: 1

                                Row {
                                    id: cMdRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Codicon { icon: "copy"; iconSize: 11; iconColor: theme.secondaryText; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Markdown"; font.family: "Stack Sans Headline"; font.pixelSize: 10; color: theme.primaryText; anchors.verticalCenter: parent.verticalCenter }
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: root.exportMarkdown(modelData) }
                            }

                            // Copy JSON
                            Rectangle {
                                width: cJRow.implicitWidth + 12
                                height: 24
                                radius: 4
                                color: "transparent"
                                border.color: theme.borderColor
                                border.width: 1

                                Row {
                                    id: cJRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Codicon { icon: "json"; iconSize: 11; iconColor: theme.secondaryText; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "JSON"; font.family: "Stack Sans Headline"; font.pixelSize: 10; color: theme.primaryText; anchors.verticalCenter: parent.verticalCenter }
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        if (typeof filterEngine !== "undefined") {
                                            filterEngine.copyText(JSON.stringify(modelData, null, 2))
                                            root.notify("Copied tutorial JSON to clipboard!")
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Delete (if custom)
                            Rectangle {
                                width: 24; height: 24; radius: 3; color: "transparent"; border.color: theme.borderColor; border.width: 1
                                Codicon { anchors.centerIn: parent; icon: "trash"; iconSize: 11; iconColor: delHov.hovered ? "#FF453A" : theme.secondaryText }
                                HoverHandler { id: delHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        if (typeof filterEngine !== "undefined" && typeof filterEngine.deleteTutorial === "function") {
                                            filterEngine.deleteTutorial(modelData.id)
                                            root.notify("Deleted tutorial: " + modelData.title)
                                            root.refreshTutorials()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
