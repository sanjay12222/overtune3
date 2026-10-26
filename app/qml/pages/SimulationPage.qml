import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

// SimulationPage.qml — interactive signal generator & live filter simulation
Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitWidth: 800
    implicitHeight: 600
    clip: true

    readonly property int pageMargin: width < 700 ? 12 : 20
    property alias signalPlot: sigPlot

    function generateSelectedSignal() {
        switch (signalCombo.currentIndex) {
        case 0: { // Dual-Tone
            const f1 = Math.max(200, Math.round(filterEngine.cutoffFreq * 0.4))
            const f2 = Math.min(filterEngine.sampleRate * 0.45, Math.round(filterEngine.cutoffFreq * 2.2))
            simulation.generateMultiTone(f1, f2, filterEngine.sampleRate, 0.04)
            break
        }
        case 1: { // Sine Wave
            const f = Math.max(100, Math.round(filterEngine.cutoffFreq * 0.75))
            simulation.generateSine(f, filterEngine.sampleRate, 0.04)
            break
        }
        case 2: { // Chirp Sweep
            simulation.generateChirp(100, Math.min(22000, filterEngine.sampleRate * 0.45), filterEngine.sampleRate, 0.05)
            break
        }
        case 3: { // Square Wave
            const f = Math.max(100, Math.round(filterEngine.cutoffFreq * 0.5))
            simulation.generateSquare(f, filterEngine.sampleRate, 0.04)
            break
        }
        case 4: { // White Noise
            simulation.generateNoise(0.04, filterEngine.sampleRate)
            break
        }
        }
        simulation.applyFilter(filterEngine)
        sigPlot.restartAnimation()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pageMargin
        spacing: 12

        // ── Consistent Tab Page Headline ──────────────────────────────────────
        PageHeader {
            Layout.fillWidth: true
            title: "Signal Simulation Studio"
            badgeText: filterEngine.responseName + " " + filterEngine.typeName + " (" + filterEngine.orderLabel + ")"


            // Standalone Scope Window Opener
            Rectangle {
                implicitHeight: 28
                implicitWidth: popScopeRow.implicitWidth + 16
                radius: 5
                color: popScopeMouse.containsMouse ? (theme.isDark ? "#32353A" : "#E2E5E9") : theme.surfaceHigh
                border.color: theme.borderColor
                border.width: 1

                Row {
                    id: popScopeRow
                    anchors.centerIn: parent
                    spacing: 6
                    Codicon {
                        icon: "link-external"
                        iconSize: 12
                        iconColor: theme.primaryText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Pop-out Scope"
                        font.family: "Stack Sans Headline"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: theme.primaryText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: popScopeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const w = Window.window
                        if (w && typeof w.openStandalonePlot === "function") {
                            w.openStandalonePlot(3, {})
                        }
                    }
                }
            }
        }


        // Signal Generator Toolbar
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            contentWidth: toolRow.implicitWidth
            contentHeight: 32
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentWidth > width

            Row {
                id: toolRow
                spacing: 8
                height: 32

                Text {
                    text: "Signal Source:"
                    font.family: "Stack Sans Headline"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: theme.secondaryText
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                }

                StyledCombo {
                    id: signalCombo
                    implicitWidth: 190
                    implicitHeight: 30
                    model: [
                        "Dual-Tone Wave",
                        "Sine Wave",
                        "Chirp Sweep",
                        "Square Wave",
                        "White Noise"
                    ]
                    currentIndex: 0
                    onActivated: root.generateSelectedSignal()
                }

                StyledButton {
                    text: "Run Simulation"
                    primary: true
                    implicitWidth: 124
                    implicitHeight: 30
                    onClicked: root.generateSelectedSignal()
                }

                StyledButton {
                    text: "Re-apply Filter"
                    primary: false
                    implicitWidth: 110
                    implicitHeight: 30
                    enabled: simulation.hasData
                    onClicked: {
                        simulation.applyFilter(filterEngine)
                        sigPlot.restartAnimation()
                    }
                }

                Rectangle {
                    width: 1
                    height: 18
                    color: theme.borderColor
                    opacity: 0.6
                    y: 6
                }

                StyledButton {
                    text: "Load WAV..."
                    primary: false
                    implicitWidth: 96
                    implicitHeight: 30
                    onClicked: wavDialog.open()
                }

                StyledButton {
                    text: "Load CSV..."
                    primary: false
                    implicitWidth: 92
                    implicitHeight: 30
                    onClicked: csvDialog.open()
                }

                StyledButton {
                    text: "Clear"
                    primary: false
                    implicitWidth: 64
                    implicitHeight: 30
                    enabled: simulation.hasData
                    onClicked: simulation.clear()
                }
            }
        }

        // Active Signal Status & Info Bar
        Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 6
            color: theme.surfaceHigh
            border.color: theme.borderColor
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Codicon {
                    icon: "pulse"
                    iconSize: 13
                    iconColor: theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: simulation.hasData
                        ? ("Input: " + simulation.signalLabel + "  ·  Filtered with current DSP design")
                        : "No signal active — select a signal and click Run Simulation above."
                    font.family: "Stack Sans Headline"
                    font.pixelSize: 13
                    color: theme.primaryText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 22
                radius: 4
                color: popStripMouse.containsMouse ? (theme.isDark ? "#32353A" : "#E2E5E9") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "link-external"
                    iconSize: 11
                    iconColor: popStripMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }

                ToolTip.visible: popStripMouse.containsMouse
                ToolTip.text: "Open Oscilloscope in Dedicated Window"
                ToolTip.delay: 300

                MouseArea {
                    id: popStripMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const w = Window.window
                        if (w && typeof w.openStandalonePlot === "function") {
                            w.openStandalonePlot(3, {})
                        }
                    }
                }
            }
        }


        FilterCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 200
            clip: true
            SignalPlot {
                id: sigPlot
                anchors.fill: parent
            }
        }
    }

    // Live auto-filter synchronization when filter parameters change
    Connections {
        target: filterEngine
        function onResultsChanged() {
            if (simulation.hasData) {
                simulation.applyFilter(filterEngine)
            }
        }
    }

    Component.onCompleted: {
        if (!simulation.hasData) {
            const f1 = Math.max(200, Math.round(filterEngine.cutoffFreq * 0.4))
            const f2 = Math.min(filterEngine.sampleRate * 0.45, Math.round(filterEngine.cutoffFreq * 2.2))
            simulation.generateMultiTone(f1, f2, filterEngine.sampleRate, 0.04)
        }
        simulation.applyFilter(filterEngine)
    }

    FileDialog {
        id: wavDialog
        title: "Open WAV File"
        options: FileDialog.DontUseNativeDialog
        nameFilters: ["WAV files (*.wav)", "All files (*)"]
        onAccepted: {
            simulation.loadWav(selectedFile.toString())
            simulation.applyFilter(filterEngine)
        }
    }
    FileDialog {
        id: csvDialog
        title: "Open CSV File"
        options: FileDialog.DontUseNativeDialog
        nameFilters: ["CSV files (*.csv *.txt)", "All files (*)"]
        onAccepted: {
            simulation.loadCsv(selectedFile.toString())
            simulation.applyFilter(filterEngine)
        }
    }
}
