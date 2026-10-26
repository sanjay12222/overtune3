import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../components"

// AnalysisPage.qml — Full analysis suite with unified headline, card headers, and new window openers
Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitWidth: 800
    implicitHeight: 600
    clip: true

    readonly property bool narrowLayout: width < 740
    readonly property int pageMargin: width < 700 ? 10 : 16
    readonly property real cardMinH: narrowLayout ? 240 : 180

    property alias magPlot: anaMagPlot
    property alias phasePlot: anaPhasePlot
    property alias gdPlot: anaGdPlot
    property alias pzPlot: anaPzPlot

    function autoScaleAll() {
        if (anaMagPlot) anaMagPlot.autoScale()
        if (anaPhasePlot) anaPhasePlot.autoScale()
        if (anaGdPlot) anaGdPlot.autoScale()
        if (anaPzPlot) anaPzPlot.autoScale()
    }

    function openPlotWindow(type, extraProps) {
        const w = Window.window
        if (w && typeof w.openStandalonePlot === "function") {
            w.openStandalonePlot(type, extraProps)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pageMargin
        spacing: 10

        // ── Consistent Tab Page Headline ──────────────────────────────────────
        PageHeader {
            Layout.fillWidth: true
            title: "Frequency Analysis Suite"
            badgeText: filterEngine.responseName + " " + filterEngine.typeName + " (" + filterEngine.orderLabel + ")"


            // Auto-Scale All action button
            Rectangle {
                implicitHeight: 28
                implicitWidth: fitAllRow.implicitWidth + 16
                radius: 5
                color: fitAllMouse.containsMouse ? (theme.isDark ? "#32353A" : "#E2E5E9") : theme.surfaceHigh
                border.color: theme.borderColor
                border.width: 1

                Row {
                    id: fitAllRow
                    anchors.centerIn: parent
                    spacing: 6
                    Codicon {
                        icon: "screen-full"
                        iconSize: 12
                        iconColor: theme.primaryText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Fit All (Ctrl+0)"
                        font.family: "Stack Sans Headline"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: theme.primaryText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: fitAllMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.autoScaleAll()
                }
            }
        }

        // ── 2x2 Responsive Plot Grid ──────────────────────────────────────────
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: root.narrowLayout ? grid.implicitHeight : height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: root.narrowLayout ? Flickable.VerticalFlick : Flickable.AutoFlickIfNeeded
            interactive: root.narrowLayout
            ScrollBar.vertical: ScrollBar {
                policy: root.narrowLayout && flick.contentHeight > flick.height
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            GridLayout {
                id: grid
                width: flick.width
                height: root.narrowLayout ? implicitHeight : flick.height
                columns: root.narrowLayout ? 1 : 2
                rowSpacing: 10
                columnSpacing: 10

                // ── Card 1: Magnitude ─────────────────────────────────────────
                FilterCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: !root.narrowLayout
                    Layout.preferredHeight: root.narrowLayout ? root.cardMinH : -1
                    Layout.minimumHeight: root.cardMinH
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Magnitude (dB)"
                                font.family: "Stack Sans Headline"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: theme.primaryText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Window Opener Icon Button
                            Rectangle {
                                width: 24
                                height: 22
                                radius: 4
                                color: magPopMouse.containsMouse ? (theme.isDark ? "#32353A" : "#E2E5E9") : "transparent"
                                border.color: theme.borderColor
                                border.width: 1

                                Codicon {
                                    anchors.centerIn: parent
                                    icon: "link-external"
                                    iconSize: 11
                                    iconColor: magPopMouse.containsMouse ? theme.primaryText : theme.secondaryText
                                }

                                ToolTip.visible: magPopMouse.containsMouse
                                ToolTip.text: "Open Magnitude in Dedicated Window"
                                ToolTip.delay: 300

                                MouseArea {
                                    id: magPopMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openPlotWindow(0, { displayMode: 0 })
                                }
                            }
                        }

                        FrequencyPlot {
                            id: anaMagPlot
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 120
                            displayMode: 0
                        }
                    }
                }

                // ── Card 2: Phase ─────────────────────────────────────────────
                FilterCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: !root.narrowLayout
                    Layout.preferredHeight: root.narrowLayout ? root.cardMinH : -1
                    Layout.minimumHeight: root.cardMinH
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Phase (°)"
                                font.family: "Stack Sans Headline"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: theme.primaryText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Window Opener Icon Button
                            Rectangle {
                                width: 24
                                height: 22
                                radius: 4
                                color: phasePopMouse.containsMouse ? (theme.isDark ? "#32353A" : "#E2E5E9") : "transparent"
                                border.color: theme.borderColor
                                border.width: 1

                                Codicon {
                                    anchors.centerIn: parent
                                    icon: "link-external"
                                    iconSize: 11
                                    iconColor: phasePopMouse.containsMouse ? theme.primaryText : theme.secondaryText
                                }

                                ToolTip.visible: phasePopMouse.containsMouse
                                ToolTip.text: "Open Phase in Dedicated Window"
                                ToolTip.delay: 300

                                MouseArea {
                                    id: phasePopMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openPlotWindow(0, { displayMode: 1 })
                                }
                            }
                        }

                        FrequencyPlot {
                            id: anaPhasePlot
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 120
                            displayMode: 1
                        }
                    }
                }

                // ── Card 3: Group Delay ───────────────────────────────────────
                FilterCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: !root.narrowLayout
                    Layout.preferredHeight: root.narrowLayout ? root.cardMinH : -1
                    Layout.minimumHeight: root.cardMinH
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Group Delay (samples)"
                                font.family: "Stack Sans Headline"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: theme.primaryText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Window Opener Icon Button
                            Rectangle {
                                width: 24
                                height: 22
                                radius: 4
                                color: gdPopMouse.containsMouse ? (theme.isDark ? "#32353A" : "#E2E5E9") : "transparent"
                                border.color: theme.borderColor
                                border.width: 1

                                Codicon {
                                    anchors.centerIn: parent
                                    icon: "link-external"
                                    iconSize: 11
                                    iconColor: gdPopMouse.containsMouse ? theme.primaryText : theme.secondaryText
                                }

                                ToolTip.visible: gdPopMouse.containsMouse
                                ToolTip.text: "Open Group Delay in Dedicated Window"
                                ToolTip.delay: 300

                                MouseArea {
                                    id: gdPopMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openPlotWindow(0, { displayMode: 2 })
                                }
                            }
                        }

                        FrequencyPlot {
                            id: anaGdPlot
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 120
                            displayMode: 2
                        }
                    }
                }

                // ── Card 4: Time / Pole-Zero ──────────────────────────────────
                FilterCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: !root.narrowLayout
                    Layout.preferredHeight: root.narrowLayout ? 280 : -1
                    Layout.minimumHeight: 200
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Time / Pole-Zero"
                                font.family: "Stack Sans Headline"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: theme.primaryText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Window Opener Icon Button
                            Rectangle {
                                width: 24
                                height: 22
                                radius: 4
                                color: pzPopMouse.containsMouse ? (theme.isDark ? "#32353A" : "#E2E5E9") : "transparent"
                                border.color: theme.borderColor
                                border.width: 1

                                Codicon {
                                    anchors.centerIn: parent
                                    icon: "link-external"
                                    iconSize: 11
                                    iconColor: pzPopMouse.containsMouse ? theme.primaryText : theme.secondaryText
                                }

                                ToolTip.visible: pzPopMouse.containsMouse
                                ToolTip.text: "Open Active Plot in Dedicated Window"
                                ToolTip.delay: 300

                                MouseArea {
                                    id: pzPopMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (stackView.currentIndex === 0) {
                                            root.openPlotWindow(1, {})
                                        } else if (stackView.currentIndex === 1) {
                                            root.openPlotWindow(2, { mode: 0 })
                                        } else {
                                            root.openPlotWindow(2, { mode: 1 })
                                        }
                                    }
                                }
                            }
                        }

                        SegmentedButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            model: ["Pole-Zero", "Impulse", "Step"]
                            currentIndex: stackView.currentIndex
                            onActivated: function(idx) { stackView.currentIndex = idx }
                        }

                        StackLayout {
                            id: stackView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 120
                            currentIndex: 0

                            PoleZeroPlot { id: anaPzPlot; Layout.fillWidth: true; Layout.fillHeight: true }
                            ImpulseStepPlot { Layout.fillWidth: true; Layout.fillHeight: true; mode: 0 }
                            ImpulseStepPlot { Layout.fillWidth: true; Layout.fillHeight: true; mode: 1 }
                        }
                    }
                }
            }
        }
    }
}
