#Requires -Version 5.1
<#
.SYNOPSIS
    DYFI Updater Windows Uninstaller

.DESCRIPTION
    Removes the DYFI Updater scheduled task and/or Startup shortcut, stops
    any running instance, and deletes the install directory.

.EXAMPLE
    .\uninstall.ps1
#>

$ErrorActionPreference = "Stop"

$AppName    = "dyfi-updater"
$InstallDir = Join-Path $env:ProgramFiles $AppName
$TaskName   = $AppName

Write-Host "============================================"
Write-Host " DYFI Updater Windows Uninstaller"
Write-Host "============================================"
Write-Host ""

# ---------------- Check administrator ----------------

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Please run this uninstaller as Administrator:" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Right-click uninstall.ps1 -> Run with PowerShell (as Administrator)"
    Write-Host "  or from an elevated PowerShell prompt: .\uninstall.ps1"
    Write-Host ""
    exit 1
}

# ---------------- Stop and remove scheduled task ----------------

$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Stopping scheduled task..."
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    Write-Host "Removing scheduled task..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
} else {
    Write-Host "Scheduled task not found, skipping."
}

# ---------------- Remove Startup shortcut ----------------

$StartupFolder = [Environment]::GetFolderPath("Startup")
$ShortcutPath  = Join-Path $StartupFolder "$AppName.lnk"

if (Test-Path $ShortcutPath) {
    Write-Host "Removing Startup shortcut:"
    Write-Host "  $ShortcutPath"
    Remove-Item $ShortcutPath -Force
} else {
    Write-Host "Startup shortcut not found, skipping."
}

# ---------------- Stop running process ----------------

$process = Get-Process -Name "dyfi-updater" -ErrorAction SilentlyContinue
if ($process) {
    Write-Host "Stopping running process..."
    $process | Stop-Process -Force -ErrorAction SilentlyContinue
}

# ---------------- Remove install directory ----------------

if (Test-Path $InstallDir) {
    Write-Host "Removing install directory:"
    Write-Host "  $InstallDir"
    Remove-Item $InstallDir -Recurse -Force
} else {
    Write-Host "Install directory not found, skipping."
}

# ---------------- Result ----------------

Write-Host ""
Write-Host "============================================"
Write-Host " Uninstallation completed"
Write-Host "============================================"
Write-Host ""