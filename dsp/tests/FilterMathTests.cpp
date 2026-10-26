#include "dsp/FilterAnalysis.h"
#include "dsp/FilterDesigner.h"
#include "dsp/SignalProcessor.h"
#include "dsp/CodeExporter.h"
#include "dsp/CsvReader.h"
#include "dsp/WavReader.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <string>
#include <vector>
#include <iostream>
#include <numbers>
#include <stdexcept>

namespace {

int failures = 0;

void check(bool condition, const char* message) {
    if (!condition) {
        std::cerr << "FAIL: " << message << '\n';
        ++failures;
    }
}

void runDesignMatrix() {
    for (int response = 0; response < 5; ++response) {
        const int maxOrder = response == static_cast<int>(dsp::FilterResponse::Bessel) ? 10 : 16;
        for (int type = 0; type < 4; ++type) {
            for (int order : {1, 2, 3, 4, maxOrder}) {
                dsp::FilterSpec spec;
                spec.response = static_cast<dsp::FilterResponse>(response);
                spec.type = static_cast<dsp::FilterType>(type);
                spec.order = order;
                spec.sampleRate = 48000.0;
                spec.cutoffFreq = type >= 2 ? 900.0 : 1000.0;
                spec.cutoffFreq2 = type >= 2 ? 1100.0 : 2000.0;
                spec.rippleDb = 1.0;
                spec.stopbandDb = 60.0;

                const auto coeff = dsp::designFilter(spec);
                const int expectedOrder = order * (type >= 2 ? 2 : 1);
                check(static_cast<int>(coeff.poles.size()) == expectedOrder,
                      "pole count matches transformed filter order");
                check(coeff.zeros.size() == coeff.poles.size(),
                      "finite zero count matches pole count");
                check(coeff.sos.size() == static_cast<size_t>((expectedOrder + 1) / 2),
                      "SOS count matches filter order");
                for (const auto& pole : coeff.poles)
                    check(std::isfinite(pole.real()) && std::isfinite(pole.imag()) && std::abs(pole) < 1.0,
                          "all digital poles are finite and strictly stable");

                if (type <= 2) {
                    double expectedDb = -3.0102999566;
                    if (response == static_cast<int>(dsp::FilterResponse::ChebyshevI) ||
                        response == static_cast<int>(dsp::FilterResponse::Elliptic))
                        expectedDb = -spec.rippleDb;
                    else if (response == static_cast<int>(dsp::FilterResponse::ChebyshevII))
                        expectedDb = -spec.stopbandDb;
                    const int edgeCount = type == 2 ? 2 : 1;
                    for (int edge = 0; edge < edgeCount; ++edge) {
                        const double edgeHz = edge == 0 ? spec.cutoffFreq : spec.cutoffFreq2;
                        const double edgeDb = 20.0 * std::log10(std::abs(
                            coeff.evaluate(2.0 * std::numbers::pi * edgeHz / spec.sampleRate)));
                        check(std::isfinite(edgeDb) && std::abs(edgeDb - expectedDb) < 0.1,
                              "filter cutoff edges meet response-family specification");
                    }
                }

                const auto analysis = dsp::FilterAnalysis::compute(
                    coeff, spec.sampleRate, 1024, spec.cutoffFreq,
                    type >= 2 ? spec.cutoffFreq2 : -1.0);
                check(analysis.frequencyResponse.size() >= 1024,
                      "frequency grid is populated");
                for (const auto& point : analysis.frequencyResponse) {
                    check(std::isfinite(point.frequency) && std::isfinite(point.magnitude) &&
                          std::isfinite(point.phase) && std::isfinite(point.groupDelay),
                          "plot samples are finite");
                }
                const auto verified = dsp::FilterAnalysis::verify(spec, coeff, analysis);
                if (!verified.referenceModelVerified) {
                    std::cerr << "reference mismatch response=" << response << " type=" << type
                              << " order=" << order << " mag=" << verified.maxPointMagnitudeErrorDb
                              << " phase=" << verified.maxPointPhaseErrorDeg
                              << " gdRel=" << verified.maxGroupDelayRelativeError
                              << " impulse=" << verified.maxImpulseError
                              << " matched=" << verified.matchedPoints << "/" << verified.totalPoints
                              << " details=" << verified.stage2Details << '\n';
                    check(false, "independent SOS, phase, group-delay, and impulse checks pass");
                }
                check(verified.passed && verified.specificationOk,
                      "full verifier accepts designs meeting their family specifications");
            }
        }
    }
}

void runFirMatrix() {
    constexpr int windowCount = static_cast<int>(dsp::FirWindow::DolphChebyshev) + 1;
    for (int window = 0; window < windowCount; ++window) {
        // Full order sweep for the original windows, a shorter one for the rest
        const std::vector<int> orders = window < 5 ? std::vector<int>{63, 64, 128, 256}
                                                   : std::vector<int>{63, 128};
        for (int type = 0; type < 4; ++type) {
            for (int order : orders) {
                dsp::FilterSpec spec;
                spec.response = dsp::FilterResponse::FIR;
                spec.firWindow = static_cast<dsp::FirWindow>(window);
                spec.type = static_cast<dsp::FilterType>(type);
                spec.order = order;
                spec.sampleRate = 48000.0;
                spec.cutoffFreq = type >= 2 ? 3000.0 : 4000.0;
                spec.cutoffFreq2 = 9000.0;
                spec.stopbandDb = 60.0;

                const auto coeff = dsp::designFilter(spec);
                const bool needsEven = type == 1 || type == 3;
                const int expectedOrder = (needsEven && order % 2) ? order + 1 : order;
                check(coeff.isFir() && coeff.sos.empty(), "FIR designs store taps, not SOS");
                check(static_cast<int>(coeff.fir.size()) == expectedOrder + 1, "FIR tap count is order + 1");
                check(static_cast<int>(coeff.poles.size()) == expectedOrder, "FIR poles sit at the origin");
                for (const auto& pole : coeff.poles)
                    check(std::abs(pole) == 0.0, "FIR poles are exactly zero");
                for (size_t n = 0; n < coeff.fir.size(); ++n)
                    check(std::abs(coeff.fir[n] - coeff.fir[coeff.fir.size() - 1 - n]) < 1e-12,
                          "FIR taps are symmetric (linear phase)");

                // Zeros must reconstruct the tap polynomial
                size_t lead = 0;
                while (lead < coeff.fir.size() && coeff.fir[lead] == 0.0) ++lead;
                const double w = 0.7;
                dsp::Complex zpk{coeff.fir[lead], 0.0};
                const dsp::Complex zInv = std::polar(1.0, -w);
                for (const auto& z : coeff.zeros) zpk *= 1.0 - z * zInv;
                for (size_t i = 0; i < lead; ++i) zpk *= zInv;
                // Zeros only drive the pole-zero plot; near-double roots limit accuracy to ~1e-6
                check(std::abs(zpk - coeff.evaluate(w)) < 1e-5 * std::max(1.0, std::abs(coeff.evaluate(w))),
                      "FIR zeros reconstruct the transfer function");

                const auto analysis = dsp::FilterAnalysis::compute(
                    coeff, spec.sampleRate, 1024, spec.cutoffFreq,
                    type >= 2 ? spec.cutoffFreq2 : -1.0);
                for (const auto& point : analysis.frequencyResponse)
                    check(std::isfinite(point.magnitude) && std::isfinite(point.phase) &&
                          std::isfinite(point.groupDelay), "FIR plot samples are finite");

                // Streaming processor must reproduce the taps as its impulse response
                std::vector<double> impulse(coeff.fir.size() + 8, 0.0);
                impulse[0] = 1.0;
                const auto out = dsp::SignalProcessor::process(coeff, impulse);
                for (size_t n = 0; n < out.size(); ++n)
                    check(std::abs(out[n] - (n < coeff.fir.size() ? coeff.fir[n] : 0.0)) < 1e-15,
                          "FIR signal processor impulse equals taps");

                const auto verified = dsp::FilterAnalysis::verify(spec, coeff, analysis);
                if (order >= 128 && !verified.passed) {
                    std::cerr << "FIR verify window=" << window << " type=" << type << " order=" << order
                              << "\n" << verified.stage1Details << verified.stage2Details << '\n';
                }
                check(verified.referenceModelVerified, "FIR reference model checks pass");
                if (order >= 128)
                    check(verified.passed, "full verifier accepts long FIR designs");
            }
        }
    }

    dsp::FilterSpec spec;
    spec.response = dsp::FilterResponse::FIR;
    spec.order = 257;
    bool rejected = false;
    try { (void)dsp::designFilter(spec); }
    catch (const std::invalid_argument&) { rejected = true; }
    check(rejected, "FIR order above 256 is rejected");
}

// Write a minimal RIFF/WAVE file; fmtExtra and padChunk exercise parser edge cases
void writeWav(const std::string& path, uint16_t format, uint16_t channels, uint16_t bits,
              const std::vector<uint8_t>& samples, bool extensible, bool oddChunkFirst, bool withFmt = true) {
    std::vector<uint8_t> body;
    auto u16 = [&](uint16_t v) { body.push_back(v & 0xFF); body.push_back(v >> 8); };
    auto u32 = [&](uint32_t v) { for (int i = 0; i < 4; ++i) body.push_back((v >> (8 * i)) & 0xFF); };
    auto tag = [&](const char* t) { body.insert(body.end(), t, t + 4); };
    tag("WAVE");
    if (oddChunkFirst) { tag("LIST"); u32(3); body.push_back('a'); body.push_back('b'); body.push_back('c'); body.push_back(0); }
    if (withFmt) {
        tag("fmt ");
        u32(extensible ? 40 : 16);
        u16(extensible ? 0xFFFE : format);
        u16(channels); u32(48000); u32(48000u * channels * bits / 8); u16(static_cast<uint16_t>(channels * bits / 8)); u16(bits);
        if (extensible) {
            u16(22); u16(bits); u32(0);
            u16(format);  // SubFormat GUID starts with the real format tag
            for (int i = 0; i < 14; ++i) body.push_back(0);
        }
    }
    tag("data"); u32(static_cast<uint32_t>(samples.size()));
    body.insert(body.end(), samples.begin(), samples.end());
    std::ofstream f(path, std::ios::binary);
    f.write("RIFF", 4);
    const uint32_t size = static_cast<uint32_t>(body.size());
    for (int i = 0; i < 4; ++i) f.put(static_cast<char>((size >> (8 * i)) & 0xFF));
    f.write(reinterpret_cast<const char*>(body.data()), static_cast<std::streamsize>(body.size()));
}

void runFileReaderChecks() {
    const std::string wav = "overtune_test.wav";
    // 16-bit stereo after an odd-sized LIST chunk: needs RIFF pad-byte handling
    writeWav(wav, 1, 2, 16, {0x00, 0x40, 0x00, 0xC0, 0x00, 0x20, 0x00, 0x20}, false, true);
    auto mono = dsp::WavReader::readMono(wav);
    check(mono.size() == 2 && std::abs(mono[0]) < 1e-12 && std::abs(mono[1] - 0.25) < 1e-12,
          "WAV parser skips padded odd chunks and mixes stereo to mono");

    // 24-bit WAVE_FORMAT_EXTENSIBLE
    writeWav(wav, 1, 1, 24, {0x00, 0x00, 0x40, 0x00, 0x00, 0xC0}, true, false);
    mono = dsp::WavReader::readMono(wav);
    check(mono.size() == 2 && std::abs(mono[0] - 0.5) < 1e-9 && std::abs(mono[1] + 0.5) < 1e-9,
          "WAV parser reads WAVE_FORMAT_EXTENSIBLE 24-bit PCM");

    // Missing fmt chunk and zero channels must fail cleanly instead of hanging
    bool rejected = false;
    writeWav(wav, 1, 1, 16, {0, 0}, false, false, false);
    try { (void)dsp::WavReader::readMono(wav); } catch (const std::runtime_error&) { rejected = true; }
    check(rejected, "WAV without fmt chunk is rejected");
    rejected = false;
    writeWav(wav, 1, 0, 16, {0, 0}, false, false);
    try { (void)dsp::WavReader::readMono(wav); } catch (const std::runtime_error&) { rejected = true; }
    check(rejected, "WAV with zero channels is rejected");
    std::remove(wav.c_str());

    const std::string csv = "overtune_test.csv";
    { std::ofstream f(csv); f << "0.5\n-0.25\r\n1e-3\n"; }
    auto col = dsp::CsvReader::readColumn(csv, 0);
    check(col.size() == 3 && col[0] == 0.5, "headerless CSV keeps its first sample");
    { std::ofstream f(csv); f << "time;value\n0;0.5\n1;0.75\n"; }
    col = dsp::CsvReader::readColumn(csv, 1);
    check(col.size() == 2 && col[1] == 0.75, "CSV header row is skipped and ';' delimiter detected");
    std::remove(csv.c_str());
}

void runExporterChecks() {
    for (auto response : {dsp::FilterResponse::Butterworth, dsp::FilterResponse::FIR}) {
        dsp::FilterSpec spec;
        spec.response = response;
        spec.order = response == dsp::FilterResponse::FIR ? 32 : 4;
        const auto coeff = dsp::designFilter(spec);
        for (int format = 0; format <= static_cast<int>(dsp::ExportFormat::Csv); ++format) {
            const auto code = dsp::CodeExporter::generate(coeff, spec, static_cast<dsp::ExportFormat>(format));
            check(code.size() > 40, "every export format produces output");
            check(code.find("2000 Hz") == std::string::npos,
                  "low-pass export does not print the unused second cutoff");
        }
        const auto rust = dsp::CodeExporter::generate(coeff, spec, dsp::ExportFormat::Rust);
        check(rust.find(", 1,") == std::string::npos && rust.find("[1,") == std::string::npos,
              "Rust export writes float literals");
        const auto json = dsp::CodeExporter::generate(coeff, spec, dsp::ExportFormat::Json);
        check(json.find("\"isStable\": true") != std::string::npos, "JSON export reports stability");
    }
}

void runInvalidSpecChecks() {
    dsp::FilterSpec spec;
    spec.cutoffFreq = 24000.0;
    bool rejected = false;
    try { (void)dsp::designFilter(spec); }
    catch (const std::invalid_argument&) { rejected = true; }
    check(rejected, "Nyquist cutoff is rejected");

    spec = {};
    spec.type = dsp::FilterType::BandPass;
    spec.cutoffFreq = 1200.0;
    spec.cutoffFreq2 = 1000.0;
    rejected = false;
    try { (void)dsp::designFilter(spec); }
    catch (const std::invalid_argument&) { rejected = true; }
    check(rejected, "reversed band edges are rejected");
}

} // namespace

int main() {
    runDesignMatrix();
    runFirMatrix();
    runFileReaderChecks();
    runExporterChecks();
    runInvalidSpecChecks();
    if (failures != 0) {
        std::cerr << failures << " DSP math checks failed\n";
        return 1;
    }
    std::cout << "DSP math checks passed\n";
    return 0;
}
