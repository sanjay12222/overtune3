!include "MUI2.nsh"

!define APP_VERSION "3.2.5"
!if /FileExists "..\dist\overtune3-windows-x64\bin\ot3.exe"
  !define APP_BIN "..\dist\overtune3-windows-x64\bin"
!elseif /FileExists "..\build\windows-release\bin\ot3.exe"
  !define APP_BIN "..\build\windows-release\bin"
!elseif /FileExists "..\build\bin\Release\ot3.exe"
  !define APP_BIN "..\build\bin\Release"
!else
  !define APP_BIN "..\build\bin"
!endif

Name "Overtune 3"
OutFile "..\dist\Overtune3-Setup-x64.exe"
Unicode True
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\Programs\Overtune3"
InstallDirRegKey HKCU "Software\Overtune3" "InstallDir"

!define MUI_ABORTWARNING
!define MUI_ICON "..\assets\logo.ico"
!define MUI_UNICON "..\assets\logo.ico"
!define MUI_FINISHPAGE_RUN "$INSTDIR\ot3.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch Overtune 3"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductName" "Overtune 3"
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileDescription" "Overtune 3 Setup"

Section "Overtune 3 (Required)" SecCore
    SetOutPath "$INSTDIR"
    File /r "${APP_BIN}\*.*"
    File "..\assets\logo.ico"
    File "..\assets\logo.png"

    IfFileExists "$INSTDIR\ot3.exe" app_exists 0
    MessageBox MB_ICONSTOP "The application files were not installed correctly. Please rebuild Overtune and run setup again."
    Abort
app_exists:
    WriteRegStr HKCU "Software\Overtune3" "InstallDir" "$INSTDIR"
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Overtune3" "DisplayName" "Overtune 3"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Overtune3" "DisplayVersion" "${APP_VERSION}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Overtune3" "Publisher" "Shadcy"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Overtune3" "InstallLocation" "$INSTDIR"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Overtune3" "DisplayIcon" "$INSTDIR\ot3.exe,0"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Overtune3" "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Overtune3" "NoModify" 1
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Overtune3" "NoRepair" 1

    CreateDirectory "$SMPROGRAMS\Overtune 3"
    CreateShortcut "$SMPROGRAMS\Overtune 3\Overtune 3.lnk" "$INSTDIR\ot3.exe" "" "$INSTDIR\logo.ico" 0
    CreateShortcut "$SMPROGRAMS\Overtune 3\Uninstall Overtune 3.lnk" "$INSTDIR\Uninstall.exe"
    CreateShortcut "$DESKTOP\Overtune 3.lnk" "$INSTDIR\ot3.exe" "" "$INSTDIR\logo.ico" 0
SectionEnd

Section "Uninstall"
    Delete "$DESKTOP\Overtune 3.lnk"
    Delete "$SMPROGRAMS\Overtune 3\Overtune 3.lnk"
    Delete "$SMPROGRAMS\Overtune 3\Uninstall Overtune 3.lnk"
    RMDir "$SMPROGRAMS\Overtune 3"
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Overtune3"
    DeleteRegKey HKCU "Software\Overtune3"
    RMDir /r "$INSTDIR"
SectionEnd
