#include "SimulationModel.h"
#include "FilterEngine.h"
#include "dsp/WavReader.h"
#include "dsp/CsvReader.h"
#include "dsp/SignalProcessor.h"
#include <cmath>
#include <numbers>
#include <QVariantMap>
#include <QUrl>

SimulationModel::SimulationModel(QObject* parent) : QObject(parent) {
    // Initialize with a clean dual-tone test signal (1 kHz passband + 6 kHz stopband)
    generateMultiTone(1000.0, 6000.0, 48000.0, 0.04);
}

static QString localPath(const QString& urlOrPath) {
    return urlOrPath.startsWith("file:", Qt::CaseInsensitive) ? QUrl(urlOrPath).toLocalFile() : urlOrPath;
}

void SimulationModel::loadWav(const QString& url) {
    const QString path = localPath(url);
    try {
        auto samples = dsp::WavReader::readMono(path.toStdString());
        m_label = QStringLiteral("WAV: ") + path.section('/', -1);
        publish(samples);
    } catch (const std::exception& e) {
        emit errorOccurred(QString::fromStdString(e.what()));
    }
}

void SimulationModel::loadCsv(const QString& url, int column) {
    const QString path = localPath(url);
    try {
        auto samples = dsp::CsvReader::readColumn(path.toStdString(), column);
        m_label = QStringLiteral("CSV: ") + path.section('/', -1);
        publish(samples);
    } catch (const std::exception& e) {
        emit errorOccurred(QString::fromStdString(e.what()));
    }
}

void SimulationModel::generateSine(double freq, double sampleRate, double durationSec) {
    const int n = static_cast<int>(sampleRate * durationSec);
    std::vector<double> samples(n);
    const double omega = 2.0 * std::numbers::pi * freq / sampleRate;
    for (int i = 0; i < n; ++i) samples[i] = std::sin(omega * i);
    m_label = QString("Sine %1 Hz").arg(freq);
    publish(samples);
}

void SimulationModel::generateChirp(double f0, double f1, double sampleRate, double durationSec) {
    const int n = static_cast<int>(sampleRate * durationSec);
    std::vector<double> samples(n);
    const double pi = std::numbers::pi;
    const double k  = (f1 - f0) / durationSec;
    for (int i = 0; i < n; ++i) {
        const double t = i / sampleRate;
        samples[i] = std::sin(2.0 * pi * (f0 * t + 0.5 * k * t * t));
    }
    m_label = QString("Chirp %1–%2 Hz").arg(f0).arg(f1);
    publish(samples);
}

void SimulationModel::generateMultiTone(double fPass, double fStop, double sampleRate, double durationSec) {
    const int n = static_cast<int>(sampleRate * durationSec);
    std::vector<double> samples(n);
    const double w1 = 2.0 * std::numbers::pi * fPass / sampleRate;
    const double w2 = 2.0 * std::numbers::pi * fStop / sampleRate;
    for (int i = 0; i < n; ++i) {
        samples[i] = 0.5 * std::sin(w1 * i) + 0.5 * std::sin(w2 * i);
    }
    m_label = QString("Dual-Tone (%1 Hz + %2 Hz)").arg(fPass).arg(fStop);
    publish(samples);
}

void SimulationModel::generateSquare(double freq, double sampleRate, double durationSec) {
    const int n = static_cast<int>(sampleRate * durationSec);
    std::vector<double> samples(n);
    const double omega = 2.0 * std::numbers::pi * freq / sampleRate;
    for (int i = 0; i < n; ++i) {
        samples[i] = std::sin(omega * i) >= 0.0 ? 0.8 : -0.8;
    }
    m_label = QString("Square Wave %1 Hz").arg(freq);
    publish(samples);
}

void SimulationModel::generateNoise(double durationSec, double sampleRate) {
    const int n = static_cast<int>(sampleRate * durationSec);
    std::vector<double> samples(n);
    for (int i = 0; i < n; ++i) {
        samples[i] = (static_cast<double>(rand()) / RAND_MAX) * 1.6 - 0.8;
    }
    m_label = QStringLiteral("White Noise");
    publish(samples);
}

void SimulationModel::applyFilter(QObject* enginePtr) {
    if (m_rawInput.empty()) return;
    auto* eng = qobject_cast<FilterEngine*>(enginePtr);
    if (!eng) return;

    static bool inApply = false;
    if (inApply) return;
    inApply = true;

    const auto& coeff = eng->coefficients();
    if (!coeff.isValid()) {
        inApply = false;
        return;
    }

    auto filtered = dsp::SignalProcessor::process(coeff, m_rawInput);

    m_output.clear();
    const int dispMax = 4096;
    const int step = std::max(1, static_cast<int>(filtered.size()) / dispMax);
    for (int i = 0; i < static_cast<int>(filtered.size()); i += step) {
        QVariantMap pt;
        pt["x"] = static_cast<double>(i);
        pt["y"] = filtered[i];
        m_output.append(pt);
    }

    emit dataChanged();
    inApply = false;
}

void SimulationModel::clear() {
    m_input.clear();
    m_output.clear();
    m_rawInput.clear();
    m_label.clear();
    emit dataChanged();
}

void SimulationModel::publish(const std::vector<double>& input) {
    m_rawInput = input;
    m_input.clear();
    m_output.clear();

    // Downsample to max 4096 points for display
    const int dispMax = 4096;
    const int step = std::max(1, static_cast<int>(input.size()) / dispMax);
    for (int i = 0; i < static_cast<int>(input.size()); i += step) {
        QVariantMap pt;
        pt["x"] = static_cast<double>(i);
        pt["y"] = input[i];
        m_input.append(pt);
    }

    emit dataChanged();
}
