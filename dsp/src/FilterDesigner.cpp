#include "dsp/FilterCoefficients.h"
#include "Butterworth.h"
#include "Chebyshev.h"
#include "Elliptic.h"
#include "Bessel.h"
#include "Fir.h"
#include "dsp/FilterSpec.h"
#include <cmath>
#include <stdexcept>

// Factory function: dispatch to the correct designer based on FilterSpec
namespace dsp {

FilterCoefficients designFilter(const FilterSpec& spec) {
    if (spec.response == FilterResponse::FIR) {
        if (spec.order < 1 || spec.order > 256)
            throw std::invalid_argument("FIR filter order must be between 1 and 256");
    } else if (spec.order < 1 || spec.order > 16) {
        throw std::invalid_argument("Filter order must be between 1 and 16");
    }
    if (spec.response == FilterResponse::Bessel && spec.order > 10)
        throw std::invalid_argument("Bessel filter order must be between 1 and 10");
    if (!std::isfinite(spec.sampleRate) || spec.sampleRate <= 0.0 ||
        !std::isfinite(spec.cutoffFreq) || spec.cutoffFreq <= 0.0 ||
        spec.cutoffFreq >= spec.sampleRate / 2.0)
        throw std::invalid_argument("Sample rate and cutoff must be finite and cutoff below Nyquist");
    if (spec.type == FilterType::BandPass || spec.type == FilterType::BandStop) {
        if (!std::isfinite(spec.cutoffFreq2) || spec.cutoffFreq2 <= spec.cutoffFreq ||
            spec.cutoffFreq2 >= spec.sampleRate / 2.0)
            throw std::invalid_argument("Band filters require ordered cutoffs below Nyquist");
    }
    if ((spec.response == FilterResponse::ChebyshevI || spec.response == FilterResponse::Elliptic) &&
        (!std::isfinite(spec.rippleDb) || spec.rippleDb <= 0.0))
        throw std::invalid_argument("Passband ripple must be positive and finite");
    if ((spec.response == FilterResponse::ChebyshevII || spec.response == FilterResponse::Elliptic) &&
        (!std::isfinite(spec.stopbandDb) || spec.stopbandDb <= 0.0 ||
         (spec.response == FilterResponse::Elliptic && spec.stopbandDb <= spec.rippleDb)))
        throw std::invalid_argument("Stopband attenuation must exceed zero and exceed ripple for elliptic designs");

    switch (spec.response) {
        case FilterResponse::Butterworth:  return internal::designButterworth(spec);
        case FilterResponse::ChebyshevI:   return internal::designChebyshevI(spec);
        case FilterResponse::ChebyshevII:  return internal::designChebyshevII(spec);
        case FilterResponse::Elliptic:     return internal::designElliptic(spec);
        case FilterResponse::Bessel:       return internal::designBessel(spec);
        case FilterResponse::FIR:          return internal::designFir(spec);
    }
    return {};
}

} // namespace dsp
