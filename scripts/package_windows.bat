@echo off
rem package_windows.bat — Package Overtune 3 for Windows distribution
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "ROOT_DIR=%CD%"
popd

set "DIST_DIR=%ROOT_DIR%\dist"
set "RELEASE_DIR=%DIST_DIR%\release"
set "PKG_NAME=overtune3-windows-x64"
set "STAGE_DIR=%DIST_DIR%\staging\%PKG_NAME%"

echo ========================================================
echo   Packaging Overtune 3.2.5 for Windows x64
echo ========================================================
echo Root directory: %ROOT_DIR%

set "BIN_SRC="
if exist "%ROOT_DIR%\build\windows-release\bin\ot3.exe" (
    set "BIN_SRC=%ROOT_DIR%\build\windows-release\bin"
) else if exist "%ROOT_DIR%\build\bin\Release\ot3.exe" (
    set "BIN_SRC=%ROOT_DIR%\build\bin\Release"
) else if exist "%ROOT_DIR%\build\bin\ot3.exe" (
    set "BIN_SRC=%ROOT_DIR%\build\bin"
)

if "%BIN_SRC%"=="" (
    echo [ERROR] Could not find built binary ot3.exe.
    echo Please build the project first using build.bat.
    exit /b 1
)

echo Source binary path: %BIN_SRC%

if exist "%STAGE_DIR%" rmdir /s /q "%STAGE_DIR%"
mkdir "%STAGE_DIR%"
mkdir "%STAGE_DIR%\bin"
mkdir "%STAGE_DIR%\assets"

echo [1/4] Copying binary and deployed Qt runtime...
xcopy /s /e /y /q "%BIN_SRC%\*" "%STAGE_DIR%\bin\" >nul
if exist "%STAGE_DIR%\bin\dsp_tests.exe" del /q "%STAGE_DIR%\bin\dsp_tests.exe"

rem Guarantee MSVC CRT Redistributable DLLs are bundled for zero-dependency execution
echo Deploying MSVC C++ runtime dependencies...
powershell -NoProfile -Command "$crt = (Get-ChildItem 'C:\Program Files*\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT' -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1).FullName; if ($crt) { Copy-Item \"$crt\*.dll\" -Destination '%STAGE_DIR%\bin' -Force; Write-Host '  -> Bundled MSVC CRT runtime DLLs successfully.' -ForegroundColor Green } else { Write-Warning 'Could not locate MSVC CRT Redist folder' }"

if not exist "%STAGE_DIR%\bin\FilterDesigner.exe" (
    copy /y "%STAGE_DIR%\bin\ot3.exe" "%STAGE_DIR%\bin\FilterDesigner.exe" >nul
)
if exist "%STAGE_DIR%\bin\ot3-installer.exe" (
    copy /y "%STAGE_DIR%\bin\ot3-installer.exe" "%STAGE_DIR%\ot3-installer.exe" >nul
)

echo [2/4] Adding documentation and assets...
if exist "%ROOT_DIR%\assets\logo.png" (
    copy /y "%ROOT_DIR%\assets\logo.png" "%STAGE_DIR%\assets\" >nul
    copy /y "%ROOT_DIR%\assets\logo.png" "%STAGE_DIR%\" >nul
)
if exist "%ROOT_DIR%\assets\logo.ico" (
    copy /y "%ROOT_DIR%\assets\logo.ico" "%STAGE_DIR%\assets\" >nul
    copy /y "%ROOT_DIR%\assets\logo.ico" "%STAGE_DIR%\" >nul
)
if exist "%ROOT_DIR%\assets\banner.png" (
    copy /y "%ROOT_DIR%\assets\banner.png" "%STAGE_DIR%\assets\" >nul
)
if exist "%ROOT_DIR%\shareware\windows\README_WINDOWS.txt" (
    copy /y "%ROOT_DIR%\shareware\windows\README_WINDOWS.txt" "%STAGE_DIR%\" >nul
)
if exist "%ROOT_DIR%\README.md" (
    copy /y "%ROOT_DIR%\README.md" "%STAGE_DIR%\" >nul
)

echo [3/4] Adding Windows launcher and installer scripts...
copy /y "%SCRIPT_DIR%install_windows.ps1" "%STAGE_DIR%\" >nul

(
    echo @echo off
    echo pushd "%%~dp0bin"
    echo start "" "ot3.exe" %%*
    echo popd
) > "%STAGE_DIR%\ot3.bat"

(
    echo @echo off
    echo pushd "%%~dp0bin"
    echo start "" "ot3.exe" %%*
    echo popd
) > "%STAGE_DIR%\run.bat"

echo [4/5] Creating zip archives...
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"
if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

powershell -NoProfile -Command "Compress-Archive -Path '%STAGE_DIR%' -DestinationPath '%DIST_DIR%\%PKG_NAME%.zip' -Force"
if errorlevel 1 (
    echo [ERROR] Failed to create the portable Windows archive.
    exit /b 1
)
copy /y "%DIST_DIR%\%PKG_NAME%.zip" "%RELEASE_DIR%\%PKG_NAME%.zip" >nul
if errorlevel 1 (
    echo [ERROR] Failed to stage the portable archive for GitHub release.
    exit /b 1
)

echo [5/5] Building the Windows setup installer...
where makensis >nul 2>nul
if errorlevel 1 (
    echo [ERROR] NSIS is required to build the setup installer. Install NSIS and add makensis to PATH.
    exit /b 1
)
pushd "%SCRIPT_DIR%"
makensis installer_windows.nsi
if errorlevel 1 (
    popd
    echo [ERROR] NSIS failed to build the setup installer.
    exit /b 1
)
popd

copy /y "%DIST_DIR%\Overtune3-Setup-x64.exe" "%RELEASE_DIR%\Overtune3-Setup-x64.exe" >nul
if errorlevel 1 (
    echo [ERROR] Failed to stage the setup installer for GitHub release.
    exit /b 1
)

powershell -NoProfile -Command "$files = Get-ChildItem -LiteralPath '%RELEASE_DIR%' -File | Where-Object { $_.Name -in @('Overtune3-Setup-x64.exe', '%PKG_NAME%.zip') }; $files | Get-FileHash -Algorithm SHA256 | ForEach-Object { '{0}  {1}' -f $_.Hash.ToLowerInvariant(), $_.Path.Substring('%RELEASE_DIR%'.Length + 1) } | Set-Content -LiteralPath '%RELEASE_DIR%\SHA256SUMS.txt' -Encoding ascii"
if errorlevel 1 (
    echo [ERROR] Failed to write GitHub release checksums.
    exit /b 1
)

echo.
echo [OK] Windows distribution package created successfully:
echo   - Folder:  %STAGE_DIR%
echo   - Archive: %DIST_DIR%\%PKG_NAME%.zip
echo   - Dist:    %DIST_DIR%\%PKG_NAME%.zip
echo   - Setup:   %DIST_DIR%\Overtune3-Setup-x64.exe
echo   - Release: %RELEASE_DIR%
echo.
endlocal
