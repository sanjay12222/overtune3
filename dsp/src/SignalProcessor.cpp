#include "dsp/SignalProcessor.h"
#include <algorithm>

namespace dsp {

std::vector<double> SignalProcessor::process(const FilterCoefficients& coeff,
                                              const std::vector<double>& input) {
    SignalProcessor sp;
    sp.setCoefficients(coeff);
    std::vector<double> out;
    out.reserve(input.size());
    for (double s : input)
        out.push_back(sp.processSample(s));
    return out;
}

void SignalProcessor::reset() {
    for (auto& s : m_state) s = {};
    std::fill(m_firHistory.begin(), m_firHistory.end(), 0.0);
    m_firPos = 0;
}

void SignalProcessor::setCoefficients(const FilterCoefficients& coeff) {
    m_coeff = coeff;
    m_state.assign(coeff.sos.size(), {});
    m_firHistory.assign(coeff.fir.size(), 0.0);
    m_firPos = 0;
}

double SignalProcessor::processSample(double x) {
    if (m_coeff.isFir()) {
        // Direct-form FIR convolution over a circular delay line
        const size_t taps = m_coeff.fir.size();
        m_firHistory[m_firPos] = x;
        double acc = 0.0;
        size_t idx = m_firPos;
        for (size_t k = 0; k < taps; ++k) {
            acc += m_coeff.fir[k] * m_firHistory[idx];
            idx = (idx == 0) ? taps - 1 : idx - 1;
        }
        m_firPos = (m_firPos + 1) % taps;
        return acc * m_coeff.gain;
    }
    // Direct Form II Transposed biquad cascade
    double y = x * m_coeff.gain;
    for (size_t i = 0; i < m_coeff.sos.size(); ++i) {
        const auto& s = m_coeff.sos[i];
        const double w   = y - s.a1 * m_state[i].x1 - s.a2 * m_state[i].x2;
        const double out = s.b0 * w + s.b1 * m_state[i].x1 + s.b2 * m_state[i].x2;
        m_state[i].x2 = m_state[i].x1;
        m_state[i].x1 = w;
        y = out;
    }
    return y;
}

} // namespace dsp
