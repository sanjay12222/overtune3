import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// PoleZeroPlot.qml — Mathematically precise Z-plane pole-zero plot with polar grid, stability region & image export
Item {
    id: root
    implicitWidth: 320
    implicitHeight: 320

    property int hoverIndex: -1
    property string hoverType: "" // "pole" or "zero"
    property real hoverRe: 0
    property real hoverIm: 0
    property real hoverR: 0
    property real hoverThetaDeg: 0
    property bool showCrosshair: false // Opt-in Data Cursor / Inspector (+) (Default: OFF)
    property bool showPolarGrid: true
    property bool showStabilityRegion: true
    property bool isDetached: false


    function openInNewWindow() {
        const w = Window.window
        if (w && typeof w.openStandalonePlot === "function") {
            w.openStandalonePlot(1, {})
        }
    }

    // Viewport Zoom & Pan State (Desmos Complex Plane Engine)
    property real zoomScale: 1.0
    property real panOffsetX: 0.0
    property real panOffsetY: 0.0

    property bool isCustomView: false
    property bool isPanning: false
    property real lastMouseX: 0
    property real lastMouseY: 0

    function autoScale() {
        isCustomView = false
        panOffsetX = 0
        panOffsetY = 0
        let maxR = 1.0
        const pts = filterEngine.poleZeroData
        if (pts) {
            for (let i = 0; i < pts.length; ++i) {
                const re = Number(pts[i]["re"])
                const im = Number(pts[i]["im"])
                const dist = Math.hypot(re, im)
                if (dist > maxR) maxR = dist
            }
        }
        if (maxR > 1.05) {
            zoomScale = Math.min(1.0, 1.25 / (maxR * 1.2))
        } else {
            zoomScale = 1.0
        }
        schedulePaint()
    }

    function zoomAt(mx, my, factor) {
        isCustomView = true
        const newScale = Math.max(0.15, Math.min(30.0, zoomScale * factor))
        const cx = width / 2 + panOffsetX
        const cy = height / 2 + 8 + panOffsetY
        const ratio = newScale / zoomScale
        panOffsetX = (mx - (mx - cx) * ratio) - width / 2
        panOffsetY = (my - (my - cy) * ratio) - (height / 2 + 8)
        zoomScale = newScale
        schedulePaint()
    }

    function zoomCenter(factor) {
        zoomAt(width / 2, height / 2 + 8, factor)
    }

    function panBy(dx, dy) {
        isCustomView = true
        panOffsetX += dx
        panOffsetY += dy
        schedulePaint()
    }

    // Notification toast state
    property string toastMessage: ""
    property bool toastVisible: false

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
        savePlotDialog.currentFile = "file://" + filterEngine.defaultExportPlotPath("pole_zero_zplane")
        savePlotDialog.open()
    }

    function quickSavePlotImage() {
        saveToFile(filterEngine.defaultExportPlotPath("pole_zero_zplane"))
    }

    function copyPlotImage() {
        const tempPath = filterEngine.defaultExportPlotPath("clipboard_temp_pz")
        root.grabToImage(function(result) {
            if (result.saveToFile(tempPath)) {
                filterEngine.copyImageFileToClipboard(tempPath)
                showPlotToast("Z-plane image copied to clipboard")
            } else {
                showPlotToast("Failed to copy Z-plane image")
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
                showPlotToast("Failed to save Z-plane image")
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
            if (available) requestPaint()
        }

        onPaint: {
            const ctx = getContext("2d")
            if (!ctx) return

            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            const cx = width / 2 + root.panOffsetX
            const cy = height / 2 + 8 + root.panOffsetY
            const baseR = Math.min(width, height - 36) / 2 - 28
            const r  = baseR * root.zoomScale
            if (r <= 2) return

            ctx.save()
            ctx.beginPath()
            ctx.rect(0, 0, width, height)
            ctx.clip()

            // 1) Shaded Stable Unit Disk (|z| < 1) — clean and subtle
            if (root.showStabilityRegion) {
                ctx.fillStyle = theme.isDark ? "rgba(255, 255, 255, 0.025)" : "rgba(0, 0, 0, 0.02)"
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                ctx.fill()
            }

            // 2) Polar Concentric Rings & Radial Spokes
            if (root.showPolarGrid) {
                ctx.strokeStyle = theme.plotGrid
                ctx.lineWidth = 1

                // r = 0.5
                ctx.beginPath()
                ctx.arc(cx, cy, r * 0.5, 0, 2 * Math.PI)
                ctx.stroke()

                // r = 1.5 (if fits)
                if (r * 1.5 < Math.min(cx, cy)) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, r * 1.5, 0, 2 * Math.PI)
                    ctx.stroke()
                }

                // Radial Angular Spokes (0, pi/4, pi/2, 3pi/4, etc.)
                for (let a = 0; a < 8; ++a) {
                    const angle = a * Math.PI / 4
                    const rayLen = r * 1.15
                    ctx.beginPath()
                    ctx.moveTo(cx, cy)
                    ctx.lineTo(cx + Math.cos(angle) * rayLen, cy - Math.sin(angle) * rayLen)
                    ctx.stroke()
                }
            }

            // 3) Real and Imaginary Coordinate Axes
            ctx.strokeStyle = theme.borderColor
            ctx.lineWidth = 1.2
            const axisExt = r * 1.2
            // Real axis (horizontal)
            ctx.beginPath()
            ctx.moveTo(cx - axisExt, cy)
            ctx.lineTo(cx + axisExt, cy)
            ctx.stroke()
            // Imaginary axis (vertical)
            ctx.beginPath()
            ctx.moveTo(cx, cy - axisExt)
            ctx.lineTo(cx, cy + axisExt)
            ctx.stroke()

            // 4) Unit Circle (|z| = 1) Prominent Boundary
            ctx.strokeStyle = theme.isDark ? "#5AC8FA" : "#007AFF"
            ctx.lineWidth = 1.8
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.stroke()

            // Mathematical Axis Markings
            ctx.fillStyle = theme.secondaryText
            ctx.font = "11px 'Stack Sans Headline', sans-serif"

            function drawSquircleBadge(label, bx, by, isAccent) {
                ctx.save()
                ctx.font = "bold 11px 'Stack Sans Headline', sans-serif"
                const m = ctx.measureText(label)
                const padH = 6
                const bw = m.width + padH * 2
                const bh = 18
                const x0 = bx - bw / 2
                const y0 = by - bh / 2
                const rad = 5

                ctx.fillStyle = "#000000"
                ctx.strokeStyle = isAccent ? theme.accent : "rgba(255, 255, 255, 0.25)"
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(x0 + rad, y0)
                ctx.lineTo(x0 + bw - rad, y0)
                ctx.arcTo(x0 + bw, y0, x0 + bw, y0 + rad, rad)
                ctx.lineTo(x0 + bw, y0 + bh - rad)
                ctx.arcTo(x0 + bw, y0 + bh, x0 + bw - rad, y0 + bh, rad)
                ctx.lineTo(x0 + rad, y0 + bh)
                ctx.arcTo(x0, y0 + bh, x0, y0 + bh - rad, rad)
                ctx.lineTo(x0, y0 + rad)
                ctx.arcTo(x0, y0, x0 + rad, y0, rad)
                ctx.closePath()
                ctx.fill()
                ctx.stroke()

                ctx.fillStyle = isAccent ? theme.accent : "#FFFFFF"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(label, bx, by)
                ctx.restore()
            }

            // Real axis ticks
            ctx.textAlign = "center"
            ctx.textBaseline = "top"
            ctx.fillText("-1", cx - r, cy + 4)
            ctx.fillText("-0.5", cx - r * 0.5, cy + 4)
            ctx.fillText("+0.5", cx + r * 0.5, cy + 4)
            ctx.fillText("+1", cx + r, cy + 4)
            drawSquircleBadge("Re{z}", Math.min(width - 24, cx + axisExt + 18), cy, false)

            // Imag axis ticks
            ctx.textAlign = "right"
            ctx.textBaseline = "middle"
            ctx.fillText("+j", cx - 4, cy - r)
            ctx.fillText("-j", cx - 4, cy + r)
            drawSquircleBadge("Im{z}", cx, Math.max(14, cy - axisExt - 12), false)

            // Unit circle badge
            drawSquircleBadge("|z| = 1.0", cx + r * 0.72, cy - r * 0.72, true)

            // 5) Plot Poles (x) and Zeros (o)
            const pts = filterEngine.poleZeroData
            const n = pts ? pts.length : 0

            for (let i = 0; i < n; ++i) {
                const pt = pts[i]
                const re = Number(pt["re"])
                const im = Number(pt["im"])
                const px = cx + re * r
                const py = cy - im * r
                const kind = String(pt["kind"])
                const isHovered = (root.showCrosshair && root.hoverIndex === i && root.hoverType === kind)
                const mult = pt["multiplicity"] ? Number(pt["multiplicity"]) : 1
                const isPrimary = (pt["isPrimary"] !== undefined) ? Boolean(pt["isPrimary"]) : true

                if (kind === "pole") {
                    // Pole: Cross 'x'
                    ctx.strokeStyle = isHovered ? "#FF453A" : theme.danger
                    ctx.lineWidth = isHovered ? 3.0 : 2.2
                    const s = isHovered ? 8 : 6
                    ctx.beginPath()
                    ctx.moveTo(px - s, py - s)
                    ctx.lineTo(px + s, py + s)
                    ctx.moveTo(px + s, py - s)
                    ctx.lineTo(px - s, py + s)
                    ctx.stroke()

                    if (isHovered) {
                        ctx.beginPath()
                        ctx.arc(px, py, 11, 0, 2 * Math.PI)
                        ctx.strokeStyle = "rgba(255, 69, 58, 0.4)"
                        ctx.lineWidth = 1.5
                        ctx.stroke()
                    }
                } else {
                    // Zero: Circle 'o'
                    ctx.strokeStyle = isHovered ? "#0A84FF" : theme.accent
                    ctx.lineWidth = isHovered ? 2.8 : 2.0
                    ctx.beginPath()
                    ctx.arc(px, py, isHovered ? 7 : 5.5, 0, 2 * Math.PI)
                    ctx.fillStyle = theme.surface
                    ctx.fill()
                    ctx.stroke()

                    if (isHovered) {
                        ctx.beginPath()
                        ctx.arc(px, py, 11, 0, 2 * Math.PI)
                        ctx.strokeStyle = "rgba(10, 132, 255, 0.4)"
                        ctx.lineWidth = 1.5
                        ctx.stroke()
                    }
                }

                // MATLAB zplane Multiplicity Badge
                if (isPrimary && mult > 1) {
                    ctx.fillStyle = (kind === "pole") ? (isHovered ? "#FF453A" : theme.danger) : (isHovered ? "#0A84FF" : theme.accent)
                    ctx.font = "bold 11px 'Stack Sans Headline', sans-serif"
                    ctx.textAlign = "left"
                    ctx.textBaseline = "bottom"
                    ctx.fillText(String(mult), px + 7, py - 4)
                }
            }

            ctx.restore()

            // 6) Hover Inspection HUD Badge
            if (root.showCrosshair && root.hoverIndex >= 0 && root.hoverIndex < n) {
                const targetPt = pts[root.hoverIndex]
                const kind = root.hoverType
                const sign = root.hoverIm >= 0 ? "+" : "-"
                const mult = (targetPt && targetPt["multiplicity"]) ? Number(targetPt["multiplicity"]) : 1
                const multStr = mult > 1 ? (" (×" + mult + ")") : ""

                const fs = filterEngine.sampleRate
                const freqHz = (root.hoverThetaDeg <= 180 ? root.hoverThetaDeg : 360 - root.hoverThetaDeg) * fs / 360.0

                const zStr = (kind === "pole" ? "Pole: z = " : "Zero: z = ") +
                             root.hoverRe.toFixed(4) + " " + sign + " j" + Math.abs(root.hoverIm).toFixed(4) + multStr

                let polarStr = "r = " + root.hoverR.toFixed(4) + ", θ = " + root.hoverThetaDeg.toFixed(1) + "° (f ≈ " + Math.round(freqHz) + " Hz)"
                if (kind === "pole" && root.hoverR > 0.5 && root.hoverR < 0.9999) {
                    const qEst = 1.0 / (2.0 * Math.max(0.0001, 1.0 - root.hoverR))
                    polarStr += " [Q ≈ " + qEst.toFixed(1) + "]"
                }

                const stabStr = root.hoverR < 0.999 ? ("Stable (Margin: " + (1.0 - root.hoverR).toFixed(4) + ")") :
                                (root.hoverR > 1.001 ? "UNSTABLE (r > 1)" : "Marginally Stable (r ≈ 1)")

                ctx.font = "bold 10px 'Stack Sans Headline', monospace"
                const w1 = ctx.measureText(zStr).width
                const w2 = ctx.measureText(polarStr).width
                const bw = Math.max(w1, w2) + 18
                const bh = 48
                const bx = 10
                const by = height - bh - 8

                ctx.fillStyle = theme.isDark ? "rgba(25, 25, 25, 0.94)" : "rgba(255, 255, 255, 0.94)"
                ctx.strokeStyle = theme.borderColor
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.rect(bx, by, bw, bh)
                ctx.fill()
                ctx.stroke()

                ctx.fillStyle = kind === "pole" ? theme.danger : theme.accent
                ctx.textAlign = "left"
                ctx.textBaseline = "top"
                ctx.fillText(zStr, bx + 8, by + 5)

                ctx.fillStyle = theme.primaryText
                ctx.fillText(polarStr, bx + 8, by + 19)

                ctx.fillStyle = root.hoverR < 1.001 ? "#30D158" : theme.danger
                ctx.fillText(stabStr, bx + 8, by + 33)
            }
        }
    }

    // Top Controls Bar (Clean and consistent)
    Item {
        id: topBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 8
            leftMargin: 12
            rightMargin: 12
        }
        height: 24
        z: 10

        // Left Controls Cluster
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Stability Indicator Pill (Clean, minimal)
            Rectangle {
                height: 22
                width: stabRow.implicitWidth + 14
                radius: 4
                color: theme.surfaceHigh
                border.color: theme.borderColor
                border.width: 1

                Row {
                    id: stabRow
                    anchors.centerIn: parent
                    spacing: 5
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: filterEngine.isStable() ? "#34C759" : theme.danger
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: filterEngine.isStable() ? "Stable" : "Unstable"
                        font.family: "Stack Sans Headline"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: theme.primaryText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Right Controls Cluster (Auto Scale, Data Cursor, Save, Copy, Menu)
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            // Auto Scale Pill
            Rectangle {
                height: 22
                width: autoScalePzRow.implicitWidth + 12
                radius: 4
                color: root.isCustomView
                        ? (theme.isDark ? "#1C2D42" : "#E1EFFF")
                        : (autoScalePzMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent")
                border.color: root.isCustomView ? theme.accent : theme.borderColor
                border.width: 1

                Row {
                    id: autoScalePzRow
                    anchors.centerIn: parent
                    spacing: 4
                    Codicon {
                        icon: "screen-full"
                        iconSize: 11
                        iconColor: root.isCustomView ? theme.accent : (autoScalePzMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Auto Scale"
                        font.family: "Stack Sans Headline"
                        font.pixelSize: 11
                        font.weight: root.isCustomView ? Font.DemiBold : Font.Normal
                        color: root.isCustomView ? theme.accent : (autoScalePzMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                ToolTip.visible: autoScalePzMouse.containsMouse
                ToolTip.text: "Auto Scale / Fit View (Desmos)"
                ToolTip.delay: 350

                MouseArea {
                    id: autoScalePzMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.autoScale()
                        root.showPlotToast("Z-plane auto-scaled")
                    }
                }
            }

            // Data Cursor (+) Inspector Opt-in Toggle Pill
            Rectangle {
                height: 22
                width: curPzRow.implicitWidth + 12
                radius: 4
                color: root.showCrosshair
                        ? theme.accent
                        : (curPzMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent")
                border.color: root.showCrosshair ? theme.accent : theme.borderColor
                border.width: 1

                Row {
                    id: curPzRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "✛"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.showCrosshair ? "#FFFFFF" : (curPzMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Cursor"
                        font.family: "Stack Sans Headline"
                        font.pixelSize: 11
                        font.weight: root.showCrosshair ? Font.DemiBold : Font.Normal
                        color: root.showCrosshair ? "#FFFFFF" : (curPzMouse.containsMouse ? theme.primaryText : theme.secondaryText)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                ToolTip.visible: curPzMouse.containsMouse
                ToolTip.text: root.showCrosshair ? "Root Inspector Active (Click to Hide)" : "Enable Data Cursor / Root Inspector (+) (Default: Off)"
                ToolTip.delay: 350

                MouseArea {
                    id: curPzMouse
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
                color: savePzMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "camera"
                    iconSize: 12
                    iconColor: savePzMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }
                ToolTip.visible: savePzMouse.containsMouse
                ToolTip.text: "Save Z-Plane Image (PNG)"
                ToolTip.delay: 400

                MouseArea {
                    id: savePzMouse
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
                color: copyPzMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "copy"
                    iconSize: 12
                    iconColor: copyPzMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }
                ToolTip.visible: copyPzMouse.containsMouse
                ToolTip.text: "Copy Z-Plane Image"
                ToolTip.delay: 400

                MouseArea {
                    id: copyPzMouse
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
                color: popoutPzMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "link-external"
                    iconSize: 12
                    iconColor: popoutPzMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }
                ToolTip.visible: popoutPzMouse.containsMouse
                ToolTip.text: "Open Z-Plane in Dedicated Window"
                ToolTip.delay: 400

                MouseArea {
                    id: popoutPzMouse
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
                color: menuPzBtnMouse.containsMouse ? (theme.isDark ? "#25272B" : "#E4E7EB") : "transparent"
                border.color: theme.borderColor
                border.width: 1

                Codicon {
                    anchors.centerIn: parent
                    icon: "kebab-vertical"
                    iconSize: 13
                    iconColor: menuPzBtnMouse.containsMouse ? theme.primaryText : theme.secondaryText
                }

                ToolTip.visible: menuPzBtnMouse.containsMouse
                ToolTip.text: "Z-Plane Settings & Options (Right-Click)"
                ToolTip.delay: 400

                MouseArea {
                    id: menuPzBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pzContextMenu.popup(topBar.x + topBar.width - 230, topBar.y + topBar.height + 4)
                }
            }
        }
    }

    // Interactive Hover Snapping, Pan/Zoom & Context Menu
    MouseArea {
        id: pzMouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.showCrosshair ? Qt.CrossCursor : Qt.OpenHandCursor
        z: 2

        onPressed: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                pzContextMenu.popup(mouse.x, mouse.y)
                return
            }
            root.lastMouseX = mouse.x
            root.lastMouseY = mouse.y
            root.isPanning = true
            cursorShape = Qt.ClosedHandCursor
        }

        onReleased: function(mouse) {
            root.isPanning = false
            cursorShape = root.showCrosshair ? Qt.CrossCursor : Qt.OpenHandCursor
        }

        onDoubleClicked: function(mouse) {
            root.autoScale()
            root.showPlotToast("Z-plane auto-scaled")
        }

        onWheel: function(wheel) {
            const factor = wheel.angleDelta.y > 0 ? 1.20 : 0.83
            root.zoomAt(wheel.x, wheel.y, factor)
        }

        onPositionChanged: function(mouse) {
            if (root.isPanning) {
                const dx = mouse.x - root.lastMouseX
                const dy = mouse.y - root.lastMouseY
                root.lastMouseX = mouse.x
                root.lastMouseY = mouse.y
                root.panBy(dx, dy)
                return
            }

            if (!root.showCrosshair) {
                if (root.hoverIndex !== -1) {
                    root.hoverIndex = -1
                    root.schedulePaint()
                }
                cursorShape = Qt.OpenHandCursor
                return
            }

            const cx = width / 2 + root.panOffsetX
            const cy = height / 2 + 8 + root.panOffsetY
            const baseR = Math.min(width, height - 36) / 2 - 28
            const r  = baseR * root.zoomScale
            const pts = filterEngine.poleZeroData
            const n = pts ? pts.length : 0

            let foundIdx = -1
            let minD = 14 * Math.max(0.7, Math.min(2.0, root.zoomScale)) // snap radius in pixels

            for (let i = 0; i < n; ++i) {
                const pt = pts[i]
                const px = cx + Number(pt["re"]) * r
                const py = cy - Number(pt["im"]) * r
                const d = Math.hypot(mouse.x - px, mouse.y - py)
                if (d < minD) {
                    minD = d
                    foundIdx = i
                }
            }

            if (foundIdx >= 0) {
                const target = pts[foundIdx]
                root.hoverIndex = foundIdx
                root.hoverType = String(target["kind"])
                root.hoverRe = Number(target["re"])
                root.hoverIm = Number(target["im"])
                root.hoverR = Math.hypot(root.hoverRe, root.hoverIm)
                root.hoverThetaDeg = (Math.atan2(root.hoverIm, root.hoverRe) * 180 / Math.PI + 360) % 360
                root.schedulePaint()
            } else if (root.hoverIndex !== -1) {
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

    // Desmos Floating Zoom & Auto-Scale Tool Cluster (Bottom-Right overlay)
    Rectangle {
        id: floatingDesmosPzControls
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: 14
            bottomMargin: 14
        }
        width: 32
        height: 94
        radius: 7
        color: theme.isDark ? "#25272B" : "#FFFFFF"
        border.color: theme.borderColor
        border.width: 1
        z: 20

        Column {
            anchors.centerIn: parent
            spacing: 2

            // Zoom In (+)
            Rectangle {
                width: 28; height: 26; radius: 4
                color: pzZoomInMouse.containsMouse ? (theme.isDark ? "#3A3A3C" : "#EAEAEA") : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.family: "Stack Sans Headline"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: theme.primaryText
                }
                ToolTip.visible: pzZoomInMouse.containsMouse
                ToolTip.text: "Zoom In (+)"
                ToolTip.delay: 350
                MouseArea {
                    id: pzZoomInMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.zoomCenter(1.25)
                }
            }

            Rectangle {
                width: 20; height: 1
                color: theme.borderColor
                opacity: 0.6
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Zoom Out (−)
            Rectangle {
                width: 28; height: 26; radius: 4
                color: pzZoomOutMouse.containsMouse ? (theme.isDark ? "#3A3A3C" : "#EAEAEA") : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "−"
                    font.family: "Stack Sans Headline"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: theme.primaryText
                }
                ToolTip.visible: pzZoomOutMouse.containsMouse
                ToolTip.text: "Zoom Out (−)"
                ToolTip.delay: 350
                MouseArea {
                    id: pzZoomOutMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.zoomCenter(0.8)
                }
            }

            Rectangle {
                width: 20; height: 1
                color: theme.borderColor
                opacity: 0.6
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Auto Scale / Fit (⤢)
            Rectangle {
                width: 28; height: 26; radius: 4
                color: pzAutoFitMouse.containsMouse ? (theme.isDark ? "#3A3A3C" : "#EAEAEA") : "transparent"
                Codicon {
                    anchors.centerIn: parent
                    icon: "screen-full"
                    iconSize: 13
                    iconColor: root.isCustomView ? theme.accent : theme.secondaryText
                }
                ToolTip.visible: pzAutoFitMouse.containsMouse
                ToolTip.text: "Auto Scale / Fit View (Double-click plot)"
                ToolTip.delay: 350
                MouseArea {
                    id: pzAutoFitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.autoScale()
                        root.showPlotToast("Z-plane auto-scaled")
                    }
                }
            }
        }
    }

    // MATLAB Filter Designer Pole-Zero Context Menu
    Menu {
        id: pzContextMenu

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
                root.showPlotToast("Z-plane auto-scaled")
            }
        }

        MenuItem {
            text: "Zoom In (+)"
            onTriggered: root.zoomCenter(1.25)
        }

        MenuItem {
            text: "Zoom Out (−)"
            onTriggered: root.zoomCenter(0.8)
        }

        MenuSeparator {}

        MenuItem {
            text: "Polar Grid (Rings & Radial Spokes)"
            checkable: true
            checked: root.showPolarGrid
            onTriggered: {
                root.showPolarGrid = !root.showPolarGrid
                root.schedulePaint()
            }
        }

        MenuItem {
            text: "Stability Region (|z| < 1) Shading"
            checkable: true
            checked: root.showStabilityRegion
            onTriggered: {
                root.showStabilityRegion = !root.showStabilityRegion
                root.schedulePaint()
            }
        }

        MenuSeparator {}

        MenuItem {
            text: "Data Cursor / Root Inspector (+)"
            checkable: true
            checked: root.showCrosshair
            onTriggered: {
                root.showCrosshair = !root.showCrosshair
                if (!root.showCrosshair) root.hoverIndex = -1
                root.schedulePaint()
            }
        }

        MenuSeparator {}

        MenuItem {
            text: "Copy Z-Plane Image to Clipboard"
            onTriggered: root.copyPlotImage()
        }

        MenuItem {
            text: "Save Z-Plane Image (PNG)..."
            onTriggered: root.exportPlotImage()
        }

        MenuSeparator {}

        MenuItem {
            text: "Copy Poles and Zeros (JSON)"
            onTriggered: {
                const pts = filterEngine.poleZeroData
                filterEngine.copyText(JSON.stringify(pts, null, 2))
                root.showPlotToast("Poles & Zeros JSON copied")
            }
        }
    }

    // Save File Dialog
    FileDialog {
        id: savePlotDialog
        title: "Save Z-Plane Plot Image"
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
        width: Math.min(parent.width - 24, pzToastText.implicitWidth + 20)
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
                id: pzToastText
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
        onTriggered: root.schedulePaint()
    }

    Connections {
        target: filterEngine
        function onResultsChanged() { root.schedulePaint() }
    }

    Connections {
        target: theme
        function onThemeModeChanged() { root.schedulePaint() }
    }

    Component.onCompleted: schedulePaint()
    onVisibleChanged: { if (visible) schedulePaint() }
    onWidthChanged:  schedulePaint()
    onHeightChanged: schedulePaint()
}
