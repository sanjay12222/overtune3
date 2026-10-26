#include "dsp/WavReader.h"
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <stdexcept>
#include <vector>

namespace dsp {

namespace {

constexpr uint16_t kFormatPcm        = 1;
constexpr uint16_t kFormatFloat      = 3;
constexpr uint16_t kFormatExtensible = 0xFFFE;

uint16_t readU16(const uint8_t* p) { return static_cast<uint16_t>(p[0] | (p[1] << 8)); }
uint32_t readU32(const uint8_t* p) {
    return static_cast<uint32_t>(p[0]) | (static_cast<uint32_t>(p[1]) << 8) |
           (static_cast<uint32_t>(p[2]) << 16) | (static_cast<uint32_t>(p[3]) << 24);
}

} // anonymous namespace

WavData WavReader::read(const std::string& path) {
    WavData data;
    std::ifstream f(path, std::ios::binary);
    if (!f) { data.error = "Cannot open file: " + path; return data; }

    f.seekg(0, std::ios::end);
    const auto fileSize = static_cast<uint64_t>(f.tellg());
    f.seekg(0, std::ios::beg);

    char riff[12] = {};
    if (!f.read(riff, 12) || std::memcmp(riff, "RIFF", 4) != 0 || std::memcmp(riff + 8, "WAVE", 4) != 0) {
        data.error = "Not a valid WAV file"; return data;
    }

    bool     haveFmt = false;
    uint16_t format = 0, channels = 0, bits = 0;
    uint32_t sampleRate = 0;
    std::vector<uint8_t> pcmData;

    uint8_t header[8];
    while (f.read(reinterpret_cast<char*>(header), 8)) {
        const uint32_t chunkSize = readU32(header + 4);
        const uint64_t chunkStart = static_cast<uint64_t>(f.tellg());
        // Streamed/truncated files may declare more bytes than exist
        const uint64_t available = fileSize > chunkStart ? fileSize - chunkStart : 0;
        const uint32_t usable = static_cast<uint32_t>(std::min<uint64_t>(chunkSize, available));

        if (std::memcmp(header, "fmt ", 4) == 0) {
            std::vector<uint8_t> fmt(usable);
            f.read(reinterpret_cast<char*>(fmt.data()), usable);
            if (usable < 16) { data.error = "Malformed fmt chunk"; return data; }
            format     = readU16(&fmt[0]);
            channels   = readU16(&fmt[2]);
            sampleRate = readU32(&fmt[4]);
            bits       = readU16(&fmt[14]);
            // WAVE_FORMAT_EXTENSIBLE stores the real format in the SubFormat GUID
            if (format == kFormatExtensible && usable >= 26) format = readU16(&fmt[24]);
            haveFmt = true;
        } else if (std::memcmp(header, "data", 4) == 0) {
            pcmData.resize(usable);
            f.read(reinterpret_cast<char*>(pcmData.data()), usable);
            pcmData.resize(static_cast<size_t>(f.gcount()));
            break;
        } else {
            f.seekg(static_cast<std::streamoff>(usable), std::ios::cur);
        }
        // RIFF chunks are padded to an even size
        if (chunkSize % 2 != 0) f.seekg(1, std::ios::cur);
    }

    if (!haveFmt) { data.error = "WAV file has no fmt chunk"; return data; }
    if (channels == 0) { data.error = "WAV file declares zero channels"; return data; }
    const bool pcmOk   = format == kFormatPcm && (bits == 8 || bits == 16 || bits == 24 || bits == 32);
    const bool floatOk = format == kFormatFloat && (bits == 32 || bits == 64);
    if (!pcmOk && !floatOk) {
        data.error = "Unsupported WAV encoding (format " + std::to_string(format) + ", " +
                     std::to_string(bits) + "-bit)";
        return data;
    }
    if (pcmData.empty()) { data.error = "No data chunk found"; return data; }

    data.channels      = channels;
    data.sampleRate    = static_cast<int>(sampleRate);
    data.bitsPerSample = bits;
    data.valid         = true;

    const size_t bytesPerSample = bits / 8u;
    const size_t frameBytes     = bytesPerSample * channels;
    const size_t numSamples     = (pcmData.size() / frameBytes) * channels;   // whole frames only
    data.samples.reserve(numSamples);

    for (size_t i = 0; i < numSamples; ++i) {
        const uint8_t* p = pcmData.data() + i * bytesPerSample;
        double sample = 0.0;
        if (format == kFormatPcm) {
            switch (bits) {
                case 8:  sample = (static_cast<double>(*p) - 128.0) / 128.0; break;
                case 16: {
                    int16_t v = 0;
                    std::memcpy(&v, p, 2);
                    sample = v / 32768.0;
                    break;
                }
                case 24: {
                    const int32_t v = (static_cast<int32_t>(p[2]) << 24 |
                                       static_cast<int32_t>(p[1]) << 16 |
                                       static_cast<int32_t>(p[0]) << 8) >> 8;
                    sample = v / 8388608.0;
                    break;
                }
                case 32: {
                    int32_t v = 0;
                    std::memcpy(&v, p, 4);
                    sample = v / 2147483648.0;
                    break;
                }
                default: break;
            }
        } else if (bits == 32) {
            float v = 0.0f;
            std::memcpy(&v, p, 4);
            sample = static_cast<double>(v);
        } else {
            double v = 0.0;
            std::memcpy(&v, p, 8);
            sample = v;
        }
        data.samples.push_back(sample);
    }

    return data;
}

std::vector<double> WavReader::readMono(const std::string& path) {
    auto d = read(path);
    if (!d.valid) throw std::runtime_error(d.error);
    if (d.samples.empty()) throw std::runtime_error("WAV file contains no samples");
    if (d.channels == 1) return d.samples;
    // Mix down to mono
    const auto channels = static_cast<size_t>(d.channels);
    std::vector<double> mono;
    mono.reserve(d.samples.size() / channels);
    for (size_t i = 0; i + channels <= d.samples.size(); i += channels) {
        double sum = 0.0;
        for (size_t c = 0; c < channels; ++c) sum += d.samples[i + c];
        mono.push_back(sum / static_cast<double>(channels));
    }
    return mono;
}

} // namespace dsp
