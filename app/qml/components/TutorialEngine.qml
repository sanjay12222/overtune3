import QtQuick
import QtQuick.Window

// TutorialEngine.qml — Central state machine for Modes (Design, Learn, Challenge),
// interactive tutorial DSL execution, live DSP condition checking, and gamified progress.
Item {
    id: engine

    // ── Application Modes: 0 = DESIGN, 1 = LEARN, 2 = CHALLENGE ─────────────
    property int currentMode: 0 // 0=DESIGN, 1=LEARN, 2=CHALLENGE

    // ── Gamified Mastery State ────────────────────────────────────────────────
    property int userXp: 340
    property int maxXp: 500
    property string userBadge: "Pole Explorer"
    property var unlockedBadges: ["First Filter", "Pole Explorer", "Butterworth Master"]

    // ── Interactive Tutorial (LEARN mode) ─────────────────────────────────────
    property int currentTutorialIndex: 0
    property int currentStepIndex: 0
    property var activeTutorial: tutorials[currentTutorialIndex]
    readonly property var currentStep: (activeTutorial && activeTutorial.steps && activeTutorial.steps.length > currentStepIndex)
                                        ? activeTutorial.steps[currentStepIndex] : null

    property bool stepSatisfied: false
    property int userPredictionChoice: -1
    property bool predictionAnswered: false
    property bool predictionCorrect: false
    property string feedbackText: ""
    property bool showRegionHighlight: false

    // Target coordinates for the spotlight overlay
    property string spotlightTargetId: currentStep ? (currentStep.target || "") : ""
    property var spotlightRegion: currentStep ? (currentStep.highlightRegion || null) : null

    // ── Lab Challenges (CHALLENGE mode) ───────────────────────────────────────
    property int currentChallengeIndex: 0
    property var activeChallenge: challenges[currentChallengeIndex]
    property var labEvaluation: ({
        passbandSatisfied: false,
        stopbandSatisfied: false,
        stabilitySatisfied: true,
        orderSatisfied: true,
        attenuationAtStop: 0.0,
        rippleInPass: 0.0,
        maxPoleRadius: 0.6,
        score: 0,
        allPassed: false
    })

    // ── Authoring & Recording Mode ────────────────────────────────────────────
    property bool isRecording: false
    property var recordedActions: []

    // ─────────────────────────────────────────────────────────────────────────
    // TUTORIAL DSL CATALOG
    // ─────────────────────────────────────────────────────────────────────────
    readonly property var tutorials: [
        {
            id: "tut_pole_locations",
            title: "Understanding Pole Locations & Resonance",
            difficulty: "Beginner",
            category: "IIR Fundamentals",
            badge: "Pole Explorer",
            xpAward: 120,
            steps: [
                {
                    stepNum: 1,
                    type: "navigate",
                    target: "sidebar_analysis",
                    title: "Step 1 — Open the Pole-Zero View",
                    instruction: "Click Analysis (or press Ctrl+2) in the sidebar to open the Frequency & Pole-Zero suite.",
                    expectedPage: 1
                },
                {
                    stepNum: 2,
                    type: "observe",
                    target: "pole_zero_plot",
                    title: "Step 2 — Observe the Poles in the Complex Z-Plane",
                    instruction: "Notice how the poles are concentrated around a radius of approximately 0.6 inside the unit circle.",
                    highlightRegion: { type: "circle", radius: 0.6, label: "r ≈ 0.6" }
                },
                {
                    stepNum: 3,
                    type: "predict",
                    target: "pole_zero_plot",
                    title: "Step 3 — Interactive Prediction",
                    instruction: "What happens to the filter frequency response if you move the poles closer to the unit circle (|z| → 1)?",
                    options: [
                        "Moving poles closer makes the resonance significantly sharper",
                        "Moving poles closer creates a wider, flatter passband",
                        "The output signal is completely attenuated to zero"
                    ],
                    correctIndex: 0,
                    explanation: "Moving poles closer to the unit circle causes the denominator of H(z) to approach zero, producing high resonant peaking and sharp rolloff."
                },
                {
                    stepNum: 4,
                    type: "manipulate",
                    target: "param_cutoff",
                    title: "Step 4 — Your Turn: Push Poles Toward Unit Circle",
                    instruction: "Decrease cutoff frequency or increase the order until the maximum pole radius exceeds 0.82.",
                    conditionName: "maxPoleRadius >= 0.82",
                    checkCondition: function() {
                        return (typeof filterEngine !== "undefined") && (filterEngine.maxPoleRadius() >= 0.82)
                    },
                    successMessage: "✓ Correct! Moving the poles closer to the unit circle makes the resonance sharper."
                },
                {
                    stepNum: 5,
                    type: "explain",
                    target: "pole_zero_plot",
                    title: "Step 5 — Summary & Key Insight",
                    instruction: "Poles dictate the resonant frequencies and sharpness of your filter. As long as all poles remain strictly inside |z| < 1, the filter remains BIBO stable.",
                    highlightRegion: { type: "circle", radius: 1.0, label: "Stability Boundary |z| = 1" }
                }
            ]
        },
        {
            id: "tut_butterworth_design",
            title: "Design a Butterworth Audio Lowpass",
            difficulty: "Beginner",
            category: "Audio Engineering",
            badge: "Butterworth Master",
            xpAward: 140,
            steps: [
                {
                    stepNum: 1,
                    type: "navigate",
                    target: "sidebar_design",
                    title: "Step 1 — Open Filter Designer Studio",
                    instruction: "Click Design in the sidebar (or press Ctrl+1) to begin synthesizing.",
                    expectedPage: 0
                },
                {
                    stepNum: 2,
                    type: "manipulate",
                    target: "param_fc",
                    title: "Step 2 — Set Cutoff to 4 kHz",
                    instruction: "Adjust the cutoff frequency slider to 4,000 Hz (between 3,800 Hz and 4,200 Hz).",
                    conditionName: "3800 <= Cutoff <= 4200 Hz",
                    checkCondition: function() {
                        return (typeof filterEngine !== "undefined") && (filterEngine.cutoffFreq >= 3800 && filterEngine.cutoffFreq <= 4200)
                    },
                    successMessage: "✓ Cutoff frequency set to 4 kHz."
                },
                {
                    stepNum: 3,
                    type: "manipulate",
                    target: "param_response",
                    title: "Step 3 — Select Butterworth Prototype",
                    instruction: "Select Butterworth response from the dropdown to ensure a maximally flat passband with zero ripple.",
                    conditionName: "Response == Butterworth",
                    checkCondition: function() {
                        return (typeof filterEngine !== "undefined") && (filterEngine.filterResponse === 0)
                    },
                    successMessage: "✓ Butterworth prototype selected."
                },
                {
                    stepNum: 4,
                    type: "manipulate",
                    target: "param_order",
                    title: "Step 4 — Increase Order to 6",
                    instruction: "Set filter order to 6 for a steep -36 dB/octave attenuation slope.",
                    conditionName: "Order == 6",
                    checkCondition: function() {
                        return (typeof filterEngine !== "undefined") && (filterEngine.order === 6)
                    },
                    successMessage: "✓ Filter order set to 6."
                },
                {
                    stepNum: 5,
                    type: "manipulate",
                    target: "freq_plot",
                    title: "Step 5 — Challenge: Attenuation at 8 kHz",
                    instruction: "Challenge: Adjust order or cutoff until attenuation at 8,000 Hz exceeds 40 dB.",
                    conditionName: "Attenuation @ 8 kHz >= 40 dB",
                    checkCondition: function() {
                        return (typeof filterEngine !== "undefined") && (filterEngine.attenuationDbAt(8000) >= 40.0)
                    },
                    successMessage: "✓ Goal achieved! Attenuation at 8 kHz exceeds 40 dB."
                }
            ]
        },
        {
            id: "tut_mains_notch",
            title: "50/60 Hz Ground Loop Notch Elimination",
            difficulty: "Intermediate",
            category: "Interference Rejection",
            badge: "Notch Surgeon",
            xpAward: 150,
            steps: [
                {
                    stepNum: 1,
                    type: "manipulate",
                    target: "param_type",
                    title: "Step 1 — Select Bandstop (Notch) Topology",
                    instruction: "Change the Filter Type dropdown to Bandstop (Notch).",
                    conditionName: "Type == Bandstop",
                    checkCondition: function() {
                        return (typeof filterEngine !== "undefined") && (filterEngine.filterType === 3)
                    },
                    successMessage: "✓ Bandstop topology activated."
                },
                {
                    stepNum: 2,
                    type: "manipulate",
                    target: "param_fc",
                    title: "Step 2 — Tune to 50 Hz Mains Frequency",
                    instruction: "Set cutoff frequency to 50 Hz to target electrical mains hum.",
                    conditionName: "48 <= Cutoff <= 52 Hz",
                    checkCondition: function() {
                        return (typeof filterEngine !== "undefined") && (filterEngine.cutoffFreq >= 48 && filterEngine.cutoffFreq <= 52)
                    },
                    successMessage: "✓ Notch frequency tuned to 50 Hz."
                },
                {
                    stepNum: 3,
                    type: "observe",
                    target: "pole_zero_plot",
                    title: "Step 3 — Observe Unit Circle Transmission Zeros",
                    instruction: "Notice how conjugate zeros lie directly on the unit circle (|z| = 1) at angle ±ω0, ensuring mathematical infinite rejection at 50 Hz.",
                    highlightRegion: { type: "circle", radius: 1.0, label: "Zero on Unit Circle" }
                }
            ]
        }
    ]

    // ─────────────────────────────────────────────────────────────────────────
    // LAB CHALLENGES (CHALLENGE MODE)
    // ─────────────────────────────────────────────────────────────────────────
    readonly property var challenges: [
        {
            id: "ch_01_audio_lpf",
            title: "Challenge 01 — Broadcast Studio Lowpass",
            category: "Audio Engineering",
            badge: "Audio Architect",
            xp: 150,
            description: "Synthesize an audio lowpass filter satisfying strict broadcast studio specs.",
            passbandFreq: 4000.0,
            maxPassbandRipple: 1.0,
            stopbandFreq: 8000.0,
            minStopbandAtten: 45.0,
            maxOrder: 8,
            hints: [
                "Butterworth or Chebyshev Type II will satisfy passband flatness.",
                "Order 6 to 8 will provide > 45 dB attenuation at 8 kHz with Fc around 4 kHz."
            ]
        },
        {
            id: "ch_02_notch_hum",
            title: "Challenge 02 — 50 Hz Ground Loop Eliminator",
            category: "Signal Conditioning",
            badge: "Notch Master",
            xp: 150,
            description: "Eliminate mains electrical hum with minimum passband phase distortion.",
            passbandFreq: 40.0,
            maxPassbandRipple: 2.0,
            stopbandFreq: 50.0,
            minStopbandAtten: 35.0,
            maxOrder: 6,
            hints: [
                "Select Bandstop (Notch) topology.",
                "Keep stopband width narrow to minimize phase distortion on nearby bass notes."
            ]
        },
        {
            id: "ch_03_biomedical_ecg",
            title: "Challenge 03 — Biomedical ECG Baseline Wandering",
            category: "Biomedical Instrumentation",
            badge: "Biomedical Specialist",
            xp: 180,
            description: "Isolate ECG QRS complexes while rejecting patient respiration drift below 0.5 Hz.",
            passbandFreq: 1.0,
            maxPassbandRipple: 1.5,
            stopbandFreq: 0.2,
            minStopbandAtten: 25.0,
            maxOrder: 6,
            hints: [
                "Highpass filter topology with sharp transition.",
                "Ensure all poles remain strictly stable within the unit circle."
            ]
        },
        {
            id: "ch_04_crossover",
            title: "Challenge 04 — Linkwitz-Riley Acoustic Crossover",
            category: "Acoustics & Loudspeakers",
            badge: "Acoustics Pro",
            xp: 200,
            description: "Design a matched 4th-order Linkwitz-Riley lowpass crossover section at 1,200 Hz.",
            passbandFreq: 1000.0,
            maxPassbandRipple: 0.5,
            stopbandFreq: 2400.0,
            minStopbandAtten: 24.0,
            maxOrder: 4,
            hints: [
                "A 4th-order Butterworth rolls off at -24 dB/octave (a Linkwitz-Riley LR4 crossover is two cascaded 2nd-order Butterworths, not one 4th-order)."
            ]
        }
    ]

    // ─────────────────────────────────────────────────────────────────────────
    // CORE LOGIC & CONTROLS
    // ─────────────────────────────────────────────────────────────────────────
    function setMode(modeIdx) {
        currentMode = modeIdx
        if (modeIdx === 1) {
            // LEARN mode: start or resume tutorial
            currentStepIndex = 0
            checkCurrentStep()
        } else if (modeIdx === 2) {
            // CHALLENGE mode: evaluate active lab challenge
            evaluateCurrentChallenge()
        }
    }

    function selectTutorial(idx) {
        currentTutorialIndex = Math.max(0, Math.min(tutorials.length - 1, idx))
        currentStepIndex = 0
        stepSatisfied = false
        predictionAnswered = false
        userPredictionChoice = -1
        checkCurrentStep()
    }

    function nextStep() {
        if (!activeTutorial || !activeTutorial.steps) return
        if (currentStepIndex < activeTutorial.steps.length - 1) {
            currentStepIndex++
            stepSatisfied = false
            predictionAnswered = false
            userPredictionChoice = -1
            checkCurrentStep()
        } else {
            // Tutorial Completed! Award XP
            userXp = Math.min(maxXp, userXp + (activeTutorial.xpAward || 100))
            if (activeTutorial.badge && unlockedBadges.indexOf(activeTutorial.badge) === -1) {
                unlockedBadges.push(activeTutorial.badge)
            }
            feedbackText = "Tutorial Completed! +" + (activeTutorial.xpAward || 100) + " XP Awarded!"
        }
    }

    function prevStep() {
        if (currentStepIndex > 0) {
            currentStepIndex--
            stepSatisfied = false
            predictionAnswered = false
            userPredictionChoice = -1
            checkCurrentStep()
        }
    }

    function answerPrediction(optIdx) {
        if (!currentStep || currentStep.type !== "predict") return
        userPredictionChoice = optIdx
        predictionAnswered = true
        predictionCorrect = (optIdx === currentStep.correctIndex)
        if (predictionCorrect) {
            stepSatisfied = true
            feedbackText = "✓ Correct! " + (currentStep.explanation || "")
        } else {
            stepSatisfied = false
            feedbackText = "Not quite. Think about how proximity to the unit circle (|z|=1) changes the denominator in H(z)."
        }
    }

    function checkCurrentStep() {
        if (!currentStep) return
        if (currentStep.type === "navigate") {
            const w = Window.window
            if (currentStep.expectedPage !== undefined && w && typeof w.sidebar !== "undefined") {
                stepSatisfied = (w.sidebar.currentPage === currentStep.expectedPage)
            }
        } else if (currentStep.type === "manipulate" && typeof currentStep.checkCondition === "function") {
            stepSatisfied = currentStep.checkCondition()
            if (stepSatisfied && currentStep.successMessage) {
                feedbackText = currentStep.successMessage
            }
        } else if (currentStep.type === "observe" || currentStep.type === "explain") {
            stepSatisfied = true
        }
    }

    function selectChallenge(idx) {
        currentChallengeIndex = Math.max(0, Math.min(challenges.length - 1, idx))
        evaluateCurrentChallenge()
    }

    function evaluateCurrentChallenge() {
        if (!activeChallenge || typeof filterEngine === "undefined") return
        labEvaluation = filterEngine.evaluateLab(
            activeChallenge.passbandFreq,
            activeChallenge.stopbandFreq,
            activeChallenge.minStopbandAtten,
            activeChallenge.maxPassbandRipple,
            activeChallenge.maxOrder
        )
        if (labEvaluation.allPassed) {
            userXp = Math.min(maxXp, userXp + 30)
            if (activeChallenge.badge && unlockedBadges.indexOf(activeChallenge.badge) === -1) {
                unlockedBadges.push(activeChallenge.badge)
            }
        }
    }

    // Connect to engine changes for dynamic satisfaction checking
    Connections {
        target: (typeof filterEngine !== "undefined") ? filterEngine : null
        function onSpecChanged() {
            if (engine.currentMode === 1) engine.checkCurrentStep()
            if (engine.currentMode === 2) engine.evaluateCurrentChallenge()
            if (engine.isRecording) {
                engine.recordAction("specChanged", {
                    type: filterEngine.filterType,
                    response: filterEngine.filterResponse,
                    order: filterEngine.order,
                    fc: filterEngine.cutoffFreq,
                    fs: filterEngine.sampleRate
                })
            }
        }
        function onResultsChanged() {
            if (engine.currentMode === 1) engine.checkCurrentStep()
            if (engine.currentMode === 2) engine.evaluateCurrentChallenge()
        }
    }

    // ── Interaction Recording (Authoring Mode) ────────────────────────────────
    function startRecording() {
        isRecording = true
        recordedActions = []
    }

    function stopRecording() {
        isRecording = false
    }

    function recordAction(actionType, params) {
        recordedActions.push({
            timestamp: Date.now(),
            action: actionType,
            params: params
        })
    }
}
