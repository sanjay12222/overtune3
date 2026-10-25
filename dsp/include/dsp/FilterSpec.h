#pragma once
#include <cstdint>
#include <string>

namespace dsp {

enum class FilterType {
    LowPass,
    HighPass,
    BandPass,
    BandStop
};

enum class FilterResponse {
    Butterworth,
    ChebyshevI,
    ChebyshevII,
    Elliptic,
    Bessel,
    FIR          // Linear-phase windowed-sinc FIR
};

enum class FirWindow {
    Rectangular,
    Hann,
    Hamming,
    Blackman,
    Kaiser       // beta derived from stopbandDb
};

struct FilterSpec {
    FilterType     type     = FilterType::LowPass;
    FilterResponse response = FilterResponse::Butterworth;
    int            order    = 4;
    double         sampleRate = 48000.0;   // Hz
    double         cutoffFreq = 1000.0;    // Hz  (LPF / HPF)
    double         cutoffFreq2 = 2000.0;   // Hz  (BPF / BSF upper)
    double         rippleDb  = 1.0;        // Chebyshev / Elliptic passband ripple
    double         stopbandDb = 60.0;      // Elliptic stopband attenuation / Kaiser FIR target
    FirWindow      firWindow = FirWindow::Hamming; // FIR window function

    [[nodiscard]] std::string typeName()     const noexcept;
    [[nodiscard]] std::string responseName() const noexcept;
    [[nodiscard]] std::string windowName()   const noexcept;
    [[nodiscard]] bool        isFir()        const noexcept { return response == FilterResponse::FIR; }
};

} // namespace dsp
