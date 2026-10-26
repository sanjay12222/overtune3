#pragma once
#include "dsp/FilterCoefficients.h"
#include "dsp/FilterSpec.h"
#include <string>

namespace dsp {

// Values index the Export page tabs and the persisted default, so only append.
enum class ExportFormat { C, CppHeader, Python, Json, Matlab, Rust, JavaScript, Csv };

class CodeExporter {
public:
    static std::string generate(const FilterCoefficients& coeff,
                                const FilterSpec&         spec,
                                ExportFormat              format);

private:
    static std::string genC       (const FilterCoefficients&, const FilterSpec&);
    static std::string genCpp     (const FilterCoefficients&, const FilterSpec&);
    static std::string genPython  (const FilterCoefficients&, const FilterSpec&);
    static std::string genJson    (const FilterCoefficients&, const FilterSpec&);

    static std::string genFirC     (const FilterCoefficients&, const FilterSpec&);
    static std::string genFirCpp   (const FilterCoefficients&, const FilterSpec&);
    static std::string genFirPython(const FilterCoefficients&, const FilterSpec&);
    static std::string genFirJson  (const FilterCoefficients&, const FilterSpec&);

    // These handle both IIR (SOS) and FIR (taps) designs
    static std::string genMatlab    (const FilterCoefficients&, const FilterSpec&);
    static std::string genRust      (const FilterCoefficients&, const FilterSpec&);
    static std::string genJavaScript(const FilterCoefficients&, const FilterSpec&);
    static std::string genCsv       (const FilterCoefficients&, const FilterSpec&);
};

} // namespace dsp
