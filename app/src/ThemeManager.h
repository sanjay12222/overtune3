#pragma once
#include <QObject>
#include <QString>

class ThemeManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(int themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged)
  Q_PROPERTY(bool isDark READ isDark NOTIFY themeModeChanged)
  Q_PROPERTY(int accentColorIndex READ accentColorIndex WRITE setAccentColorIndex NOTIFY themeModeChanged)
  Q_PROPERTY(bool oledMode READ oledMode WRITE setOledMode NOTIFY themeModeChanged)
  Q_PROPERTY(double plotLineWidth READ plotLineWidth WRITE setPlotLineWidth NOTIFY plotSettingsChanged)
  Q_PROPERTY(int plotResolution READ plotResolution WRITE setPlotResolution NOTIFY plotSettingsChanged)
  Q_PROPERTY(bool showCrosshairByDefault READ showCrosshairByDefault WRITE setShowCrosshairByDefault NOTIFY plotSettingsChanged)
  Q_PROPERTY(bool animationsEnabled READ animationsEnabled WRITE setAnimationsEnabled NOTIFY uiSettingsChanged)
  Q_PROPERTY(int defaultSampleRate READ defaultSampleRate WRITE setDefaultSampleRate NOTIFY dspSettingsChanged)
  Q_PROPERTY(int defaultExportLang READ defaultExportLang WRITE setDefaultExportLang NOTIFY exportSettingsChanged)

  // Resolved colors
  Q_PROPERTY(QString background READ background NOTIFY themeModeChanged)
  Q_PROPERTY(QString surface READ surface NOTIFY themeModeChanged)
  Q_PROPERTY(QString surfaceHigh READ surfaceHigh NOTIFY themeModeChanged)
  Q_PROPERTY(QString primaryText READ primaryText NOTIFY themeModeChanged)
  Q_PROPERTY(QString secondaryText READ secondaryText NOTIFY themeModeChanged)
  Q_PROPERTY(QString borderColor READ borderColor NOTIFY themeModeChanged)
  Q_PROPERTY(QString accent READ accent NOTIFY themeModeChanged)
  Q_PROPERTY(QString accentMuted READ accentMuted NOTIFY themeModeChanged)
  Q_PROPERTY(QString plotGrid READ plotGrid NOTIFY themeModeChanged)
  Q_PROPERTY(QString plotCurve READ plotCurve NOTIFY themeModeChanged)
  Q_PROPERTY(QString sidebarBg READ sidebarBg NOTIFY themeModeChanged)
  Q_PROPERTY(QString activityBarBg READ activityBarBg NOTIFY themeModeChanged)
  Q_PROPERTY(QString danger READ danger NOTIFY themeModeChanged)
  Q_PROPERTY(QString headlineFont READ headlineFont CONSTANT)
  Q_PROPERTY(QString bodyFont READ bodyFont CONSTANT)

public:
  enum ThemeMode { System = 0, Light = 1, Dark = 2 };
  Q_ENUM(ThemeMode)

  explicit ThemeManager(QObject *parent = nullptr);

  int themeMode() const { return m_mode; }
  bool isDark() const { return m_dark; }
  int accentColorIndex() const { return m_accentColorIndex; }
  bool oledMode() const { return m_oledMode; }
  double plotLineWidth() const { return m_plotLineWidth; }
  int plotResolution() const { return m_plotResolution; }
  bool showCrosshairByDefault() const { return m_showCrosshairByDefault; }
  bool animationsEnabled() const { return m_animationsEnabled; }
  int defaultSampleRate() const { return m_defaultSampleRate; }
  int defaultExportLang() const { return m_defaultExportLang; }
  QString headlineFont() const { return QStringLiteral("Stack Sans Headline"); }
  QString bodyFont() const { return QStringLiteral("Stack Sans Headline"); }

  void setThemeMode(int mode);
  void setAccentColorIndex(int index);
  void setOledMode(bool enabled);
  void setPlotLineWidth(double width);
  void setPlotResolution(int resolution);
  void setShowCrosshairByDefault(bool show);
  void setAnimationsEnabled(bool enabled);
  void setDefaultSampleRate(int rate);
  void setDefaultExportLang(int lang);

  Q_INVOKABLE void resetToDefaults();

  QString background() const;
  QString surface() const;
  QString surfaceHigh() const;
  QString primaryText() const;
  QString secondaryText() const;
  QString borderColor() const;
  QString accent() const;
  QString accentMuted() const;
  QString plotGrid() const;
  QString plotCurve() const;
  QString sidebarBg() const;
  QString activityBarBg() const;
  QString danger() const;

signals:
  void themeModeChanged();
  void plotSettingsChanged();
  void uiSettingsChanged();
  void dspSettingsChanged();
  void exportSettingsChanged();

private:
  void applySystemTheme();
  void loadSettings();
  void saveSettings();

  int m_mode{Dark};
  bool m_dark{true};
  int m_accentColorIndex{0};
  bool m_oledMode{false};
  double m_plotLineWidth{2.2};
  int m_plotResolution{1024};
  bool m_showCrosshairByDefault{false};
  bool m_animationsEnabled{true};
  int m_defaultSampleRate{48000};
  int m_defaultExportLang{0};
};

