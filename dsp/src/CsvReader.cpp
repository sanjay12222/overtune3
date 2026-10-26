#include "dsp/CsvReader.h"
#include <cerrno>
#include <cstdlib>
#include <initializer_list>
#include <fstream>
#include <sstream>
#include <stdexcept>

namespace dsp {

namespace {

// Parse a whole cell as a number (surrounding whitespace allowed)
bool parseNumber(const std::string& token, double& out) {
    const char* begin = token.c_str();
    char* end = nullptr;
    errno = 0;
    const double v = std::strtod(begin, &end);
    if (end == begin || errno == ERANGE) return false;
    while (*end == ' ' || *end == '\t' || *end == '\r') ++end;
    if (*end != '\0') return false;
    out = v;
    return true;
}

char detectDelimiter(const std::string& line) {
    for (char d : {',', ';', '\t'})
        if (line.find(d) != std::string::npos) return d;
    return ',';
}

} // anonymous namespace

std::vector<double> CsvReader::readColumn(const std::string& path, int column, bool hasHeader) {
    std::ifstream f(path);
    if (!f) throw std::runtime_error("Cannot open CSV: " + path);

    std::vector<double> data;
    std::string line;
    bool firstRow = true;
    char delimiter = ',';

    while (std::getline(f, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line.empty() || line[0] == '#') continue;
        if (firstRow) delimiter = detectDelimiter(line);

        std::istringstream ss(line);
        std::string token;
        int col = 0;
        bool found = false;
        double value = 0.0;
        while (std::getline(ss, token, delimiter)) {
            if (col == column) {
                found = parseNumber(token, value);
                break;
            }
            ++col;
        }
        // A header row is only skipped when it is not numeric, so headerless
        // files keep their first sample.
        if (firstRow && hasHeader && !found) { firstRow = false; continue; }
        firstRow = false;
        if (found) data.push_back(value);
    }
    if (data.empty())
        throw std::runtime_error("CSV contains no numeric samples in column " + std::to_string(column + 1));
    return data;
}

} // namespace dsp
