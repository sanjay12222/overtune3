#pragma once
// Internal header — not part of the public API
#include "dsp/FilterCoefficients.h"
#include "dsp/FilterSpec.h"

namespace dsp::internal {

// Linear-phase (Type I/II) windowed-sinc FIR design.
// High-pass and band-stop designs need an even order (odd tap count), so an
// odd requested order is rounded up by one for those topologies.
FilterCoefficients designFir(const FilterSpec& spec);

// Effective FIR order actually designed for a spec (after even-order rounding).
int firEffectiveOrder(const FilterSpec& spec) noexcept;

} // namespace dsp::internal
