#include "dsp/FilterAnalysis.h"
#include <array>
#include <cmath>
#include <numbers>
#include <algorithm>
#include <stdexcept>
#include <tuple>
#include <utility>

namespace dsp {

static constexpr double PI = std::numbers::pi;

// Apply filter biquad cascade to a single sample (Direct Form II Canonical)
static double biquadProcess(const FilterCoefficients& c,
                             std::vector<std::array<double,2>>& state,
                             double x) {
    double y = x * c.gain;
    for (size_t i = 0; i < c.sos.size(); ++i) {
        const auto& s = c.sos[i];
        const double w   = y - s.a1 * state[i][0] - s.a2 * state[i][1];
        const double out = s.b0 * w + s.b1 * state[i][0] + s.b2 * state[i][1];
        state[i][1] = state[i][0];
        state[i][0] = w;
        y = out;
    }
    return y;
}

// Evaluate H(z) slightly inside the unit circle (|z| = 1 - 1e-4) so the phase of
// transmission nulls is taken off the branch-cut singularity
static Complex evaluateRegularized(const FilterCoefficients& coeff, double omega) {
    const Complex zReg = std::polar(1.0 - 1e-4, omega);
    if (coeff.isFir()) {
        Complex acc{};
        Complex zPow{1.0, 0.0};
        for (double h : coeff.fir) {
            acc += h * zPow;
            zPow /= zReg;
        }
        return coeff.gain * acc;
    }
    Complex HReg{coeff.gain};
    for (const auto& s : coeff.sos) {
        const Complex numReg = s.b0 + s.b1 / zReg + s.b2 / (zReg * zReg);
        const Complex denReg = 1.0  + s.a1 / zReg + s.a2 / (zReg * zReg);
        if (std::abs(denReg) > 1e-300) {
            HReg *= numReg / denReg;
        }
    }
    return HReg;
}

// FIR group delay: tau(w) = Re{ sum n h[n] z^-n / sum h[n] z^-n }
static double firGroupDelay(const FilterCoefficients& coeff, double omega) {
    auto ratioAt = [&](double radius) {
        const Complex zInv = 1.0 / std::polar(radius, omega);
        Complex num{}, numDeriv{};
        Complex zPow{1.0, 0.0};
        for (size_t n = 0; n < coeff.fir.size(); ++n) {
            num += coeff.fir[n] * zPow;
            numDeriv += static_cast<double>(n) * coeff.fir[n] * zPow;
            zPow *= zInv;
        }
        return std::make_pair(num, numDeriv);
    };
    auto [num, numDeriv] = ratioAt(1.0);
    if (std::abs(num) <= 1e-10) std::tie(num, numDeriv) = ratioAt(1.0 - 1e-4);
    if (std::abs(num) <= 1e-300) return 0.0;
    return (numDeriv / num).real();
}

static double sosGroupDelay(const FilterCoefficients& coeff, const Complex& zInv, const Complex& zInv2) {
    double totalGd = 0.0;
    for (const auto& s : coeff.sos) {
        Complex num = s.b0 + s.b1 * zInv + s.b2 * zInv2;
        Complex den = 1.0  + s.a1 * zInv + s.a2 * zInv2;

        if (std::abs(num) > 1e-14) {
            const Complex numDeriv = (s.b1 * zInv + 2.0 * s.b2 * zInv2) / num;
            totalGd += numDeriv.real();
        }

        if (std::abs(den) > 1e-14) {
            const Complex denDeriv = (s.a1 * zInv + 2.0 * s.a2 * zInv2) / den;
            totalGd -= denDeriv.real();
        }
    }
    return totalGd;
}

AnalysisResult FilterAnalysis::compute(const FilterCoefficients& coeff,
                                       double sampleRate,
                                       int    numPoints,
                                       double cutoff1,
                                       double cutoff2) {
    AnalysisResult result;
    result.poles = coeff.poles;
    result.zeros = coeff.zeros;
    result.gain  = coeff.gain;

    if (!coeff.isValid() || !std::isfinite(sampleRate) || sampleRate <= 0.0 ||
        !std::isfinite(cutoff1) || !std::isfinite(cutoff2)) {
        throw std::invalid_argument("Frequency analysis requires valid coefficients, sample rate, and cutoffs");
    }
    const double nyquist = sampleRate / 2.0;
    if (cutoff1 > 0.0 && cutoff1 >= nyquist)
        throw std::invalid_argument("The lower cutoff must be below Nyquist");
    if (cutoff2 > 0.0 && cutoff2 >= nyquist)
        throw std::invalid_argument("The upper cutoff must be below Nyquist");
    if (cutoff2 > 0.0 && cutoff1 > 0.0 && cutoff2 <= cutoff1)
        throw std::invalid_argument("The upper cutoff must exceed the lower cutoff");
    if (numPoints < 256) numPoints = 256;

    // Minimum frequency: adapt to low cutoff filters (e.g. 5 Hz or 13.5 Hz)
    double fMin = 0.05;
    if (cutoff1 > 0.0) {
        fMin = std::min(fMin, cutoff1 / 50.0);
    }
    if (cutoff2 > 0.0) {
        fMin = std::min(fMin, cutoff2 / 50.0);
    }
    fMin = std::clamp(fMin, 0.0001, 1.0);

    // Build comprehensive adaptive frequency vector
    std::vector<double> freqs;
    freqs.reserve(numPoints * 2 + 1024);

    // 1. DC (0 Hz) - vital for linear and normalized digital axes
    freqs.push_back(0.0);

    // 2. Logarithmically spaced base grid (dense audio/low-frequency coverage)
    const double logMin = std::log10(fMin);
    const double logMax = std::log10(nyquist);
    for (int i = 0; i < numPoints; ++i) {
        const double frac = static_cast<double>(i) / static_cast<double>(numPoints - 1);
        freqs.push_back(std::pow(10.0, logMin + (logMax - logMin) * frac));
    }

    // 3. Linearly spaced uniform grid (dense RF/high-frequency coverage across entire spectrum)
    for (int i = 0; i < numPoints; ++i) {
        const double f = (static_cast<double>(i) / static_cast<double>(numPoints - 1)) * nyquist;
        if (f > 0.0 && f < nyquist) {
            freqs.push_back(f);
        }
    }

    // 4. High-precision transition band clustering around critical cutoff frequencies
    auto injectCluster = [&](double fc) {
        if (fc <= fMin || fc >= nyquist) return;
        freqs.push_back(fc); // Exact cutoff point

        // Dense sampling around transition band
        static constexpr double offsets[] = {
            -0.35, -0.25, -0.18, -0.12, -0.08, -0.05, -0.03, -0.02, -0.015, -0.01,
            -0.005, -0.002, -0.001, -0.0005, -0.0002,
             0.0002,  0.0005,  0.001,  0.002,  0.005,  0.01,  0.015,  0.02,  0.03,
             0.05,  0.08,  0.12,  0.18,  0.25,  0.35
        };
        for (double off : offsets) {
            double f = fc * (1.0 + off);
            if (f > 0.0 && f < nyquist) {
                freqs.push_back(f);
            }
        }
    };

    if (cutoff1 > 0.0) injectCluster(cutoff1);
    if (cutoff2 > 0.0) injectCluster(cutoff2);

    // 5. Resonant peaks and zeros near the unit circle
    for (const auto& p : coeff.poles) {
        double theta = std::abs(std::arg(p));
        double f = (theta / (2.0 * PI)) * sampleRate;
        if (f > 0.0 && f < nyquist) {
            freqs.push_back(f);
            double bw = (1.0 - std::min(0.9999, std::abs(p))) * sampleRate / (2.0 * PI);
            if (bw > 0.001 && bw < sampleRate * 0.1) {
                static constexpr double scales[] = {0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0};
                for (double scale : scales) {
                    if (f - bw * scale > 0.0) freqs.push_back(f - bw * scale);
                    if (f + bw * scale < nyquist) freqs.push_back(f + bw * scale);
                }
            }
        }
    }
    for (const auto& z : coeff.zeros) {
        double theta = std::abs(std::arg(z));
        double f = (theta / (2.0 * PI)) * sampleRate;
        if (f > 0.0 && f < nyquist) {
            freqs.push_back(f);
            double bw = (1.0 - std::min(0.9999, std::abs(z))) * sampleRate / (2.0 * PI);
            if (bw > 0.001 && bw < sampleRate * 0.1) {
                static constexpr double scales[] = {0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0};
                for (double scale : scales) {
                    if (f - bw * scale > 0.0) freqs.push_back(f - bw * scale);
                    if (f + bw * scale < nyquist) freqs.push_back(f + bw * scale);
                }
            }
        }
    }

    // Exact Nyquist boundaries
    freqs.push_back(nyquist * (1.0 - 1e-9));
    freqs.push_back(nyquist);

    // Sort frequencies monotonically
    std::sort(freqs.begin(), freqs.end());

    // Deduplicate closely spaced frequencies
    auto it = std::unique(freqs.begin(), freqs.end(), [](double a, double b) {
        if (a == 0.0 && b == 0.0) return true;
        if (a == 0.0 || b == 0.0) return false;
        return std::abs(a - b) <= 1e-7 * std::max(a, b);
    });
    freqs.erase(it, freqs.end());

    const size_t totalFreqs = freqs.size();
    result.frequencyResponse.resize(totalFreqs);

    double unwrappedPhase = 0.0;
    double prevRawPhase   = 0.0;
    bool hasPrevPhase     = false;

    for (size_t i = 0; i < totalFreqs; ++i) {
        const double freq = freqs[i];
        const double omega = 2.0 * PI * freq / sampleRate;

        // z = e^{jω} on unit circle
        const Complex z    = std::polar(1.0, omega);
        const Complex zInv = 1.0 / z;
        const Complex zInv2 = zInv * zInv;

        const Complex H = coeff.evaluate(omega);
        const double mag = std::abs(H);
        double magDb = -300.0;
        if (mag > 1e-15) {
            magDb = 20.0 * std::log10(mag);
            if (magDb < -300.0) magDb = -300.0;
            if (magDb > 100.0)  magDb = 100.0;
        }

        // Smooth continuous phase unwrapping across frequency sweep
        // For zeros on unit circle (transmission nulls), evaluate slightly inside (|z|=1-1e-4)
        // to bypass the branch cut singularity and avoid numerical random noise jumps
        double rawPhase = 0.0;
        if (mag > 1e-14) {
            rawPhase = std::arg(H);
        } else {
            rawPhase = std::arg(evaluateRegularized(coeff, omega));
        }

        if (!hasPrevPhase) {
            unwrappedPhase = rawPhase;
            hasPrevPhase = true;
        } else {
            double dP = rawPhase - prevRawPhase;
            while (dP > PI)  dP -= 2.0 * PI;
            while (dP < -PI) dP += 2.0 * PI;
            unwrappedPhase += dP;
        }
        prevRawPhase = rawPhase;
        const double phaseDeg = unwrappedPhase * 180.0 / PI;

        // Exact analytical group delay: \tau_g(\omega) = \sum \tau_{g,k}(\omega)
        // Edge cases: zeros or poles on or very close to unit circle cause division by zero.
        // We apply Poisson regularization (evaluating with r = 1 - 1e-4) when denominator < 1e-4.
        double totalGd = coeff.isFir() ? firGroupDelay(coeff, omega)
                                       : sosGroupDelay(coeff, zInv, zInv2);

        if (!std::isfinite(totalGd))
            totalGd = 0.0;

        result.frequencyResponse[i] = { freq, magDb, phaseDeg, totalGd };
    }

    result.impulseResponse = impulseResponse(coeff, 512);
    result.stepResponse    = stepResponse(coeff, 512);

    return result;
}

AnalysisPoint FilterAnalysis::evaluatePoint(const FilterCoefficients& coeff,
                                           double sampleRate,
                                           double freqHz) {
    if (!coeff.isValid() || sampleRate <= 0.0) {
        return { 0.0, 0.0, 0.0, 0.0 };
    }
    const double nyquist = sampleRate / 2.0;
    const double clampedF = std::clamp(freqHz, 0.0, nyquist);
    const double omega = 2.0 * PI * clampedF / sampleRate;

    const Complex z = std::polar(1.0, omega);
    const Complex zInv = 1.0 / z;
    const Complex zInv2 = zInv * zInv;

    const Complex H = coeff.evaluate(omega);
    const double mag = std::abs(H);
    double magDb = -300.0;
    if (mag > 1e-15) {
        magDb = 20.0 * std::log10(mag);
        if (magDb < -300.0) magDb = -300.0;
        if (magDb > 100.0)  magDb = 100.0;
    }

    double phaseDeg = 0.0;
    if (mag > 1e-14) {
        phaseDeg = std::arg(H) * 180.0 / PI;
    } else {
        phaseDeg = std::arg(evaluateRegularized(coeff, omega)) * 180.0 / PI;
    }

    double totalGd = coeff.isFir() ? firGroupDelay(coeff, omega)
                                   : sosGroupDelay(coeff, zInv, zInv2);

    if (std::isnan(totalGd) || std::isinf(totalGd)) {
        totalGd = 0.0;
    } else {
        // Preserve finite group-delay peaks; artificial clipping distorts plots.
    }

    return { clampedF, magDb, phaseDeg, totalGd };
}

std::vector<double> FilterAnalysis::impulseResponse(const FilterCoefficients& coeff, int length) {
    if (length < 32) length = 32;
    if (coeff.isFir()) {
        std::vector<double> out(length, 0.0);
        for (size_t n = 0; n < coeff.fir.size() && n < out.size(); ++n)
            out[n] = coeff.gain * coeff.fir[n];
        return out;
    }
    std::vector<std::array<double,2>> state(coeff.sos.size(), {0.0, 0.0});
    std::vector<double> out(length);
    for (int i = 0; i < length; ++i) {
        double val = biquadProcess(coeff, state, i == 0 ? 1.0 : 0.0);
        if (std::isnan(val) || std::isinf(val)) val = 0.0;
        out[i] = val;
    }
    return out;
}

std::vector<double> FilterAnalysis::stepResponse(const FilterCoefficients& coeff, int length) {
    if (length < 32) length = 32;
    if (coeff.isFir()) {
        std::vector<double> out(length, 0.0);
        double acc = 0.0;
        for (size_t n = 0; n < out.size(); ++n) {
            if (n < coeff.fir.size()) acc += coeff.gain * coeff.fir[n];
            out[n] = acc;
        }
        return out;
    }
    std::vector<std::array<double,2>> state(coeff.sos.size(), {0.0, 0.0});
    std::vector<double> out(length);
    for (int i = 0; i < length; ++i) {
        double val = biquadProcess(coeff, state, 1.0);
        if (std::isnan(val) || std::isinf(val)) val = 0.0;
        out[i] = val;
    }
    return out;
}

// FIR designs are always stable (all poles at z = 0), so verification checks
// linear-phase symmetry, Parseval energy, the tap-domain reference model and
// the -6 dB windowed-sinc band edges instead of the SOS/ZPK cross-checks.
static VerificationResult verifyFir(const FilterSpec& spec,
                                    const FilterCoefficients& coeff,
                                    const AnalysisResult& analysis) {
    VerificationResult res;
    const auto& h = coeff.fir;
    const size_t taps = h.size();

    bool finite = std::isfinite(coeff.gain) && std::isfinite(spec.sampleRate) &&
                  spec.sampleRate > 0.0 && !analysis.frequencyResponse.empty() &&
                  !analysis.impulseResponse.empty() && !analysis.stepResponse.empty();
    for (double v : h) finite = finite && std::isfinite(v);
    for (const auto& pt : analysis.frequencyResponse)
        finite = finite && std::isfinite(pt.frequency) && std::isfinite(pt.magnitude) &&
                 std::isfinite(pt.phase) && std::isfinite(pt.groupDelay);
    if (!finite) {
        res.passed = res.stage1Passed = res.stage2Passed = false;
        res.poleUnitCircleOk = false;
        res.referenceModelVerified = false;
        res.stage1Details += "[FAIL] Numerical Breakdown: FIR taps or response contain NaN / Infinity.\n";
        res.summary = "Verification Failed: Numerical Instability Detected";
        return res;
    }

    // ── STAGE 1: Structural audit ─────────────────────────────────────────
    res.maxPoleRadius = 0.0;
    res.stabilityMargin = 1.0;
    res.poleUnitCircleOk = true;
    res.stage1Details += "[PASS] FIR is unconditionally stable: all " + std::to_string(coeff.poles.size()) +
                         " poles at z = 0.\n";

    double maxAsym = 0.0;
    for (size_t n = 0; n < taps; ++n)
        maxAsym = std::max(maxAsym, std::abs(h[n] - h[taps - 1 - n]));
    res.conjugateSymmetryOk = maxAsym <= 1e-12;
    if (res.conjugateSymmetryOk) {
        res.stage1Details += "[PASS] Linear Phase: taps are symmetric (max asymmetry " +
                             std::to_string(maxAsym) + ").\n";
    } else {
        res.stage1Passed = false;
        res.stage1Details += "[FAIL] Linear Phase: tap symmetry violated by " + std::to_string(maxAsym) + ".\n";
    }

    double tapSum = 0.0;
    for (double v : h) tapSum += v;
    res.dcGainError = std::abs(coeff.evaluate(0.0) - Complex{coeff.gain * tapSum, 0.0});
    if (res.dcGainError > 1e-9) {
        res.stage1Passed = false;
        res.stage1Details += "[FAIL] DC gain disagrees with tap sum by " + std::to_string(res.dcGainError) + ".\n";
    } else {
        res.stage1Details += "[PASS] DC gain equals tap sum (error " + std::to_string(res.dcGainError) + ").\n";
    }

    // ── STAGE 2: Parseval energy, BIBO and reference model ────────────────
    // Parseval: integral_0^{fs/2} |H(f)|^2 df = (fs / 2) * sum h[n]^2
    double plottedEnergy = 0.0;
    const auto& fr = analysis.frequencyResponse;
    for (size_t i = 0; i + 1 < fr.size(); ++i) {
        const double mag1 = std::pow(10.0, fr[i].magnitude / 20.0);
        const double mag2 = std::pow(10.0, fr[i + 1].magnitude / 20.0);
        plottedEnergy += 0.5 * (mag1 * mag1 + mag2 * mag2) * (fr[i + 1].frequency - fr[i].frequency);
    }
    double tapEnergy = 0.0;
    for (double v : h) tapEnergy += v * v;
    tapEnergy *= coeff.gain * coeff.gain * spec.sampleRate * 0.5;
    res.parsevalEnergyError = tapEnergy > 1e-20 ? std::abs(plottedEnergy - tapEnergy) / tapEnergy : 0.0;
    res.parsevalEnergyOk = res.parsevalEnergyError <= 0.02;
    if (res.parsevalEnergyOk) {
        res.stage2Details += "[PASS] Parseval Energy Error: " + std::to_string(res.parsevalEnergyError) + ".\n";
    } else {
        res.stage2Passed = false;
        res.stage2Details += "[FAIL] Parseval Energy Error: " + std::to_string(res.parsevalEnergyError * 100.0) + "%\n";
    }

    double maxStepPeak = 0.0;
    for (double s : analysis.stepResponse) maxStepPeak = std::max(maxStepPeak, std::abs(s));
    res.maxTransientPeak = maxStepPeak;
    res.biboStabilityOk = true;
    res.stage2Details += "[PASS] BIBO Transient Peak: " + std::to_string(maxStepPeak) + " (Bounded).\n";

    // Reference: long-double DFT of the taps and the ideal N/2 linear-phase delay
    const double expectedDelay = static_cast<double>(taps - 1) / 2.0;
    int matchedPts = 0;
    double maxMagErrDb = 0.0, maxPhaseErrDeg = 0.0, maxGdErr = 0.0;
    for (const auto& pt : fr) {
        const long double omega = 2.0L * static_cast<long double>(PI) * pt.frequency / spec.sampleRate;
        std::complex<long double> ref{0.0L, 0.0L};
        for (size_t n = 0; n < taps; ++n) {
            const long double phase = omega * static_cast<long double>(n);
            ref += static_cast<long double>(h[n]) * std::complex<long double>{std::cos(phase), -std::sin(phase)};
        }
        ref *= static_cast<long double>(coeff.gain);
        const double refAbs = static_cast<double>(std::abs(ref));
        const double refDb = refAbs > 1e-15 ? std::clamp(20.0 * std::log10(refAbs), -300.0, 100.0) : -300.0;
        double errDb = std::abs(pt.magnitude - refDb);
        if (pt.magnitude < -80.0 && refDb < -80.0) errDb = 0.0;
        maxMagErrDb = std::max(maxMagErrDb, errDb);
        if (errDb <= 0.05) ++matchedPts;

        const Complex Hs = coeff.evaluate(static_cast<double>(omega));
        if (refAbs > 1e-6 && std::abs(Hs) > 1e-6) {
            const double phaseErr = std::abs(std::remainder(
                static_cast<double>(std::arg(ref)) - std::arg(Hs), 2.0 * PI)) * 180.0 / PI;
            maxPhaseErrDeg = std::max(maxPhaseErrDeg, phaseErr);
        }
        if (res.conjugateSymmetryOk && refAbs > 1e-3)
            maxGdErr = std::max(maxGdErr, std::abs(pt.groupDelay - expectedDelay) / std::max(1.0, expectedDelay));
    }

    double maxImpulseErr = 0.0;
    for (size_t n = 0; n < analysis.impulseResponse.size(); ++n) {
        const double expected = n < taps ? coeff.gain * h[n] : 0.0;
        maxImpulseErr = std::max(maxImpulseErr, std::abs(analysis.impulseResponse[n] - expected));
    }

    const int totalPts = static_cast<int>(fr.size());
    res.totalPoints = totalPts;
    res.matchedPoints = matchedPts;
    res.maxPointMagnitudeErrorDb = maxMagErrDb;
    res.maxPointPhaseErrorDeg = maxPhaseErrDeg;
    res.maxGroupDelayRelativeError = maxGdErr;
    res.maxImpulseError = maxImpulseErr;
    res.referenceModelVerified = totalPts > 0 && matchedPts == totalPts && maxMagErrDb <= 1e-3 &&
                                 maxPhaseErrDeg <= 1e-3 && maxGdErr <= 1e-6 && maxImpulseErr <= 1e-12;
    if (res.referenceModelVerified) {
        res.stage2Details += "[PASS] Reference Model Compliance: 100% matched (" + std::to_string(matchedPts) + "/" +
                             std::to_string(totalPts) + " points; group delay = " +
                             std::to_string(expectedDelay) + " samples).\n";
    } else {
        res.stage2Passed = false;
        res.stage2Details += "[FAIL] Reference Model Discrepancy: Max error = " + std::to_string(maxMagErrDb) +
                             " dB (" + std::to_string(matchedPts) + "/" + std::to_string(totalPts) +
                             " points matched; group-delay relative error " + std::to_string(maxGdErr) + ").\n";
    }

    // Windowed-sinc band edges sit at half amplitude (-6.02 dB)
    const double expectedEdgeDb = -6.0205999133;
    const double edges[] = {spec.cutoffFreq, spec.cutoffFreq2};
    const int edgeCount = (spec.type == FilterType::BandPass || spec.type == FilterType::BandStop) ? 2 : 1;
    double maxSpecErrDb = 0.0;
    for (int i = 0; i < edgeCount; ++i) {
        const double mag = std::abs(coeff.evaluate(2.0 * PI * edges[i] / spec.sampleRate));
        const double measured = mag > 1e-15 ? 20.0 * std::log10(mag) : -300.0;
        maxSpecErrDb = std::max(maxSpecErrDb, std::abs(measured - expectedEdgeDb));
    }
    res.maxSpecificationErrorDb = maxSpecErrDb;
    res.specificationOk = maxSpecErrDb <= 1.0;
    if (res.specificationOk) {
        res.stage2Details += "[PASS] FIR band edges are within 1 dB of the -6.02 dB windowed-sinc target.\n";
    } else {
        res.stage2Passed = false;
        res.stage2Details += "[FAIL] FIR band edges miss the -6.02 dB target by " + std::to_string(maxSpecErrDb) +
                             " dB (increase the order to sharpen the transition band).\n";
    }

    res.passed = res.stage1Passed && res.stage2Passed && res.specificationOk;
    res.summary = res.passed ? "Filter Design Verified Successfully without Errors"
                             : "Verification Flagged Mathematical Anomalies";
    return res;
}

VerificationResult FilterAnalysis::verify(const FilterSpec& spec,
                                          const FilterCoefficients& coeff,
                                          const AnalysisResult& analysis) {
    if (coeff.isFir())
        return verifyFir(spec, coeff, analysis);

    VerificationResult res;
    res.stage1Passed = true;
    res.stage2Passed = true;

    // ── STAGE 0: Strict Numerical Sanity Check ──────────────────────────────
    bool hasNanOrInf = false;
    if (!coeff.isValid() || spec.order < 1 || !std::isfinite(spec.sampleRate) ||
        spec.sampleRate <= 0.0 || analysis.frequencyResponse.empty() ||
        analysis.impulseResponse.empty() || analysis.stepResponse.empty() ||
        coeff.poles.size() != static_cast<size_t>(spec.order) *
            ((spec.type == FilterType::BandPass || spec.type == FilterType::BandStop) ? 2 : 1) ||
        coeff.zeros.size() != coeff.poles.size() ||
        !std::isfinite(coeff.gain)) hasNanOrInf = true;
    for (const auto& p : coeff.poles) {
        if (std::isnan(p.real()) || std::isnan(p.imag()) || std::isinf(p.real()) || std::isinf(p.imag())) {
            hasNanOrInf = true;
        }
    }
    for (const auto& z : coeff.zeros) {
        if (std::isnan(z.real()) || std::isnan(z.imag()) || std::isinf(z.real()) || std::isinf(z.imag())) {
            hasNanOrInf = true;
        }
    }
    for (const auto& s : coeff.sos) {
        if (std::isnan(s.b0) || std::isnan(s.b1) || std::isnan(s.b2) ||
            std::isnan(s.a1) || std::isnan(s.a2) ||
            std::isinf(s.b0) || std::isinf(s.b1) || std::isinf(s.b2) ||
            std::isinf(s.a1) || std::isinf(s.a2)) {
            hasNanOrInf = true;
        }
    }
    for (const auto& pt : analysis.frequencyResponse) {
        if (!std::isfinite(pt.frequency) || !std::isfinite(pt.magnitude) ||
            !std::isfinite(pt.phase) || !std::isfinite(pt.groupDelay))
            hasNanOrInf = true;
    }

    if (hasNanOrInf) {
        res.passed = false;
        res.stage1Passed = false;
        res.stage2Passed = false;
        res.poleUnitCircleOk = false;
        res.referenceModelVerified = false;
        res.stage1Details += "[FAIL] Numerical Breakdown: Filter coefficients or poles contain NaN / Infinity.\n";
        res.summary = "Verification Failed: Numerical Instability Detected";
        return res;
    }

    // ── STAGE 1: Analytical & Structural Pole-Zero Audit ─────────────────────
    double maxR = 0.0;
    for (const auto& p : coeff.poles) {
        double r = std::abs(p);
        if (r > maxR) maxR = r;
    }
    res.maxPoleRadius = maxR;
    res.stabilityMargin = std::max(0.0, 1.0 - maxR);

    if (std::isnan(maxR) || maxR >= 1.0) {
        res.poleUnitCircleOk = false;
        res.stage1Passed = false;
        res.stage1Details += "[FAIL] Pole Instability: Max pole radius |p| = " + std::to_string(maxR) + " >= 1.0.\n";
    } else {
        res.poleUnitCircleOk = true;
        res.stage1Details += "[PASS] Stability Margin: " + std::to_string(res.stabilityMargin) + " (|p_max| = " + std::to_string(maxR) + ").\n";
    }

    // Check Conjugate Pair Symmetry
    bool symOk = true;
    for (size_t i = 0; i < coeff.poles.size(); ++i) {
        const auto& p = coeff.poles[i];
        if (std::abs(p.imag()) > 1e-8) {
            bool foundConj = false;
            for (size_t j = 0; j < coeff.poles.size(); ++j) {
                if (i == j) continue;
                if (std::abs(p.real() - coeff.poles[j].real()) < 1e-6 &&
                    std::abs(p.imag() + coeff.poles[j].imag()) < 1e-6) {
                    foundConj = true;
                    break;
                }
            }
            if (!foundConj) { symOk = false; break; }
        }
    }
    res.conjugateSymmetryOk = symOk;
    if (!symOk) {
        res.stage1Passed = false;
        res.stage1Details += "[FAIL] Pole Conjugate Symmetry Violated.\n";
    } else {
        res.stage1Details += "[PASS] Conjugate Symmetry: 100% Conjugate Pairs Verified.\n";
    }

    Complex dcRootNumerator{coeff.gain, 0.0};
    Complex dcRootDenominator{1.0, 0.0};
    for (const auto& zero : coeff.zeros) dcRootNumerator *= (Complex{1.0, 0.0} - zero);
    for (const auto& pole : coeff.poles) dcRootDenominator *= (Complex{1.0, 0.0} - pole);
    Complex dcRoot = std::abs(dcRootDenominator) > 1e-300
        ? dcRootNumerator / dcRootDenominator : Complex{};
    const Complex dcH = coeff.evaluate(0.0);
    res.dcGainError = std::abs(dcH - dcRoot);
    if (!std::isfinite(res.dcGainError) || res.dcGainError > 1e-7) {
        res.stage1Passed = false;
        res.stage1Details += "[FAIL] SOS and pole-zero DC gains disagree by " +
                             std::to_string(res.dcGainError) + ".\n";
    } else {
        res.stage1Details += "[PASS] SOS and pole-zero DC gains agree (error " +
                             std::to_string(res.dcGainError) + ").\n";
    }

    bool zeroSymmetryOk = true;
    for (size_t i = 0; i < coeff.zeros.size() && zeroSymmetryOk; ++i) {
        const auto& zero = coeff.zeros[i];
        if (std::abs(zero.imag()) <= 1e-8) continue;
        bool foundConjugate = false;
        for (size_t j = 0; j < coeff.zeros.size(); ++j) {
            if (i != j && std::abs(zero.real() - coeff.zeros[j].real()) < 1e-6 &&
                std::abs(zero.imag() + coeff.zeros[j].imag()) < 1e-6) {
                foundConjugate = true;
                break;
            }
        }
        zeroSymmetryOk = foundConjugate;
    }
    if (!zeroSymmetryOk) {
        res.stage1Passed = false;
        res.stage1Details += "[FAIL] Zero Conjugate Symmetry Violated.\n";
    }

    // ── STAGE 2: Time-Domain & Numerical Precision Audit ──────────────────────
    double plottedEnergy = 0.0;
    const auto& fr = analysis.frequencyResponse;
    if (fr.size() >= 2) {
        for (size_t i = 0; i + 1 < fr.size(); ++i) {
            double df = fr[i + 1].frequency - fr[i].frequency;
            double mag1 = std::pow(10.0, fr[i].magnitude / 20.0);
            double mag2 = std::pow(10.0, fr[i + 1].magnitude / 20.0);
            double avgH2 = 0.5 * (mag1 * mag1 + mag2 * mag2);
            plottedEnergy += avgH2 * df;
        }
    }

    // Validate the plotted nonuniform grid against an independent dense
    // uniform-frequency quadrature. A short impulse truncation is not a valid
    // Parseval reference for very high-Q filters.
    constexpr int quadraturePoints = 65536;
    const double nyquist = spec.sampleRate * 0.5;
    std::vector<double> quadratureFrequencies;
    quadratureFrequencies.reserve(quadraturePoints + coeff.poles.size() * 38);
    for (int i = 0; i <= quadraturePoints; ++i)
        quadratureFrequencies.push_back(nyquist * static_cast<double>(i) / quadraturePoints);
    auto addRootNeighborhood = [&](const Complex& root) {
        const double f = std::abs(std::arg(root)) * spec.sampleRate / (2.0 * PI);
        const double bw = std::max(1e-9, std::abs(1.0 - std::abs(root)) * spec.sampleRate / (2.0 * PI));
        static constexpr double scales[] = {0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0};
        if (f > 0.0 && f < nyquist) quadratureFrequencies.push_back(f);
        for (double scale : scales) {
            if (f - bw * scale > 0.0) quadratureFrequencies.push_back(f - bw * scale);
            if (f + bw * scale < nyquist) quadratureFrequencies.push_back(f + bw * scale);
        }
    };
    for (const auto& pole : coeff.poles) addRootNeighborhood(pole);
    for (const auto& zero : coeff.zeros) addRootNeighborhood(zero);
    std::sort(quadratureFrequencies.begin(), quadratureFrequencies.end());
    quadratureFrequencies.erase(std::unique(quadratureFrequencies.begin(), quadratureFrequencies.end()),
                                quadratureFrequencies.end());
    double denseEnergy = 0.0;
    double previousPower = std::norm(coeff.evaluate(0.0));
    double previousFrequency = 0.0;
    for (size_t i = 1; i < quadratureFrequencies.size(); ++i) {
        const double frequency = quadratureFrequencies[i];
        const double power = std::norm(coeff.evaluate(2.0 * PI * frequency / spec.sampleRate));
        denseEnergy += 0.5 * (previousPower + power) * (frequency - previousFrequency);
        previousPower = power;
        previousFrequency = frequency;
    }
    double parsevalErr = (denseEnergy > 1e-20)
        ? std::abs(plottedEnergy - denseEnergy) / denseEnergy : 0.0;
    res.parsevalEnergyError = parsevalErr;
    if (parsevalErr > 0.02) {
        res.parsevalEnergyOk = false;
        res.stage2Passed = false;
        res.stage2Details += "[FAIL] Frequency-Grid Integration Error: " + std::to_string(parsevalErr * 100.0) + "%\n";
    } else {
        res.parsevalEnergyOk = true;
        res.stage2Details += "[PASS] Frequency-Grid Integration Error: " + std::to_string(parsevalErr) + ".\n";
    }

    double maxStepPeak = 0.0;
    for (double s : analysis.stepResponse) {
        if (std::abs(s) > maxStepPeak) maxStepPeak = std::abs(s);
    }
    res.maxTransientPeak = maxStepPeak;
    if (maxStepPeak > 50.0 || std::isnan(maxStepPeak)) {
        res.biboStabilityOk = false;
        res.stage2Passed = false;
        res.stage2Details += "[FAIL] BIBO Transient Divergence: Step peak = " + std::to_string(maxStepPeak) + "\n";
    } else {
        res.biboStabilityOk = true;
        res.stage2Details += "[PASS] BIBO Transient Peak: " + std::to_string(maxStepPeak) + " (Bounded).\n";
    }

    // ── STAGE 3: Independent SOS/root and derivative cross-checks ───────────
    int matchedPts = 0;
    const int totalPts = static_cast<int>(analysis.frequencyResponse.size());
    double maxMagErrDb = 0.0;
    double maxPhaseErrDeg = 0.0;
    double maxGroupDelayRelativeError = 0.0;
    double maxImpulseErr = 0.0;

    // Compare the SOS implementation with the factored ZPK transfer function.
    // Also compare analytical group delay with a centered phase derivative.
    const double gdStep = 1e-6;
    for (int i = 0; i < totalPts; ++i) {
        const auto& pt = analysis.frequencyResponse[i];
        const double omega = 2.0 * PI * pt.frequency / spec.sampleRate;
        using LongComplex = std::complex<long double>;
        const LongComplex zInv{std::cos(static_cast<long double>(omega)),
                               -std::sin(static_cast<long double>(omega))};

        LongComplex refNum{1.0L, 0.0L};
        for (const auto& zk : coeff.zeros) {
            refNum *= LongComplex{1.0L, 0.0L} - LongComplex{zk.real(), zk.imag()} * zInv;
        }

        LongComplex refDen{1.0L, 0.0L};
        for (const auto& pk : coeff.poles) {
            refDen *= LongComplex{1.0L, 0.0L} - LongComplex{pk.real(), pk.imag()} * zInv;
        }

        LongComplex H_ref{0.0L, 0.0L};
        if (std::abs(refDen) > 1e-300L) {
            H_ref = (refNum / refDen) * static_cast<long double>(coeff.gain);
        }

        double refMagDb = -300.0;
        const double refMagAbs = static_cast<double>(std::abs(H_ref));
        if (refMagAbs > 1e-15) {
            refMagDb = 20.0 * std::log10(refMagAbs);
            if (refMagDb < -300.0) refMagDb = -300.0;
            if (refMagDb > 100.0) refMagDb = 100.0;
        }

        double errDb = std::abs(pt.magnitude - refMagDb);
        if (pt.magnitude < -80.0 && refMagDb < -80.0)
            errDb = 0.0;
        const double sosPhase = std::arg(coeff.evaluate(omega));
        if (refMagAbs > 1e-6 && std::abs(coeff.evaluate(omega)) > 1e-6) {
            const double phaseErr = std::abs(std::remainder(static_cast<double>(std::arg(H_ref)) - sosPhase, 2.0 * PI)) * 180.0 / PI;
            maxPhaseErrDeg = std::max(maxPhaseErrDeg, phaseErr);
        }

        if (pt.frequency > 0.0 && pt.frequency < spec.sampleRate / 2.0 && refMagAbs > 1e-4) {
            double localScale = 1.0;
            for (const auto& root : coeff.poles) {
                const double angularDistance = std::abs(std::remainder(omega - std::arg(root), 2.0 * PI));
                localScale = std::min(localScale, std::hypot(angularDistance, 1.0 - std::abs(root)));
            }
            for (const auto& root : coeff.zeros) {
                const double angularDistance = std::abs(std::remainder(omega - std::arg(root), 2.0 * PI));
                localScale = std::min(localScale, std::hypot(angularDistance, std::abs(1.0 - std::abs(root))));
            }
            const double h = std::min(gdStep, std::max(1e-11, localScale * 0.01));
            if (std::abs(coeff.evaluate(omega - h)) > 1e-8 &&
                std::abs(coeff.evaluate(omega + h)) > 1e-8) {
                const double phaseBefore = std::arg(coeff.evaluate(omega - h));
                const double phaseAfter = std::arg(coeff.evaluate(omega + h));
                const double phaseDelta = std::remainder(phaseAfter - phaseBefore, 2.0 * PI);
                const double numericGd = -phaseDelta / (2.0 * h);
                const double relativeError = std::abs(pt.groupDelay - numericGd) /
                                             std::max(1.0, std::abs(numericGd));
                maxGroupDelayRelativeError = std::max(maxGroupDelayRelativeError, relativeError);
            }
        }

        if (errDb > maxMagErrDb) maxMagErrDb = errDb;

        // Tolerance: within 0.05 dB
        if (errDb <= 0.05) {
            matchedPts++;
        }
    }

    // Compute each section impulse independently, then convolve the sections.
    std::vector<double> referenceImpulse(analysis.impulseResponse.size(), 0.0);
    if (!referenceImpulse.empty()) referenceImpulse[0] = coeff.gain;
    for (const auto& s : coeff.sos) {
        std::vector<double> sectionImpulse(referenceImpulse.size(), 0.0);
        for (size_t n = 0; n < sectionImpulse.size(); ++n) {
            const double input = n == 0 ? 1.0 : 0.0;
            const double x1 = n >= 1 ? (n == 1 ? 1.0 : 0.0) : 0.0;
            const double x2 = n == 2 ? 1.0 : 0.0;
            const double y1 = n >= 1 ? sectionImpulse[n - 1] : 0.0;
            const double y2 = n >= 2 ? sectionImpulse[n - 2] : 0.0;
            sectionImpulse[n] = s.b0 * input + s.b1 * x1 + s.b2 * x2 - s.a1 * y1 - s.a2 * y2;
        }
        std::vector<double> next(referenceImpulse.size(), 0.0);
        for (size_t i = 0; i < referenceImpulse.size(); ++i)
            for (size_t j = 0; j + i < referenceImpulse.size(); ++j)
                next[i + j] += referenceImpulse[i] * sectionImpulse[j];
        referenceImpulse = std::move(next);
    }
    for (size_t n = 0; n < referenceImpulse.size(); ++n)
        maxImpulseErr = std::max(maxImpulseErr,
                                 std::abs(referenceImpulse[n] - analysis.impulseResponse[n]));

    res.totalPoints = totalPts;
    res.matchedPoints = matchedPts;
    res.maxPointMagnitudeErrorDb = maxMagErrDb;
    res.maxPointPhaseErrorDeg = maxPhaseErrDeg;
    res.maxImpulseError = maxImpulseErr;
    res.maxGroupDelayRelativeError = maxGroupDelayRelativeError;

    // Strict criterion: >= 99.5% points within 0.05 dB, max error <= 0.5 dB, and impulse drift < 1e-4
    const bool referenceOk = totalPts > 0 && matchedPts == totalPts &&
        maxMagErrDb <= 1e-3 && maxPhaseErrDeg <= 1e-3 &&
        maxGroupDelayRelativeError <= 1e-3 && maxImpulseErr <= 1e-8 &&
        parsevalErr <= 0.02;
    if (!referenceOk) {
        res.referenceModelVerified = false;
        res.stage2Passed = false;
        res.stage2Details += "[FAIL] Reference Model Discrepancy: Max error = " + std::to_string(maxMagErrDb) + " dB (" +
                             std::to_string(matchedPts) + "/" + std::to_string(totalPts) +
                             " points matched; phase " + std::to_string(maxPhaseErrDeg) +
                             " deg; group-delay relative error " + std::to_string(maxGroupDelayRelativeError) +
                             "; impulse " + std::to_string(maxImpulseErr) + ").\n";
    } else {
        res.referenceModelVerified = true;
        res.stage2Details += "[PASS] Reference Model Compliance: 100% matched (" + std::to_string(matchedPts) + "/" +
                             std::to_string(totalPts) + " points; magnitude " + std::to_string(maxMagErrDb) +
                             " dB; phase " + std::to_string(maxPhaseErrDeg) + " deg; group-delay relative error " +
                             std::to_string(maxGroupDelayRelativeError) + ").\n";
    }

    double maxSpecErrDb = 0.0;
    bool specOk = true;
    auto magnitudeDbAt = [&](double frequency) {
        const double magnitude = std::abs(coeff.evaluate(2.0 * PI * frequency / spec.sampleRate));
        return magnitude > 1e-15 ? 20.0 * std::log10(magnitude) : -300.0;
    };
    if (spec.type == FilterType::BandStop) {
        const double warpedCenter = std::sqrt(
            std::tan(PI * spec.cutoffFreq / spec.sampleRate) *
            std::tan(PI * spec.cutoffFreq2 / spec.sampleRate));
        const double centerHz = std::atan(warpedCenter) * spec.sampleRate / PI;
        const double notchDb = magnitudeDbAt(centerHz);
        specOk = std::isfinite(notchDb) && notchDb <= -40.0;
        if (!specOk)
            res.stage2Details += "[FAIL] Band-stop rejection is below 40 dB at the warped notch center.\n";
    } else {
        double expectedEdgeDb = -3.0102999566;
        if (spec.response == FilterResponse::ChebyshevI ||
            spec.response == FilterResponse::Elliptic)
            expectedEdgeDb = -spec.rippleDb;
        else if (spec.response == FilterResponse::ChebyshevII)
            expectedEdgeDb = -spec.stopbandDb;

        const double edges[] = {spec.cutoffFreq, spec.cutoffFreq2};
        const int edgeCount = spec.type == FilterType::BandPass ? 2 : 1;
        for (int i = 0; i < edgeCount; ++i) {
            const double measured = magnitudeDbAt(edges[i]);
            const double error = std::abs(measured - expectedEdgeDb);
            maxSpecErrDb = std::max(maxSpecErrDb, error);
            if (!std::isfinite(measured) || error > 0.1)
                specOk = false;
        }
        if (!specOk) {
            res.stage2Details += "[FAIL] Critical-frequency response misses its " +
                std::to_string(expectedEdgeDb) + " dB edge target by " +
                std::to_string(maxSpecErrDb) + " dB.\n";
        }
    }
    res.specificationOk = specOk;
    res.maxSpecificationErrorDb = maxSpecErrDb;
    if (specOk)
        res.stage2Details += "[PASS] Filter-family cutoff/stopband requirements are met.\n";
    else
        res.stage2Passed = false;

    res.passed = res.stage1Passed && res.stage2Passed && res.specificationOk;
    if (res.passed) {
        res.summary = "Filter Design Verified Successfully without Errors";
    } else {
        res.summary = "Verification Flagged Mathematical Anomalies";
    }

    return res;
}

} // namespace dsp
