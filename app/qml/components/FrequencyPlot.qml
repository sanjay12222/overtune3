import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// FrequencyPlot.qml — Interactive, mathematically precise DSP frequency response plot
// Optimized for ultra-high throughput, 144 FPS rendering and zero-lag mouse tracking
Item {
    id: root
    implicitWidth: 600
    implicitHeight: 400

    property int    displayMode: 0   // 0=Magnitude, 1=Phase, 2=Group Delay
    property double sampleRate: filterEngine.sampleRate
    property double cutoffFreq: filterEngine.cutoffFreq
    property double cutoffFreq2: filterEngine.cutoffFreq2
    property bool   isBandFilter: filterEngine.filterType >= 2
    property var    points: []

    // High-performance typed array buffers for ultra-low latency plot math & culling
    property var _cachedX: null
    property var _cachedY: null
    property int _cachedCount: 0
    property var _screenX: null
    property var _screenY: null

    // DSP Frequency Settings
    property int  freqScale: 0        // 0=Logarithmic (Hz), 1=Linear (Hz), 2=Normalized (ω/π rad/s), 3=Normalized (f/fs)
    property int  magScaleMode: 0     // 0=dB scale, 1=Linear |H|
    property int  phaseWrapMode: 0    // 0=Unwrapped, 1=Wrapped [-180°, 180°]
    property bool showDspGuides: false // Default: OFF (clean view)
    property bool showCrosshair: theme.showCrosshairByDefault // Data Cursor / + Inspector (Settings default)
    property real plotLineWidth: theme.plotLineWidth
    property bool isDetached: false

    // ── Responsive Layout Breakpoints ─────────────────────────────────────────
    readonly property bool compactMode: width < 540
    readonly property bool ultraCompactMode: width < 420

    function openInNewWindow() {
        const w = Window.window
        if (w && typeof w.openStandalonePlot === "function") {
            w.openStandalonePlot(0, { displayMode: root.displayMode })
        }
    }

    // Interactive Hover & Cursor state
    property real hoverFreq: -1
    property real hoverVal: 0
    property real hoverLinMag: 0
    property real hoverPhaseDeg: 0
    property real hoverPhaseUnwrapped: 0
    property real hoverGd: 0
    property real cursorCanvasX: -1
    property real cursorCanvasY: -1
    property bool isHovering: false

    // Notification toast state
    property string toastMessage: ""
    property bool toastVisible: false

    readonly property real marginLeft:   80
    readonly property real marginRight:  20
    readonly property real marginTop:    48
    readonly property real marginBottom: 56
    readonly property real plotW: Math.max(1, width  - marginLeft - marginRight)
    readonly property real plotH: Math.max(1, height - marginTop  - marginBottom)

    // Viewport Zoom & Pan State (Desmos Graphing Engine)
    property real viewXMin: (freqScale === 0 ? 10 : 0)
    property real viewXMax: sampleRate / 2.0
    property real viewYMin: -100
    property real viewYMax: 10
    property bool isCustomView: false

    function autoScale() {
        isCustomView = false
        const nyquist = sampleRate / 2.0
        if (freqScale === 0) {
            let minF = 10
            const fc = filterEngine.cutoffFreq
            if (fc > 0 && fc < 100) {
                minF = Math.max(0.05, Math.pow(10, Math.floor(Math.log10(fc)) - 1))
            }
            viewXMin = minF
            viewXMax = nyquist
        } else {
            viewXMin = 0
            viewXMax = nyquist
        }

        const cnt = root._cachedCount
        const cy = root._cachedY

        if (displayMode === 0) {
            if (magScaleMode === 0) {
                let minDb = 999, maxDb = -999
                if (cnt > 0 && cy) {
                    for (let i = 0; i < cnt; ++i) {
                        const y = cy[i]
                        if (!isNaN(y) && isFinite(y)) {
                            if (y < minDb) minDb = y
                            if (y > maxDb) maxDb = y
                        }
                    }
                }
                if (minDb > maxDb) { minDb = -80; maxDb = 5; }
                viewYMin = Math.max(-160, Math.floor(minDb / 10) * 10 - 10)
                viewYMax = Math.min(40, Math.ceil(maxDb / 5) * 5 + 5)
            } else {
                viewYMin = 0.0
                viewYMax = 1.2
            }
        } else if (displayMode === 1) {
            if (phaseWrapMode === 1) {
                viewYMin = -180
                viewYMax = 180
            } else {
                let minP = 0, maxP = 0
                if (cnt > 0 && cy) {
                    minP = cy[0]; maxP = minP
                    for (let i = 1; i < cnt; ++i) {
                        const y = cy[i]
                        if (!isNaN(y) && isFinite(y)) {
                            if (y < minP) minP = y
                            if (y > maxP) maxP = y
                        }
                    }
                }
                viewYMin = Math.min(-90, Math.floor((minP - 15) / 45) * 45)
                viewYMax = Math.max(0,   Math.ceil((maxP + 15) / 45) * 45)
            }
        } else {
            let minGd = 0, maxGd = 5
            if (cnt > 0 && cy) {
                for (let i = 0; i < cnt; ++i) {
                    const y = cy[i]
                    if (!isNaN(y) && isFinite(y) && Math.abs(y) < 1000) {
                        if (y < minGd) minGd = y
                        if (y > maxGd) maxGd = y
                    }
                }
            }
            viewYMin = Math.floor(minGd / 5) * 5
            viewYMax = Math.max(5, Math.ceil(maxGd * 1.25 / 5) * 5 + 5)
        }
        schedulePaint()
    }

    function findClosestPointIndex(targetF) {
        const cnt = root._cachedCount
        const cx = root._cachedX
        if (cnt <= 0 || !cx) return -1
        let low = 0, high = cnt - 1
        while (low <= high) {
            const mid = (low + high) >> 1
            const fMid = cx[mid]
            if (fMid < targetF) low = mid + 1
            else high = mid - 1
        }
        if (low >= cnt) return cnt - 1
        if (low <= 0) return 0
        const d1 = Math.abs(cx[low] - targetF)
        const d0 = Math.abs(cx[low - 1] - targetF)
        return (d0 <= d1) ? (low - 1) : low
    }

    function zoomAt(mx, my, factor) {
        isCustomView = true
        const pW = root.plotW
        const pH = root.plotH
        const clampedMx = Math.max(root.marginLeft, Math.min(root.marginLeft + pW, mx))
        const clampedMy = Math.max(root.marginTop, Math.min(root.marginTop + pH, my))

        const curF = xToFreq(clampedMx)
        const curV = yToVal(clampedMy)

        // X Zoom (Log vs Linear)
        if (root.freqScale === 0) {
            const logMin = Math.log(Math.max(0.1, viewXMin)) / Math.LN10
            const logMax = Math.log(Math.max(1, viewXMax)) / Math.LN10
            const logCur = Math.log(Math.max(0.1, curF)) / Math.LN10
            const newLogMin = logCur - (logCur - logMin) * factor
            const newLogMax = logCur + (logMax - logCur) * factor
            if (newLogMax - newLogMin > 0.08 && newLogMax - newLogMin < 7) {
                viewXMin = Math.max(0.01, Math.pow(10, newLogMin))
                viewXMax = Math.min(root.sampleRate * 2, Math.pow(10, newLogMax))
            }
        } else {
            const newXMin = curF - (curF - viewXMin) * factor
            const newXMax = curF + (viewXMax - curF) * factor
            if (newXMax - newXMin > 5 && newXMax - newXMin < root.sampleRate * 4) {
                viewXMin = newXMin
                viewXMax = newXMax
            }
        }

        // Y Zoom
        const newYMin = curV - (curV - viewYMin) * factor
        const newYMax = curV + (viewYMax - curV) * factor
        if (newYMax - newYMin > 0.01 && newYMax - newYMin < 500) {
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

        if (root.freqScale === 0) {
            const logMin = Math.log(Math.max(0.1, viewXMin)) / Math.LN10
            const logMax = Math.log(Math.max(1, viewXMax)) / Math.LN10
            const dLog = (dx / pW) * (logMax - logMin)
            viewXMin = Math.max(0.01, Math.pow(10, logMin - dLog))
            viewXMax = Math.min(root.sampleRate * 2, Math.pow(10, logMax - dLog))
        } else {
            const dF = (dx / pW) * (viewXMax - viewXMin)
            viewXMin -= dF
            viewXMax -= dF
        }
        const dV = (dy / pH) * (viewYMax - viewYMin)
        viewYMin += dV
        viewYMax += dV
        schedulePaint()
    }

    function xToFreq(mx) {
        const pW = root.plotW
        const norm = Math.max(0, Math.min(1, (mx - root.marginLeft) / pW))
        if (root.freqScale === 0) {
            const logMin = Math.log(Math.max(1e-4, root.viewXMin)) / Math.LN10
            const logMax = Math.log(Math.max(1, root.viewXMax)) / Math.LN10
            return Math.pow(10, logMin + norm * (logMax - logMin))
        } else {
            return Math.max(0, root.viewXMin + norm * (root.viewXMax - root.viewXMin))
        }
    }

    function yToVal(my) {
        const pH = root.plotH
        const norm = (my - root.marginTop) / pH
        return root.viewYMax - norm * (root.viewYMax - root.viewYMin)
    }

    function freqToCanvasX(f) {
        const pW = root.plotW
        if (root.freqScale === 0) {
            const safeF = Math.max(1e-4, f)
            const logMin = Math.log(Math.max(1e-4, root.viewXMin)) / Math.LN10
            const logMax = Math.log(Math.max(1, root.viewXMax)) / Math.LN10
            const logRange = (logMax - logMin) || 1
            const logF = Math.log(safeF) / Math.LN10
            return root.marginLeft + ((logF - logMin) / logRange) * pW
        } else {
            const range = (root.viewXMax - root.viewXMin) || 1
            return root.marginLeft + ((f - root.viewXMin) / range) * pW
        }
    }

    function refreshPoints() {
        if (displayMode === 0) {
            points = filterEngine.magnitudeData
        } else if (displayMode === 1) {
            points = filterEngine.phaseData
        } else {
            points = filterEngine.groupDelayData
        }

        const pts = root.points
        const n = pts ? pts.length : 0
        root._cachedCount = n
        if (n > 0) {
            if (!root._cachedX || root._cachedX.length < n) {
                root._cachedX = new Float64Array(n)
                root._cachedY = new Float64Array(n)
            }
            const cx = root._cachedX
            const cy = root._cachedY
            for (let i = 0; i < n; ++i) {
                const p = pts[i]
                cx[i] = p["x"]
                cy[i] = p["y"]
            }
        }
        if (!isCustomView) autoScale()
    }

    function schedulePaint() {
        if (canvas.available) canvas.requestPaint()
        else paintRetry.restart()
        if (crosshairCanvas.available) crosshairCanvas.requestPaint()
    }

    function scheduleCrosshairPaint() {
        if (crosshairCanvas.available) crosshairCanvas.requestPaint()
    }

    function showPlotToast(msg) {
        toastMessage = msg
        toastVisible = true
        toastTimer.restart()
    }

    function exportPlotImage() {
        const modeName = displayMode === 0 ? "magnitude_response" : (displayMode === 1 ? "phase_response" : "group_delay")
        savePlotDialog.currentFile = "file://" + filterEngine.defaultExportPlotPath(modeName)
        savePlotDialog.open()
    }

    function quickSavePlotImage() {
        const modeName = displayMode === 0 ? "magnitude_response" : (displayMode === 1 ? "phase_response" : "group_delay")
        saveToFile(filterEngine.defaultExportPlotPath(modeName))
    }

    function copyPlotImage() {
        const tempPath = filterEngine.defaultExportPlotPath("clipboard_temp_freq")
        root.grabToImage(function(result) {
            if (result.saveToFile(tempPath)) {
                filterEngine.copyImageFileToClipboard(tempPath)
                showPlotToast("Plot image copied to clipboard")
            } else {
                showPlotToast("Failed to copy plot image")
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
                showPlotToast("Failed to save plot image")
            }
        }, Qt.size(root.width * 2, root.height * 2))
    }

    // Inner plot area background
    Rectangle {
        x: root.marginLeft
        y: root.marginTop
        width: root.plotW
        height: root.plotH
        color: theme.surfaceHigh
        radius: 6
        border.color: theme.borderColor
        border.width: 1
    }

    // ── Native QML Math Typography with Squircle Background ──────────────────────
    // Y-Axis Label (Rotated 90 degrees with solid black squircle badge, spaced from tick numbers)
    Item {
        x: 0
        y: root.marginTop
        width: 36
        height: root.plotH

        Rectangle {
            anchors.centerIn: parent
            rotation: -90
            width: yAxisRow.implicitWidth + 14
            height: 24
            radius: 6
            color: "#000000"
            border.color: Qt.rgba(1, 1, 1, 0.22)
            border.width: 1

            Row {
                id: yAxisRow
                anchors.centerIn: parent
                spacing: 6

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 14
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    source: {
                        const sfx = "_dark.png" // Always use white/light math glyphs on solid black background
                        if (root.displayMode === 0) {
                            return root.magScaleMode === 1
                                ? "qrc:/FilterDesigner/math/axis_mag_lin" + sfx
                                : "qrc:/FilterDesigner/math/axis_mag_db" + sfx
                        } else if (root.displayMode === 1) {
                            return "qrc:/FilterDesigner/math/axis_phase" + sfx
                        } else {
                            return "qrc:/FilterDesigner/math/axis_group_delay" + sfx
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (root.displayMode === 0) {
                            return root.magScaleMode === 1 ? "Linear" : "Magnitude"
                        } else if (root.displayMode === 1) {
                            return root.phaseWrapMode === 1 ? "Wrapped Phase" : "Unwrapped Phase"
                        } else {
                            return "Group Delay"
                        }
                    }
                    font.pixelSize: 11
                    font.family: "Stack Sans Headline"
                    font.weight: Font.Medium
                    color: "#FFFFFF"
                }
            }
        }
    }

    // X-Axis Label with solid black squircle badge (anchored safely below frequency tick numbers)
    Item {
        x: root.marginLeft
        y: root.marginTop + root.plotH
        width: root.plotW
        height: root.marginBottom

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            width: xAxisRow.implicitWidth + 16
            height: 24
            radius: 6
            color: "#000000"
            border.color: Qt.rgba(1, 1, 1, 0.22)
            border.width: 1

            Row {
                id: xAxisRow
                anchors.centerIn: parent
                spacing: 6

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 14
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    source: {
                        const sfx = "_dark.png" // Always white math glyphs on solid black background
                        if (root.freqScale === 2) return "qrc:/FilterDesigner/math/axis_freq_rad" + sfx
                        if (root.freqScale === 3) return "qrc:/FilterDesigner/math/axis_freq_norm" + sfx
                        return "qrc:/FilterDesigner/math/axis_freq_hz" + sfx
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (root.freqScale === 2) return "Normalized Radian Frequency"
                        if (root.freqScale === 3) return "Digital Frequency"
                        return "Frequency"
                    }
                    font.pixelSize: 11
                    font.family: "Stack Sans Headline"
                    font.weight: Font.Medium
                    color: "#FFFFFF"
                }
            }
        }
    }

    // ── Main Plot Canvas (Background Grid, Axes, DSP Curve, Handles) ──────────
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
            const pW = root.plotW
            const pH = root.plotH
            const nyquist = root.sampleRate / 2.0
            const mode = root.displayMode
            const fScale = root.freqScale
            const vXMin = root.viewXMin
            const vXMax = root.viewXMax
            const vYMin = root.viewYMin
            const vYMax = root.viewYMax
            const vYRange = (vYMax - vYMin) || 1

            // Fast native line dash helper
            function strokeDashedLine(x1, y1, x2, y2, dashLen, gapLen) {
                ctx.setLineDash([dashLen, gapLen])
                ctx.beginPath()
                ctx.moveTo(x1, y1)
                ctx.lineTo(x2, y2)
                ctx.stroke()
                ctx.setLineDash([])
            }

            // Coordinate mapping functions
            function freqToX(f) {
                return root.freqToCanvasX(f) - mL
            }

            function valToY(v) {
                return mT + ((vYMax - v) / vYRange) * pH
            }

            function niceStep(range, targetTicks) {
                const raw = Math.abs(range) / Math.max(1, targetTicks)
                const power = Math.floor(Math.log10(raw))
                const base = raw / Math.pow(10, power)
                let niceBase = 1
                if (base >= 7) niceBase = 10
                else if (base >= 3.5) niceBase = 5
                else if (base >= 1.5) niceBase = 2
                return niceBase * Math.pow(10, power)
            }

            function formatFreqLabel(f) {
                if (fScale === 0 || fScale === 1) {
                    if (f >= 1000) return (f / 1000).toFixed(f % 1000 === 0 ? 0 : 1) + "k"
                    return String(Math.round(f))
                } else if (fScale === 2) {
                    const frac = f / nyquist
                    if (frac === 0) return "0"
                    if (Math.abs(frac - 1.0) < 0.01) return "π"
                    return frac.toFixed(2) + "π"
                } else {
                    const frac = (f / root.sampleRate).toFixed(2)
                    return String(frac)
                }
            }

            // ── Grid & Axes ────────────────────────────────────────────────────────
            ctx.strokeStyle = theme.plotGrid
            ctx.lineWidth = 1

            // Y-Grid
            const yStep = niceStep(vYRange, 7)
            const yStart = Math.floor(vYMin / yStep) * yStep
            for (let v = yStart; v <= vYMax + yStep * 0.05; v += yStep) {
                if (v < vYMin - yStep * 0.05) continue
                const y = valToY(v)
                if (y < mT - 0.5 || y > mT + pH + 0.5) continue

                ctx.strokeStyle = theme.plotGrid
                ctx.beginPath()
                ctx.moveTo(mL, y)
                ctx.lineTo(mL + pW, y)
                ctx.stroke()

                ctx.fillStyle = theme.secondaryText
                ctx.font = "500 11px 'Stack Sans Headline', sans-serif"
                ctx.textAlign = "right"
                ctx.textBaseline = "middle"
                let label = (yStep < 1) ? v.toFixed(1) : v.toFixed(0)
                if (mode === 0 && root.magScaleMode === 1) label = v.toFixed(2)
                ctx.fillText(label, mL - 8, y)
            }

            // X-Grid
            ctx.textAlign = "center"
            ctx.textBaseline = "top"
            ctx.font = "500 11px 'Stack Sans Headline', sans-serif"

            if (fScale === 0) {
                const logMin = Math.log(Math.max(0.01, vXMin)) / Math.LN10
                const logMax = Math.log(Math.max(1, vXMax)) / Math.LN10
                const dStart = Math.floor(logMin)
                const dEnd = Math.ceil(logMax)

                for (let d = dStart; d <= dEnd; ++d) {
                    const baseFreq = Math.pow(10, d)
                    const multipliers = (logMax - logMin <= 2.2) ? [1, 2, 5] : [1]
                    for (let m = 0; m < multipliers.length; ++m) {
                        const freq = baseFreq * multipliers[m]
                        if (freq < vXMin * 0.98 || freq > vXMax * 1.02) continue
                        const x = mL + freqToX(freq)
                        if (x < mL - 0.5 || x > mL + pW + 0.5) continue

                        ctx.strokeStyle = (multipliers[m] === 1) ? theme.plotGrid : (theme.isDark ? "rgba(255, 255, 255, 0.05)" : "rgba(0, 0, 0, 0.05)")
                        ctx.beginPath()
                        ctx.moveTo(x, mT)
                        ctx.lineTo(x, mT + pH)
                        ctx.stroke()

                        ctx.fillStyle = theme.secondaryText
                        ctx.fillText(formatFreqLabel(freq), x, mT + pH + 6)
                    }
                }
            } else {
                const xRange = (vXMax - vXMin) || 1
                const xStep = niceStep(xRange, 7)
                const xStart = Math.floor(vXMin / xStep) * xStep

                for (let freq = xStart; freq <= vXMax + xStep * 0.05; freq += xStep) {
                    if (freq < vXMin - xStep * 0.05) continue
                    const x = mL + freqToX(freq)
                    if (x < mL - 0.5 || x > mL + pW + 0.5) continue

                    ctx.strokeStyle = theme.plotGrid
                    ctx.beginPath()
                    ctx.moveTo(x, mT)
                    ctx.lineTo(x, mT + pH)
                    ctx.stroke()

                    ctx.fillStyle = theme.secondaryText
                    ctx.fillText(formatFreqLabel(freq), x, mT + pH + 6)
                }
            }

            // ── DSP Reference Overlays (Tolerances & Cutoff) ──────────────────────
            ctx.save()
            ctx.beginPath()
            ctx.rect(mL, mT, pW, pH)
            ctx.clip()

            if (root.showDspGuides && mode === 0) {
                if (root.magScaleMode === 0) {
                    const edgeDb = filterEngine.edgeDb
                    const y3 = valToY(edgeDb)
                    if (y3 >= mT && y3 <= mT + pH) {
                        ctx.strokeStyle = "#D97706"
                        ctx.lineWidth = 1
                        strokeDashedLine(mL, y3, mL + pW, y3, 4, 3)
                        ctx.fillStyle = "#D97706"
                        ctx.font = "bold 11px 'Stack Sans Headline', sans-serif"
                        ctx.textAlign = "right"
                        ctx.textBaseline = "bottom"
                        ctx.fillText(edgeDb.toFixed(1) + " dB Cutoff", mL + pW - 8, y3 - 2)
                    }

                    const rip = filterEngine.rippleDb
                    if (rip > 0.05 && rip < 10) {
                        const yRip = valToY(-rip)
                        if (yRip >= mT && yRip <= mT + pH) {
                            ctx.strokeStyle = "rgba(16, 185, 129, 0.85)"
                            ctx.lineWidth = 1
                            strokeDashedLine(mL, yRip, mL + pW, yRip, 3, 3)
                            ctx.fillStyle = "rgba(16, 185, 129, 0.9)"
                            ctx.font = "bold 11px 'Stack Sans Headline', sans-serif"
                            ctx.textAlign = "left"
                            ctx.textBaseline = "bottom"
                            ctx.fillText("Passband Ripple (-" + rip.toFixed(1) + " dB)", mL + 8, yRip - 2)
                        }
                    }

                    const stopDb = filterEngine.stopbandDb
                    if (stopDb > 10 && stopDb < 100) {
                        const yStop = valToY(-stopDb)
                        if (yStop >= mT && yStop <= mT + pH) {
                            ctx.strokeStyle = "rgba(239, 68, 68, 0.85)"
                            ctx.lineWidth = 1
                            strokeDashedLine(mL, yStop, mL + pW, yStop, 4, 3)
                            ctx.fillStyle = "rgba(239, 68, 68, 0.9)"
                            ctx.font = "bold 11px 'Stack Sans Headline', sans-serif"
                            ctx.textAlign = "right"
                            ctx.textBaseline = "bottom"
                            ctx.fillText("Stopband Min (-" + stopDb.toFixed(0) + " dB)", mL + pW - 8, yStop - 2)
                        }
                    }
                } else {
                    const yHalf = valToY(Math.SQRT1_2)
                    if (yHalf >= mT && yHalf <= mT + pH) {
                        ctx.strokeStyle = "#D97706"
                        ctx.lineWidth = 1
                        strokeDashedLine(mL, yHalf, mL + pW, yHalf, 4, 3)
                        ctx.fillStyle = "#D97706"
                        ctx.font = "bold 11px 'Stack Sans Headline', sans-serif"
                        ctx.textAlign = "right"
                        ctx.textBaseline = "bottom"
                        ctx.fillText("1/√2 ≈ 0.7071 (-3 dB)", mL + pW - 8, yHalf - 2)
                    }
                }
            }

            // ── Frequency Response Curve (Ultra-Fast Culling & Typed Buffer Pass) ──
            const count = root._cachedCount
            const cachedX = root._cachedX
            const cachedY = root._cachedY

            if (count > 1 && cachedX && cachedY) {
                // Viewport Culling via Binary Search
                let iStart = 0, iEnd = count - 1
                if (count > 2) {
                    let low = 0, high = count - 1
                    while (low <= high) {
                        const mid = (low + high) >> 1
                        if (cachedX[mid] < vXMin) low = mid + 1
                        else high = mid - 1
                    }
                    iStart = Math.max(0, low - 1)

                    low = 0; high = count - 1
                    while (low <= high) {
                        const mid = (low + high) >> 1
                        if (cachedX[mid] <= vXMax) low = mid + 1
                        else high = mid - 1
                    }
                    iEnd = Math.min(count - 1, low + 1)
                }

                const visibleCount = iEnd - iStart + 1
                if (visibleCount > 1) {
                    if (!root._screenX || root._screenX.length < visibleCount) {
                        root._screenX = new Float32Array(visibleCount + 64)
                        root._screenY = new Float32Array(visibleCount + 64)
                    }
                    const sX = root._screenX
                    const sY = root._screenY

                    const magLin = (mode === 0 && root.magScaleMode === 1)
                    const phaseWrap = (mode === 1 && root.phaseWrapMode === 1)

                    // Single-pass screen coordinate transform
                    for (let idx = 0, i = iStart; i <= iEnd; ++i, ++idx) {
                        const rawX = cachedX[i]
                        const rawY = cachedY[i]
                        let yVal = rawY
                        if (magLin) {
                            yVal = Math.pow(10, rawY / 20.0)
                        } else if (phaseWrap) {
                            yVal = ((((rawY + 180) % 360) + 360) % 360) - 180
                        }
                        sX[idx] = mL + freqToX(rawX)
                        sY[idx] = Math.max(mT, Math.min(mT + pH, valToY(yVal)))
                    }

                    // Polished Adaptive Gradient Background Fill
                    ctx.beginPath()
                    ctx.moveTo(sX[0], sY[0])
                    for (let idx = 1; idx < visibleCount; ++idx) {
                        ctx.lineTo(sX[idx], sY[idx])
                    }
                    ctx.lineTo(sX[visibleCount - 1], mT + pH)
                    ctx.lineTo(sX[0], mT + pH)
                    ctx.closePath()

                    let r = 10, g = 132, b = 255
                    if (mode === 1) { r = 255; g = 159; b = 10 }
                    else if (mode === 2) { r = 48; g = 209; b = 88 }

                    const grad = ctx.createLinearGradient(0, mT, 0, mT + pH)
                    grad.addColorStop(0, `rgba(${r}, ${g}, ${b}, ${theme.isDark ? 0.35 : 0.45})`)
                    grad.addColorStop(1, `rgba(${r}, ${g}, ${b}, 0.02)`)
                    ctx.fillStyle = grad
                    ctx.fill()

                    // Stroke Curve
                    ctx.lineWidth = root.plotLineWidth
                    ctx.strokeStyle = root.curveColor()
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"

                    ctx.beginPath()
                    ctx.moveTo(sX[0], sY[0])
                    for (let idx = 1; idx < visibleCount; ++idx) {
                        ctx.lineTo(sX[idx], sY[idx])
                    }
                    ctx.stroke()
                }
            }

            // ── Interactive Cutoff Frequency Marker / Handles ────────────────────
            function drawCutoffHandle(freq, color, labelText) {
                if (!(freq > 0) || freq >= nyquist) return
                const x = mL + freqToX(freq)
                ctx.strokeStyle = color
                ctx.lineWidth = 1.6
                strokeDashedLine(x, mT, x, mT + pH, 5, 3)

                ctx.fillStyle = color
                ctx.beginPath()
                ctx.arc(x, mT + pH * 0.22, 6, 0, 2 * Math.PI)
                ctx.fill()
                ctx.strokeStyle = "#FFFFFF"
                ctx.lineWidth = 1.2
                ctx.stroke()

                ctx.font = "bold 10.5px 'Stack Sans Headline', sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "bottom"
                ctx.fillStyle = color
                ctx.fillText(labelText + ": " + formatFreqLabel(freq) + (fScale <= 1 ? " Hz" : ""), x, mT + pH * 0.22 - 9)
            }

            drawCutoffHandle(root.cutoffFreq, "#0A84FF", "fc1")
            if (root.isBandFilter) drawCutoffHandle(root.cutoffFreq2, "#30D158", "fc2")
            ctx.restore()
        }
    }

    // ── Dedicated Interactive Crosshair HUD Canvas (Zero-Lag Mouse Hover) ──────
    Canvas {
        id: crosshairCanvas
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative
        z: 3

        onPaint: {
            const ctx = getContext("2d")
            if (!ctx) return

            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            if (!root.isHovering || !(root.hoverFreq >= 0)) return

            const mL = root.marginLeft
            const mT = root.marginTop
            const pW = root.plotW
            const pH = root.plotH
            const hx = root.cursorCanvasX
            const hy = root.cursorCanvasY
            const mode = root.displayMode
            const fScale = root.freqScale
            const nyquist = root.sampleRate / 2.0

            // Clamp on-screen visual positions to plot bounds
            const dotX = Math.max(mL, Math.min(mL + pW, hx))
            const isOutOfYRange = (hy < mT || hy > mT + pH)
            const dotY = Math.max(mT, Math.min(mT + pH, hy))

            // Dashed Crosshair Tracking Lines (Full Inspector Reticle when showCrosshair is enabled)
            if (root.showCrosshair) {
                ctx.strokeStyle = theme.isDark ? "rgba(255, 255, 255, 0.40)" : "rgba(0, 0, 0, 0.40)"
                ctx.lineWidth = 1
                ctx.setLineDash([3, 3])

                ctx.beginPath()
                ctx.moveTo(dotX, mT); ctx.lineTo(dotX, mT + pH)
                if (!isOutOfYRange) {
                    ctx.moveTo(mL, dotY); ctx.lineTo(mL + pW, dotY)
                }
                ctx.stroke()
                ctx.setLineDash([])
            }

            // Tracking Dot (Rich Apple-style glow + outer ring)
            ctx.beginPath()
            ctx.arc(dotX, dotY, isOutOfYRange ? 4 : 5.5, 0, 2 * Math.PI)
            ctx.fillStyle = theme.accent
            ctx.fill()
            ctx.strokeStyle = "#FFFFFF"
            ctx.lineWidth = 1.8
            ctx.stroke()

            // Subtle outer glow halo when in-bounds
            if (!isOutOfYRange) {
                ctx.beginPath()
                ctx.arc(dotX, dotY, 9, 0, 2 * Math.PI)
                ctx.strokeStyle = theme.accent
                ctx.globalAlpha = 0.35
                ctx.lineWidth = 2
                ctx.stroke()
                ctx.globalAlpha = 1.0
            }

            // High-Precision Mathematical HUD Readout
            let fLabel = ""
            if (fScale === 0 || fScale === 1) {
                const fVal = root.hoverFreq
                if (fVal >= 1000) {
                    fLabel = (fVal / 1000).toFixed(3) + " kHz"
                } else if (fVal >= 100) {
                    fLabel = fVal.toFixed(1) + " Hz"
                } else {
                    fLabel = fVal.toFixed(2) + " Hz"
                }
                const radPi = (root.hoverFreq / nyquist).toFixed(3) + "π rad"
                fLabel += " (" + radPi + ")"
            } else if (fScale === 2) {
                const radFrac = (root.hoverFreq / nyquist)
                fLabel = radFrac.toFixed(3) + "π rad/s (" + root.hoverFreq.toFixed(1) + " Hz)"
            } else {
                const cycFrac = (root.hoverFreq / root.sampleRate)
                fLabel = cycFrac.toFixed(4) + " cyc/s (" + root.hoverFreq.toFixed(1) + " Hz)"
            }

            let valLabel = ""
            if (mode === 0) {
                if (root.magScaleMode === 1) {
                    valLabel = "|H|: " + root.hoverVal.toFixed(4) + " (" + (20 * Math.log10(Math.max(1e-12, root.hoverVal))).toFixed(2) + " dB)"
                } else {
                    const linVal = Math.pow(10, root.hoverVal / 20.0)
                    valLabel = "|H|: " + root.hoverVal.toFixed(2) + " dB (lin: " + (linVal < 0.0001 ? linVal.toExponential(2) : linVal.toFixed(4)) + ")"
                }
            } else if (mode === 1) {
                if (root.phaseWrapMode === 1) {
                    valLabel = "Phase: " + root.hoverVal.toFixed(1) + "°"
                } else {
                    valLabel = "Phase: " + root.hoverVal.toFixed(1) + "° (wrap: " + (((((root.hoverVal + 180) % 360) + 360) % 360) - 180).toFixed(1) + "°)"
                }
            } else {
                const msDelay = (root.hoverVal / root.sampleRate) * 1000.0
                valLabel = "τg: " + root.hoverVal.toFixed(2) + " smp (" + (msDelay < 0.01 ? (msDelay * 1000).toFixed(1) + " µs" : msDelay.toFixed(2) + " ms") + ")"
            }

            const lines = [ fLabel, valLabel ]

            ctx.font = "bold 10px 'Stack Sans Headline', monospace"
            const line1W = ctx.measureText(lines[0]).width
            const line2W = ctx.measureText(lines[1]).width
            const boxW = Math.max(line1W, line2W) + 20
            const boxH = 38

            // Floating placement to avoid cursor occlusions
            let boxX = dotX + 14
            if (boxX + boxW > mL + pW - 6) {
                boxX = dotX - boxW - 14
            }
            boxX = Math.max(mL + 4, Math.min(mL + pW - boxW - 4, boxX))

            let boxY = dotY - boxH / 2
            boxY = Math.max(mT + 4, Math.min(mT + pH - boxH - 4, boxY))

            // Rounded badge background
            ctx.fillStyle = theme.isDark ? "rgba(22, 24, 28, 0.94)" : "rgba(255, 255, 255, 0.95)"
            ctx.strokeStyle = theme.borderColor
            ctx.lineWidth = 1
            ctx.beginPath()
            if (typeof ctx.roundRect === "function") {
                ctx.roundRect(boxX, boxY, boxW, boxH, 6)
            } else {
                ctx.rect(boxX, boxY, boxW, boxH)
            }
            ctx.fill()
            ctx.stroke()

            // Badge text render
            ctx.fillStyle = theme.primaryText
            ctx.textAlign = "left"
            ctx.textBaseline = "top"
            ctx.fillText(lines[0], boxX + 10, boxY + 6)
            ctx.fillStyle = theme.accent
            ctx.fillText(lines[1], boxX + 10, boxY + 20)
        }
    }

    // Top Controls Bar (Fully Responsive Segmented Controls)
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

            // 1. Unified Frequency Scale Segmented Pill: [ Log | Lin | ω/π ]
            Rectangle {
                height: 22
                width: fScaleRow.implicitWidth + 2
                radius: 4
                color: theme.isDark ? "#25272B" : "#E4E7EB"
                border.color: theme.borderColor
                border.width: 1

                Row {
                    id: fScaleRow
                    anchors.centerIn: parent
                    spacing: 1

                    Repeater {
                        model: [
                            { name: "Log", scale: 0 },
                            { name: "Lin", scale: 1 },
                            { name: "ω/π", scale: 2 }
                        ]
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            readonly property bool active: root.freqScale === modelData.scale
                            width: fTxt.implicitWidth + 10
                            height: 20
                            radius: 3
                            color: active ? theme.accent : (fMouse.containsMouse ? (theme.isDark ? "#32353A" : "#D1D5DB") : "transparent")

                            Text {
                                id: fTxt
                                anchors.centerIn: parent
                                text: modelData.name
                                font.family: "Stack Sans Headline"
                                font.pixelSize: 11
                                font.weight: parent.active ? Font.DemiBold : Font.Normal
                                color: parent.active ? "#FFFFFF" : (fMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                            }

                            MouseArea {
                                id: fMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.freqScale = modelData.scale
                                    root.schedulePaint()
                                }
                            }
                        }
                    }
                }
            }

            // 2. Unit Scale Segmented Pill (dB vs Lin)
            Rectangle {
                visible: (root.displayMode === 0 || root.displayMode === 1) && !root.ultraCompactMode
                height: 22
                width: unitRow.implicitWidth + 2
                radius: 4
                color: theme.isDark ? "#25272B" : "#E4E7EB"
                border.color: theme.borderColor
                border.width: 1

                Row {
                    id: unitRow
                    anchors.centerIn: parent
                    spacing: 1

                    Repeater {
                        model: root.displayMode === 0
                                ? [{ name: "dB", mode: 0 }, { name: "Lin", mode: 1 }]
                                : [{ name: "Unwrap", mode: 0 }, { name: "Wrap", mode: 1 }]
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            readonly property bool active: root.displayMode === 0
                                    ? (root.magScaleMode === modelData.mode)
                                    : (root.phaseWrapMode === modelData.mode)
                            width: unitTxt.implicitWidth + 10
                            height: 20
                            radius: 3
                            color: active ? theme.accent : (uMouse.containsMouse ? (theme.isDark ? "#32353A" : "#D1D5DB") : "transparent")

                            Text {
                                id: unitTxt
                                anchors.centerIn: parent
                                text: modelData.name
                                font.family: "Stack Sans Headline"
                                font.pixelSize: 11
                                font.weight: parent.active ? Font.DemiBold : Font.Normal
                                color: parent.active ? "#FFFFFF" : (uMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                            }

                            MouseArea {
                                id: uMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.displayMode === 0) root.magScaleMode = modelData.mode
                                    else root.phaseWrapMode = modelData.mode
                                    root.refreshPoints()
                                    root.schedulePaint()
                                }
                            }
                        }
                    }
                }
            }

            // 3. Guides Toggle Pill
            Rectangle {
                visible: root.displayMode === 0 && !root.compactMode
                height: 22
                width: guideTxt.implicitWidth + 14
                radius: 4
                color: root.showDspGuides
                        ? (theme.isDark ? "#1C2D42" : "#E1EFFF")
                        : (gMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent")
                border.color: root.showDspGuides ? theme.accent : theme.borderColor
                border.width: 1

                Text {
                    id: guideTxt
                    anchors.centerIn: parent
                    text: "Guides"
                    font.family: "Stack Sans Headline"
                    font.pixelSize: 11
                    font.weight: root.showDspGuides ? Font.DemiBold : Font.Normal
                    color: root.showDspGuides ? theme.accent : (gMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                }

                MouseArea {
                    id: gMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.showDspGuides = !root.showDspGuides
                        root.schedulePaint()
                    }
                }
            }
        }

        // Right Controls Cluster (Responsive)
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            // Auto Scale / Fit View Pill (Hides in Ultra Compact)
            Rectangle {
                visible: !root.ultraCompactMode
                height: 22
                width: autoScaleRow.implicitWidth + 12
                radius: 4
                color: root.isCustomView
                        ? (theme.isDark ? "#1C2D42" : "#E1EFFF")
                        : (autoScaleMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent")
                border.color: root.isCustomView ? theme.accent : theme.borderColor
                border.width: 1

                Row {
                    id: autoScaleRow
                    anchors.centerIn: parent
                    spacing: 4
                    Codicon {
                        icon: "screen-full"
                        iconSize: 11
                        iconColor: root.isCustomView ? theme.accent : (autoScaleMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Auto Scale"
                        font.family: "Stack Sans Headline"
                        font.pixelSize: 11
                        font.weight: root.isCustomView ? Font.DemiBold : Font.Normal
                        color: root.isCustomView ? theme.accent : (autoScaleMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                ToolTip.visible: autoScaleMouse.containsMouse
                ToolTip.text: "Auto Scale / Fit View (Desmos)"
                ToolTip.delay: 350

                MouseArea {
                    id: autoScaleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.autoScale()
                        root.showPlotToast("Auto-scaled to curve fit")
                    }
                }
            }

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
                        font.pixelSize: 11
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
                        if (!root.showCrosshair) root.isHovering = false
                        root.schedulePaint()
                    }
                }
            }

            // Save Image Button (Hides in Compact)
            Rectangle {
                visible: !root.compactMode
                width: 26; height: 22; radius: 4
                color: saveMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor; border.width: 1
                Codicon {
                    anchors.centerIn: parent
                    icon: "camera"
                    iconSize: 12
                    iconColor: saveMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }
                ToolTip.visible: saveMouse.containsMouse
                ToolTip.text: "Save Plot Image (PNG)"
                ToolTip.delay: 400
                MouseArea { id: saveMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.exportPlotImage() }
            }

            // Copy Image Button (Hides in Compact)
            Rectangle {
                visible: !root.compactMode
                width: 26; height: 22; radius: 4
                color: copyMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor; border.width: 1
                Codicon {
                    anchors.centerIn: parent
                    icon: "copy"
                    iconSize: 12
                    iconColor: copyMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }
                ToolTip.visible: copyMouse.containsMouse
                ToolTip.text: "Copy Plot to Clipboard"
                ToolTip.delay: 400
                MouseArea { id: copyMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.copyPlotImage() }
            }

            // Pop out in New Window Button (Hides in Compact)
            Rectangle {
                visible: !root.compactMode && !root.isDetached
                width: 26; height: 22; radius: 4
                color: popoutMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor; border.width: 1
                Codicon {
                    anchors.centerIn: parent
                    icon: "link-external"
                    iconSize: 12
                    iconColor: popoutMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }
                ToolTip.visible: popoutMouse.containsMouse
                ToolTip.text: "Open in Dedicated Window"
                ToolTip.delay: 400
                MouseArea { id: popoutMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openInNewWindow() }
            }

            // MATLAB Context Menu / Overflow (Always Visible)
            Rectangle {
                width: 24; height: 22; radius: 4
                color: menuBtnMouse.containsMouse || plotContextMenu.opened ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor; border.width: 1
                Codicon {
                    anchors.centerIn: parent
                    icon: "kebab-vertical"
                    iconSize: 13
                    iconColor: menuBtnMouse.containsMouse || plotContextMenu.opened ? theme.primaryText : theme.secondaryText
                }
                ToolTip.visible: menuBtnMouse.containsMouse && !plotContextMenu.opened
                ToolTip.text: "Plot Settings & MATLAB Analysis Menu (Right-Click)"
                ToolTip.delay: 400
                MouseArea {
                    id: menuBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: plotContextMenu.popup(topBar.x + topBar.width - 230, topBar.y + topBar.height + 4)
                }
            }
        }
    }

    Rectangle {
        id: toastBanner
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 10 }
        width: Math.min(parent.width - 24, toastText.implicitWidth + 20); height: 26; radius: 6
        color: theme.isDark ? "#2C2C2E" : "#3A3A3C"
        border.color: theme.borderColor; border.width: 1
        opacity: root.toastVisible ? 1.0 : 0.0
        visible: opacity > 0.01
        z: 100
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Row {
            anchors.centerIn: parent; spacing: 6
            Codicon { icon: "check"; iconSize: 11; iconColor: "#30D158"; anchors.verticalCenter: parent.verticalCenter }
            Text {
                id: toastText
                text: root.toastMessage
                font.family: "Stack Sans Headline"; font.pixelSize: 11; color: "#FFFFFF"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Timer { id: toastTimer; interval: 2200; onTriggered: root.toastVisible = false }
    }

    FileDialog {
        id: savePlotDialog
        title: "Save Plot Image"
        options: FileDialog.DontUseNativeDialog
        fileMode: FileDialog.SaveFile
        nameFilters: ["PNG Image (*.png)", "JPEG Image (*.jpg *.jpeg)", "All files (*)"]
        defaultSuffix: "png"
        onAccepted: root.saveToFile(selectedFile)
    }

    Timer { id: paintRetry; interval: 50; repeat: false; onTriggered: root.schedulePaint() }
    Timer { interval: 120; running: true; repeat: false; onTriggered: { root.refreshPoints(); root.schedulePaint() } }

    Connections {
        target: filterEngine
        function onResultsChanged() { root.refreshPoints(); root.schedulePaint() }
        function onSpecChanged() { root.schedulePaint() }
    }
    Connections {
        target: theme
        function onThemeModeChanged() { root.schedulePaint() }
    }

    Component.onCompleted: { refreshPoints(); schedulePaint() }

    onVisibleChanged:     { if (visible) schedulePaint() }
    onWidthChanged:       schedulePaint()
    onHeightChanged:      schedulePaint()
    onDisplayModeChanged: { refreshPoints(); schedulePaint() }
    onPointsChanged:      schedulePaint()

    property bool draggingCutoff:  false
    property bool draggingCutoff2: false
    property bool isPanning:       false
    property real lastMouseX:      0
    property real lastMouseY:      0

    MouseArea {
        id: plotMouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 5

        onPressed: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                plotContextMenu.popup(mouse.x, mouse.y)
                return
            }
            lastMouseX = mouse.x
            lastMouseY = mouse.y

            const x1 = root.freqToCanvasX(root.cutoffFreq)
            const x2 = root.freqToCanvasX(root.cutoffFreq2)
            if (Math.abs(mouse.x - x1) < 14) {
                root.draggingCutoff = true
                cursorShape = Qt.SizeHorCursor
            } else if (root.isBandFilter && Math.abs(mouse.x - x2) < 14) {
                root.draggingCutoff2 = true
                cursorShape = Qt.SizeHorCursor
            } else {
                root.isPanning = true
                cursorShape = Qt.ClosedHandCursor
            }
        }

        onReleased: function(mouse) {
            root.draggingCutoff  = false
            root.draggingCutoff2 = false
            root.isPanning       = false
            const x1 = root.freqToCanvasX(root.cutoffFreq)
            const x2 = root.freqToCanvasX(root.cutoffFreq2)
            const nearHandle = Math.abs(mouse.x - x1) < 14 || (root.isBandFilter && Math.abs(mouse.x - x2) < 14)
            cursorShape = nearHandle ? Qt.SizeHorCursor : (root.showCrosshair ? Qt.CrossCursor : Qt.OpenHandCursor)
        }

        onDoubleClicked: function(mouse) {
            root.autoScale()
            root.showPlotToast("Auto-scaled to curve fit")
        }

        onWheel: function(wheel) {
            const factor = wheel.angleDelta.y > 0 ? 0.82 : 1.22
            root.zoomAt(wheel.x, wheel.y, factor)
        }

        onPositionChanged: function(mouse) {
            if (root.draggingCutoff) {
                const f = root.xToFreq(mouse.x)
                if (f > 1 && f < root.sampleRate / 2.0) {
                    filterEngine.cutoffFreq = Math.round(f * 10) / 10
                    root.schedulePaint()
                }
            } else if (root.draggingCutoff2) {
                const f = root.xToFreq(mouse.x)
                if (f > filterEngine.cutoffFreq && f < root.sampleRate / 2.0) {
                    filterEngine.cutoffFreq2 = Math.round(f * 10) / 10
                    root.schedulePaint()
                }
            } else if (root.isPanning) {
                const dx = mouse.x - lastMouseX
                const dy = mouse.y - lastMouseY
                lastMouseX = mouse.x
                lastMouseY = mouse.y
                root.panBy(dx, dy)
            } else {
                const mL = root.marginLeft
                const mT = root.marginTop
                const pW = root.plotW
                const pH = root.plotH

                const x1 = root.freqToCanvasX(root.cutoffFreq)
                const x2 = root.freqToCanvasX(root.cutoffFreq2)
                const nearHandle = Math.abs(mouse.x - x1) < 14 || (root.isBandFilter && Math.abs(mouse.x - x2) < 14)
                const inPlotX = mouse.x >= mL && mouse.x <= mL + pW
                const inPlotY = mouse.y >= mT - 10 && mouse.y <= mT + pH + 15

                cursorShape = nearHandle ? Qt.SizeHorCursor : ((inPlotX && inPlotY) ? Qt.CrossCursor : Qt.ArrowCursor)

                if (inPlotX && inPlotY && !nearHandle) {
                    const f = root.xToFreq(mouse.x)
                    // Continuous analytical evaluation across 100% of mathematical spectrum
                    const res = filterEngine.evaluateResponseAt(f)
                    root.hoverFreq = res["freq"]
                    root.hoverLinMag = res["magLin"]
                    root.hoverPhaseDeg = res["phase"]
                    root.hoverPhaseUnwrapped = res["phaseUnwrapped"]
                    root.hoverGd = res["groupDelay"]

                    let mappedY = 0
                    if (root.displayMode === 0) {
                        root.hoverVal = (root.magScaleMode === 1) ? res["magLin"] : res["magDb"]
                        mappedY = root.hoverVal
                    } else if (root.displayMode === 1) {
                        root.hoverVal = (root.phaseWrapMode === 1) ? res["phaseWrapped"] : res["phaseUnwrapped"]
                        mappedY = root.hoverVal
                    } else {
                        root.hoverVal = res["groupDelay"]
                        mappedY = root.hoverVal
                    }

                    root.cursorCanvasX = root.freqToCanvasX(root.hoverFreq)
                    const yRange = (root.viewYMax - root.viewYMin) || 1
                    root.cursorCanvasY = mT + ((root.viewYMax - mappedY) / yRange) * pH
                    root.isHovering = true
                    root.scheduleCrosshairPaint()
                    return
                }

                if (root.isHovering) {
                    root.isHovering = false
                    root.scheduleCrosshairPaint()
                }
            }
        }

        onExited: {
            if (root.isHovering) {
                root.isHovering = false
                root.scheduleCrosshairPaint()
            }
        }
    }

    Rectangle {
        id: floatingDesmosControls
        anchors {
            right: parent.right; bottom: parent.bottom
            rightMargin: root.marginRight + 12; bottomMargin: root.marginBottom + 12
        }
        width: 32; height: 94; radius: 7
        color: theme.isDark ? "#25272B" : "#FFFFFF"
        border.color: theme.borderColor; border.width: 1
        z: 20

        Column {
            anchors.centerIn: parent; spacing: 2
            Rectangle {
                width: 28; height: 26; radius: 4
                color: fZoomInMouse.containsMouse ? (theme.isDark ? "#3A3A3C" : "#EAEAEA") : "transparent"
                Text { anchors.centerIn: parent; text: "+"; font.family: "Stack Sans Headline"; font.pixelSize: 18; font.weight: Font.DemiBold; color: theme.primaryText }
                ToolTip.visible: fZoomInMouse.containsMouse; ToolTip.text: "Zoom In (+)"; ToolTip.delay: 350
                MouseArea { id: fZoomInMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.zoomCenter(0.8) }
            }
            Rectangle { width: 20; height: 1; color: theme.borderColor; opacity: 0.6; anchors.horizontalCenter: parent.horizontalCenter }
            Rectangle {
                width: 28; height: 26; radius: 4
                color: fZoomOutMouse.containsMouse ? (theme.isDark ? "#3A3A3C" : "#EAEAEA") : "transparent"
                Text { anchors.centerIn: parent; text: "−"; font.family: "Stack Sans Headline"; font.pixelSize: 18; font.weight: Font.DemiBold; color: theme.primaryText }
                ToolTip.visible: fZoomOutMouse.containsMouse; ToolTip.text: "Zoom Out (−)"; ToolTip.delay: 350
                MouseArea { id: fZoomOutMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.zoomCenter(1.25) }
            }
            Rectangle { width: 20; height: 1; color: theme.borderColor; opacity: 0.6; anchors.horizontalCenter: parent.horizontalCenter }
            Rectangle {
                width: 28; height: 26; radius: 4
                color: fAutoFitMouse.containsMouse ? (theme.isDark ? "#3A3A3C" : "#EAEAEA") : "transparent"
                Codicon { anchors.centerIn: parent; icon: "screen-full"; iconSize: 13; iconColor: root.isCustomView ? theme.accent : theme.secondaryText }
                ToolTip.visible: fAutoFitMouse.containsMouse; ToolTip.text: "Auto Scale / Fit View"; ToolTip.delay: 350
                MouseArea { id: fAutoFitMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.autoScale(); root.showPlotToast("Auto-scaled to curve fit") } }
            }
        }
    }

    Menu {
        id: plotContextMenu
        parent: root
        background: Rectangle { implicitWidth: 230; color: theme.isDark ? "#25272B" : "#FFFFFF"; border.color: theme.borderColor; border.width: 1; radius: 8 }

        MenuItem { text: "Auto Scale / Fit View (Desmos)"; onTriggered: { root.autoScale(); root.showPlotToast("Auto-scaled to curve fit") } }
        MenuItem { text: "Zoom In (+)"; onTriggered: root.zoomCenter(0.8) }
        MenuItem { text: "Zoom Out (−)"; onTriggered: root.zoomCenter(1.25) }
        MenuSeparator {}
        Menu {
            title: "Response View"
            MenuItem { text: "Magnitude (dB)"; checkable: true; checked: root.displayMode === 0 && root.magScaleMode === 0; onTriggered: { root.displayMode = 0; root.magScaleMode = 0; root.refreshPoints(); root.schedulePaint() } }
            MenuItem { text: "Magnitude (Linear |H|)"; checkable: true; checked: root.displayMode === 0 && root.magScaleMode === 1; onTriggered: { root.displayMode = 0; root.magScaleMode = 1; root.refreshPoints(); root.schedulePaint() } }
            MenuItem { text: "Phase Response"; checkable: true; checked: root.displayMode === 1; onTriggered: { root.displayMode = 1; root.refreshPoints(); root.schedulePaint() } }
            MenuItem { text: "Group Delay Response"; checkable: true; checked: root.displayMode === 2; onTriggered: { root.displayMode = 2; root.refreshPoints(); root.schedulePaint() } }
        }
        Menu {
            title: "Frequency Axis Scale"
            MenuItem { text: "Logarithmic (Hz)"; checkable: true; checked: root.freqScale === 0; onTriggered: { root.freqScale = 0; root.schedulePaint() } }
            MenuItem { text: "Linear (Hz)"; checkable: true; checked: root.freqScale === 1; onTriggered: { root.freqScale = 1; root.schedulePaint() } }
            MenuItem { text: "Normalized Radian (ω/π rad/sample)"; checkable: true; checked: root.freqScale === 2; onTriggered: { root.freqScale = 2; root.schedulePaint() } }
            MenuItem { text: "Normalized Digital (f/fs cycles/sample)"; checkable: true; checked: root.freqScale === 3; onTriggered: { root.freqScale = 3; root.schedulePaint() } }
        }
        Menu {
            title: "Magnitude Scale"
            visible: root.displayMode === 0
            MenuItem { text: "Decibels (dB)"; checkable: true; checked: root.magScaleMode === 0; onTriggered: { root.magScaleMode = 0; root.refreshPoints(); root.schedulePaint() } }
            MenuItem { text: "Linear (|H|)"; checkable: true; checked: root.magScaleMode === 1; onTriggered: { root.magScaleMode = 1; root.refreshPoints(); root.schedulePaint() } }
        }
        Menu {
            title: "Phase Scale"
            visible: root.displayMode === 1
            MenuItem { text: "Unwrapped Phase"; checkable: true; checked: root.phaseWrapMode === 0; onTriggered: { root.phaseWrapMode = 0; root.refreshPoints(); root.schedulePaint() } }
            MenuItem { text: "Wrapped Phase [-180°, +180°]"; checkable: true; checked: root.phaseWrapMode === 1; onTriggered: { root.phaseWrapMode = 1; root.refreshPoints(); root.schedulePaint() } }
        }
        MenuSeparator {}
        MenuItem { text: "Data Cursor / Inspector (+)"; checkable: true; checked: root.showCrosshair; onTriggered: { root.showCrosshair = !root.showCrosshair; if (!root.showCrosshair) root.isHovering = false; root.schedulePaint() } }
        MenuItem { text: "DSP Reference Spec Guides"; visible: root.displayMode === 0; checkable: true; checked: root.showDspGuides; onTriggered: { root.showDspGuides = !root.showDspGuides; root.schedulePaint() } }
        Menu {
            title: "Plot Line Thickness"
            MenuItem { text: "Fine (1.5 px)"; checkable: true; checked: Math.abs(root.plotLineWidth - 1.5) < 0.2; onTriggered: { root.plotLineWidth = 1.5; root.schedulePaint() } }
            MenuItem { text: "Standard (2.2 px)"; checkable: true; checked: Math.abs(root.plotLineWidth - 2.2) < 0.2; onTriggered: { root.plotLineWidth = 2.2; root.schedulePaint() } }
            MenuItem { text: "Bold (3.2 px)"; checkable: true; checked: Math.abs(root.plotLineWidth - 3.2) < 0.2; onTriggered: { root.plotLineWidth = 3.2; root.schedulePaint() } }
        }
        MenuSeparator {}
        MenuItem { text: "Copy Plot Image to Clipboard"; onTriggered: root.copyPlotImage() }
        MenuItem { text: "Save Plot Image (PNG)..."; onTriggered: root.exportPlotImage() }
        MenuSeparator {}
        MenuItem {
            text: "Copy Filter Specifications"
            onTriggered: {
                const specText = filterEngine.responseName + " " + filterEngine.typeName +
                    "\nOrder: " + filterEngine.order + "\nSample Rate: " + filterEngine.sampleRate + " Hz" +
                    "\nCutoff: " + filterEngine.cutoffFreq + " Hz" + (root.isBandFilter ? (" to " + filterEngine.cutoffFreq2 + " Hz") : "") +
                    (filterEngine.filterResponse === 1 || filterEngine.filterResponse === 3 ? ("\nRipple: " + filterEngine.rippleDb + " dB") : "") +
                    (filterEngine.filterResponse === 2 || filterEngine.filterResponse === 3 ? ("\nStopband: " + filterEngine.stopbandDb + " dB") : "")
                filterEngine.copyText(specText)
                root.showPlotToast("Filter specifications copied")
            }
        }
        MenuItem { text: "Copy Numerator & Denominator (b, a)"; onTriggered: { filterEngine.copyText(filterEngine.exportCode(2)); root.showPlotToast("Coefficients (b, a) copied") } }
    }

    function curveColor() {
        if (displayMode === 0) return "#0A84FF"
        if (displayMode === 1) return "#FF9F0A"
        return "#30D158"
    }
}
