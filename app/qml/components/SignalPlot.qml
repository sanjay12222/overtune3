import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// SignalPlot.qml — Waveform simulation plot with discrete stem mode, axes & image export
Item {
    id: root
    implicitWidth: 600
    implicitHeight: 300

    property var  inputData:  []
    property var  outputData: []
    property bool showOutput: true

    // DSP Plot Settings
    property int displayStyle: 0 // 0=Continuous Line, 1=Discrete Stem, 2=Points
    property int sampleLimit: 256 // Maximum samples rendered

    // Notification toast state
    property string toastMessage: ""
    property bool toastVisible: false
    property bool isDetached: false

    function openInNewWindow() {
        const w = Window.window
        if (w && typeof w.openStandalonePlot === "function") {
            w.openStandalonePlot(3, {})
        }
    }


    readonly property real marginLeft:   68
    readonly property real marginRight:  18
    readonly property real marginTop:    48
    readonly property real marginBottom: 48
    readonly property real plotW: Math.max(1, width  - marginLeft - marginRight)
    readonly property real plotH: Math.max(1, height - marginTop  - marginBottom)

    // Viewport Zoom & Pan State (Desmos Graphing Engine)
    property real viewXMin: 0
    property real viewXMax: 100
    property real viewYMin: -1.2
    property real viewYMax: 1.2
    property bool isCustomView: false
    property bool isPanning: false
    property real lastMouseX: 0
    property real lastMouseY: 0

    // Realtime Signal Animation Engine
    property bool isAnimating: false
    property real animProgress: 1.0
    property int  animDuration: 1800
    property bool loopAnimation: false
    property int  currentSampleIdx: 0

    function startAnimation() {
        animRunner.stop()
        animProgress = 0.0
        animRunner.start()
    }

    function pauseAnimation() {
        if (animRunner.running) {
            animRunner.pause()
        } else if (animRunner.paused) {
            animRunner.resume()
        } else {
            startAnimation()
        }
    }

    function restartAnimation() {
        startAnimation()
    }

    NumberAnimation {
        id: animRunner
        target: root
        property: "animProgress"
        from: 0.0
        to: 1.0
        duration: root.animDuration
        easing.type: Easing.Linear
        onRunningChanged: {
            root.isAnimating = running
            if (!running && root.loopAnimation) {
                root.startAnimation()
            }
        }
    }

    onAnimProgressChanged: {
        if (isAnimating || animProgress < 1.0) {
            schedulePaint()
        }
    }

    function desmosNiceStep(range, targetSteps) {
        if (!(range > 0)) return 1
        const rawStep = range / targetSteps
        const mag = Math.pow(10, Math.floor(Math.log10(rawStep)))
        const norm = rawStep / mag
        let step = mag
        if (norm <= 1.5) step = 1 * mag
        else if (norm <= 3.5) step = 2 * mag
        else if (norm <= 7.5) step = 5 * mag
        else step = 10 * mag
        return step
    }

    function autoScale() {
        isCustomView = false
        const pts = root.inputData
        const totalN = pts ? pts.length : 0
        if (totalN > 1) {
            const n = Math.min(totalN, root.sampleLimit)
            viewXMin = 0
            viewXMax = Math.max(1, Number(pts[n - 1]["x"]))

            let yMin = -0.5
            let yMax = 0.5
            for (let i = 0; i < n; ++i) {
                const inY = Number(pts[i]["y"])
                if (inY < yMin) yMin = inY
                if (inY > yMax) yMax = inY
            }
            if (root.showOutput && root.outputData) {
                const outN = Math.min(root.outputData.length, n)
                for (let i = 0; i < outN; ++i) {
                    const outY = Number(root.outputData[i]["y"])
                    if (outY < yMin) yMin = outY
                    if (outY > yMax) yMax = outY
                }
            }
            const pad = Math.max(0.08, (yMax - yMin) * 0.15)
            viewYMin = yMin - pad
            viewYMax = yMax + pad
        } else {
            viewXMin = 0
            viewXMax = 100
            viewYMin = -1.2
            viewYMax = 1.2
        }
        schedulePaint()
    }

    function zoomAt(mx, my, factor) {
        isCustomView = true
        const pW = root.plotW
        const pH = root.plotH
        const curX = xToVal(mx)
        const curY = yToVal(my)

        const newXMin = curX - (curX - viewXMin) * factor
        const newXMax = curX + (viewXMax - curX) * factor
        if (newXMax - newXMin > 2 && newXMax - newXMin < 20000) {
            viewXMin = newXMin
            viewXMax = newXMax
        }

        const newYMin = curY - (curY - viewYMin) * factor
        const newYMax = curY + (viewYMax - curY) * factor
        if (newYMax - newYMin > 0.005 && newYMax - newYMin < 500) {
            viewYMin = newYMin
            viewYMax = newYMax
        }
        schedulePaint()
    }

    function zoomCenter(factor) {
        zoomAt(root.marginLeft + root.plotW / 2, root.marginTop + root.plotH / 2, factor)
    }

    function panBy(dx, dy) {
        isCustomView = true
        const pW = root.plotW
        const pH = root.plotH
        const dX = (dx / pW) * (viewXMax - viewXMin)
        viewXMin -= dX
        viewXMax -= dX

        const dY = (dy / pH) * (viewYMax - viewYMin)
        viewYMin += dY
        viewYMax += dY
        schedulePaint()
    }

    function toX(x) {
        const range = (viewXMax - viewXMin) || 1
        return root.marginLeft + ((Number(x) - viewXMin) / range) * root.plotW
    }

    function toY(y) {
        const range = (viewYMax - viewYMin) || 1
        return root.marginTop + (1.0 - (Number(y) - viewYMin) / range) * root.plotH
    }

    function xToVal(mx) {
        const norm = Math.max(0, Math.min(1, (mx - root.marginLeft) / root.plotW))
        return viewXMin + norm * (viewXMax - viewXMin)
    }

    function yToVal(my) {
        const norm = (my - root.marginTop) / root.plotH
        return viewYMax - norm * (viewYMax - viewYMin)
    }

    function refreshData() {
        const prevLen = outputData ? outputData.length : 0
        inputData = simulation.inputSignal
        outputData = simulation.outputSignal
        if (!isCustomView) {
            autoScale()
        }
        if (outputData && outputData.length > 1 && (prevLen === 0 || !isAnimating)) {
            startAnimation()
        }
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
        savePlotDialog.currentFile = "file://" + filterEngine.defaultExportPlotPath("simulation_waveform")
        savePlotDialog.open()
    }

    function quickSavePlotImage() {
        saveToFile(filterEngine.defaultExportPlotPath("simulation_waveform"))
    }

    function copyPlotImage() {
        const tempPath = filterEngine.defaultExportPlotPath("clipboard_temp_signal")
        root.grabToImage(function(result) {
            if (result.saveToFile(tempPath)) {
                filterEngine.copyImageFileToClipboard(tempPath)
                showPlotToast("Signal plot copied to clipboard")
            } else {
                showPlotToast("Failed to copy signal plot")
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
                showPlotToast("Failed to save signal plot")
            }
        }, Qt.size(root.width * 2, root.height * 2))
    }

    Rectangle {
        anchors.fill: parent
        color: theme.surface
        radius: 10
        border.color: theme.borderColor
        border.width: 1
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative

        onAvailableChanged: {
            if (available) {
                root.refreshData()
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
            const pW = width  - mL - root.marginRight
            const pH = height - mT - root.marginBottom
            const pts = root.inputData
            const totalN = pts ? pts.length : 0

            if (pW <= 10 || pH <= 10) return

            if (totalN < 2) {
                ctx.strokeStyle = theme.plotGrid
                ctx.lineWidth = 1
                for (let k = 0; k <= 4; ++k) {
                    const y = mT + (k / 4) * pH
                    ctx.beginPath(); ctx.moveTo(mL, y); ctx.lineTo(mL + pW, y); ctx.stroke()
                }
                ctx.fillStyle = theme.secondaryText
                ctx.font = "13px 'Stack Sans Headline', sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText("Click Sine, Chirp, or Dual-Tone above to preview live filtering", mL + pW / 2, mT + pH / 2)
                return
            }

            const n = Math.min(totalN, root.sampleLimit)

            // Dynamic Desmos Y Grid & Ticks
            const yRange = (root.viewYMax - root.viewYMin) || 1
            const yStep = root.desmosNiceStep(yRange, 5)
            const firstY = Math.ceil(root.viewYMin / yStep) * yStep

            ctx.strokeStyle = theme.plotGrid
            ctx.lineWidth = 1
            ctx.fillStyle = theme.secondaryText
            ctx.font = "11px 'Stack Sans Headline', sans-serif"
            ctx.textAlign = "right"
            ctx.textBaseline = "middle"

            for (let yVal = firstY; yVal <= root.viewYMax + 0.0001; yVal += yStep) {
                const y = root.toY(yVal)
                if (y >= mT && y <= mT + pH) {
                    ctx.beginPath()
                    ctx.moveTo(mL, y)
                    ctx.lineTo(mL + pW, y)
                    ctx.stroke()
                    const decimals = yStep < 0.05 ? 3 : (yStep < 0.5 ? 2 : (yStep < 2 ? 1 : 0))
                    ctx.fillText(yVal.toFixed(decimals), mL - 6, y)
                }
            }

            // Zero Baseline Axis
            const zy = root.toY(0)
            if (zy >= mT && zy <= mT + pH) {
                ctx.strokeStyle = theme.primaryText
                ctx.lineWidth = 1.2
                ctx.beginPath()
                ctx.moveTo(mL, zy)
                ctx.lineTo(mL + pW, zy)
                ctx.stroke()
            }

            // Dynamic Desmos X Grid & Ticks
            const xRange = (root.viewXMax - root.viewXMin) || 1
            const xStep = root.desmosNiceStep(xRange, 6)
            const firstX = Math.ceil(root.viewXMin / xStep) * xStep

            ctx.fillStyle = theme.secondaryText
            ctx.font = "11px 'Stack Sans Headline', sans-serif"
            ctx.textAlign = "center"
            ctx.textBaseline = "top"

            for (let xVal = firstX; xVal <= root.viewXMax + 0.0001; xVal += xStep) {
                const x = root.toX(xVal)
                if (x >= mL && x <= mL + pW) {
                    ctx.beginPath()
                    ctx.moveTo(x, mT)
                    ctx.lineTo(x, mT + pH)
                    ctx.stroke()
                    const xDecimals = xStep < 1 ? 1 : 0
                    ctx.fillText(xVal.toFixed(xDecimals), x, mT + pH + 5)
                }
            }

            // Render Signals (Strictly clipped to graph viewport)
            ctx.save()
            ctx.beginPath()
            ctx.rect(mL, mT, pW, pH)
            ctx.clip()

            const style = root.displayStyle // 0=Line, 1=Stem, 2=Points

            // 1) Input Signal (theme.accent / blue)
            if (style === 0) {
                // Continuous Line
                ctx.lineWidth = 1.6
                ctx.strokeStyle = theme.accent
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(root.toX(pts[0]["x"]), root.toY(pts[0]["y"]))
                for (let i = 1; i < n; ++i) ctx.lineTo(root.toX(pts[i]["x"]), root.toY(pts[i]["y"]))
                ctx.stroke()
            } else if (style === 1) {
                // Discrete Stems
                const step = n <= 64 ? 1 : Math.ceil(n / 64)
                for (let i = 0; i < n; i += step) {
                    const sx = root.toX(pts[i]["x"])
                    const sy = root.toY(pts[i]["y"])
                    ctx.strokeStyle = "rgba(10, 132, 255, 0.7)"
                    ctx.lineWidth = 1.4
                    ctx.beginPath(); ctx.moveTo(sx, zy); ctx.lineTo(sx, sy); ctx.stroke()
                    ctx.beginPath(); ctx.arc(sx, sy, 2.5, 0, 2 * Math.PI)
                    ctx.fillStyle = theme.accent; ctx.fill()
                }
            } else {
                // Points
                for (let i = 0; i < n; ++i) {
                    const sx = root.toX(pts[i]["x"])
                    const sy = root.toY(pts[i]["y"])
                    ctx.beginPath(); ctx.arc(sx, sy, 2.0, 0, 2 * Math.PI)
                    ctx.fillStyle = theme.accent; ctx.fill()
                }
            }

            // 2) Filtered Output Signal (#30D158 / green)
            if (root.showOutput && root.outputData && root.outputData.length > 1) {
                const opts = root.outputData
                const maxOn = Math.min(opts.length, n)
                // Realtime animated emergence of filtered output
                const on = Math.max(1, Math.min(maxOn, Math.ceil(root.animProgress * maxOn)))
                root.currentSampleIdx = on - 1

                if (style === 0) {
                    ctx.lineWidth = 2.0
                    ctx.strokeStyle = "#30D158"
                    ctx.beginPath()
                    ctx.moveTo(root.toX(opts[0]["x"]), root.toY(opts[0]["y"]))
                    for (let i = 1; i < on; ++i) ctx.lineTo(root.toX(opts[i]["x"]), root.toY(opts[i]["y"]))
                    ctx.stroke()
                } else if (style === 1) {
                    const step = maxOn <= 64 ? 1 : Math.ceil(maxOn / 64)
                    for (let i = 0; i < on; i += step) {
                        const sx = root.toX(opts[i]["x"])
                        const sy = root.toY(opts[i]["y"])
                        ctx.strokeStyle = "rgba(48, 209, 88, 0.8)"
                        ctx.lineWidth = 1.4
                        ctx.beginPath(); ctx.moveTo(sx, zy); ctx.lineTo(sx, sy); ctx.stroke()
                        ctx.beginPath(); ctx.arc(sx, sy, 2.5, 0, 2 * Math.PI)
                        ctx.fillStyle = "#30D158"; ctx.fill()
                    }
                } else {
                    for (let i = 0; i < on; ++i) {
                        const sx = root.toX(opts[i]["x"])
                        const sy = root.toY(opts[i]["y"])
                        ctx.beginPath(); ctx.arc(sx, sy, 2.2, 0, 2 * Math.PI)
                        ctx.fillStyle = "#30D158"; ctx.fill()
                    }
                }

                // If currently animating or scanning across the waveform:
                if (root.animProgress < 1.0 || root.isAnimating) {
                    const headIdx = Math.max(0, Math.min(maxOn - 1, on - 1))
                    const headX = root.toX(opts[headIdx]["x"])
                    const outY = root.toY(opts[headIdx]["y"])
                    const inY = root.toY(pts[headIdx] ? pts[headIdx]["y"] : 0)

                    // 1. Vertical Scanner Laser Line
                    const grad = ctx.createLinearGradient(headX, mT, headX, mT + pH)
                    grad.addColorStop(0.0, "rgba(48, 209, 88, 0.0)")
                    grad.addColorStop(0.2, "rgba(48, 209, 88, 0.35)")
                    grad.addColorStop(0.5, "rgba(48, 209, 88, 0.8)")
                    grad.addColorStop(0.8, "rgba(48, 209, 88, 0.35)")
                    grad.addColorStop(1.0, "rgba(48, 209, 88, 0.0)")
                    ctx.strokeStyle = grad
                    ctx.lineWidth = 1.6
                    ctx.beginPath()
                    ctx.moveTo(headX, mT)
                    ctx.lineTo(headX, mT + pH)
                    ctx.stroke()

                    // 2. Attenuation/Transfer Delta Bar
                    ctx.strokeStyle = "rgba(255, 159, 10, 0.65)"
                    ctx.lineWidth = 1.2
                    ctx.beginPath()
                    ctx.moveTo(headX, inY)
                    ctx.lineTo(headX, outY)
                    ctx.stroke()

                    // 3. Input beacon ring (Blue)
                    ctx.beginPath()
                    ctx.arc(headX, inY, 4.0, 0, 2 * Math.PI)
                    ctx.fillStyle = theme.accent
                    ctx.fill()

                    // 4. Emerging Output wavefront particle (Green Halo + Core)
                    ctx.beginPath()
                    ctx.arc(headX, outY, 7.0, 0, 2 * Math.PI)
                    ctx.fillStyle = "rgba(48, 209, 88, 0.3)"
                    ctx.fill()

                    ctx.beginPath()
                    ctx.arc(headX, outY, 3.5, 0, 2 * Math.PI)
                    ctx.fillStyle = "#30D158"
                    ctx.fill()

                    // 5. Floating Realtime Data Pill
                    const badgeText = "n=" + headIdx + " | y[n]=" + Number(opts[headIdx]["y"]).toFixed(2)
                    ctx.font = "bold 10px 'Stack Sans Headline', sans-serif"
                    const badgeW = ctx.measureText(badgeText).width + 14
                    const badgeX = Math.max(mL + 4, Math.min(mL + pW - badgeW - 4, headX - badgeW / 2))
                    const badgeY = mT + 8

                    ctx.fillStyle = theme.isDark ? "rgba(20, 22, 25, 0.92)" : "rgba(255, 255, 255, 0.95)"
                    ctx.strokeStyle = "#30D158"
                    ctx.lineWidth = 1
                    ctx.fillRect(badgeX, badgeY, badgeW, 18)
                    ctx.strokeRect(badgeX, badgeY, badgeW, 18)

                    ctx.fillStyle = "#30D158"
                    ctx.textAlign = "center"
                    ctx.textBaseline = "middle"
                    ctx.fillText(badgeText, badgeX + badgeW / 2, badgeY + 9)
                }
            }

            ctx.restore()

            // Legend Badges
            ctx.font = "bold 12px 'Stack Sans Headline', sans-serif"
            ctx.textAlign = "left"
            ctx.textBaseline = "middle"

            ctx.fillStyle = theme.accent
            ctx.fillRect(mL + 8, mT + 8, 14, 3)
            ctx.fillStyle = theme.primaryText
            ctx.fillText("x[n] Input Signal", mL + 26, mT + 9)

            if (root.showOutput) {
                const inW = ctx.measureText("x[n] Input Signal").width
                const outBarX = mL + 26 + inW + 20
                ctx.fillStyle = "#30D158"
                ctx.fillRect(outBarX, mT + 8, 14, 3)
                ctx.fillStyle = theme.primaryText
                ctx.fillText("y[n] Filtered Output", outBarX + 18, mT + 9)
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

            // Unified Style Segmented Pill: [ Curve | Stem | Dots ]
            Rectangle {
                height: 22
                width: sigStyleRow.implicitWidth + 2
                radius: 4
                color: theme.isDark ? "#25272B" : "#E4E7EB"
                border.color: theme.borderColor
                border.width: 1

                Row {
                    id: sigStyleRow
                    anchors.centerIn: parent
                    spacing: 1

                    Repeater {
                        model: [
                            { name: "Curve", style: 0 },
                            { name: "Stem",  style: 1 },
                            { name: "Dots",  style: 2 }
                        ]
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            readonly property bool active: root.displayStyle === modelData.style
                            width: sigTxt.implicitWidth + 10
                            height: 20
                            radius: 3
                            color: active ? theme.accent : (sigMouse.containsMouse ? (theme.isDark ? "#32353A" : "#D1D5DB") : "transparent")

                            Text {
                                id: sigTxt
                                anchors.centerIn: parent
                                text: modelData.name
                                font.family: "Stack Sans Headline"
                                font.pixelSize: 10
                                font.weight: parent.active ? Font.DemiBold : Font.Normal
                                color: parent.active ? "#FFFFFF" : (sigMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                            }

                            MouseArea {
                                id: sigMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.displayStyle = modelData.style
                                    root.schedulePaint()
                                }
                            }
                        }
                    }
                }
            }

            // Realtime Filter Animation Button
            Rectangle {
                height: 22
                width: playAnimRow.implicitWidth + 14
                radius: 4
                color: root.isAnimating
                       ? (theme.isDark ? "#143820" : "#E6F9ED")
                       : (playAnimMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent")
                border.color: root.isAnimating ? "#30D158" : theme.borderColor
                border.width: 1

                Row {
                    id: playAnimRow
                    anchors.centerIn: parent
                    spacing: 5
                    Codicon {
                        icon: root.isAnimating ? "debug-pause" : (root.animProgress >= 1.0 ? "debug-restart" : "play")
                        iconSize: 11
                        iconColor: root.isAnimating ? "#30D158" : (playAnimMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.isAnimating ? "Filtering..." : (root.animProgress >= 1.0 ? "Replay Wave" : "Play Wave")
                        font.family: "Stack Sans Headline"
                        font.pixelSize: 10
                        font.weight: root.isAnimating ? Font.DemiBold : Font.Normal
                        color: root.isAnimating ? "#30D158" : (playAnimMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                ToolTip.visible: playAnimMouse.containsMouse
                ToolTip.text: root.isAnimating ? "Pause realtime filter animation" : "Play realtime animated filter propagation"
                ToolTip.delay: 350

                MouseArea {
                    id: playAnimMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.isAnimating) {
                            root.pauseAnimation()
                        } else {
                            root.startAnimation()
                        }
                    }
                }
            }

            // Loop Toggle Button (Oscilloscope Mode)
            Rectangle {
                width: 24
                height: 22
                radius: 4
                color: root.loopAnimation
                       ? (theme.isDark ? "#143820" : "#E6F9ED")
                       : (loopMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent")
                border.color: root.loopAnimation ? "#30D158" : theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "sync"
                    iconSize: 11
                    iconColor: root.loopAnimation ? "#30D158" : (loopMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                }

                ToolTip.visible: loopMouse.containsMouse
                ToolTip.text: "Toggle Continuous Loop Sweep (Oscilloscope Mode)"
                ToolTip.delay: 350

                MouseArea {
                    id: loopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.loopAnimation = !root.loopAnimation
                        if (root.loopAnimation && !root.isAnimating) {
                            root.startAnimation()
                        }
                        root.showPlotToast(root.loopAnimation ? "Loop sweep active" : "Loop sweep disabled")
                    }
                }
            }

            // Speed Cycle Button
            Rectangle {
                width: speedTxt.implicitWidth + 10
                height: 22
                radius: 4
                color: speedMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Text {
                    id: speedTxt
                    anchors.centerIn: parent
                    text: root.animDuration === 1800 ? "1x" : (root.animDuration === 900 ? "2x" : "0.5x")
                    font.family: "Stack Sans Headline"
                    font.pixelSize: 10
                    color: speedMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }

                ToolTip.visible: speedMouse.containsMouse
                ToolTip.text: "Animation Speed (Click to cycle 1x, 2x, 0.5x)"
                ToolTip.delay: 350

                MouseArea {
                    id: speedMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.animDuration === 1800) root.animDuration = 900
                        else if (root.animDuration === 900) root.animDuration = 3600
                        else root.animDuration = 1800
                    }
                }
            }
        }

        // Right Controls Cluster (Auto Scale, Save, Copy, Menu)
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            // Auto Scale / Fit View Pill (Desmos Home)
            Rectangle {
                height: 22
                width: autoScaleSigRow.implicitWidth + 12
                radius: 4
                color: root.isCustomView
                        ? (theme.isDark ? "#1C2D42" : "#E1EFFF")
                        : (autoScaleSigMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent")
                border.color: root.isCustomView ? theme.accent : theme.borderColor
                border.width: 1

                Row {
                    id: autoScaleSigRow
                    anchors.centerIn: parent
                    spacing: 4
                    Codicon {
                        icon: "screen-full"
                        iconSize: 11
                        iconColor: root.isCustomView ? theme.accent : (autoScaleSigMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Auto Scale"
                        font.family: "Stack Sans Headline"
                        font.pixelSize: 11
                        font.weight: root.isCustomView ? Font.DemiBold : Font.Normal
                        color: root.isCustomView ? theme.accent : (autoScaleSigMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                ToolTip.visible: autoScaleSigMouse.containsMouse
                ToolTip.text: "Auto Scale / Fit View (Desmos)"
                ToolTip.delay: 350

                MouseArea {
                    id: autoScaleSigMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.autoScale()
                        root.showPlotToast("Auto-scaled waveform fit")
                    }
                }
            }

            // Save Image Button
            Rectangle {
                width: 26
                height: 22
                radius: 4
                color: saveSigMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "camera"
                    iconSize: 12
                    iconColor: saveSigMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }
                ToolTip.visible: saveSigMouse.containsMouse
                ToolTip.text: "Save Signal Plot Image (PNG)"
                ToolTip.delay: 400

                MouseArea {
                    id: saveSigMouse
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
                color: copySigMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "copy"
                    iconSize: 12
                    iconColor: copySigMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }
                ToolTip.visible: copySigMouse.containsMouse
                ToolTip.text: "Copy Signal Image"
                ToolTip.delay: 400

                MouseArea {
                    id: copySigMouse
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
                color: popoutSigMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "link-external"
                    iconSize: 12
                    iconColor: popoutSigMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }

                ToolTip.visible: popoutSigMouse.containsMouse
                ToolTip.text: "Open Signal Scope in Dedicated Window"
                ToolTip.delay: 400

                MouseArea {
                    id: popoutSigMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openInNewWindow()
                }
            }

            // Options Menu Button

            Rectangle {
                width: 24
                height: 22
                radius: 4
                color: menuSigBtnMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "kebab-vertical"
                    iconSize: 13
                    iconColor: menuSigBtnMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }

                ToolTip.visible: menuSigBtnMouse.containsMouse
                ToolTip.text: "Signal Plot Settings & Options (Right-Click)"
                ToolTip.delay: 400

                MouseArea {
                    id: menuSigBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sigContextMenu.popup(topBar.x + topBar.width - 230, topBar.y + topBar.height + 4)
                }
            }
        }
    }

    // Interactive Graph MouseArea: Drag to Pan, Wheel to Zoom, Double-click to Auto-scale
    MouseArea {
        id: plotAreaMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.isPanning ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onPressed: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                sigContextMenu.popup(mouse.x, mouse.y)
            } else if (mouse.button === Qt.LeftButton) {
                root.isPanning = true
                root.lastMouseX = mouse.x
                root.lastMouseY = mouse.y
                cursorShape = Qt.ClosedHandCursor
            }
        }

        onReleased: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.isPanning = false
                cursorShape = Qt.OpenHandCursor
            }
        }

        onDoubleClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.autoScale()
                root.showPlotToast("Auto-scaled waveform fit")
            }
        }

        onWheel: function(wheel) {
            const factor = wheel.angleDelta.y > 0 ? 0.82 : 1.22
            root.zoomAt(wheel.x, wheel.y, factor)
        }

        onPositionChanged: function(mouse) {
            if (root.isPanning) {
                const dx = mouse.x - root.lastMouseX
                const dy = mouse.y - root.lastMouseY
                root.lastMouseX = mouse.x
                root.lastMouseY = mouse.y
                root.panBy(dx, dy)
            }
        }
    }

    // Floating Desmos Graphing Controls Cluster [ + ] [ − ] [ ⤢ ]
    Rectangle {
        id: desmosCluster
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: 16
            bottomMargin: 14
        }
        width: 30
        height: 88
        radius: 6
        color: theme.isDark ? "#25272B" : "#FFFFFF"
        border.color: theme.borderColor
        border.width: 1
        z: 20

        Column {
            anchors.centerIn: parent
            spacing: 2

            // Zoom In (+)
            Rectangle {
                width: 26; height: 26; radius: 4
                color: sigZoomInMouse.containsMouse ? (theme.isDark ? "#3A3A3C" : "#E5E5EA") : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.family: "Stack Sans Headline"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    color: theme.primaryText
                }
                ToolTip.visible: sigZoomInMouse.containsMouse
                ToolTip.text: "Zoom In (+)"
                ToolTip.delay: 350
                MouseArea {
                    id: sigZoomInMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.zoomCenter(0.8)
                }
            }

            // Zoom Out (−)
            Rectangle {
                width: 26; height: 26; radius: 4
                color: sigZoomOutMouse.containsMouse ? (theme.isDark ? "#3A3A3C" : "#E5E5EA") : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "−"
                    font.family: "Stack Sans Headline"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    color: theme.primaryText
                }
                ToolTip.visible: sigZoomOutMouse.containsMouse
                ToolTip.text: "Zoom Out (−)"
                ToolTip.delay: 350
                MouseArea {
                    id: sigZoomOutMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.zoomCenter(1.25)
                }
            }

            // Auto Scale / Fit (⤢)
            Rectangle {
                width: 26; height: 26; radius: 4
                color: sigAutoFitMouse.containsMouse ? (theme.isDark ? "#3A3A3C" : "#E5E5EA") : "transparent"
                Codicon {
                    anchors.centerIn: parent
                    icon: "screen-full"
                    iconSize: 12
                    iconColor: root.isCustomView ? theme.accent : theme.secondaryText
                }
                ToolTip.visible: sigAutoFitMouse.containsMouse
                ToolTip.text: "Auto Scale / Fit View (Double-click plot)"
                ToolTip.delay: 350
                MouseArea {
                    id: sigAutoFitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.autoScale()
                        root.showPlotToast("Auto-scaled waveform fit")
                    }
                }
            }
        }
    }

    // MATLAB Simulation Waveform Context Menu
    Menu {
        id: sigContextMenu

        background: Rectangle {
            implicitWidth: 230
            color: theme.isDark ? "#25272B" : "#FFFFFF"
            border.color: theme.borderColor
            border.width: 1
            radius: 8
        }

        MenuItem {
            text: "Auto Scale / Fit View (Desmos)"
            onTriggered: {
                root.autoScale()
                root.showPlotToast("Auto-scaled waveform fit")
            }
        }

        MenuItem {
            text: "Zoom In"
            onTriggered: root.zoomCenter(0.8)
        }

        MenuItem {
            text: "Zoom Out"
            onTriggered: root.zoomCenter(1.25)
        }

        MenuSeparator {}

        Menu {
            title: "Waveform Style"
            MenuItem {
                text: "Continuous Line"
                checkable: true
                checked: root.displayStyle === 0
                onTriggered: { root.displayStyle = 0; root.schedulePaint() }
            }
            MenuItem {
                text: "Discrete Stem (Digital)"
                checkable: true
                checked: root.displayStyle === 1
                onTriggered: { root.displayStyle = 1; root.schedulePaint() }
            }
            MenuItem {
                text: "Sample Points Only"
                checkable: true
                checked: root.displayStyle === 2
                onTriggered: { root.displayStyle = 2; root.schedulePaint() }
            }
        }

        MenuItem {
            text: "Show Filtered Output Signal"
            checkable: true
            checked: root.showOutput
            onTriggered: {
                root.showOutput = !root.showOutput
                root.schedulePaint()
            }
        }

        MenuSeparator {}

        MenuItem {
            text: "Copy Signal Waveform to Clipboard"
            onTriggered: root.copyPlotImage()
        }

        MenuItem {
            text: "Save Waveform Image (PNG)..."
            onTriggered: root.exportPlotImage()
        }

        MenuSeparator {}

        MenuItem {
            text: "Copy Input & Output Signal Data (CSV)"
            onTriggered: {
                let csv = "index,input,output\n"
                const n = Math.min(root.inputData ? root.inputData.length : 0, root.sampleLimit)
                for (let i = 0; i < n; ++i) {
                    const inVal = root.inputData[i] || 0
                    const outVal = (root.outputData && root.outputData.length > i) ? root.outputData[i] : ""
                    csv += i + "," + inVal + "," + outVal + "\n"
                }
                filterEngine.copyText(csv)
                root.showPlotToast("Simulation signal CSV copied")
            }
        }
    }

    // Save File Dialog
    FileDialog {
        id: savePlotDialog
        title: "Save Waveform Plot Image"
        options: FileDialog.DontUseNativeDialog
        fileMode: FileDialog.SaveFile
        nameFilters: ["PNG Image (*.png)", "JPEG Image (*.jpg *.jpeg)", "All files (*)"]
        defaultSuffix: "png"
        onAccepted: root.saveToFile(selectedFile)
    }

    // In-plot Notification Toast
    Rectangle {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 10
        }
        width: Math.min(parent.width - 24, sigToastText.implicitWidth + 20)
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
                id: sigToastText
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
        width: ySigBadgeRow.implicitWidth + 12
        height: 22
        radius: 6
        color: "#000000"
        border.color: Qt.rgba(1, 1, 1, 0.22)
        border.width: 1

        Row {
            id: ySigBadgeRow
            anchors.centerIn: parent
            spacing: 5
            Image {
                anchors.verticalCenter: parent.verticalCenter
                height: 12
                fillMode: Image.PreserveAspectFit
                mipmap: true
                source: "qrc:/FilterDesigner/math/axis_signals_dark.png"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Signals"
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
        width: xSigBadgeRow.implicitWidth + 14
        height: 22
        radius: 6
        color: "#000000"
        border.color: Qt.rgba(1, 1, 1, 0.22)
        border.width: 1

        Row {
            id: xSigBadgeRow
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
            root.refreshData()
            root.schedulePaint()
        }
    }

    Connections {
        target: simulation
        function onDataChanged() {
            root.refreshData()
            root.schedulePaint()
        }
    }

    Connections {
        target: theme
        function onThemeModeChanged() { root.schedulePaint() }
    }

    Component.onCompleted: {
        refreshData()
        schedulePaint()
    }

    onVisibleChanged: { if (visible) schedulePaint() }
    onWidthChanged:  schedulePaint()
    onHeightChanged: schedulePaint()
    onInputDataChanged: schedulePaint()
    onOutputDataChanged: schedulePaint()
}
