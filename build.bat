@echo off
setlocal
set "QT_PATH=C:\Qt\6.7.2\msvc2019_64"
set "CMAKE_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"

rem Terminate any running instances to avoid LNK1104 file locking
taskkill /f /im ot3.exe >nul 2>&1
taskkill /f /im FilterDesigner.exe >nul 2>&1
taskkill /f /im ot3-installer.exe >nul 2>&1

echo [1/3] Configuring CMake...
"%CMAKE_PATH%" -G "Visual Studio 17 2022" -A x64 -S "%~dp0." -B "%~dp0build" -DCMAKE_PREFIX_PATH="%QT_PATH%"
if errorlevel 1 exit /b %errorlevel%

echo [2/3] Compiling Release build...
"%CMAKE_PATH%" --build "%~dp0build" --config Release --parallel
if errorlevel 1 exit /b %errorlevel%

echo [3/3] Deploying Qt runtime and MSVC CRT libraries (zero external dependency)...
"%QT_PATH%\bin\windeployqt.exe" "%~dp0build\bin\Release\ot3.exe" --qmldir "%~dp0app\qml" --multimedia --compiler-runtime

rem Deploy MSVC CRT runtime libraries app-locally (msvcp140.dll, msvcp140_2.dll, vcruntime140.dll, etc.)
powershell -NoProfile -Command "$crt = (Get-ChildItem 'C:\Program Files*\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT' -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1).FullName; if ($crt) { Copy-Item \"$crt\*.dll\" -Destination '%~dp0build\bin\Release' -Force; Write-Host \"[OK] Bundled MSVC CRT runtime from $crt\" -ForegroundColor Green }"

copy /y "%~dp0build\bin\Release\ot3.exe" "%~dp0build\bin\Release\FilterDesigner.exe" >nul
copy /y "%~dp0assets\logo.ico" "%~dp0build\bin\Release\logo.ico" >nul
copy /y "%~dp0assets\logo.png" "%~dp0build\bin\Release\logo.png" >nul
if exist "%~dp0build\bin\Release\ot3-installer.exe" (
    copy /y "%~dp0build\bin\Release\ot3-installer.exe" "%~dp0ot3-installer.exe" >nul
)

echo Build complete! Run run.bat or .\build\bin\Release\ot3.exe (or ot3-installer.exe)
endlocal
