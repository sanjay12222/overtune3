import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "components"
import "pages"

// Main.qml — Root application window with global shortcuts & toast notifications
Window {
    id: root
    title:         "Overtune " + updateInstaller.currentVersion + " — Digital Filter Designer & DSP Studio"
    width:         1280
    height:        800
    minimumWidth:  860
    minimumHeight: 600
    visible:       true
    color:         theme.background

    palette.window:          theme.background
    palette.windowText:      theme.primaryText
    palette.base:            theme.surface
    palette.text:            theme.primaryText
    palette.button:          theme.surfaceHigh
    palette.buttonText:      theme.primaryText
    palette.highlight:       theme.accent
    palette.highlightedText: "#FFFFFF"
    palette.mid:             theme.borderColor

    readonly property bool isNarrow: width < 820
    readonly property bool isCompact: width < 1100
    readonly property int contentMargin: isNarrow ? 12 : 20

    // ── Bundled fonts (Stack Sans Headline, Inter, Codicons) ───────────────────
    FontLoader { id: stackSansRegular;  source: "qrc:/FilterDesigner/fonts/StackSansHeadline-Regular.ttf" }
    FontLoader { id: stackSansMedium;   source: "qrc:/FilterDesigner/fonts/StackSansHeadline-Medium.ttf" }
    FontLoader { id: stackSansSemiBold; source: "qrc:/FilterDesigner/fonts/StackSansHeadline-SemiBold.ttf" }
    FontLoader { id: stackSansBold;     source: "qrc:/FilterDesigner/fonts/StackSansHeadline-Bold.ttf" }
    FontLoader { id: interRegular;      source: "qrc:/FilterDesigner/fonts/Inter-Regular.ttf" }
    FontLoader { id: codiconFont;       source: "qrc:/FilterDesigner/fonts/codicon.ttf" }

    readonly property bool fontsReady:
        stackSansRegular.status === FontLoader.Ready &&
        codiconFont.status === FontLoader.Ready

    function navigateTo(pageIndex) {
        const n = Math.max(0, Math.min(5, pageIndex | 0))
        if (sidebar.currentPage !== n)
            sidebar.currentPage = n
    }

    function nextTab() {
        navigateTo((sidebar.currentPage + 1) % 6)
        showTabName()
    }

    function prevTab() {
        navigateTo((sidebar.currentPage + 5) % 6)
        showTabName()
    }

    function showTabName() {
        const names = [
            "Filter Designer Studio",
            "Frequency Analysis Suite",
            "Signal Simulation Studio",
            "Production Code Exporter",
            "Documentation & Theory",
            "Workspace Settings"
        ]
        showNotification("Workspace: " + names[sidebar.currentPage], false)
    }

    function doReset() {
        if (typeof filterEngine !== "undefined" && typeof filterEngine.reset === "function") {
            filterEngine.reset()
            filterEngine.sampleRate = theme.defaultSampleRate
            filterEngine.design()
        }
        showNotification("Filter reset to default (Butterworth 4th-order LPF @ 1 kHz, Fs "
                         + (theme.defaultSampleRate / 1000) + " kHz)", false)
    }

    function doClear() {
        if (typeof simulation !== "undefined" && typeof simulation.clear === "function") {
            simulation.clear()
        }
        showNotification("Simulation signal buffer cleared", false)
    }

    function doSave() {
        if (sidebar.currentPage !== 3) {
            navigateTo(3)
        }
        exportModel.generate(filterEngine)
        if (exportPage && typeof exportPage.openSaveDialog === "function") {
            exportPage.openSaveDialog()
        }
        showNotification("Opened Save Code dialog", false)
    }

    function doAutoScale() {
        if (sidebar.currentPage === 0 && designPage && designPage.freqPlot) {
            designPage.freqPlot.autoScale()
            showNotification("Auto-scaled frequency response (Desmos Fit)", false)
        } else if (sidebar.currentPage === 1 && analysisPage) {
            analysisPage.autoScaleAll()
            showNotification("Auto-scaled analysis plots (Desmos Fit)", false)
        } else if (sidebar.currentPage === 2 && simulationPage && simulationPage.signalPlot) {
            simulationPage.signalPlot.autoScale()
            showNotification("Auto-scaled simulation waveform (Desmos Fit)", false)
        }
    }

    function doZoomIn() {
        if (sidebar.currentPage === 0 && designPage && designPage.freqPlot) {
            designPage.freqPlot.zoomCenter(0.8)
        } else if (sidebar.currentPage === 2 && simulationPage && simulationPage.signalPlot) {
            simulationPage.signalPlot.zoomCenter(0.8)
        }
    }

    function doZoomOut() {
        if (sidebar.currentPage === 0 && designPage && designPage.freqPlot) {
            designPage.freqPlot.zoomCenter(1.25)
        } else if (sidebar.currentPage === 2 && simulationPage && simulationPage.signalPlot) {
            simulationPage.signalPlot.zoomCenter(1.25)
        }
    }

    Component {
        id: standalonePlotComp
        StandalonePlotWindow {}
    }

    function openStandalonePlot(type, props) {
        var w = standalonePlotComp.createObject(root, {
            plotType: (type !== undefined ? type : 0),
            extraProps: (props || {})
        });
        if (w) {
            w.show();
            w.raise();
            w.requestActivate();
            root.showNotification("Opened plot in dedicated high-res window", false);
        }
        return w;
    }


    // ── Global Toast / Snackbar Notification ──────────────────────────────────
    Rectangle {
        id: snackBar
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 24
            leftMargin: 16
            rightMargin: 16
        }
        width: Math.min(parent.width - 32, Math.max(220, snackContentRow.implicitWidth + 32))
        height: 38
        radius: 8
        color: snackIsError ? theme.danger : (theme.isDark ? "#252526" : "#2C2C2C")
        border.color: snackIsError ? theme.danger : theme.borderColor
        border.width: 1
        opacity: 0
        z: 100
        clip: true

        property bool snackIsError: false

        Row {
            id: snackContentRow
            anchors.centerIn: parent
            spacing: 8

            Codicon {
                icon: snackBar.snackIsError ? "error" : "check"
                iconSize: 14
                iconColor: snackBar.snackIsError ? "#FFFFFF" : "#30D158"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: snackText
                color: "#FFFFFF"
                font.family: "Stack Sans Headline"
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Behavior on opacity { NumberAnimation { duration: 180 } }

        Timer {
            id: snackHideTimer
            interval: 2400
            onTriggered: snackBar.opacity = 0
        }
    }

    function showNotification(msg, isError) {
        snackText.text = msg
        snackBar.snackIsError = !!isError
        snackBar.opacity = 1
        snackHideTimer.restart()
    }

    Connections {
        target: filterEngine
        function onErrorOccurred(msg) {
            showNotification(msg, true)
        }
    }

    Connections {
        target: simulation
        function onErrorOccurred(msg) {
            showNotification(msg, true)
        }
    }

    // ── Keyboard Shortcuts: Reset, Clear, Save, Tab Change ───────────────────
    // Tab Change Shortcuts
    Shortcut {
        sequence: "Ctrl+Tab"
        onActivated: root.nextTab()
    }
    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        onActivated: root.prevTab()
    }
    Shortcut {
        sequence: "Ctrl+PageDown"
        onActivated: root.nextTab()
    }
    Shortcut {
        sequence: "Ctrl+PageUp"
        onActivated: root.prevTab()
    }

    // Direct Tab Select Shortcuts (Ctrl+1 .. Ctrl+6)
    Shortcut { sequence: "Ctrl+1"; onActivated: { root.navigateTo(0); root.showTabName(); } }
    Shortcut { sequence: "Ctrl+2"; onActivated: { root.navigateTo(1); root.showTabName(); } }
    Shortcut { sequence: "Ctrl+3"; onActivated: { root.navigateTo(2); root.showTabName(); } }
    Shortcut { sequence: "Ctrl+4"; onActivated: { root.navigateTo(3); root.showTabName(); } }
    Shortcut { sequence: "Ctrl+5"; onActivated: { root.navigateTo(4); root.showTabName(); } }
    Shortcut { sequence: "Ctrl+6"; onActivated: { root.navigateTo(5); root.showTabName(); } }
    Shortcut { sequence: "Ctrl+,"; onActivated: { root.navigateTo(5); root.showTabName(); } }

    // Plot Sub-tab Shortcuts on Design Studio (Alt+1: Magnitude, Alt+2: Phase, Alt+3: Group Delay)
    Shortcut {
        sequence: "Alt+1"
        onActivated: {
            if (sidebar.currentPage === 0 && designPage) {
                designPage.setPlotMode(0)
                root.showNotification("Plot Mode: Magnitude (dB)", false)
            }
        }
    }
    Shortcut {
        sequence: "Alt+2"
        onActivated: {
            if (sidebar.currentPage === 0 && designPage) {
                designPage.setPlotMode(1)
                root.showNotification("Plot Mode: Phase (°)", false)
            }
        }
    }
    Shortcut {
        sequence: "Alt+3"
        onActivated: {
            if (sidebar.currentPage === 0 && designPage) {
                designPage.setPlotMode(2)
                root.showNotification("Plot Mode: Group Delay (samples)", false)
            }
        }
    }

    // Save Shortcut (Ctrl+S)
    Shortcut {
        sequence: StandardKey.Save
        onActivated: root.doSave()
    }

    // Reset Shortcut (Ctrl+R / F5)
    Shortcut {
        sequences: ["Ctrl+R", "F5"]
        onActivated: root.doReset()
    }

    // Clear Shortcut (Ctrl+K / Ctrl+Backspace / Ctrl+L)
    Shortcut {
        sequences: ["Ctrl+K", "Ctrl+L", "Ctrl+Backspace"]
        onActivated: root.doClear()
    }

    // Zoom & Desmos Fit Shortcuts
    Shortcut {
        sequence: "Ctrl+0"
        onActivated: root.doAutoScale()
    }
    Shortcut {
        sequences: ["Ctrl+=", "Ctrl++"]
        onActivated: root.doZoomIn()
    }
    Shortcut {
        sequence: "Ctrl+-"
        onActivated: root.doZoomOut()
    }

    // Theme Toggle Shortcut
    Shortcut {
        sequence: "Ctrl+T"
        onActivated: {
            theme.themeMode = theme.isDark ? 1 : 2
            root.showNotification("Theme: " + (theme.isDark ? "Dark Mode" : "Light Mode"), false)
        }
    }

    // ── Main layout ───────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        // Avoid painting before fonts register (prevents glyph flash)
        opacity: root.fontsReady ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        WindowMenuBar {
            id: windowMenuBar
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            rootWindow: root
        }

        Sidebar {
            id: sidebar
            anchors {
                top: windowMenuBar.bottom
                left: parent.left
                bottom: parent.bottom
            }
            width: 48

            onCurrentPageChanged: {
                pageTransitionAnim.restart()
                pageStack.currentIndex = currentPage
                if (currentPage === 3)
                    exportModel.generate(filterEngine)
            }
        }

        Item {
            id: contentHost
            anchors {
                top: windowMenuBar.bottom
                left: sidebar.right
                right: parent.right
                bottom: parent.bottom
            }
            clip: true

            ParallelAnimation {
                id: pageTransitionAnim
                NumberAnimation {
                    target: pageStack
                    property: "opacity"
                    from: 0.65
                    to: 1.0
                    duration: 180
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: pageTranslate
                    property: "y"
                    from: 5
                    to: 0
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            StackLayout {
                id: pageStack
                anchors.fill: parent
                currentIndex: 0
                opacity: 1.0

                transform: Translate {
                    id: pageTranslate
                    y: 0
                }

                DesignPage     { id: designPage;     Layout.fillWidth: true; Layout.fillHeight: true }
                AnalysisPage   { id: analysisPage;   Layout.fillWidth: true; Layout.fillHeight: true }
                SimulationPage { id: simulationPage; Layout.fillWidth: true; Layout.fillHeight: true }
                ExportPage     { id: exportPage;     Layout.fillWidth: true; Layout.fillHeight: true }
                DocsPage       { id: docsPage;       Layout.fillWidth: true; Layout.fillHeight: true }
                SettingsPage   { id: settingsPage;   Layout.fillWidth: true; Layout.fillHeight: true }
            }
        }
    }

    function showWhatsNew() {
        whatsNewWindow.openWindow()
    }

    function showInstallerUpdater(tabIndex) {
        installerUpdaterWindow.openWindow(tabIndex)
    }

    function checkUpdatesNow() {
        installerUpdaterWindow.checkUpdatesNow()
    }

    WhatsNewWindow {
        id: whatsNewWindow
        transientParent: root
    }

    InstallerUpdaterWindow {
        id: installerUpdaterWindow
        transientParent: root
    }

    Component.onCompleted: {
        if (typeof cliLaunchUpdater !== "undefined" && cliLaunchUpdater) {
            Qt.callLater(function() { installerUpdaterWindow.checkUpdatesNow() })
        }
    }

    Behavior on color { ColorAnimation { duration: 300 } }
}

