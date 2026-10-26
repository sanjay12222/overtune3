import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// ImpulseStepPlot.qml — Mathematically precise discrete time-domain response plot (Stem / Curve / ZOH)
Item {
    id: root
    implicitWidth: 360
    implicitHeight: 260

    property int mode: 0   // 0=Impulse, 1=Step
    property var points: []
    property string curveColor: mode === 0 ? "#BF5AF2" : "#FF375F"

    // DSP Plot Settings
    property int plotStyle: 0     // 0=Stem, 1=Continuous Line, 2=Staircase/ZOH, 3=Stem+Line
    property int sampleWindow: 48 // 16, 32, 48, 64, 128, 256
    property bool normalize: false
    property bool showGrid: true
    property bool showCrosshair: false // Opt-in Data Cursor / Inspector (+) (Default: OFF)
    property bool isDetached: false

    function openInNewWindow() {
        const w = Window.window
        if (w && typeof w.openStandalonePlot === "function") {
            w.openStandalonePlot(2, { mode: root.mode })
        }
    }


    // Hover / Cursor state
    property int hoverIndex: -1
    property real hoverVal: 0

    // Notification toast state
    property string toastMessage: ""
    property bool toastVisible: false

    readonly property real marginLeft:   68
    readonly property real marginRight:  18
    readonly property real marginTop:    48
    readonly property real marginBottom: 48

    function refreshPoints() {
        points = mode === 0 ? filterEngine.impulseData : filterEngine.stepData
    }

    function schedulePaint() {
        if (canvas.available)
            canvas.requestPaint()
        else
            paintRetry.restart()
    }

    function showPlotToast(msg) {
        toastMessage = msg
        toastVisible = true
        toastTimer.restart()
    }

    function exportPlotImage() {
        savePlotDialog.currentFile = "file://" + filterEngine.defaultExportPlotPath(mode === 0 ? "impulse_stem_plot" : "step_response_plot")
        savePlotDialog.open()
    }

    function quickSavePlotImage() {
        const dest = filterEngine.defaultExportPlotPath(mode === 0 ? "impulse_stem_plot" : "step_response_plot")
        saveToFile(dest)
    }

    function copyPlotImage() {
        const tempPath = filterEngine.defaultExportPlotPath("clipboard_temp")
        root.grabToImage(function(result) {
            if (result.saveToFile(tempPath)) {
                filterEngine.copyImageFileToClipboard(tempPath)
                showPlotToast("Plot image copied to clipboard")
            } else {
                showPlotToast("Failed to grab plot image")
            }
        }, Qt.size(root.width * 2, root.height * 2))
    }

    function saveToFile(filePath) {
        let clean = filterEngine.toLocalPath(filePath.toString())
        if (!clean.endsWith(".png") && !clean.endsWith(".jpg") && !clean.endsWith(".jpeg")) {
            clean += ".png"
        }
        root.grabToImage(function(result) {
            const ok = result.saveToFile(clean)
            if (ok) {
                showPlotToast("Saved: " + clean.substring(clean.lastIndexOf('/') + 1))
            } else {
                showPlotToast("Failed to save image")
            }
        }, Qt.size(root.width * 2, root.height * 2))
    }

    // Outer surface
    Rectangle {
        id: bgCard
        anchors.fill: parent
        color: theme.surface
        radius: 10
        border.color: theme.borderColor
        border.width: 1
    }

    // Canvas Plot
    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative

        onAvailableChanged: {
            if (available) {
                root.refreshPoints()
                requestPaint()
            }
        }

        onPaint: {
            const ctx = getContext("2d")
            if (!ctx) return

            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            const mL = root.marginLeft
            const mT = root.marginTop
            const mR = root.marginRight
            const mB = root.marginBottom
            const pW = width  - mL - mR
            const pH = height - mT - mB
            const allPts = root.points
            const totalN = allPts ? allPts.length : 0

            if (totalN < 2 || pW <= 10 || pH <= 10)
                return

            // Limit to sampleWindow
            const count = Math.min(totalN, Math.max(8, root.sampleWindow))
            const rawPts = []
            let peakAbs = 0.00001
            for (let i = 0; i < count; ++i) {
                const yVal = Number(allPts[i]["y"])
                rawPts.push(yVal)
                if (Math.abs(yVal) > peakAbs)
                    peakAbs = Math.abs(yVal)
            }

            const pts = []
            for (let i = 0; i < count; ++i) {
                pts.push(root.normalize ? (rawPts[i] / peakAbs) : rawPts[i])
            }

            let yMin = pts[0]
            let yMax = pts[0]
            for (let i = 1; i < count; ++i) {
                if (pts[i] < yMin) yMin = pts[i]
                if (pts[i] > yMax) yMax = pts[i]
            }

            // Ensure y=0 baseline is contained
            if (yMin > 0) yMin = 0
            if (yMax < 0) yMax = 0

            const span = (yMax - yMin) || 1
            const pad = Math.max(0.04, span * 0.12)
            yMin -= pad
            yMax += pad
            const yRange = yMax - yMin

            const xMax = Math.max(1, count - 1)
            function toX(i) { return mL + (i / xMax) * pW }
            function toY(v) { return mT + (1.0 - (v - yMin) / yRange) * pH }

            // Plot Grid
            if (root.showGrid) {
                ctx.strokeStyle = theme.plotGrid
                ctx.lineWidth = 1

                // Horizontal grid lines
                const yTicks = 4
                for (let k = 0; k <= yTicks; ++k) {
                    const frac = k / yTicks
                    const y = mT + frac * pH
                    ctx.beginPath()
                    ctx.moveTo(mL, y)
                    ctx.lineTo(mL + pW, y)
                    ctx.stroke()
                }

                // Vertical sample grid lines
                const step = count <= 24 ? 2 : (count <= 48 ? 4 : (count <= 96 ? 8 : (count <= 160 ? 16 : 32)))
                for (let i = 0; i < count; i += step) {
                    const x = toX(i)
                    ctx.beginPath()
                    ctx.moveTo(x, mT)
                    ctx.lineTo(x, mT + pH)
                    ctx.stroke()
                }
            }

            // Zero Baseline Axis (y = 0) — mathematically prominent
            const zy = toY(0)
            if (zy >= mT - 2 && zy <= mT + pH + 2) {
                ctx.strokeStyle = theme.primaryText
                ctx.lineWidth = 1.2
                ctx.beginPath()
                ctx.moveTo(mL, zy)
                ctx.lineTo(mL + pW, zy)
                ctx.stroke()

                // Baseline "0" tick
                ctx.fillStyle = theme.secondaryText
                ctx.font = "10px 'Stack Sans Headline', sans-serif"
                ctx.textAlign = "right"
                ctx.textBaseline = "middle"
                ctx.fillText("0.0", mL - 6, zy)
            }

            // Y-Axis Ticks & Values
            ctx.fillStyle = theme.secondaryText
            ctx.font = "10px 'Stack Sans Headline', sans-serif"
            ctx.textAlign = "right"
            ctx.textBaseline = "middle"
            const numYTicks = 4
            for (let k = 0; k <= numYTicks; ++k) {
                const frac = k / numYTicks
                const val = yMin + (1.0 - frac) * yRange
                const y = mT + frac * pH
                // Skip if too close to zero baseline to prevent overlap
                if (Math.abs(y - zy) > 12) {
                    ctx.fillText(val.toFixed(2), mL - 6, y)
                }
            }

            // X-Axis Ticks & Sample Indices n
            ctx.textAlign = "center"
            ctx.textBaseline = "top"
            const xStep = count <= 24 ? 2 : (count <= 48 ? 4 : (count <= 96 ? 8 : (count <= 160 ? 16 : 32)))
            for (let i = 0; i < count; i += xStep) {
                const x = toX(i)
                ctx.fillText(String(i), x, mT + pH + 5)
            }

            const style = root.plotStyle // 0=Stem, 1=Line, 2=Step/ZOH, 3=Stem+Line

            // 1) Continuous Line or Envelope
            if (style === 1 || style === 3) {
                ctx.lineWidth = style === 3 ? 1.4 : 2.2
                ctx.strokeStyle = style === 3 ? "rgba(191, 90, 242, 0.45)" : root.curveColor
                ctx.beginPath()
                ctx.moveTo(toX(0), toY(pts[0]))
                for (let i = 1; i < count; ++i) {
                    ctx.lineTo(toX(i), toY(pts[i]))
                }
                ctx.stroke()
            }

            // 2) Zero-Order Hold / Staircase
            if (style === 2) {
                ctx.lineWidth = 2.0
                ctx.strokeStyle = root.curveColor
                ctx.beginPath()
                ctx.moveTo(toX(0), toY(pts[0]))
                for (let i = 0; i < count - 1; ++i) {
                    const x1 = toX(i)
                    const x2 = toX(i + 1)
                    const y1 = toY(pts[i])
                    const y2 = toY(pts[i + 1])
                    ctx.lineTo(x2, y1)
                    ctx.lineTo(x2, y2)
                }
                ctx.stroke()
            }

            // 3) Discrete Stem Plot: Vertical stems from y=0 baseline with markers
            if (style === 0 || style === 3) {
                const headRadius = count <= 32 ? 4.0 : (count <= 64 ? 3.0 : 2.2)

                for (let i = 0; i < count; ++i) {
                    const sx = toX(i)
                    const sy = toY(pts[i])
                    const isHovered = (root.showCrosshair && i === root.hoverIndex)

                    // Vertical Stem line from y=0 baseline
                    ctx.strokeStyle = isHovered ? theme.accent : root.curveColor
                    ctx.lineWidth = isHovered ? 2.5 : 1.5
                    ctx.beginPath()
                    ctx.moveTo(sx, zy)
                    ctx.lineTo(sx, sy)
                    ctx.stroke()

                    // Circular Stem Head Marker
                    ctx.beginPath()
                    ctx.arc(sx, sy, isHovered ? (headRadius + 2.5) : headRadius, 0, 2 * Math.PI)
                    ctx.fillStyle = isHovered ? "#FFFFFF" : root.curveColor
                    ctx.fill()
                    ctx.strokeStyle = isHovered ? theme.accent : (theme.isDark ? "#1E1E1E" : "#FFFFFF")
                    ctx.lineWidth = 1.2
                    ctx.stroke()
                }
            }

            // 4) Step Response Theoretical Steady-State Asymptote y = H(1)
            if (root.mode === 1) {
                const yInf = root.normalize ? (filterEngine.steadyStateGain / peakAbs) : filterEngine.steadyStateGain
                const yInfPos = toY(yInf)
                if (yInfPos >= mT && yInfPos <= mT + pH) {
                    ctx.save()
                    ctx.strokeStyle = "#30D158"
                    ctx.lineWidth = 1.2
                    ctx.setLineDash([4, 4])
                    ctx.beginPath()
                    ctx.moveTo(mL, yInfPos)
                    ctx.lineTo(mL + pW, yInfPos)
                    ctx.stroke()
                    ctx.restore()

                    ctx.fillStyle = "#30D158"
                    ctx.font = "bold 10px 'Stack Sans Headline', sans-serif"
                    ctx.textAlign = "right"
                    ctx.textBaseline = "bottom"
                    ctx.fillText("y_ss = " + filterEngine.steadyStateGain.toFixed(3), mL + pW - 6, yInfPos - 2)
                }
            }

            // Hover indicator & crosshair
            if (root.showCrosshair && root.hoverIndex >= 0 && root.hoverIndex < count) {
                const hi = root.hoverIndex
                const hx = toX(hi)
                const hy = toY(pts[hi])

                // Snap indicator circle with halo
                ctx.beginPath()
                ctx.arc(hx, hy, 7, 0, 2 * Math.PI)
                ctx.strokeStyle = theme.accent
                ctx.lineWidth = 1.8
                ctx.stroke()

                // Floating precision HUD badge
                let line1 = "n=" + hi + " | " + (root.mode === 0 ? "h[" : "s[") + hi + "]=" + rawPts[hi].toFixed(5)
                let line2 = ""
                if (root.mode === 1) {
                    const sm = filterEngine.stepMetrics
                    const os = sm && sm["overshootPercent"] !== undefined ? Number(sm["overshootPercent"]) : 0
                    const st = sm && sm["settlingTimeSamples"] !== undefined ? Number(sm["settlingTimeSamples"]) : 0
                    line2 = "Overshoot: " + os.toFixed(1) + "% | Settling: " + st + " smp"
                }

                ctx.font = "bold 10px 'Stack Sans Headline', monospace"
                const tw1 = ctx.measureText(line1).width
                const tw2 = line2 ? ctx.measureText(line2).width : 0
                const tw = Math.max(tw1, tw2) + 16
                const th = line2 ? 34 : 20
                const badgeX = Math.max(mL + 4, Math.min(mL + pW - tw - 4, hx - tw / 2))
                const badgeY = hy > mT + th + 10 ? (hy - th - 4) : (hy + 10)

                ctx.fillStyle = theme.isDark ? "rgba(30, 30, 30, 0.94)" : "rgba(255, 255, 255, 0.94)"
                ctx.strokeStyle = theme.borderColor
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.rect(badgeX, badgeY, tw, th)
                ctx.fill()
                ctx.stroke()

                ctx.fillStyle = theme.primaryText
                ctx.textAlign = "left"
                ctx.textBaseline = line2 ? "top" : "middle"
                ctx.fillText(line1, badgeX + 8, line2 ? (badgeY + 4) : (badgeY + 10))
                if (line2) {
                    ctx.fillStyle = theme.accent
                    ctx.fillText(line2, badgeX + 8, badgeY + 18)
                }
            }
        }
    }

    // Top Controls Bar (Clean Segmented Controls without clutter or overlap)
    Item {
        id: topBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 8
            leftMargin: root.marginLeft
            rightMargin: root.marginRight
        }
        height: 24
        z: 10

        // Left Controls Cluster
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // 1. Unified Style Segmented Pill: [ Stem | Line | Hold ]
            Rectangle {
                height: 22
                width: stylePillRow.implicitWidth + 2
                radius: 4
                color: theme.isDark ? "#25272B" : "#E4E7EB"
                border.color: theme.borderColor
                border.width: 1

                Row {
                    id: stylePillRow
                    anchors.centerIn: parent
                    spacing: 1

                    Repeater {
                        model: [
                            { name: "Stem", style: 0 },
                            { name: "Line", style: 1 },
                            { name: "Hold", style: 2 }
                        ]
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            readonly property bool active: root.plotStyle === modelData.style
                            width: styleTxt.implicitWidth + 10
                            height: 20
                            radius: 3
                            color: active ? theme.accent : (styleMouse.containsMouse ? (theme.isDark ? "#32353A" : "#D1D5DB") : "transparent")

                            Text {
                                id: styleTxt
                                anchors.centerIn: parent
                                text: modelData.name
                                font.family: "Stack Sans Headline"
                                font.pixelSize: 10
                                font.weight: parent.active ? Font.DemiBold : Font.Normal
                                color: parent.active ? "#FFFFFF" : (styleMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                            }

                            MouseArea {
                                id: styleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.plotStyle = modelData.style
                                    root.schedulePaint()
                                }
                            }
                        }
                    }
                }
            }

            // 2. Samples Window Segmented Pill: [ 32 | 64 | All ]
            Rectangle {
                height: 22
                width: sampRow.implicitWidth + 2
                radius: 4
                color: theme.isDark ? "#25272B" : "#E4E7EB"
                border.color: theme.borderColor
                border.width: 1

                Row {
                    id: sampRow
                    anchors.centerIn: parent
                    spacing: 1

                    Repeater {
                        model: [
                            { name: "32", count: 32 },
                            { name: "64", count: 64 },
                            { name: "128", count: 128 },
                            { name: "All", count: 512 }
                        ]
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            readonly property bool active: root.sampleWindow === modelData.count
                            width: sampTxt.implicitWidth + 8
                            height: 20
                            radius: 3
                            color: active ? (theme.isDark ? "#3A3D42" : "#CBD0D6") : (sampMouse.containsMouse ? (theme.isDark ? "#32353A" : "#D1D5DB") : "transparent")

                            Text {
                                id: sampTxt
                                anchors.centerIn: parent
                                text: modelData.name
                                font.family: "Stack Sans Headline"
                                font.pixelSize: 10
                                font.weight: parent.active ? Font.DemiBold : Font.Normal
                                color: parent.active ? theme.primaryText : theme.secondaryText
                            }

                            MouseArea {
                                id: sampMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.sampleWindow = modelData.count
                                    root.schedulePaint()
                                }
                            }
                        }
                    }
                }
            }

            // 3. Normalization Toggle Pill
            Rectangle {
                height: 22
                width: normTxt.implicitWidth + 12
                radius: 4
                color: root.normalize
                        ? (theme.isDark ? "#1C2D42" : "#E1EFFF")
                        : (normMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent")
                border.color: root.normalize ? theme.accent : theme.borderColor
                border.width: 1

                Text {
                    id: normTxt
                    anchors.centerIn: parent
                    text: "Norm"
                    font.family: "Stack Sans Headline"
                    font.pixelSize: 10
                    font.weight: root.normalize ? Font.DemiBold : Font.Normal
                    color: root.normalize ? theme.accent : (normMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                }

                MouseArea {
                    id: normMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.normalize = !root.normalize
                        root.schedulePaint()
                    }
                }
            }
        }

        // Right Controls Cluster (Data Cursor, Save, Copy, Menu)
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            // Data Cursor (+) Inspector Opt-in Toggle Pill
            Rectangle {
                height: 22
                width: curRow.implicitWidth + 12
                radius: 4
                color: root.showCrosshair
                        ? theme.accent
                        : (curMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent")
                border.color: root.showCrosshair ? theme.accent : theme.borderColor
                border.width: 1

                Row {
                    id: curRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "✛"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.showCrosshair ? "#FFFFFF" : (curMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Cursor"
                        font.family: "Stack Sans Headline"
                        font.pixelSize: 10
                        font.weight: root.showCrosshair ? Font.DemiBold : Font.Normal
                        color: root.showCrosshair ? "#FFFFFF" : (curMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                ToolTip.visible: curMouse.containsMouse
                ToolTip.text: root.showCrosshair ? "Data Cursor Active (Click to Hide)" : "Enable Data Cursor / Inspector (+) (Default: Off)"
                ToolTip.delay: 350

                MouseArea {
                    id: curMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.showCrosshair = !root.showCrosshair
                        if (!root.showCrosshair) {
                            root.hoverIndex = -1
                        }
                        root.schedulePaint()
                    }
                }
            }

            // Save Image Button
            Rectangle {
                width: 26
                height: 22
                radius: 4
                color: saveMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "camera"
                    iconSize: 12
                    iconColor: saveMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }

                ToolTip.visible: saveMouse.containsMouse
                ToolTip.text: "Save Plot Image (PNG)"
                ToolTip.delay: 400

                MouseArea {
                    id: saveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.exportPlotImage()
                }
            }

            // Copy Image Button
            Rectangle {
                width: 26
                height: 22
                radius: 4
                color: copyMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "copy"
                    iconSize: 12
                    iconColor: copyMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }

                ToolTip.visible: copyMouse.containsMouse
                ToolTip.text: "Copy Plot to Clipboard"
                ToolTip.delay: 400

                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyPlotImage()
                }
            }

            // Pop out in New Window Button
            Rectangle {
                width: 26
                height: 22
                radius: 4
                visible: !root.isDetached
                color: popoutMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "link-external"
                    iconSize: 12
                    iconColor: popoutMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }

                ToolTip.visible: popoutMouse.containsMouse
                ToolTip.text: "Open in Dedicated Window"
                ToolTip.delay: 400

                MouseArea {
                    id: popoutMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openInNewWindow()
                }
            }

            // MATLAB Context Menu Button

            Rectangle {
                width: 24
                height: 22
                radius: 4
                color: menuBtnMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "kebab-vertical"
                    iconSize: 13
                    iconColor: menuBtnMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }

                ToolTip.visible: menuBtnMouse.containsMouse
                ToolTip.text: "Plot Settings & Options (Right-Click)"
                ToolTip.delay: 400

                MouseArea {
                    id: menuBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: impulseContextMenu.popup(topBar.x + topBar.width - 230, topBar.y + topBar.height + 4)
                }
            }
        }
    }

    // Mouse Area for Interactive Snapping & Context Menu
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.showCrosshair ? Qt.CrossCursor : Qt.ArrowCursor
        z: 5

        onPressed: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                impulseContextMenu.popup(mouse.x, mouse.y)
            }
        }

        onPositionChanged: function(mouse) {
            if (!root.showCrosshair) {
                if (root.hoverIndex !== -1) {
                    root.hoverIndex = -1
                    root.schedulePaint()
                }
                return
            }

            const mL = root.marginLeft
            const pW = root.width - mL - root.marginRight
            const count = Math.min(root.points ? root.points.length : 0, root.sampleWindow)
            if (count > 1 && mouse.x >= mL && mouse.x <= mL + pW) {
                const norm = (mouse.x - mL) / pW
                const idx = Math.round(norm * (count - 1))
                if (idx >= 0 && idx < count) {
                    if (root.hoverIndex !== idx) {
                        root.hoverIndex = idx
                        root.schedulePaint()
                    }
                    return
                }
            }
            if (root.hoverIndex !== -1) {
                root.hoverIndex = -1
                root.schedulePaint()
            }
        }

        onExited: {
            if (root.hoverIndex !== -1) {
                root.hoverIndex = -1
                root.schedulePaint()
            }
        }
    }

    // MATLAB Filter Designer Time-Domain Response Context Menu
    Menu {
        id: impulseContextMenu

        background: Rectangle {
            implicitWidth: 230
            color: theme.isDark ? "#25272B" : "#FFFFFF"
            border.color: theme.borderColor
            border.width: 1
            radius: 8
        }

        Menu {
            title: "Response Type"
            MenuItem {
                text: "Impulse Response h[n]"
                checkable: true
                checked: root.mode === 0
                onTriggered: { root.mode = 0; root.refreshPoints(); root.schedulePaint() }
            }
            MenuItem {
                text: "Step Response s[n]"
                checkable: true
                checked: root.mode === 1
                onTriggered: { root.mode = 1; root.refreshPoints(); root.schedulePaint() }
            }
        }

        Menu {
            title: "Plot Style"
            MenuItem {
                text: "Discrete Stem (MATLAB stem)"
                checkable: true
                checked: root.plotStyle === 0
                onTriggered: { root.plotStyle = 0; root.schedulePaint() }
            }
            MenuItem {
                text: "Continuous Line"
                checkable: true
                checked: root.plotStyle === 1
                onTriggered: { root.plotStyle = 1; root.schedulePaint() }
            }
            MenuItem {
                text: "Staircase / Zero-Order Hold (ZOH)"
                checkable: true
                checked: root.plotStyle === 2
                onTriggered: { root.plotStyle = 2; root.schedulePaint() }
            }
            MenuItem {
                text: "Stem + Line Overlay"
                checkable: true
                checked: root.plotStyle === 3
                onTriggered: { root.plotStyle = 3; root.schedulePaint() }
            }
        }

        Menu {
            title: "Sample Window"
            MenuItem {
                text: "16 Samples"
                checkable: true
                checked: root.sampleWindow === 16
                onTriggered: { root.sampleWindow = 16; root.schedulePaint() }
            }
            MenuItem {
                text: "32 Samples"
                checkable: true
                checked: root.sampleWindow === 32
                onTriggered: { root.sampleWindow = 32; root.schedulePaint() }
            }
            MenuItem {
                text: "48 Samples"
                checkable: true
                checked: root.sampleWindow === 48
                onTriggered: { root.sampleWindow = 48; root.schedulePaint() }
            }
            MenuItem {
                text: "64 Samples"
                checkable: true
                checked: root.sampleWindow === 64
                onTriggered: { root.sampleWindow = 64; root.schedulePaint() }
            }
            MenuItem {
                text: "128 Samples"
                checkable: true
                checked: root.sampleWindow === 128
                onTriggered: { root.sampleWindow = 128; root.schedulePaint() }
            }
            MenuItem {
                text: "256 Samples"
                checkable: true
                checked: root.sampleWindow === 256
                onTriggered: { root.sampleWindow = 256; root.schedulePaint() }
            }
            MenuItem {
                text: "512 Samples (All)"
                checkable: true
                checked: root.sampleWindow === 512
                onTriggered: { root.sampleWindow = 512; root.schedulePaint() }
            }
        }

        MenuSeparator {}

        MenuItem {
            text: "Data Cursor / Inspector (+)"
            checkable: true
            checked: root.showCrosshair
            onTriggered: {
                root.showCrosshair = !root.showCrosshair
                if (!root.showCrosshair) root.hoverIndex = -1
                root.schedulePaint()
            }
        }

        MenuItem {
            text: "Normalize Amplitude [0, 1]"
            checkable: true
            checked: root.normalize
            onTriggered: {
                root.normalize = !root.normalize
                root.schedulePaint()
            }
        }

        MenuItem {
            text: "Show Grid"
            checkable: true
            checked: root.showGrid
            onTriggered: {
                root.showGrid = !root.showGrid
                root.schedulePaint()
            }
        }

        MenuSeparator {}

        MenuItem {
            text: "Copy Plot Image to Clipboard"
            onTriggered: root.copyPlotImage()
        }

        MenuItem {
            text: "Save Plot Image (PNG)..."
            onTriggered: root.exportPlotImage()
        }

        MenuSeparator {}

        MenuItem {
            text: "Copy Response Sequence (CSV)"
            onTriggered: {
                let csv = "n,val\n"
                const n = Math.min(root.points ? root.points.length : 0, root.sampleWindow)
                for (let i = 0; i < n; ++i) {
                    csv += i + "," + root.points[i] + "\n"
                }
                filterEngine.copyText(csv)
                root.showPlotToast("Response sequence CSV copied")
            }
        }
    }

    // Save File Dialog
    FileDialog {
        id: savePlotDialog
        title: "Save Plot Image"
        options: FileDialog.DontUseNativeDialog
        fileMode: FileDialog.SaveFile
        nameFilters: ["PNG Image (*.png)", "JPEG Image (*.jpg *.jpeg)", "All files (*)"]
        defaultSuffix: "png"
        onAccepted: root.saveToFile(selectedFile)
    }

    // In-plot Notification Toast
    Rectangle {
        id: toastBanner
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 10
        }
        width: Math.min(parent.width - 24, toastText.implicitWidth + 20)
        height: 26
        radius: 6
        color: theme.isDark ? "#2C2C2E" : "#3A3A3C"
        border.color: theme.borderColor
        border.width: 1
        opacity: root.toastVisible ? 1.0 : 0.0
        visible: opacity > 0.01
        z: 100

        Behavior on opacity { NumberAnimation { duration: 160 } }

        Row {
            anchors.centerIn: parent
            spacing: 6
            Codicon {
                icon: "check"
                iconSize: 11
                iconColor: "#30D158"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: toastText
                text: root.toastMessage
                font.family: "Stack Sans Headline"
                font.pixelSize: 11
                color: "#FFFFFF"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Timer {
            id: toastTimer
            interval: 2200
            onTriggered: root.toastVisible = false
        }
    }

    // Y-Axis Squircle Badge (Solid Black background, positioned clear of tick numbers)
    Rectangle {
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: (root.marginTop - root.marginBottom) / 2
        rotation: -90
        width: yBadgeRow.implicitWidth + 12
        height: 22
        radius: 6
        color: "#000000"
        border.color: Qt.rgba(1, 1, 1, 0.22)
        border.width: 1

        Row {
            id: yBadgeRow
            anchors.centerIn: parent
            spacing: 5
            Image {
                anchors.verticalCenter: parent.verticalCenter
                height: 12
                fillMode: Image.PreserveAspectFit
                mipmap: true
                source: "qrc:/FilterDesigner/math/axis_" + (root.mode === 0 ? "hn" : "sn") + "_dark.png"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.mode === 0 ? "Impulse" : "Step"
                font.pixelSize: 10
                font.family: "Stack Sans Headline"
                font.weight: Font.Medium
                color: "#FFFFFF"
            }
        }
    }

    // X-Axis Squircle Badge (Solid Black background, positioned below tick numbers)
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: (root.marginLeft - root.marginRight) / 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        width: xBadgeRow.implicitWidth + 14
        height: 22
        radius: 6
        color: "#000000"
        border.color: Qt.rgba(1, 1, 1, 0.22)
        border.width: 1

        Row {
            id: xBadgeRow
            anchors.centerIn: parent
            spacing: 5
            Image {
                anchors.verticalCenter: parent.verticalCenter
                height: 12
                fillMode: Image.PreserveAspectFit
                mipmap: true
                source: "qrc:/FilterDesigner/math/axis_sample_n_dark.png"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Discrete Time"
                font.pixelSize: 10
                font.family: "Stack Sans Headline"
                font.weight: Font.Medium
                color: "#FFFFFF"
            }
        }
    }

    Timer {
        id: paintRetry
        interval: 50
        repeat: false
        onTriggered: root.schedulePaint()
    }

    Timer {
        interval: 120
        running: true
        repeat: false
        onTriggered: {
            root.refreshPoints()
            root.schedulePaint()
        }
    }

    Connections {
        target: filterEngine
        function onResultsChanged() {
            root.refreshPoints()
            root.schedulePaint()
        }
    }

    Connections {
        target: theme
        function onThemeModeChanged() { root.schedulePaint() }
    }

    Component.onCompleted: {
        refreshPoints()
        schedulePaint()
    }

    onModeChanged: {
        refreshPoints()
        schedulePaint()
    }
    onVisibleChanged: { if (visible) schedulePaint() }
    onWidthChanged:  schedulePaint()
    onHeightChanged: schedulePaint()
    onPointsChanged: schedulePaint()
}
