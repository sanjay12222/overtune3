#pragma once
#include <complex>
#include <vector>

namespace dsp {

using Complex   = std::complex<double>;
using ComplexVec = std::vector<Complex>;

// Transfer function H(z) = B(z) / A(z), stored as SOS (Second-Order Sections)
// Each section is [b0, b1, b2, a0, a1, a2].
struct Biquad {
    double b0{1}, b1{0}, b2{0};
    double a0{1}, a1{0}, a2{0};
};

// FIR designs leave `sos` empty and store their taps h[n] in `fir` instead;
// their poles are all at the origin and `zeros` holds the roots of H(z).
struct FilterCoefficients {
    std::vector<Biquad> sos;           // Second-order sections (normalised, a0=1)
    std::vector<double> fir;           // FIR taps h[0..N] (empty for IIR designs)
    double              gain{1.0};     // Overall gain
    ComplexVec          poles;         // z-domain poles
    ComplexVec          zeros;         // z-domain zeros

    [[nodiscard]] bool  isFir()    const noexcept { return !fir.empty(); }
    [[nodiscard]] bool  isValid()  const noexcept { return !sos.empty() || !fir.empty(); }
    [[nodiscard]] int   order()    const noexcept { return static_cast<int>(poles.size()); }

    // Evaluate H(z) at a given normalised digital frequency ω ∈ [0, π]
    [[nodiscard]] Complex evaluate(double omega) const noexcept;
};

} // namespace dsp
