#include "ExportModel.h"
#include "FilterEngine.h"
#include <QFile>
#include <QUrl>
#include <QGuiApplication>
#include <QClipboard>

ExportModel::ExportModel(QObject* parent) : QObject(parent) {}

void ExportModel::generate(QObject* enginePtr) {
    auto* eng = qobject_cast<FilterEngine*>(enginePtr);
    if (!eng) return;
    m_code = eng->exportCode(m_format);
    emit codeChanged();
}

bool ExportModel::saveToFile(const QString& path) {
    // File dialogs hand back URLs (file:///C:/...); stripping "file://" by hand
    // leaves "/C:/..." which cannot be opened on Windows
    const QString local = path.startsWith("file:", Qt::CaseInsensitive) ? QUrl(path).toLocalFile() : path;
    QFile f(local);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) return false;
    f.write(m_code.toUtf8());
    return true;
}

void ExportModel::copyToClipboard() {
    QGuiApplication::clipboard()->setText(m_code);
}
