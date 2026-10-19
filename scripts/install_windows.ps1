# install_windows.ps1 - Native Windows Installer for Overtune 3 DSP Filter Designer
# Usage:
#   powershell -ExecutionPolicy Bypass -File install_windows.ps1 [-InstallDir <path>] [-NoDesktop] [-NoStartMenu]

param (
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\Overtune3",
    [switch]$NoDesktop = $false,
    [switch]$NoStartMenu = $false
)

$ErrorActionPreference = "Stop"

$AppName = "Overtune 3"
$AppId = "Overtune3"
$ExeName = "ot3.exe"
$Version = "3.2.5"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         Overtune 3 - Windows Native Installer            " -ForegroundColor White
Write-Host "         Version: $Version (x64 Release)                  " -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan

Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Candidate paths to locate binaries and deployed dependencies
$Candidates = @(
    (Join-Path $ScriptDir "bin\$ExeName"),
    (Join-Path $ScriptDir "..\build\windows-release\bin\$ExeName"),
    (Join-Path $ScriptDir "bin\FilterDesigner.exe"),
    (Join-Path $ScriptDir $ExeName),
    (Join-Path $ScriptDir "FilterDesigner.exe"),
    (Join-Path $ScriptDir "..\build\bin\Release\$ExeName"),
    (Join-Path $ScriptDir "..\build\bin\$ExeName"),
    (Join-Path $ScriptDir "..\..\build\bin\Release\$ExeName"),
    (Join-Path $ScriptDir "..\..\build\bin\$ExeName"),
    (Join-Path $ScriptDir "..\dist\overtune3-windows-x64\bin\$ExeName"),
    (Join-Path $ScriptDir "..\windows\overtune3-windows-x64\bin\$ExeName"),
    (Join-Path $ScriptDir "overtune3-windows-x64\bin\$ExeName")
)

$SourceBin = ""
foreach ($cand in $Candidates) {
    if (Test-Path $cand) {
        $SourceBin = (Resolve-Path $cand).Path
        break
    }
}

if (-not $SourceBin) {
    Write-Warning "Could not find $ExeName in any standard candidate paths:"
    foreach ($cand in $Candidates) {
        Write-Host "  - $cand" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "Please build the project first using build.bat or place $ExeName with its Qt libraries in bin\." -ForegroundColor Yellow
    exit 1
}

$SourceDir = Split-Path -Parent $SourceBin
Write-Host "Source directory: $SourceDir" -ForegroundColor Cyan
Write-Host "Target Installation Directory: $InstallDir" -ForegroundColor Yellow

if (!(Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$DestExe = Join-Path $InstallDir $ExeName

# Copy all application binaries, runtime DLLs, plugins, and QML resources
Write-Host "  -> Copying application binaries and Qt runtime dependencies..." -ForegroundColor Green
Copy-Item -Path "$SourceDir\*" -Destination $InstallDir -Recurse -Force

# Ensure MSVC C++ runtime DLLs are present in the target installation directory for zero-dependency execution
$RequiredCrt = @("msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll", "vcruntime140.dll", "vcruntime140_1.dll")
$missingCrt = $RequiredCrt | Where-Object { -not (Test-Path (Join-Path $InstallDir $_)) }
if ($missingCrt) {
    Write-Host "  -> Bundling MSVC CRT libraries for zero-dependency operation..." -ForegroundColor Cyan
    $crtSource = (Get-ChildItem 'C:\Program Files*\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT' -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1).FullName
    if ($crtSource) {
        Copy-Item "$crtSource\*.dll" -Destination $InstallDir -Force
    }
}

# Create FilterDesigner.exe copy if not already present
$AltDestExe = Join-Path $InstallDir "FilterDesigner.exe"
if (!(Test-Path $AltDestExe) -and (Test-Path $DestExe)) {
    Copy-Item -Path $DestExe -Destination $AltDestExe -Force
}

# Copy icons & resources (both ICO and PNG)
$IcoCandidates = @(
    (Join-Path $ScriptDir "assets\logo.ico"),
    (Join-Path $ScriptDir "logo.ico"),
    (Join-Path $ScriptDir "..\assets\logo.ico"),
    (Join-Path $ScriptDir "..\..\assets\logo.ico"),
    (Join-Path $SourceDir "logo.ico"),
    (Join-Path $ScriptDir "..\app\icons\logo.ico"),
    (Join-Path $ScriptDir "..\..\app\icons\logo.ico")
)
$DestIco = Join-Path $InstallDir "logo.ico"
foreach ($icoCand in $IcoCandidates) {
    if (Test-Path $icoCand) {
        Copy-Item -Path $icoCand -Destination $DestIco -Force
        break
    }
}

$IconCandidates = @(
    (Join-Path $ScriptDir "assets\logo.png"),
    (Join-Path $ScriptDir "logo.png"),
    (Join-Path $ScriptDir "..\assets\logo.png"),
    (Join-Path $ScriptDir "..\..\assets\logo.png"),
    (Join-Path $SourceDir "logo.png")
)
$DestIcon = Join-Path $InstallDir "logo.png"
foreach ($iconCand in $IconCandidates) {
    if (Test-Path $iconCand) {
        Copy-Item -Path $iconCand -Destination $DestIcon -Force
        break
    }
}

# Self-updater batch file for Windows in-place atomic updates
$UpdaterBat = Join-Path $InstallDir "overtune_update.bat"
$UpdaterLines = @(
    '@echo off',
    'echo Updating Overtune 3...',
    'timeout /t 1 /nobreak >nul',
    'if exist "%~dp0ot3.exe.new" (',
    '    copy /y "%~dp0ot3.exe.new" "%~dp0ot3.exe" >nul',
    '    del "%~dp0ot3.exe.new" >nul',
    ')',
    'if exist "%~dp0FilterDesigner.exe.new" (',
    '    copy /y "%~dp0FilterDesigner.exe.new" "%~dp0FilterDesigner.exe" >nul',
    '    del "%~dp0FilterDesigner.exe.new" >nul',
    ')',
    'start "" "%~dp0ot3.exe"',
    'exit'
)
$UpdaterLines | Out-File -FilePath $UpdaterBat -Encoding ASCII -Force

# Create Shortcuts via WScript.Shell
$WshShell = New-Object -ComObject WScript.Shell

$IconRef = if (Test-Path $DestIco) { "$DestIco,0" } else { "$DestExe,0" }

if (!$NoDesktop) {
    Write-Host "  -> Creating Desktop shortcut..." -ForegroundColor Green
    $DesktopPath = [System.Environment]::GetFolderPath('Desktop')
    $DesktopShortcut = Join-Path $DesktopPath "Overtune 3.lnk"
    $Shortcut = $WshShell.CreateShortcut($DesktopShortcut)
    $Shortcut.TargetPath = $DestExe
    $Shortcut.WorkingDirectory = $InstallDir
    $Shortcut.Description = "Overtune 3.2 - DSP Filter Designer and Audio Lab"
    $Shortcut.IconLocation = $IconRef
    $Shortcut.Save()
}

if (!$NoStartMenu) {
    Write-Host "  -> Creating Start Menu shortcut..." -ForegroundColor Green
    $ProgramsPath = [System.Environment]::GetFolderPath('Programs')
    $MenuFolder = Join-Path $ProgramsPath "Overtune 3"
    if (!(Test-Path $MenuFolder)) {
        New-Item -ItemType Directory -Path $MenuFolder -Force | Out-Null
    }
    $StartShortcut = Join-Path $MenuFolder "Overtune 3.lnk"
    $Shortcut = $WshShell.CreateShortcut($StartShortcut)
    $Shortcut.TargetPath = $DestExe
    $Shortcut.WorkingDirectory = $InstallDir
    $Shortcut.Description = "Overtune 3.2 - DSP Filter Designer and Audio Lab"
    $Shortcut.IconLocation = $IconRef
    $Shortcut.Save()
}

# Register in Windows Add/Remove Programs (Registry HKCU)
Write-Host "  -> Registering in Windows Add/Remove Programs..." -ForegroundColor Green
$UninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppId"
if (!(Test-Path $UninstallKey)) {
    New-Item -Path $UninstallKey -Force | Out-Null
}

Set-ItemProperty -Path $UninstallKey -Name "DisplayName" -Value "Overtune 3.2 Studio"
Set-ItemProperty -Path $UninstallKey -Name "DisplayVersion" -Value $Version
Set-ItemProperty -Path $UninstallKey -Name "Publisher" -Value "Shadcy"
Set-ItemProperty -Path $UninstallKey -Name "InstallLocation" -Value $InstallDir
Set-ItemProperty -Path $UninstallKey -Name "DisplayIcon" -Value $IconRef
Set-ItemProperty -Path $UninstallKey -Name "UninstallString" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$InstallDir\uninstall.ps1`""

# Create uninstaller scripts (PowerShell & Batch)
$UninstallScript = Join-Path $InstallDir "uninstall.ps1"
$UninstallLines = @(
    "`$ErrorActionPreference = 'SilentlyContinue'",
    "Write-Host 'Uninstalling Overtune 3...' -ForegroundColor Yellow",
    "`$DesktopPath = [System.Environment]::GetFolderPath('Desktop')",
    "Remove-Item -Path (Join-Path `$DesktopPath 'Overtune 3.lnk') -Force -ErrorAction SilentlyContinue",
    "`$ProgramsPath = [System.Environment]::GetFolderPath('Programs')",
    "Remove-Item -Path (Join-Path `$ProgramsPath 'Overtune 3') -Recurse -Force -ErrorAction SilentlyContinue",
    "Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Overtune3' -Recurse -Force -ErrorAction SilentlyContinue",
    "Remove-Item -Path '$InstallDir' -Recurse -Force -ErrorAction SilentlyContinue",
    "Write-Host 'Overtune 3 has been uninstalled successfully.' -ForegroundColor Green"
)
$UninstallLines | Out-File -FilePath $UninstallScript -Encoding ASCII -Force

$UninstallBat = Join-Path $InstallDir "uninstall.bat"
@(
    '@echo off',
    'powershell.exe -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"'
) | Out-File -FilePath $UninstallBat -Encoding ASCII -Force

Write-Host ""
Write-Host "[OK] Installation completed successfully!" -ForegroundColor Green
Write-Host "Installed in: $InstallDir"
Write-Host "You can now run Overtune 3 from the Start Menu or Desktop."
