#pragma once
#include <QObject>
#include <QString>

class ExportModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString code     READ code     NOTIFY codeChanged)
    Q_PROPERTY(int     format   READ format   WRITE setFormat   NOTIFY formatChanged)

public:
    explicit ExportModel(QObject* parent = nullptr);

    QString code()   const { return m_code; }
    int     format() const { return m_format; }

    static constexpr int formatCount = 8;   // dsp::ExportFormat::C .. Csv

    Q_INVOKABLE void setFormat(int f) {
        if (f < 0 || f >= formatCount) return;
        if (m_format != f) { m_format = f; emit formatChanged(); }
    }

    Q_INVOKABLE void generate(QObject* engine);
    Q_INVOKABLE bool saveToFile(const QString& path);
    Q_INVOKABLE void copyToClipboard();

signals:
    void codeChanged();
    void formatChanged();

private:
    QString m_code;
    int     m_format{0};
};
