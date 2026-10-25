#pragma once
#include "dsp/FilterCoefficients.h"
#include <vector>

namespace dsp {

class SignalProcessor {
public:
    // Apply the filter to a block of samples
    static std::vector<double> process(const FilterCoefficients& coeff,
                                       const std::vector<double>& input);

    // Reset internal biquad state (call before processing a new signal)
    void reset();

    // Stateful sample-by-sample processing
    void        setCoefficients(const FilterCoefficients& coeff);
    double      processSample(double sample);

private:
    struct BiquadState { double x1{}, x2{}, y1{}, y2{}; };
    std::vector<BiquadState> m_state;
    std::vector<double>      m_firHistory;   // circular delay line for FIR taps
    size_t                   m_firPos{0};
    FilterCoefficients       m_coeff;
};

} // namespace dsp
