#Requires -Version 5.1
<#
.SYNOPSIS
    DYFI Updater Windows Installer

.DESCRIPTION
    Installs the DYFI Updater to Program Files and configures it to start
    automatically, either via a Scheduled Task (default) or by dropping a
    shortcut in the current user's Startup folder.

.PARAMETER Method
    "TaskScheduler" (default) - registers a scheduled task that runs at logon.
    "Startup"                 - creates a shortcut in the Startup folder instead.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Method Startup
#>

param(
    [ValidateSet("TaskScheduler", "Startup")]
    [string]$Method = "TaskScheduler"
)

$ErrorActionPreference = "Stop"

$AppName    = "dyfi-updater"
$InstallDir = Join-Path $env:ProgramFiles $AppName
$TaskName   = $AppName

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

Write-Host "============================================"
Write-Host " DYFI Updater Windows Installer"
Write-Host "============================================"
Write-Host ""

# ---------------- Check administrator ----------------

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Please run this installer as Administrator:" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Right-click install.ps1 -> Run with PowerShell (as Administrator)"
    Write-Host "  or from an elevated PowerShell prompt: .\install.ps1"
    Write-Host ""
    exit 1
}

# ---------------- Detect invoking user ----------------
# When launched via "Run as administrator" the identity keeps the original
# interactive user (just an elevated token), so USERNAME/USERDOMAIN are
# correct for who should own the autostart entry.

$ServiceUser = "$env:USERDOMAIN\$env:USERNAME"
Write-Host "Service user: $ServiceUser"
Write-Host ""

# ---------------- Check files ----------------

$CsharpDir = Join-Path $ScriptDir "csharp"
if (-not (Test-Path $CsharpDir -PathType Container)) {
    Write-Host "ERROR: csharp directory not found." -ForegroundColor Red
    Write-Host "Run this installer from the root of the release package."
    exit 1
}

# ---------------- Detect architecture ----------------

$ArchRaw = $env:PROCESSOR_ARCHITECTURE

switch ($ArchRaw) {
    "AMD64" { $Runtime = "win-x64" }
    "ARM64" { $Runtime = "win-arm64" }
    default {
        Write-Host "ERROR: Unsupported architecture: $ArchRaw" -ForegroundColor Red
        exit 1
    }
}

$Executable = Join-Path $CsharpDir "$Runtime\dyfi-updater.exe"

if (-not (Test-Path $Executable -PathType Leaf)) {
    Write-Host "ERROR: DYFI Updater executable not found:" -ForegroundColor Red
    Write-Host "  $Executable"
    exit 1
}

Write-Host "Detected architecture: $ArchRaw"
Write-Host "Using runtime: $Runtime"
Write-Host ""

# ---------------- Stop / remove existing installation ----------------

$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Stopping existing scheduled task..."
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
}

Get-Process -Name "dyfi-updater" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

$StartupFolder = [Environment]::GetFolderPath("Startup")
$ShortcutPath  = Join-Path $StartupFolder "$AppName.lnk"
if (Test-Path $ShortcutPath) {
    Remove-Item $ShortcutPath -Force
}

# ---------------- Install application ----------------

Write-Host "Installing to:"
Write-Host "  $InstallDir"

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

Write-Host "Copying application..."

Copy-Item -Path $CsharpDir -Destination $InstallDir -Recurse -Force

foreach ($dir in @("python", "docker", "powershell", "shell")) {
    $srcDir = Join-Path $ScriptDir $dir
    if (Test-Path $srcDir -PathType Container) {
        Copy-Item -Path $srcDir -Destination $InstallDir -Recurse -Force
    }
}

$InstalledExecutable = Join-Path $InstallDir "csharp\$Runtime\dyfi-updater.exe"
$InstalledWorkingDir  = Split-Path $InstalledExecutable -Parent

# ---------------- Register startup method ----------------

Write-Host ""
Write-Host "Registering startup method: $Method"

if ($Method -eq "TaskScheduler") {

    $action    = New-ScheduledTaskAction -Execute $InstalledExecutable -WorkingDirectory $InstalledWorkingDir
    $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $ServiceUser
    $principal = New-ScheduledTaskPrincipal -UserId $ServiceUser -LogonType Interactive -RunLevel Limited
    $settings  = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1)

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "DYFI Updater - keeps your dynamic DNS record up to date" `
        -Force | Out-Null

    Write-Host "Starting task..."
    Start-ScheduledTask -TaskName $TaskName
}
else {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath       = $InstalledExecutable
    $Shortcut.WorkingDirectory = $InstalledWorkingDir
    $Shortcut.Description      = "DYFI Updater"
    $Shortcut.Save()

    Write-Host "Starting application..."
    Start-Process -FilePath $InstalledExecutable -WorkingDirectory $InstalledWorkingDir
}

# ---------------- Result ----------------

Write-Host ""
Write-Host "============================================"
Write-Host " Installation completed"
Write-Host "============================================"
Write-Host ""

Write-Host "Installation directory:"
Write-Host "  $InstallDir"
Write-Host ""

Write-Host "Service user:"
Write-Host "  $ServiceUser"
Write-Host ""

Write-Host "Startup method:"
Write-Host "  $Method"
Write-Host ""

if ($Method -eq "TaskScheduler") {
    Write-Host "Task commands:"
    Write-Host ""
    Write-Host "  Status:  Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo"
    Write-Host "  Stop:    Stop-ScheduledTask -TaskName $TaskName"
    Write-Host "  Start:   Start-ScheduledTask -TaskName $TaskName"
    Write-Host "  Remove:  Unregister-ScheduledTask -TaskName $TaskName"
    Write-Host ""
}
else {
    Write-Host "Startup shortcut:"
    Write-Host "  $ShortcutPath"
    Write-Host ""
    Write-Host "Remove it to disable autostart, or re-run:"
    Write-Host "  Remove-Item '$ShortcutPath'"
    Write-Host ""
}