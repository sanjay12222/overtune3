import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// WindowMenuBar.qml — Native-styled VS Code window titlebar menu
Rectangle {
    id: root
    height: 30
    color: theme.isDark ? "#1E1E1E" : "#F3F3F3"
    border.color: theme.borderColor
    border.width: 1
    z: 90

    property var rootWindow: null

    // Copy one export format to the clipboard without changing the Export page's tab
    // Formats: 0 C, 1 C++, 2 Python, 3 JSON, 4 MATLAB, 5 Rust, 6 WebAudio JS, 7 CSV
    function copyExport(format, message) {
        const previous = exportModel.format
        exportModel.setFormat(format)
        exportModel.generate(filterEngine)
        exportModel.copyToClipboard()
        exportModel.setFormat(previous)
        exportModel.generate(filterEngine)
        rootWindow.showNotification(message, false)
    }

    // Component for clean, styled MenuItems with shortcuts and checkmarks
    component StyledMenuItem: MenuItem {
        id: mi
        property string shortcutText: ""

        implicitHeight: 26
        padding: 0
        leftPadding: 8
        rightPadding: 8
        topPadding: 2
        bottomPadding: 2

        arrow: Item {
            implicitWidth: 0
            implicitHeight: 0
            visible: false
        }

        contentItem: RowLayout {
            spacing: 6

            // Checkmark indicator or indentation spacing
            Item {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                visible: mi.checkable

                Codicon {
                    anchors.centerIn: parent
                    icon: "check"
                    iconSize: 11
                    iconColor: theme.accent
                    visible: mi.checked
                }
            }

            Text {
                text: mi.text
                font.family: "Stack Sans Headline"
                font.pixelSize: 12
                font.weight: Font.Normal
                color: mi.highlighted ? theme.primaryText : (mi.enabled ? theme.primaryText : theme.secondaryText)
                Layout.fillWidth: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                text: mi.shortcutText
                font.family: "Stack Sans Headline"
                font.pixelSize: 11
                color: theme.secondaryText
                opacity: 0.7
                visible: mi.shortcutText !== ""
                verticalAlignment: Text.AlignVCenter
            }

            // Submenu chevron for items that open submenus (the ones with >)
            Codicon {
                icon: "chevron-right"
                iconSize: 10
                iconColor: mi.highlighted ? theme.primaryText : theme.secondaryText
                visible: mi.subMenu !== null && mi.subMenu !== undefined
                Layout.alignment: Qt.AlignVCenter
            }
        }

        background: Rectangle {
            implicitHeight: 26
            color: mi.highlighted ? (theme.isDark ? "#32353A" : "#E2E5E9") : "transparent"
            radius: 4
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }

    // Component for styled Submenus
    component StyledMenu: Menu {
        delegate: MenuItem {
            id: smDelegateItem
            implicitHeight: 26
            padding: 0
            leftPadding: 8
            rightPadding: 8
            topPadding: 2
            bottomPadding: 2

            arrow: Item {
                implicitWidth: 0
                implicitHeight: 0
                visible: false
            }

            contentItem: RowLayout {
                spacing: 6

                Item {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    visible: smDelegateItem.checkable

                    Codicon {
                        anchors.centerIn: parent
                        icon: "check"
                        iconSize: 11
                        iconColor: theme.accent
                        visible: smDelegateItem.checked
                    }
                }

                Text {
                    text: smDelegateItem.text
                    font.family: "Stack Sans Headline"
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    color: smDelegateItem.highlighted ? theme.primaryText : (smDelegateItem.enabled ? theme.primaryText : theme.secondaryText)
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Codicon {
                    icon: "chevron-right"
                    iconSize: 10
                    iconColor: smDelegateItem.highlighted ? theme.primaryText : theme.secondaryText
                    visible: smDelegateItem.subMenu !== null && smDelegateItem.subMenu !== undefined
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            background: Rectangle {
                implicitHeight: 26
                color: smDelegateItem.highlighted ? (theme.isDark ? "#32353A" : "#E2E5E9") : "transparent"
                radius: 4
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }

        background: Rectangle {
            implicitWidth: 240
            color: theme.isDark ? "#25272B" : "#FFFFFF"
            border.color: theme.borderColor
            border.width: 1
            radius: 7
        }
    }

    // Left cluster: MenuBar
    Row {
        id: leftCluster
        anchors {
            left: parent.left
            leftMargin: 8
            verticalCenter: parent.verticalCenter
        }
        spacing: 4

        // Top Window MenuBar
        MenuBar {
            id: mainMenuBar
            anchors.verticalCenter: parent.verticalCenter

            background: Rectangle { color: "transparent" }

            delegate: MenuBarItem {
                id: mbi
                contentItem: Text {
                    text: mbi.text
                    font.family: "Stack Sans Headline"
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    color: mbi.highlighted ? theme.primaryText : (theme.isDark ? "#CCCCCC" : "#4B5563")
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    color: mbi.highlighted ? (theme.isDark ? "#32353A" : "#E2E5E9") : (mbi.hovered ? (theme.isDark ? "#282B30" : "#EAEDF1") : "transparent")
                    radius: 4
                }
                padding: 0
                leftPadding: 7
                rightPadding: 7
                topPadding: 3
                bottomPadding: 3

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }

            // ── 1. FILE MENU ──────────────────────────────────────────────────────────
            StyledMenu {
                title: "File"

                StyledMenuItem {
                    text: "New Filter (Reset)"
                    shortcutText: "Ctrl+N"
                    onTriggered: rootWindow.doReset()
                }

                StyledMenuItem {
                    text: "Save Generated Code..."
                    shortcutText: "Ctrl+S"
                    onTriggered: rootWindow.doSave()
                }

                MenuSeparator {}

                StyledMenuItem {
                    text: "Export Magnitude Plot (PNG)..."
                    onTriggered: {
                        if (designPage && designPage.freqPlot) {
                            designPage.freqPlot.exportPlotImage()
                        } else {
                            rootWindow.showNotification("Open Design Studio to export magnitude plot", false)
                        }
                    }
                }

                StyledMenuItem {
                    text: "Export Pole-Zero Diagram (PNG)..."
                    onTriggered: {
                        if (analysisPage && analysisPage.pzPlot) {
                            analysisPage.pzPlot.exportPlotImage()
                        } else {
                            rootWindow.showNotification("Open Analysis Suite to export pole-zero plot", false)
                        }
                    }
                }

                StyledMenuItem {
                    text: "Export Simulation Waveform (PNG)..."
                    onTriggered: {
                        if (simulationPage && simulationPage.signalPlot) {
                            simulationPage.signalPlot.exportPlotImage()
                        } else {
                            rootWindow.showNotification("Open Simulation Studio to export waveform", false)
                        }
                    }
                }

                MenuSeparator {}

                StyledMenuItem {
                    text: "Copy Coefficients CSV to Clipboard"
                    onTriggered: {
                        root.copyExport(7, "Filter coefficients CSV copied to clipboard")
                    }
                }

                StyledMenuItem {
                    text: "Copy Coefficients JSON to Clipboard"
                    onTriggered: {
                        root.copyExport(3, "Filter coefficients JSON copied to clipboard")
                    }
                }

                MenuSeparator {}

                StyledMenuItem {
                    text: "Exit Overtune"
                    shortcutText: "Ctrl+Q"
                    onTriggered: Qt.quit()
                }
            }

            // ── 2. EDIT MENU ──────────────────────────────────────────────────────────
            StyledMenu {
                title: "Edit"

                StyledMenuItem {
                    text: "Copy C++ Filter Class"
                    onTriggered: {
                        root.copyExport(1, "C++ filter code copied to clipboard")
                    }
                }

                StyledMenuItem {
                    text: "Copy Python (SciPy) Script"
                    onTriggered: {
                        root.copyExport(2, "Python (SciPy) filter script copied")
                    }
                }

                StyledMenuItem {
                    text: "Copy MATLAB Filter Script"
                    onTriggered: {
                        root.copyExport(4, "MATLAB filter design script copied")
                    }
                }

                StyledMenuItem {
                    text: "Copy Rust Filter Implementation"
                    onTriggered: {
                        root.copyExport(5, "Rust DSP filter implementation copied")
                    }
                }

                StyledMenuItem {
                    text: "Copy WebAudio (JS) Filter"
                    onTriggered: {
                        root.copyExport(6, "WebAudio JavaScript code copied")
                    }
                }

                MenuSeparator {}

                StyledMenuItem {
                    text: "Copy Active Graph Image"
                    onTriggered: {
                        if (sidebar.currentPage === 0 && designPage && designPage.freqPlot) {
                            designPage.freqPlot.copyPlotImage()
                        } else if (sidebar.currentPage === 2 && simulationPage && simulationPage.signalPlot) {
                            simulationPage.signalPlot.copyPlotImage()
                        } else {
                            rootWindow.showNotification("Select Design or Simulation to copy plot image", false)
                        }
                    }
                }

                MenuSeparator {}

                StyledMenuItem {
                    text: "Clear Simulation Waveforms"
                    shortcutText: "Ctrl+K"
                    onTriggered: rootWindow.doClear()
                }

                StyledMenuItem {
                    text: "Reset Filter to Default"
                    shortcutText: "Ctrl+R"
                    onTriggered: rootWindow.doReset()
                }
            }

            // ── 3. SELECTION MENU (Filter Specifications) ─────────────────────────────
            StyledMenu {
                title: "Selection"

                StyledMenu {
                    title: "Filter Topology / Family"

                    StyledMenuItem {
                        text: "Butterworth (Maximally Flat)"
                        checkable: true
                        checked: filterEngine.filterResponse === 0
                        onTriggered: { filterEngine.filterResponse = 0; filterEngine.design(); rootWindow.showNotification("Selected: Butterworth (Maximally Flat)", false) }
                    }
                    StyledMenuItem {
                        text: "Chebyshev Type I (Passband Ripple)"
                        checkable: true
                        checked: filterEngine.filterResponse === 1
                        onTriggered: { filterEngine.filterResponse = 1; filterEngine.design(); rootWindow.showNotification("Selected: Chebyshev Type I", false) }
                    }
                    StyledMenuItem {
                        text: "Chebyshev Type II (Stopband Ripple)"
                        checkable: true
                        checked: filterEngine.filterResponse === 2
                        onTriggered: { filterEngine.filterResponse = 2; filterEngine.design(); rootWindow.showNotification("Selected: Chebyshev Type II", false) }
                    }
                    StyledMenuItem {
                        text: "Elliptic / Cauer (Equiripple)"
                        checkable: true
                        checked: filterEngine.filterResponse === 3
                        onTriggered: { filterEngine.filterResponse = 3; filterEngine.design(); rootWindow.showNotification("Selected: Elliptic (Cauer)", false) }
                    }
                    StyledMenuItem {
                        text: "Bessel / Thomson (Linear Phase)"
                        checkable: true
                        checked: filterEngine.filterResponse === 4
                        onTriggered: { filterEngine.filterResponse = 4; filterEngine.design(); rootWindow.showNotification("Selected: Bessel (Linear Phase)", false) }
                    }
                    StyledMenuItem {
                        text: "FIR / Windowed Sinc (Exact Linear Phase)"
                        checkable: true
                        checked: filterEngine.filterResponse === 5
                        onTriggered: {
                            filterEngine.filterResponse = 5
                            if (filterEngine.order < 16) filterEngine.order = 64
                            filterEngine.design()
                            rootWindow.showNotification("Selected: FIR (Windowed Sinc)", false)
                        }
                    }
                }

                StyledMenu {
                    title: "Filter Response Type"

                    StyledMenuItem {
                        text: "Low Pass (LPF)"
                        checkable: true
                        checked: filterEngine.filterType === 0
                        onTriggered: { filterEngine.filterType = 0; filterEngine.design(); rootWindow.showNotification("Response: Low Pass", false) }
                    }
                    StyledMenuItem {
                        text: "High Pass (HPF)"
                        checkable: true
                        checked: filterEngine.filterType === 1
                        onTriggered: { filterEngine.filterType = 1; filterEngine.design(); rootWindow.showNotification("Response: High Pass", false) }
                    }
                    StyledMenuItem {
                        text: "Band Pass (BPF)"
                        checkable: true
                        checked: filterEngine.filterType === 2
                        onTriggered: { filterEngine.filterType = 2; filterEngine.design(); rootWindow.showNotification("Response: Band Pass", false) }
                    }
                    StyledMenuItem {
                        text: "Band Stop / Notch (BSF)"
                        checkable: true
                        checked: filterEngine.filterType === 3
                        onTriggered: { filterEngine.filterType = 3; filterEngine.design(); rootWindow.showNotification("Response: Band Stop", false) }
                    }
                }

                StyledMenu {
                    title: "Filter Order"

                    StyledMenuItem {
                        text: "2nd Order (Single Biquad)"
                        checkable: true
                        checked: filterEngine.order === 2
                        onTriggered: { filterEngine.order = 2; filterEngine.design(); rootWindow.showNotification("Order set to 2", false) }
                    }
                    StyledMenuItem {
                        text: "4th Order (2 Biquads)"
                        checkable: true
                        checked: filterEngine.order === 4
                        onTriggered: { filterEngine.order = 4; filterEngine.design(); rootWindow.showNotification("Order set to 4", false) }
                    }
                    StyledMenuItem {
                        text: "6th Order (3 Biquads)"
                        checkable: true
                        checked: filterEngine.order === 6
                        onTriggered: { filterEngine.order = 6; filterEngine.design(); rootWindow.showNotification("Order set to 6", false) }
                    }
                    StyledMenuItem {
                        text: "8th Order (4 Biquads)"
                        checkable: true
                        checked: filterEngine.order === 8
                        onTriggered: { filterEngine.order = 8; filterEngine.design(); rootWindow.showNotification("Order set to 8", false) }
                    }
                    StyledMenuItem {
                        text: "10th Order (5 Biquads)"
                        checkable: true
                        checked: filterEngine.order === 10
                        onTriggered: { filterEngine.order = 10; filterEngine.design(); rootWindow.showNotification("Order set to 10", false) }
                    }
                }

                StyledMenu {
                    title: "Audio Sampling Rate"

                    StyledMenuItem {
                        text: "44,100 Hz (CD Audio)"
                        checkable: true
                        checked: filterEngine.sampleRate === 44100
                        onTriggered: { filterEngine.sampleRate = 44100; filterEngine.design(); rootWindow.showNotification("Sample Rate: 44.1 kHz", false) }
                    }
                    StyledMenuItem {
                        text: "48,000 Hz (Standard Production)"
                        checkable: true
                        checked: filterEngine.sampleRate === 48000
                        onTriggered: { filterEngine.sampleRate = 48000; filterEngine.design(); rootWindow.showNotification("Sample Rate: 48 kHz", false) }
                    }
                    StyledMenuItem {
                        text: "96,000 Hz (Hi-Res Audio)"
                        checkable: true
                        checked: filterEngine.sampleRate === 96000
                        onTriggered: { filterEngine.sampleRate = 96000; filterEngine.design(); rootWindow.showNotification("Sample Rate: 96 kHz", false) }
                    }
                    StyledMenuItem {
                        text: "192,000 Hz (Studio Master)"
                        checkable: true
                        checked: filterEngine.sampleRate === 192000
                        onTriggered: { filterEngine.sampleRate = 192000; filterEngine.design(); rootWindow.showNotification("Sample Rate: 192 kHz", false) }
                    }
                }
            }

            // ── 4. VIEW MENU (Zoom, Scale, Desmos, Overlays) ──────────────────────────
            StyledMenu {
                title: "View"

                StyledMenuItem {
                    text: "Auto Scale / Fit View (Desmos)"
                    shortcutText: "Ctrl+0"
                    onTriggered: rootWindow.doAutoScale()
                }

                StyledMenuItem {
                    text: "Zoom In (+)"
                    shortcutText: "Ctrl+="
                    onTriggered: rootWindow.doZoomIn()
                }

                StyledMenuItem {
                    text: "Zoom Out (−)"
                    shortcutText: "Ctrl+-"
                    onTriggered: rootWindow.doZoomOut()
                }

                MenuSeparator {}

                StyledMenuItem {
                    text: "DSP Specification Guides"
                    checkable: true
                    checked: designPage && designPage.freqPlot ? designPage.freqPlot.showDspGuides : false
                    onTriggered: {
                        if (designPage && designPage.freqPlot) {
                            designPage.freqPlot.showDspGuides = !designPage.freqPlot.showDspGuides
                            rootWindow.showNotification("DSP Guides: " + (designPage.freqPlot.showDspGuides ? "ON" : "OFF"), false)
                        }
                    }
                }

                StyledMenuItem {
                    text: "Data Cursor / Inspector (+)"
                    checkable: true
                    checked: designPage && designPage.freqPlot ? designPage.freqPlot.showCrosshair : false
                    onTriggered: {
                        if (designPage && designPage.freqPlot) {
                            designPage.freqPlot.showCrosshair = !designPage.freqPlot.showCrosshair
                            rootWindow.showNotification("Data Cursor (+): " + (designPage.freqPlot.showCrosshair ? "ON" : "OFF"), false)
                        }
                    }
                }

                StyledMenuItem {
                    text: "Polar Grid on Z-Plane"
                    checkable: true
                    checked: analysisPage && analysisPage.pzPlot ? analysisPage.pzPlot.showPolarGrid : true
                    onTriggered: {
                        if (analysisPage && analysisPage.pzPlot) {
                            analysisPage.pzPlot.showPolarGrid = !analysisPage.pzPlot.showPolarGrid
                            analysisPage.pzPlot.schedulePaint()
                        }
                    }
                }

                StyledMenuItem {
                    text: "Unit Circle Stability Shading"
                    checkable: true
                    checked: analysisPage && analysisPage.pzPlot ? analysisPage.pzPlot.showStabilityRegion : true
                    onTriggered: {
                        if (analysisPage && analysisPage.pzPlot) {
                            analysisPage.pzPlot.showStabilityRegion = !analysisPage.pzPlot.showStabilityRegion
                            analysisPage.pzPlot.schedulePaint()
                        }
                    }
                }

                MenuSeparator {}

                StyledMenuItem {
                    text: "Toggle Dark / Light Theme"
                    shortcutText: "Ctrl+T"
                    onTriggered: {
                        theme.themeMode = theme.isDark ? 1 : 2
                        rootWindow.showNotification("Theme set to " + (theme.isDark ? "Dark" : "Light"), false)
                    }
                }

                StyledMenuItem {
                    text: "Toggle Fullscreen"
                    shortcutText: "F11"
                    onTriggered: {
                        if (rootWindow.visibility === Window.FullScreen) {
                            rootWindow.visibility = Window.Windowed
                        } else {
                            rootWindow.visibility = Window.FullScreen
                        }
                    }
                }
            }

            // ── 5. GO MENU (Workspace Navigation) ─────────────────────────────────────
            StyledMenu {
                title: "Go"

                StyledMenuItem {
                    text: "Filter Design Studio"
                    shortcutText: "Ctrl+1"
                    onTriggered: { rootWindow.navigateTo(0); rootWindow.showTabName(); }
                }

                StyledMenuItem {
                    text: "Frequency Analysis Suite"
                    shortcutText: "Ctrl+2"
                    onTriggered: { rootWindow.navigateTo(1); rootWindow.showTabName(); }
                }

                StyledMenuItem {
                    text: "Signal Simulation Studio"
                    shortcutText: "Ctrl+3"
                    onTriggered: { rootWindow.navigateTo(2); rootWindow.showTabName(); }
                }

                StyledMenuItem {
                    text: "Production Code Exporter"
                    shortcutText: "Ctrl+4"
                    onTriggered: { rootWindow.navigateTo(3); rootWindow.showTabName(); }
                }

                StyledMenuItem {
                    text: "Theory & Documentation"
                    shortcutText: "Ctrl+5"
                    onTriggered: { rootWindow.navigateTo(4); rootWindow.showTabName(); }
                }

                StyledMenuItem {
                    text: "Workspace Settings"
                    shortcutText: "Ctrl+6"
                    onTriggered: { rootWindow.navigateTo(5); rootWindow.showTabName(); }
                }

                MenuSeparator {}

                StyledMenuItem {
                    text: "Next Workspace Tab"
                    shortcutText: "Ctrl+Tab"
                    onTriggered: rootWindow.nextTab()
                }

                StyledMenuItem {
                    text: "Previous Workspace Tab"
                    shortcutText: "Ctrl+Shift+Tab"
                    onTriggered: rootWindow.prevTab()
                }
            }

            // ── 6. RUN MENU (Live DSP Signal Simulation) ──────────────────────────────
            StyledMenu {
                title: "Run"

                StyledMenuItem {
                    text: "Run Filter Simulation (Animated)"
                    shortcutText: "F5"
                    onTriggered: {
                        simulation.applyFilter(filterEngine)
                        if (simulationPage && simulationPage.signalPlot) {
                            simulationPage.signalPlot.restartAnimation()
                        }
                        rootWindow.showNotification("Simulating filter response in realtime...", false)
                    }
                }

                StyledMenuItem {
                    text: "Replay Realtime Filter Animation"
                    onTriggered: {
                        if (sidebar.currentPage !== 2) rootWindow.navigateTo(2)
                        if (simulationPage && simulationPage.signalPlot) {
                            simulationPage.signalPlot.restartAnimation()
                        }
                    }
                }

                StyledMenuItem {
                    text: "Continuous Loop Sweep (Oscilloscope)"
                    checkable: true
                    checked: simulationPage && simulationPage.signalPlot ? simulationPage.signalPlot.loopAnimation : false
                    onTriggered: {
                        if (simulationPage && simulationPage.signalPlot) {
                            simulationPage.signalPlot.loopAnimation = !simulationPage.signalPlot.loopAnimation
                            if (simulationPage.signalPlot.loopAnimation) {
                                simulationPage.signalPlot.restartAnimation()
                            }
                            rootWindow.showNotification(simulationPage.signalPlot.loopAnimation ? "Loop sweep active" : "Loop sweep disabled", false)
                        }
                    }
                }

                MenuSeparator {}

                StyledMenu {
                    title: "Signal Generator Presets"

                    StyledMenuItem {
                        text: "Sine Wave (1 kHz)"
                        onTriggered: {
                            simulation.generateSine(1000, filterEngine.sampleRate, 0.04)
                            simulation.applyFilter(filterEngine)
                            rootWindow.navigateTo(2)
                            if (simulationPage && simulationPage.signalPlot) simulationPage.signalPlot.restartAnimation()
                            rootWindow.showNotification("Generated: Sine Wave @ 1 kHz", false)
                        }
                    }

                    StyledMenuItem {
                        text: "Chirp Sweep (20 Hz - 20 kHz)"
                        onTriggered: {
                            simulation.generateChirp(20, Math.min(20000, filterEngine.sampleRate * 0.45), filterEngine.sampleRate, 0.05)
                            simulation.applyFilter(filterEngine)
                            rootWindow.navigateTo(2)
                            if (simulationPage && simulationPage.signalPlot) simulationPage.signalPlot.restartAnimation()
                            rootWindow.showNotification("Generated: Logarithmic Chirp Sweep", false)
                        }
                    }

                    StyledMenuItem {
                        text: "Dual-Tone Intermodulation"
                        onTriggered: {
                            const f1 = Math.min(1000, Math.max(100, filterEngine.cutoffFreq * 0.5))
                            const f2 = Math.max(3000, Math.min(18000, filterEngine.cutoffFreq * 1.5))
                            simulation.generateMultiTone(f1, f2, filterEngine.sampleRate, 0.04)
                            simulation.applyFilter(filterEngine)
                            rootWindow.navigateTo(2)
                            if (simulationPage && simulationPage.signalPlot) simulationPage.signalPlot.restartAnimation()
                            rootWindow.showNotification("Generated: Dual-Tone (" + Math.round(f1) + " Hz / " + Math.round(f2) + " Hz)", false)
                        }
                    }

                    StyledMenuItem {
                        text: "White Gaussian Noise"
                        onTriggered: {
                            simulation.generateNoise(0.04, filterEngine.sampleRate)
                            simulation.applyFilter(filterEngine)
                            rootWindow.navigateTo(2)
                            if (simulationPage && simulationPage.signalPlot) simulationPage.signalPlot.restartAnimation()
                            rootWindow.showNotification("Generated: White Gaussian Noise", false)
                        }
                    }

                    StyledMenuItem {
                        text: "Square Wave (1 kHz)"
                        onTriggered: {
                            simulation.generateSquare(1000, filterEngine.sampleRate, 0.04)
                            simulation.applyFilter(filterEngine)
                            rootWindow.navigateTo(2)
                            if (simulationPage && simulationPage.signalPlot) simulationPage.signalPlot.restartAnimation()
                            rootWindow.showNotification("Generated: 1 kHz Square Wave", false)
                        }
                    }
                }

                MenuSeparator {}

                StyledMenuItem {
                    text: "Clear Simulation Buffer"
                    shortcutText: "Ctrl+K"
                    onTriggered: rootWindow.doClear()
                }
            }

            // ── 7. PLOT MENU (DSP Display Configurations) ─────────────────────────────
            StyledMenu {
                title: "Plot"

                StyledMenu {
                    title: "Frequency Response Mode"

                    StyledMenuItem {
                        text: "Magnitude (dB)"
                        shortcutText: "Alt+1"
                        checkable: true
                        checked: designPage && designPage.freqPlot ? (designPage.freqPlot.displayMode === 0 && designPage.freqPlot.magScaleMode === 0) : false
                        onTriggered: {
                            if (designPage && designPage.freqPlot) {
                                designPage.freqPlot.displayMode = 0
                                designPage.freqPlot.magScaleMode = 0
                                designPage.freqPlot.refreshPoints()
                                designPage.freqPlot.schedulePaint()
                                rootWindow.showNotification("Plot Mode: Magnitude (dB)", false)
                            }
                        }
                    }

                    StyledMenuItem {
                        text: "Magnitude (Linear |H|)"
                        checkable: true
                        checked: designPage && designPage.freqPlot ? (designPage.freqPlot.displayMode === 0 && designPage.freqPlot.magScaleMode === 1) : false
                        onTriggered: {
                            if (designPage && designPage.freqPlot) {
                                designPage.freqPlot.displayMode = 0
                                designPage.freqPlot.magScaleMode = 1
                                designPage.freqPlot.refreshPoints()
                                designPage.freqPlot.schedulePaint()
                                rootWindow.showNotification("Plot Mode: Linear Magnitude |H|", false)
                            }
                        }
                    }

                    StyledMenuItem {
                        text: "Phase Response (°)"
                        shortcutText: "Alt+2"
                        checkable: true
                        checked: designPage && designPage.freqPlot ? (designPage.freqPlot.displayMode === 1 && designPage.freqPlot.phaseWrapMode === 0) : false
                        onTriggered: {
                            if (designPage && designPage.freqPlot) {
                                designPage.freqPlot.displayMode = 1
                                designPage.freqPlot.phaseWrapMode = 0
                                designPage.freqPlot.refreshPoints()
                                designPage.freqPlot.schedulePaint()
                                rootWindow.showNotification("Plot Mode: Phase (Unwrapped)", false)
                            }
                        }
                    }

                    StyledMenuItem {
                        text: "Phase Wrapped [-180°, 180°]"
                        checkable: true
                        checked: designPage && designPage.freqPlot ? (designPage.freqPlot.displayMode === 1 && designPage.freqPlot.phaseWrapMode === 1) : false
                        onTriggered: {
                            if (designPage && designPage.freqPlot) {
                                designPage.freqPlot.displayMode = 1
                                designPage.freqPlot.phaseWrapMode = 1
                                designPage.freqPlot.refreshPoints()
                                designPage.freqPlot.schedulePaint()
                                rootWindow.showNotification("Plot Mode: Phase (Wrapped)", false)
                            }
                        }
                    }

                    StyledMenuItem {
                        text: "Group Delay (samples)"
                        shortcutText: "Alt+3"
                        checkable: true
                        checked: designPage && designPage.freqPlot ? (designPage.freqPlot.displayMode === 2) : false
                        onTriggered: {
                            if (designPage && designPage.freqPlot) {
                                designPage.freqPlot.displayMode = 2
                                designPage.freqPlot.refreshPoints()
                                designPage.freqPlot.schedulePaint()
                                rootWindow.showNotification("Plot Mode: Group Delay", false)
                            }
                        }
                    }
                }

                StyledMenu {
                    title: "Frequency Axis Scale"

                    StyledMenuItem {
                        text: "Logarithmic (Hz)"
                        checkable: true
                        checked: designPage && designPage.freqPlot ? designPage.freqPlot.freqScale === 0 : true
                        onTriggered: {
                            if (designPage && designPage.freqPlot) {
                                designPage.freqPlot.freqScale = 0
                                designPage.freqPlot.autoScale()
                            }
                        }
                    }

                    StyledMenuItem {
                        text: "Linear (Hz)"
                        checkable: true
                        checked: designPage && designPage.freqPlot ? designPage.freqPlot.freqScale === 1 : false
                        onTriggered: {
                            if (designPage && designPage.freqPlot) {
                                designPage.freqPlot.freqScale = 1
                                designPage.freqPlot.autoScale()
                            }
                        }
                    }

                    StyledMenuItem {
                        text: "Normalized Radian (ω/π)"
                        checkable: true
                        checked: designPage && designPage.freqPlot ? designPage.freqPlot.freqScale === 2 : false
                        onTriggered: {
                            if (designPage && designPage.freqPlot) {
                                designPage.freqPlot.freqScale = 2
                                designPage.freqPlot.autoScale()
                            }
                        }
                    }

                    StyledMenuItem {
                        text: "Normalized Digital (f/fs)"
                        checkable: true
                        checked: designPage && designPage.freqPlot ? designPage.freqPlot.freqScale === 3 : false
                        onTriggered: {
                            if (designPage && designPage.freqPlot) {
                                designPage.freqPlot.freqScale = 3
                                designPage.freqPlot.autoScale()
                            }
                        }
                    }
                }

                StyledMenu {
                    title: "Simulation Waveform Style"

                    StyledMenuItem {
                        text: "Continuous Curve"
                        checkable: true
                        checked: simulationPage && simulationPage.signalPlot ? simulationPage.signalPlot.displayStyle === 0 : true
                        onTriggered: {
                            if (simulationPage && simulationPage.signalPlot) {
                                simulationPage.signalPlot.displayStyle = 0
                                simulationPage.signalPlot.schedulePaint()
                            }
                        }
                    }

                    StyledMenuItem {
                        text: "Discrete Stem (Digital)"
                        checkable: true
                        checked: simulationPage && simulationPage.signalPlot ? simulationPage.signalPlot.displayStyle === 1 : false
                        onTriggered: {
                            if (simulationPage && simulationPage.signalPlot) {
                                simulationPage.signalPlot.displayStyle = 1
                                simulationPage.signalPlot.schedulePaint()
                            }
                        }
                    }

                    StyledMenuItem {
                        text: "Sample Points Only"
                        checkable: true
                        checked: simulationPage && simulationPage.signalPlot ? simulationPage.signalPlot.displayStyle === 2 : false
                        onTriggered: {
                            if (simulationPage && simulationPage.signalPlot) {
                                simulationPage.signalPlot.displayStyle = 2
                                simulationPage.signalPlot.schedulePaint()
                            }
                        }
                    }
                }
            }

            // ── 8. HELP MENU ──────────────────────────────────────────────────────────
            StyledMenu {
                title: "Help"

                StyledMenuItem {
                    text: "Interactive Challenges & Lab"
                    onTriggered: { rootWindow.navigateTo(4); rootWindow.showNotification("Opened Interactive Challenges & Theory", false) }
                }

                StyledMenuItem {
                    text: "Filter Theory & Mathematics"
                    onTriggered: { rootWindow.navigateTo(4); rootWindow.showNotification("Opened DSP Filter Theory Documentation", false) }
                }

                StyledMenuItem {
                    text: "Keyboard Shortcuts Guide"
                    onTriggered: {
                        rootWindow.showNotification("Shortcuts: Ctrl+1..6 (Tabs), Ctrl+S (Save), Ctrl+R (Reset), F5 (Run), Ctrl+0 (Fit)", false)
                    }
                }

                MenuSeparator {}

                StyledMenuItem {
                    text: "What's New in Overtune 3"
                    onTriggered: {
                        if (typeof rootWindow.showWhatsNew === "function") {
                            rootWindow.showWhatsNew()
                        }
                    }
                }

                StyledMenuItem {
                    text: "Check for Updates..."
                    shortcutText: updateInstaller.hasUpdate ? ("v" + updateInstaller.latestVersion) : ""
                    onTriggered: {
                        if (rootWindow && typeof rootWindow.checkUpdatesNow === "function") {
                            rootWindow.checkUpdatesNow()
                        }
                    }
                }

                StyledMenuItem {
                    text: "System Installer & Shortcuts..."
                    onTriggered: {
                        if (rootWindow && typeof rootWindow.showInstallerUpdater === "function") {
                            rootWindow.showInstallerUpdater(1)
                        }
                    }
                }

                StyledMenuItem {
                    text: "About Overtune 3 DSP Filter Designer"
                    onTriggered: {
                        rootWindow.showNotification("Overtune 3 — Professional Digital Filter Design & Live Simulation Studio", false)
                    }
                }
            }
        }
    }

    // Center cluster: Subtle status bar showing active filter & sample rate
    Text {
        anchors.centerIn: parent
        text: "Overtune 3  —  " + filterEngine.responseName + " " + filterEngine.orderLabel + " " + filterEngine.typeName + " (" + (filterEngine.sampleRate / 1000).toFixed(1) + " kHz)"
        font.family: "Stack Sans Headline"
        font.pixelSize: 11
        color: theme.secondaryText
        opacity: 0.85
        visible: parent.width > 720
    }

    // Right cluster: Auto-Scale Quick Button + Theme Switcher
    Row {
        anchors {
            right: parent.right
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        spacing: 6

        // Update Quick Button (Only shown when an update is available)
        Rectangle {
            id: updateBtn
            visible: updateInstaller.hasUpdate
            height: 22
            implicitWidth: updateRow.implicitWidth + 14
            radius: 6
            color: updateMouse.containsMouse ? (theme.isDark ? "#32353A" : "#E2E5E9") : Qt.darker(theme.accent, 1.3)
            border.color: theme.accent
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                id: updateRow
                anchors.centerIn: parent
                spacing: 5

                Codicon {
                    icon: updateInstaller.hasUpdate ? "cloud-download" : "package"
                    iconSize: 11
                    iconColor: updateInstaller.hasUpdate ? theme.accent : theme.secondaryText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: updateInstaller.hasUpdate ? "Update Ready" : "Installer"
                    font.family: "Stack Sans Headline"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: updateInstaller.hasUpdate ? "#FFFFFF" : theme.secondaryText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ToolTip.visible: updateMouse.containsMouse
            ToolTip.text: updateInstaller.hasUpdate ? "Update v" + updateInstaller.latestVersion + " is available!" : "Open Installer & Update Manager"
            ToolTip.delay: 350

            MouseArea {
                id: updateMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (rootWindow && typeof rootWindow.showInstallerUpdater === "function") {
                        rootWindow.showInstallerUpdater(updateInstaller.hasUpdate ? 0 : 1)
                    }
                }
            }
        }

        // Accent-colored squircle "What's New" button
        Rectangle {
            id: whatsNewBtn
            height: 22
            implicitWidth: whatsNewRow.implicitWidth + 14
            radius: 6
            color: whatsNewMouse.containsMouse ? Qt.darker(theme.accent, 1.15) : theme.accent
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                id: whatsNewRow
                anchors.centerIn: parent
                spacing: 5

                Codicon {
                    icon: "info"
                    iconSize: 11
                    iconColor: "#FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "What's New"
                    font.family: "Stack Sans Headline"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: "#FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }


            ToolTip.visible: whatsNewMouse.containsMouse
            ToolTip.text: "See What's New in Overtune 3"
            ToolTip.delay: 350

            MouseArea {
                id: whatsNewMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (rootWindow && typeof rootWindow.showWhatsNew === "function") {
                        rootWindow.showWhatsNew()
                    }
                }
            }
        }

        // Auto Scale / Fit View quick button
        Rectangle {
            width: 24
            height: 22
            radius: 4
            color: fitTopMouse.containsMouse ? (theme.isDark ? "#32353A" : "#E2E5E9") : "transparent"

            Codicon {
                anchors.centerIn: parent
                icon: "screen-full"
                iconSize: 12
                iconColor: fitTopMouse.containsMouse ? theme.primaryText : theme.secondaryText
            }

            ToolTip.visible: fitTopMouse.containsMouse
            ToolTip.text: "Auto Scale / Fit View (Ctrl+0)"
            ToolTip.delay: 350

            MouseArea {
                id: fitTopMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rootWindow.doAutoScale()
            }
        }

        // Quick Theme Toggle Button
        Rectangle {
            width: 24
            height: 22
            radius: 4
            color: themeTopMouse.containsMouse ? (theme.isDark ? "#32353A" : "#E2E5E9") : "transparent"

            Codicon {
                anchors.centerIn: parent
                icon: theme.isDark ? "sun" : "color-mode"
                iconSize: 13
                iconColor: themeTopMouse.containsMouse ? theme.primaryText : theme.secondaryText
            }

            ToolTip.visible: themeTopMouse.containsMouse
            ToolTip.text: "Switch to " + (theme.isDark ? "Light" : "Dark") + " Theme (Ctrl+T)"
            ToolTip.delay: 350

            MouseArea {
                id: themeTopMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    theme.themeMode = theme.isDark ? 1 : 2
                    rootWindow.showNotification("Theme switched to " + (theme.isDark ? "Dark" : "Light"), false)
                }
            }
        }
    }
}
