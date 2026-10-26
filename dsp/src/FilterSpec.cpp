#include "dsp/FilterSpec.h"
#include <cmath>
#include <iomanip>
#include <sstream>

namespace dsp {

std::string FilterSpec::typeName() const noexcept {
    switch (type) {
        case FilterType::LowPass:  return "Low Pass";
        case FilterType::HighPass: return "High Pass";
        case FilterType::BandPass: return "Band Pass";
        case FilterType::BandStop: return "Band Stop";
    }
    return "Unknown";
}

std::string FilterSpec::responseName() const noexcept {
    switch (response) {
        case FilterResponse::Butterworth:  return "Butterworth";
        case FilterResponse::ChebyshevI:   return "Chebyshev I";
        case FilterResponse::ChebyshevII:  return "Chebyshev II";
        case FilterResponse::Elliptic:     return "Elliptic";
        case FilterResponse::Bessel:       return "Bessel";
        case FilterResponse::FIR:          return "FIR";
    }
    return "Unknown";
}

std::string FilterSpec::windowName() const noexcept {
    switch (firWindow) {
        case FirWindow::Rectangular: return "Rectangular";
        case FirWindow::Hann:        return "Hann";
        case FirWindow::Hamming:     return "Hamming";
        case FirWindow::Blackman:    return "Blackman";
        case FirWindow::Kaiser:      return "Kaiser";
        case FirWindow::Bartlett:        return "Bartlett";
        case FirWindow::BartlettHann:    return "Bartlett-Hann";
        case FirWindow::BlackmanHarris:  return "Blackman-Harris";
        case FirWindow::Nuttall:         return "Nuttall";
        case FirWindow::BlackmanNuttall: return "Blackman-Nuttall";
        case FirWindow::FlatTop:         return "Flat Top";
        case FirWindow::Gaussian:        return "Gaussian";
        case FirWindow::Tukey:           return "Tukey";
        case FirWindow::Lanczos:         return "Lanczos";
        case FirWindow::Cosine:          return "Cosine";
        case FirWindow::DolphChebyshev:  return "Dolph-Chebyshev";
    }
    return "Unknown";
}

double FilterSpec::kaiserBeta() const noexcept {
    // Kaiser's empirical formula for the desired stopband attenuation
    if (stopbandDb > 50.0) return 0.1102 * (stopbandDb - 8.7);
    if (stopbandDb >= 21.0) return 0.5842 * std::pow(stopbandDb - 21.0, 0.4) + 0.07886 * (stopbandDb - 21.0);
    return 0.0;
}

bool FilterSpec::windowUsesParam() const noexcept {
    return firWindow == FirWindow::Gaussian || firWindow == FirWindow::Tukey;
}

bool FilterSpec::windowUsesAtten() const noexcept {
    return firWindow == FirWindow::Kaiser || firWindow == FirWindow::DolphChebyshev;
}

std::string FilterSpec::windowLabel() const {
    std::ostringstream ss;
    ss << std::setprecision(3) << windowName();
    if (firWindow == FirWindow::Kaiser)              ss << " (beta " << kaiserBeta() << ")";
    else if (firWindow == FirWindow::Gaussian)       ss << " (sigma " << firWindowParam << ")";
    else if (firWindow == FirWindow::Tukey)          ss << " (alpha " << firWindowParam << ")";
    else if (firWindow == FirWindow::DolphChebyshev) ss << " (" << stopbandDb << " dB sidelobes)";
    return ss.str();
}

} // namespace dsp
