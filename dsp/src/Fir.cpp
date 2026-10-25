#include "Fir.h"
#include <algorithm>
#include <cmath>
#include <numbers>
#include <stdexcept>

namespace dsp::internal {

static constexpr double PI = std::numbers::pi;

// Zeroth-order modified Bessel function of the first kind (power series)
static double besselI0(double x) {
    double sum = 1.0;
    double term = 1.0;
    for (int k = 1; k < 200; ++k) {
        const double r = x / (2.0 * k);
        term *= r * r;
        sum += term;
        if (term < 1e-17 * sum) break;
    }
    return sum;
}

// Kaiser beta from the desired stopband attenuation (Kaiser's empirical formula)
static double kaiserBeta(double attenDb) {
    if (attenDb > 50.0) return 0.1102 * (attenDb - 8.7);
    if (attenDb >= 21.0) return 0.5842 * std::pow(attenDb - 21.0, 0.4) + 0.07886 * (attenDb - 21.0);
    return 0.0;
}

static double windowValue(FirWindow window, int n, int order, double beta) {
    // Hann and Blackman use the (N+2) denominator so the end taps are non-zero;
    // zero end taps would shorten the filter and drop roots to infinity.
    switch (window) {
        case FirWindow::Rectangular:
            return 1.0;
        case FirWindow::Hann:
            return 0.5 - 0.5 * std::cos(2.0 * PI * (n + 1) / (order + 2));
        case FirWindow::Hamming:
            return 0.54 - 0.46 * std::cos(2.0 * PI * n / order);
        case FirWindow::Blackman: {
            const double x = 2.0 * PI * (n + 1) / (order + 2);
            return 0.42 - 0.5 * std::cos(x) + 0.08 * std::cos(2.0 * x);
        }
        case FirWindow::Kaiser: {
            const double r = 2.0 * n / order - 1.0;
            return besselI0(beta * std::sqrt(std::max(0.0, 1.0 - r * r))) / besselI0(beta);
        }
    }
    return 1.0;
}

// Ideal low-pass impulse response sampled at n, centred on alpha
static double idealLowPass(double fc, double fs, double n, double alpha) {
    const double x = n - alpha;
    const double f = 2.0 * fc / fs;
    if (std::abs(x) < 1e-12) return f;
    return std::sin(PI * f * x) / (PI * x);
}

// Roots of h[0] z^N + h[1] z^{N-1} + ... + h[N] via Aberth–Ehrlich iteration.
// Used for the pole-zero plot only; the taps remain the exact filter definition.
static ComplexVec polynomialRoots(const std::vector<double>& coeffs) {
    size_t first = 0;
    while (first < coeffs.size() && coeffs[first] == 0.0) ++first;   // roots at infinity
    size_t last = coeffs.size();
    while (last > first && coeffs[last - 1] == 0.0) --last;           // roots at the origin

    ComplexVec roots(coeffs.size() - last, Complex{0.0, 0.0});
    if (last - first < 2) return roots;

    const int degree = static_cast<int>(last - first) - 1;
    std::vector<double> c(coeffs.begin() + first, coeffs.begin() + last);
    const double lead = c[0];
    for (auto& v : c) v /= lead;

    // Start on a slightly irregular circle: perfectly symmetric starting points
    // can coincide with the symmetric root pattern of linear-phase filters.
    ComplexVec z(degree);
    for (int k = 0; k < degree; ++k)
        z[k] = std::polar(1.0 + 0.05 * k / degree, 2.0 * PI * k / degree + 0.4);

    for (int iter = 0; iter < 1000; ++iter) {
        double maxStep = 0.0;
        for (int k = 0; k < degree; ++k) {
            // Logarithmic derivative p'/p. Outside the unit circle evaluate the
            // reversed polynomial q(w) = w^n p(1/w) so Horner cannot overflow:
            // p'/p = w (n - w q'(w) / q(w)).
            Complex logDeriv;
            if (std::abs(z[k]) <= 1.0) {
                Complex p{0.0, 0.0}, dp{0.0, 0.0};
                for (double co : c) {
                    dp = dp * z[k] + p;
                    p = p * z[k] + co;
                }
                if (std::abs(p) == 0.0) continue;   // exact root
                logDeriv = dp / p;
            } else {
                const Complex w = 1.0 / z[k];
                Complex q{0.0, 0.0}, dq{0.0, 0.0};
                for (auto it = c.rbegin(); it != c.rend(); ++it) {
                    dq = dq * w + q;
                    q = q * w + *it;
                }
                if (std::abs(q) == 0.0) continue;
                logDeriv = w * (static_cast<double>(degree) - w * dq / q);
            }
            Complex repulsion{0.0, 0.0};
            for (int j = 0; j < degree; ++j)
                if (j != k && z[k] != z[j]) repulsion += 1.0 / (z[k] - z[j]);
            const Complex step = 1.0 / (logDeriv - repulsion);
            if (!std::isfinite(step.real()) || !std::isfinite(step.imag())) {
                z[k] *= std::polar(1.0 + 1e-3, 1e-2);   // nudge off the singularity
                maxStep = 1.0;
                continue;
            }
            z[k] -= step;
            maxStep = std::max(maxStep, std::abs(step) / std::max(1.0, std::abs(z[k])));
        }
        if (maxStep < 1e-14) break;
    }

    // Real-coefficient polynomial: snap near-real roots onto the real axis
    for (auto& r : z) {
        if (std::abs(r.imag()) < 1e-9 * std::max(1.0, std::abs(r))) r = {r.real(), 0.0};
        roots.push_back(r);
    }
    return roots;
}

int firEffectiveOrder(const FilterSpec& spec) noexcept {
    const bool needsEven = spec.type == FilterType::HighPass || spec.type == FilterType::BandStop;
    return (needsEven && spec.order % 2 != 0) ? spec.order + 1 : spec.order;
}

FilterCoefficients designFir(const FilterSpec& spec) {
    const int order = firEffectiveOrder(spec);
    const double alpha = order / 2.0;
    const double fs = spec.sampleRate;
    const double f1 = spec.cutoffFreq;
    const double f2 = spec.cutoffFreq2;
    const double beta = kaiserBeta(spec.stopbandDb);

    FilterCoefficients out;
    out.fir.resize(order + 1);
    for (int n = 0; n <= order; ++n) {
        const double delta = std::abs(n - alpha) < 1e-12 ? 1.0 : 0.0;
        double ideal = 0.0;
        switch (spec.type) {
            case FilterType::LowPass:  ideal = idealLowPass(f1, fs, n, alpha); break;
            case FilterType::HighPass: ideal = delta - idealLowPass(f1, fs, n, alpha); break;
            case FilterType::BandPass: ideal = idealLowPass(f2, fs, n, alpha) - idealLowPass(f1, fs, n, alpha); break;
            case FilterType::BandStop: ideal = delta - (idealLowPass(f2, fs, n, alpha) - idealLowPass(f1, fs, n, alpha)); break;
        }
        out.fir[n] = ideal * windowValue(spec.firWindow, n, order, beta);
    }

    // Normalise to unity gain at the centre of the passband
    double omegaRef = 0.0;
    if (spec.type == FilterType::HighPass) omegaRef = PI;
    else if (spec.type == FilterType::BandPass) omegaRef = PI * (f1 + f2) / fs;
    Complex href{};
    for (int n = 0; n <= order; ++n)
        href += out.fir[n] * std::polar(1.0, -omegaRef * n);
    const double refMag = std::abs(href);
    if (!std::isfinite(refMag) || refMag < 1e-12)
        throw std::runtime_error("FIR design produced a degenerate passband");
    // Taps that are zero in exact arithmetic (sinc nulls) come out as ~1e-18
    // round-off; snap them to zero so the root finder trims them instead of
    // producing spurious roots near infinity.
    double peak = 0.0;
    for (auto& h : out.fir) {
        h /= refMag;
        peak = std::max(peak, std::abs(h));
    }
    for (auto& h : out.fir)
        if (std::abs(h) < 1e-14 * peak) h = 0.0;
    // Mirror the first half so the taps are bit-exactly symmetric (linear phase)
    for (int n = 0; n < order / 2 + 1; ++n)
        out.fir[order - n] = out.fir[n];

    out.gain = 1.0;
    out.poles.assign(order, Complex{0.0, 0.0});
    out.zeros = polynomialRoots(out.fir);
    return out;
}

} // namespace dsp::internal
