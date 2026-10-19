@echo off
rem package_windows.bat — Package Overtune 3 for Windows distribution
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%..\.."
set "ROOT_DIR=%CD%"
popd

set "DIST_DIR=%ROOT_DIR%\dist"
set "PKG_NAME=overtune3-windows-x64"
set "STAGE_DIR=%SCRIPT_DIR%%PKG_NAME%"
set "DIST_STAGE_DIR=%DIST_DIR%\%PKG_NAME%"

echo ========================================================
echo   Packaging Overtune 3 for Windows x64 (Shareware)
echo ========================================================
echo Root directory: %ROOT_DIR%

set "BIN_SRC="
if exist "%ROOT_DIR%\build\bin\Release\ot3.exe" (
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

rem Clean and recreate staging directories
if exist "%STAGE_DIR%" rmdir /s /q "%STAGE_DIR%"
mkdir "%STAGE_DIR%"
mkdir "%STAGE_DIR%\bin"
mkdir "%STAGE_DIR%\assets"

echo [1/4] Copying binary and deployed Qt runtime...
xcopy /s /e /y /q "%BIN_SRC%\*" "%STAGE_DIR%\bin\" >nul

rem Guarantee MSVC CRT Redistributable DLLs are bundled for zero-dependency execution
echo Deploying MSVC C++ runtime dependencies...
powershell -NoProfile -Command "$crt = (Get-ChildItem 'C:\Program Files*\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT' -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1).FullName; if ($crt) { Copy-Item \"$crt\*.dll\" -Destination '%STAGE_DIR%\bin' -Force; Write-Host '  -> Bundled MSVC CRT runtime DLLs successfully.' -ForegroundColor Green } else { Write-Warning 'Could not locate MSVC CRT Redist folder' }"

if not exist "%STAGE_DIR%\bin\FilterDesigner.exe" (
    copy /y "%STAGE_DIR%\bin\ot3.exe" "%STAGE_DIR%\bin\FilterDesigner.exe" >nul
)
if not exist "%STAGE_DIR%\bin\ot3-installer.exe" (
    copy /y "%STAGE_DIR%\bin\ot3.exe" "%STAGE_DIR%\bin\ot3-installer.exe" >nul
)

echo [2/4] Adding documentation and assets...
if exist "%ROOT_DIR%\assets\logo.png" (
    copy /y "%ROOT_DIR%\assets\logo.png" "%STAGE_DIR%\assets\" >nul
    copy /y "%ROOT_DIR%\assets\logo.png" "%STAGE_DIR%\" >nul
)
if exist "%ROOT_DIR%\assets\logo.ico" (
    copy /y "%ROOT_DIR%\assets\logo.ico" "%STAGE_DIR%\assets\" >nul
    copy /y "%ROOT_DIR%\assets\logo.ico" "%STAGE_DIR%\bin\" >nul
)
if exist "%SCRIPT_DIR%README_WINDOWS.txt" (
    copy /y "%SCRIPT_DIR%README_WINDOWS.txt" "%STAGE_DIR%\" >nul
)
if exist "%ROOT_DIR%\CHANGELOG.md" (
    copy /y "%ROOT_DIR%\CHANGELOG.md" "%STAGE_DIR%\" >nul
)
if exist "%ROOT_DIR%\README.md" (
    copy /y "%ROOT_DIR%\README.md" "%STAGE_DIR%\" >nul
)

echo [3/4] Adding Windows launcher and installer scripts...
copy /y "%SCRIPT_DIR%install_windows.ps1" "%STAGE_DIR%\" >nul

rem Copy native one-click installer executable into the package root
if exist "%ROOT_DIR%\ot3-installer.exe" (
    copy /y "%ROOT_DIR%\ot3-installer.exe" "%STAGE_DIR%\ot3-installer.exe" >nul
) else if exist "%BIN_SRC%\ot3-installer.exe" (
    copy /y "%BIN_SRC%\ot3-installer.exe" "%STAGE_DIR%\ot3-installer.exe" >nul
)

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

echo [4/4] Creating zip archives...
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

powershell -NoProfile -Command "Compress-Archive -Path '%STAGE_DIR%' -DestinationPath '%SCRIPT_DIR%%PKG_NAME%.zip' -Force"
copy /y "%SCRIPT_DIR%%PKG_NAME%.zip" "%DIST_DIR%\%PKG_NAME%.zip" >nul

echo.
echo [OK] Windows shareware package created successfully:
echo   - Folder:  %STAGE_DIR%
echo   - Archive: %SCRIPT_DIR%%PKG_NAME%.zip
echo   - Dist:    %DIST_DIR%\%PKG_NAME%.zip
echo.
endlocal
