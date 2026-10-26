import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

// StandalonePlotWindow.qml — Dedicated high-resolution window for detailed plotter inspection and data/image export
Window {
    id: win
    property int plotType: 0 // 0=Frequency/Bode, 1=Pole-Zero, 2=Impulse/Step, 3=Signal/Scope
    property var extraProps: ({})

    title: {
        switch (plotType) {
        case 0: {
            const m = extraProps && extraProps.displayMode !== undefined ? extraProps.displayMode : 0
            const mName = m === 0 ? "Magnitude (dB)" : (m === 1 ? "Phase (°)" : "Group Delay (samples)")
            return "Overtune 3 (beta) — Frequency Response [" + mName + "] — " + filterEngine.responseName + " " + filterEngine.typeName + " (" + filterEngine.orderLabel + ")"
        }
        case 1:
            return "Overtune 3 (beta) — Z-Plane Pole-Zero Constellation — " + filterEngine.responseName + " (" + filterEngine.orderLabel + ")"
        case 2: {
            const isStep = extraProps && extraProps.mode === 1
            return "Overtune 3 (beta) — Time-Domain " + (isStep ? "Step" : "Impulse") + " Response — " + filterEngine.responseName
        }
        case 3:
            return "Overtune 3 (beta) — Real-Time Signal Simulation Studio & Oscilloscope"
        }
        return "Overtune 3 (beta) — Dedicated Plot Inspector"
    }

    width: plotType === 1 ? 920 : (plotType === 2 ? 1020 : 1180)
    height: 760
    minimumWidth: 640
    minimumHeight: 480
    color: theme.background
    visible: true

    palette.window: theme.background
    palette.windowText: theme.primaryText
    palette.base: theme.surface
    palette.text: theme.primaryText
    palette.button: theme.surfaceHigh
    palette.buttonText: theme.primaryText
    palette.highlight: theme.accent
    palette.mid: theme.borderColor

    // ── Keyboard Shortcuts ──────────────────────────────────────────────────
    Shortcut {
        sequence: "Ctrl+0"
        onActivated: {
            if (plotLoader.item && typeof plotLoader.item.autoScale === "function") {
                plotLoader.item.autoScale()
                showToast("View Auto-Scaled")
            }
        }
    }
    Shortcut {
        sequence: StandardKey.Save
        onActivated: {
            if (plotLoader.item && typeof plotLoader.item.exportPlotImage === "function") {
                plotLoader.item.exportPlotImage()
            }
        }
    }
    Shortcut {
        sequences: [ "Ctrl+C" ]
        onActivated: {
            if (plotLoader.item && typeof plotLoader.item.copyPlotImage === "function") {
                plotLoader.item.copyPlotImage()
                showToast("Plot image copied to clipboard")
            }
        }
    }
    Shortcut {
        sequence: "Escape"
        onActivated: win.close()
    }

    // ── Window Layout ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Dedicated Top Action & Inspection Toolbar
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: theme.isDark ? "#1C1C1E" : "#F3F3F5"
            border.color: theme.borderColor
            border.width: 0
            z: 20

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: theme.borderColor
                opacity: 0.6
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                // Left: Icon & Title
                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 6
                        color: theme.accentMuted
                        anchors.verticalCenter: parent.verticalCenter

                        Codicon {
                            anchors.centerIn: parent
                            icon: win.plotType === 1 ? "compass" : (win.plotType === 2 ? "pulse" : (win.plotType === 3 ? "play" : "graph"))
                            iconSize: 14
                            iconColor: theme.accent
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: {
                                switch (win.plotType) {
                                case 0: {
                                    const m = win.extraProps && win.extraProps.displayMode !== undefined ? win.extraProps.displayMode : 0
                                    return m === 0 ? "Bode Magnitude Response" : (m === 1 ? "Unwrapped Phase Response" : "Group Delay Response")
                                }
                                case 1: return "Z-Plane Pole-Zero Constellation"
                                case 2: return (win.extraProps && win.extraProps.mode === 1) ? "Step Response (h_step[n])" : "Impulse Response (h[n])"
                                case 3: return "Time-Domain Signal Oscilloscope"
                                }
                                return "Plot Inspector"
                            }
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: theme.primaryText
                        }

                        Text {
                            text: filterEngine.responseName + " " + filterEngine.typeName + "  ·  Order " + filterEngine.order + "  ·  Fs = " + Number(filterEngine.sampleRate).toLocaleString(Qt.locale(), "f", 0) + " Hz"
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 11
                            color: theme.secondaryText
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Right: Action buttons
                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8

                    // Auto-Scale (Desmos Fit)
                    Rectangle {
                        width: fitContentRow.implicitWidth + 16
                        height: 28
                        radius: 5
                        color: fitMouse.containsMouse ? (theme.isDark ? "#32353A" : "#E2E5E9") : (theme.isDark ? "#242528" : "#EAEAEA")
                        border.color: theme.borderColor
                        border.width: 1

                        Row {
                            id: fitContentRow
                            anchors.centerIn: parent
                            spacing: 6
                            Codicon {
                                icon: "screen-full"
                                iconSize: 12
                                iconColor: theme.primaryText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Fit View"
                                font.family: "Stack Sans Headline"
                                font.pixelSize: 12
                                color: theme.primaryText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: fitMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (plotLoader.item && typeof plotLoader.item.autoScale === "function") {
                                    plotLoader.item.autoScale()
                                    showToast("Plot auto-scaled to data")
                                }
                            }
                        }
                    }

                    // Save Image Button
                    Rectangle {
                        width: saveContentRow.implicitWidth + 16
                        height: 28
                        radius: 5
                        color: saveMouse.containsMouse ? (theme.isDark ? "#32353A" : "#E2E5E9") : (theme.isDark ? "#242528" : "#EAEAEA")
                        border.color: theme.borderColor
                        border.width: 1

                        Row {
                            id: saveContentRow
                            anchors.centerIn: parent
                            spacing: 6
                            Codicon {
                                icon: "camera"
                                iconSize: 12
                                iconColor: theme.primaryText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Save Image"
                                font.family: "Stack Sans Headline"
                                font.pixelSize: 12
                                color: theme.primaryText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: saveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (plotLoader.item && typeof plotLoader.item.exportPlotImage === "function") {
                                    plotLoader.item.exportPlotImage()
                                }
                            }
                        }
                    }

                    // Copy Image Button
                    Rectangle {
                        width: copyContentRow.implicitWidth + 16
                        height: 28
                        radius: 5
                        color: copyMouse.containsMouse ? (theme.isDark ? "#32353A" : "#E2E5E9") : (theme.isDark ? "#242528" : "#EAEAEA")
                        border.color: theme.borderColor
                        border.width: 1

                        Row {
                            id: copyContentRow
                            anchors.centerIn: parent
                            spacing: 6
                            Codicon {
                                icon: "copy"
                                iconSize: 12
                                iconColor: theme.primaryText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Copy"
                                font.family: "Stack Sans Headline"
                                font.pixelSize: 12
                                color: theme.primaryText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: copyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (plotLoader.item && typeof plotLoader.item.copyPlotImage === "function") {
                                    plotLoader.item.copyPlotImage()
                                    showToast("Plot image copied to clipboard")
                                }
                            }
                        }
                    }
                }
            }
        }

        // Plot Canvas Container
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Loader {
                id: plotLoader
                anchors.fill: parent
                anchors.margins: 10
                source: {
                    switch (win.plotType) {
                    case 0: return "FrequencyPlot.qml"
                    case 1: return "PoleZeroPlot.qml"
                    case 2: return "ImpulseStepPlot.qml"
                    case 3: return "SignalPlot.qml"
                    }
                    return ""
                }
                onLoaded: {
                    if (item) {
                        if (item.hasOwnProperty("isDetached")) {
                            item.isDetached = true
                        }
                        if (win.extraProps) {
                            for (let k in win.extraProps) {
                                if (item.hasOwnProperty(k)) {
                                    item[k] = win.extraProps[k]
                                }
                            }
                        }
                        if (typeof item.autoScale === "function") {
                            item.autoScale()
                        }
                    }
                }
            }
        }
    }

    // ── Floating In-Window Toast Notification ───────────────────────────────
    Rectangle {
        id: winToast
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 24
        }
        width: Math.max(180, toastRow.implicitWidth + 28)
        height: 36
        radius: 8
        color: theme.isDark ? "#28292E" : "#2C2D30"
        border.color: theme.borderColor
        border.width: 1
        opacity: 0
        z: 100

        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 8
            Codicon {
                icon: "check"
                iconSize: 13
                iconColor: "#30D158"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: toastText
                text: ""
                font.family: "Stack Sans Headline"
                font.pixelSize: 12
                color: "#FFFFFF"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Behavior on opacity { NumberAnimation { duration: 180 } }

        Timer {
            id: toastTimer
            interval: 2200
            onTriggered: winToast.opacity = 0
        }
    }

    function showToast(msg) {
        toastText.text = msg
        winToast.opacity = 1
        toastTimer.restart()
    }
}
