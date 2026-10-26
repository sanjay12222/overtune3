#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QIcon>
#include <QFont>
#include <QFontDatabase>
#include "FilterEngine.h"
#include "SimulationModel.h"
#include "ExportModel.h"
#include "ThemeManager.h"
#include "UpdateInstallerEngine.h"

#ifdef Q_OS_WIN
#include <windows.h>
#include <shobjidl.h>
#endif

int main(int argc, char* argv[]) {
#ifdef Q_OS_WIN
    SetCurrentProcessExplicitAppUserModelID(L"Overtune.FilterDesigner.3.2.5");
#endif
    // Avoid GTK theme crash on Ubuntu Wayland/GNOME
    qputenv("QT_QPA_PLATFORMTHEME", "generic");

    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
        Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

    QGuiApplication::setApplicationName("Overtune 3");
    QGuiApplication::setOrganizationName("Overtune");
    QGuiApplication::setApplicationVersion(OVERTUNE_VERSION);

    // The app restyles every control; native styles (Windows, FluentWinUI3)
    // do not support customised background/contentItem, so use Basic
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(QStringLiteral(":/FilterDesigner/icons/logo.png")));


    // Register bundled fonts
    QFontDatabase::addApplicationFont(QStringLiteral(":/FilterDesigner/fonts/StackSansHeadline-Regular.ttf"));
    QFontDatabase::addApplicationFont(QStringLiteral(":/FilterDesigner/fonts/StackSansHeadline-Medium.ttf"));
    QFontDatabase::addApplicationFont(QStringLiteral(":/FilterDesigner/fonts/StackSansHeadline-SemiBold.ttf"));
    QFontDatabase::addApplicationFont(QStringLiteral(":/FilterDesigner/fonts/StackSansHeadline-Bold.ttf"));
    QFontDatabase::addApplicationFont(QStringLiteral(":/FilterDesigner/fonts/Inter-Regular.ttf"));
    const int codiconFontId = QFontDatabase::addApplicationFont(QStringLiteral(":/FilterDesigner/fonts/codicon.ttf"));
    const QStringList codiconFamilies = QFontDatabase::applicationFontFamilies(codiconFontId);
    const QString codiconFontFamily = codiconFamilies.isEmpty() ? QStringLiteral("codicon") : codiconFamilies.constFirst();

    QFont defaultFont(QStringLiteral("Stack Sans Headline"));
    defaultFont.setStyleHint(QFont::SansSerif);
    app.setFont(defaultFont);

    // Instantiate backend objects
    FilterEngine           engine;
    SimulationModel        simulation;
    ExportModel            exportModel;
    ThemeManager           theme;
    UpdateInstallerEngine  updateInstaller;
    exportModel.setFormat(theme.defaultExportLang());

    // Apply persisted settings that drive the engine. Plot resolution 1024 (the
    // default) keeps the original 3072-point analysis grid.
    engine.setSampleRate(theme.defaultSampleRate());
    engine.setAnalysisPoints(theme.plotResolution() * 3);
    QObject::connect(&theme, &ThemeManager::plotSettingsChanged, &engine, [&engine, &theme]() {
        engine.setAnalysisPoints(theme.plotResolution() * 3);
    });

    // Check CLI arguments or executable name for installer or update launch modes
    bool launchInstaller = false;
    bool launchUpdater = false;

    QString currentExe = QFileInfo(QCoreApplication::applicationFilePath()).fileName().toLower();
    if (currentExe.contains(QStringLiteral("installer")) || currentExe.contains(QStringLiteral("setup"))) {
        launchInstaller = true;
    }

    for (int i = 1; i < argc; ++i) {
        QString arg = QString::fromLocal8Bit(argv[i]);
        if (arg == QStringLiteral("--install") || arg == QStringLiteral("-i")) {
            launchInstaller = true;
        } else if (arg == QStringLiteral("--update") || arg == QStringLiteral("--check-updates") || arg == QStringLiteral("-u")) {
            launchUpdater = true;
        }
    }

    QQmlApplicationEngine qml;

    // Expose C++ objects to QML
    qml.rootContext()->setContextProperty("filterEngine",      &engine);
    qml.rootContext()->setContextProperty("simulation",        &simulation);
    qml.rootContext()->setContextProperty("exportModel",       &exportModel);
    qml.rootContext()->setContextProperty("theme",             &theme);
    qml.rootContext()->setContextProperty("updateInstaller",   &updateInstaller);
    qml.rootContext()->setContextProperty("codiconFontFamily", codiconFontFamily);
    qml.rootContext()->setContextProperty("cliLaunchInstaller", launchInstaller);
    qml.rootContext()->setContextProperty("cliLaunchUpdater",   launchUpdater);

    const QUrl url = launchInstaller
        ? QUrl(u"qrc:/FilterDesigner/qml/InstallerApp.qml"_qs)
        : QUrl(u"qrc:/FilterDesigner/qml/Main.qml"_qs);

    QObject::connect(&qml, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject* obj, const QUrl& objUrl) {
        if (!obj && url == objUrl) QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    qml.load(url);

    return app.exec();
}
