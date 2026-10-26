import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

// ExportPage.qml — VS Code styled production code exporter
Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitWidth: 800
    implicitHeight: 600
    clip: true

    readonly property int pageMargin: width < 700 ? 10 : 16

    function openSaveDialog() {
        exportModel.generate(filterEngine)   // always save the current design
        saveDialog.open()
    }

    // Keep the generated code in sync with the design (the page stays loaded)
    Connections {
        target: filterEngine
        function onResultsChanged() { exportModel.generate(filterEngine) }
    }

    Item {
        anchors.fill: parent
        anchors.margins: root.pageMargin

        // ── Consistent Tab Page Headline ──────────────────────────────────────
        PageHeader {
            id: pageHeader
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            title: "Production Code Exporter"
            badgeText: filterEngine.responseName + " (" + filterEngine.orderLabel + ")"
        }


        // ── Main VS Code Editor Container ─────────────────────────────────────
        Rectangle {
            anchors {
                top: pageHeader.bottom
                topMargin: 10
                left: parent.left

                right: parent.right
                bottom: parent.bottom
            }
            radius: 8
            color: theme.surface
            border.color: theme.borderColor
            border.width: 1
            clip: true

            Column {
                anchors.fill: parent
                spacing: 0

                // Sticky VS Code Editor Tab Bar
                Rectangle {
                    id: editorTabBar
                    width: parent.width
                    height: 38
                    color: theme.isDark ? "#252526" : "#F3F3F3"
                    z: 5

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: theme.borderColor
                    }

                    // Left: File Tabs (scrolls horizontally when they do not fit)
                    Flickable {
                        id: tabScroller
                        anchors.left: parent.left
                        anchors.right: actionButtons.left
                        anchors.rightMargin: 8
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        contentWidth: tabStrip.width
                        contentHeight: height
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        WheelHandler {
                            onWheel: function(event) {
                                const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                                tabScroller.contentX = Math.max(0, Math.min(tabScroller.contentWidth - tabScroller.width,
                                                                            tabScroller.contentX - delta))
                            }
                        }

                    Row {
                        id: tabStrip
                        height: parent.height
                        spacing: 0

                        Repeater {
                            // Order matches dsp::ExportFormat
                            model: [
                                { name: "filter.c",    lang: "Embedded C",   icon: "file-code" },
                                { name: "Filter.hpp",  lang: "Modern C++20", icon: "file-code" },
                                { name: "filter.py",   lang: "Python SciPy", icon: "file-code" },
                                { name: "filter.json", lang: "JSON Schema",  icon: "file-code" },
                                { name: "filter.m",    lang: "MATLAB / Octave", icon: "file-code" },
                                { name: "filter.rs",   lang: "Rust",         icon: "file-code" },
                                { name: "filter.js",   lang: "WebAudio JS",  icon: "file-code" },
                                { name: "coefficients.csv", lang: "CSV",     icon: "file-code" }
                            ]
                            delegate: Rectangle {
                                required property int index
                                required property var modelData

                                readonly property bool active: exportModel.format === index
                                width: Math.max(100, tabRow.implicitWidth + 24)
                                height: editorTabBar.height
                                color: active
                                    ? (theme.isDark ? "#1E1E1E" : "#FFFFFF")
                                    : (tabHov.hovered ? (theme.isDark ? "#2A2D2E" : "#E8E8E8") : "transparent")

                                // Active top blue accent indicator line
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 2
                                    color: theme.accent
                                    visible: parent.active
                                }

                                // Right vertical divider line
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 1
                                    color: theme.borderColor
                                    opacity: 0.6
                                }

                                Row {
                                    id: tabRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Codicon {
                                        icon: modelData.icon
                                        iconSize: 13
                                        iconColor: parent.parent.active ? theme.accent : theme.secondaryText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.name
                                        font.family: "Stack Sans Headline"
                                        font.pixelSize: 12
                                        font.weight: parent.parent.active ? Font.DemiBold : Font.Normal
                                        color: parent.parent.active ? theme.primaryText : theme.secondaryText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                HoverHandler { id: tabHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        exportModel.format = index
                                        exportModel.generate(filterEngine)
                                    }
                                }
                            }
                        }
                    }
                    }

                    // Right: Action buttons (Copy & Save As)
                    Row {
                        id: actionButtons
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // Copy Button
                        Rectangle {
                            width: copyBtnContent.implicitWidth + 16
                            height: 26
                            radius: 4
                            color: copyHov.hovered ? (theme.isDark ? "#3A3D41" : "#E4E4E4") : (theme.isDark ? "#2D2D30" : "#EEEEEE")
                            border.color: theme.borderColor
                            border.width: 1

                            property bool copied: false
                            Timer {
                                id: copiedTimer
                                interval: 1500
                                onTriggered: parent.copied = false
                            }

                            Row {
                                id: copyBtnContent
                                anchors.centerIn: parent
                                spacing: 5

                                Codicon {
                                    icon: parent.parent.copied ? "check" : "copy"
                                    iconSize: 12
                                    iconColor: parent.parent.copied ? "#30D158" : theme.primaryText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: parent.parent.copied ? "Copied!" : "Copy Code"
                                    font.family: "Stack Sans Headline"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: parent.parent.copied ? "#30D158" : theme.primaryText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            HoverHandler { id: copyHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    exportModel.copyToClipboard()
                                    parent.copied = true
                                    copiedTimer.restart()
                                }
                            }
                        }

                        // Save As Button
                        Rectangle {
                            width: saveBtnContent.implicitWidth + 16
                            height: 26
                            radius: 4
                            color: saveHov.hovered ? "#1890FF" : theme.accent

                            Row {
                                id: saveBtnContent
                                anchors.centerIn: parent
                                spacing: 5

                                Codicon {
                                    icon: "save"
                                    iconSize: 12
                                    iconColor: "#FFFFFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Save File..."
                                    font.family: "Stack Sans Headline"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: "#FFFFFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            HoverHandler { id: saveHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: saveDialog.open()
                            }
                        }
                    }
                }

                // Filter Spec Summary Pill Strip
                Rectangle {
                    width: parent.width
                    height: 28
                    color: theme.isDark ? "#1A1A1A" : "#F7F8F9"

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: theme.borderColor
                        opacity: 0.4
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            text: filterEngine.responseName + " " + filterEngine.typeName
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: theme.primaryText
                        }

                        Text {
                            text: "•"
                            color: theme.secondaryText
                            font.pixelSize: 10
                        }

                        Text {
                            text: filterEngine.isFir
                                  ? "Order " + (filterEngine.tapCount - 1) + " (" + filterEngine.tapCount + " Taps)"
                                  : "Order " + filterEngine.order + " (" + filterEngine.sectionCount + (filterEngine.sectionCount === 1 ? " Biquad)" : " Biquads)")
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 11
                            color: theme.secondaryText
                        }

                        Text {
                            text: "•"
                            color: theme.secondaryText
                            font.pixelSize: 10
                        }

                        Text {
                            text: "Fc = " + Number(filterEngine.cutoffFreq).toLocaleString(Qt.locale(), "f", 0) + " Hz"
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 11
                            color: theme.secondaryText
                        }

                        Text {
                            text: "•"
                            color: theme.secondaryText
                            font.pixelSize: 10
                        }

                        Text {
                            text: "Fs = " + Number(filterEngine.sampleRate).toLocaleString(Qt.locale(), "f", 0) + " Hz"
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 11
                            color: theme.secondaryText
                        }
                    }
                }

                // Code Editor Viewer
                CodeViewer {
                    width: parent.width
                    height: parent.height - editorTabBar.height - 28 - 24
                    code: exportModel.code
                }

                // Status Bar at Bottom
                Rectangle {
                    width: parent.width
                    height: 24
                    color: theme.isDark ? "#181818" : "#EBEBEB"

                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width
                        height: 1
                        color: theme.borderColor
                        opacity: 0.5
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 16

                        Text {
                            text: "Lines: " + exportModel.code.split("\n").length
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 11
                            color: theme.secondaryText
                        }

                        Text {
                            text: "Size: " + exportModel.code.length + " bytes"
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 11
                            color: theme.secondaryText
                        }

                        Text {
                            text: "Encoding: UTF-8"
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 11
                            color: theme.secondaryText
                        }

                        Text {
                            text: "IEEE 754 64-bit Floating Point"
                            font.family: "Stack Sans Headline"
                            font.pixelSize: 11
                            color: theme.accent
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: saveDialog
        title: "Save Filter Source Code"
        options: FileDialog.DontUseNativeDialog
        fileMode: FileDialog.SaveFile
        nameFilters: {
            const ext = [
                "C source files (*.c)",
                "C++ header files (*.hpp *.h)",
                "Python script (*.py)",
                "JSON configuration (*.json)",
                "MATLAB / Octave script (*.m)",
                "Rust source (*.rs)",
                "JavaScript module (*.js *.mjs)",
                "CSV coefficients (*.csv)"
            ]
            return [ext[exportModel.format], "All files (*)"]
        }
        onAccepted: {
            if (!exportModel.saveToFile(selectedFile.toString()))
                Window.window.showNotification("Could not write " + filterEngine.toLocalPath(selectedFile.toString()), true)
        }
    }

    Component.onCompleted: exportModel.generate(filterEngine)
}
