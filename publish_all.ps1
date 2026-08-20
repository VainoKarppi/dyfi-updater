<#
.SYNOPSIS
    Builds the C# app for all platforms and assembles the release package.

.EXAMPLE
    .\publish_all.ps1 1.2.3
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

if (-not $Version) {
    Write-Host "Usage: .\publish_all.ps1 <version-id>"
    Write-Host "Example: .\publish_all.ps1 1.2.3"
    exit 1
}

$RepoRoot         = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }

$PublishRoot      = Join-Path $RepoRoot "publish"
$TargetRoot       = Join-Path $PublishRoot "dyfi_updater_$Version"
$CsharpPublishDir = Join-Path $RepoRoot "csharp\publish"

# ---------------- C# PUBLISH ----------------

Write-Host "Running C# publish..."
Push-Location (Join-Path $RepoRoot "csharp")
try {
    & .\publish.bat
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: C# publish failed!" -ForegroundColor Red
        exit 1
    }
}
finally {
    Pop-Location
}

# ---------------- PREPARE FOLDER ----------------

Write-Host "Preparing publish folder: $TargetRoot"
if (Test-Path $TargetRoot) { Remove-Item $TargetRoot -Recurse -Force }
New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null

if (-not (Test-Path $CsharpPublishDir)) {
    Write-Host "ERROR: C# publish output not found at $CsharpPublishDir" -ForegroundColor Red
    exit 1
}

# ---------------- COPY C# OUTPUT ----------------

Write-Host "Copying C# published outputs..."
$CsharpTarget = Join-Path $TargetRoot "csharp"
New-Item -ItemType Directory -Path $CsharpTarget -Force | Out-Null
Copy-Item -Path (Join-Path $CsharpPublishDir "*") -Destination $CsharpTarget -Recurse -Force
Get-ChildItem -Path $CsharpTarget -Recurse -Include "log.log", "lastupdate.txt" -File -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

# ---------------- COPY OTHER DIRS ----------------

foreach ($dir in @("python", "docker", "powershell", "shell")) {
    $sourceDir = Join-Path $RepoRoot $dir
    $targetDir = Join-Path $TargetRoot $dir

    if (-not (Test-Path $sourceDir)) {
        Write-Host "WARNING: directory '$dir' not found, skipping."
        continue
    }

    Write-Host "Copying $dir..."
    if (Test-Path $targetDir) { Remove-Item $targetDir -Recurse -Force }
    Copy-Item -Path $sourceDir -Destination $targetDir -Recurse -Force
    Get-ChildItem -Path $targetDir -Recurse -Include "log.log", "lastupdate.txt" -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "Copied $dir to $targetDir"
}

# ---------------- COPY ROOT DOCUMENTS ----------------

Write-Host "Copying root documentation..."
$UsageSource = Join-Path $RepoRoot "USAGE.txt"
if (Test-Path $UsageSource) {
    Copy-Item -Path $UsageSource -Destination (Join-Path $TargetRoot "USAGE.txt") -Force
}

# ---------------- FINAL CLEANUP ----------------

Write-Host "Removing extra runtime artifacts from final package..."
Get-ChildItem -Path $TargetRoot -Recurse -Include "log.log", "lastupdate.txt" -File -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

# ---------------- COPY INSTALLERS ----------------

Write-Host "Copying installers..."

$InstallShSource    = Join-Path $RepoRoot "install.sh"
$InstallPs1Source   = Join-Path $RepoRoot "install.ps1"
$UninstallShSource  = Join-Path $RepoRoot "uninstall.sh"
$UninstallPs1Source = Join-Path $RepoRoot "uninstall.ps1"

if (-not (Test-Path $InstallShSource)) {
    Write-Host "ERROR: install.sh not found!" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $InstallPs1Source)) {
    Write-Host "ERROR: install.ps1 not found!" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $UninstallShSource)) {
    Write-Host "ERROR: uninstall.sh not found!" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $UninstallPs1Source)) {
    Write-Host "ERROR: uninstall.ps1 not found!" -ForegroundColor Red
    exit 1
}

Copy-Item -Path $InstallShSource -Destination (Join-Path $TargetRoot "install.sh") -Force
Copy-Item -Path $InstallPs1Source -Destination (Join-Path $TargetRoot "install.ps1") -Force
Copy-Item -Path $UninstallShSource -Destination (Join-Path $TargetRoot "uninstall.sh") -Force
Copy-Item -Path $UninstallPs1Source -Destination (Join-Path $TargetRoot "uninstall.ps1") -Force

# ---------------- APPEND HASHES TO USAGE.TXT ----------------

Write-Host "Appending build hashes to USAGE.txt..."
$UsageFile = Join-Path $TargetRoot "USAGE.txt"
if (Test-Path $UsageFile) {
    Add-Content -Path $UsageFile -Value ""
    Add-Content -Path $UsageFile -Value "Build Hashes (Created automatically on 'publish_all')"
    Add-Content -Path $UsageFile -Value "============"
    foreach ($platform in @("win-x64", "linux-arm64", "linux-x64", "osx-x64")) {
        $hashFile = Join-Path $TargetRoot "csharp\$platform\hashes.sha256"
        if (Test-Path $hashFile) {
            Add-Content -Path $UsageFile -Value ""
            Add-Content -Path $UsageFile -Value "${platform}:"
            Add-Content -Path $UsageFile -Value (Get-Content $hashFile -Raw)
        }
    }
}


# ---------------- CREATE ZIP ----------------

$ZipPath = Join-Path $PublishRoot "dyfi_updater_$Version.zip"

Write-Host "Creating ZIP archive: $ZipPath"

if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

Compress-Archive `
    -Path $TargetRoot `
    -DestinationPath $ZipPath `
    -CompressionLevel Optimal

Write-Host "ZIP package created at: $ZipPath"
Write-Host ""

Write-Host ""
Write-Host "Published package created at: $TargetRoot"
Write-Host ""