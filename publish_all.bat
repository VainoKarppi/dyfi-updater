@echo off
setlocal

:: ---------------- ARGS ----------------
if "%~1"=="" (
    echo Usage: %~nx0 ^<version-id^>
    echo Example: %~nx0 1.2.3
    pause & exit /b 1
)

set VERSION=%~1
set REPO_ROOT=%~dp0
set REPO_ROOT=%REPO_ROOT:~0,-1%
set PUBLISH_ROOT=%REPO_ROOT%\publish
set TARGET_ROOT=%PUBLISH_ROOT%\dyfi_updater_%VERSION%
set CSHARP_PUBLISH_DIR=%REPO_ROOT%\csharp\publish

:: ---------------- C# PUBLISH ----------------
echo Running C# publish...
cd "%REPO_ROOT%\csharp"
call publish.bat
if errorlevel 1 ( echo ERROR: C# publish failed! & pause & exit /b 1 )

:: ---------------- PREPARE FOLDER ----------------
echo Preparing publish folder: %TARGET_ROOT%
if exist "%TARGET_ROOT%" rd /s /q "%TARGET_ROOT%"
mkdir "%TARGET_ROOT%"

if not exist "%CSHARP_PUBLISH_DIR%" (
    echo ERROR: C# publish output not found at %CSHARP_PUBLISH_DIR%
    pause & exit /b 1
)

:: ---------------- COPY C# OUTPUT ----------------
echo Copying C# published outputs...
mkdir "%TARGET_ROOT%\csharp"
xcopy /e /i /y "%CSHARP_PUBLISH_DIR%" "%TARGET_ROOT%\csharp\" >nul
del /s /q "%TARGET_ROOT%\csharp\log.log" 2>nul
del /s /q "%TARGET_ROOT%\csharp\lastupdate.txt" 2>nul

:: ---------------- COPY OTHER DIRS ----------------
for %%d in (python docker powershell shell) do (
    if exist "%REPO_ROOT%\%%d" (
        echo Copying %%d...
        if exist "%TARGET_ROOT%\%%d" rd /s /q "%TARGET_ROOT%\%%d"
        xcopy /e /i /y "%REPO_ROOT%\%%d" "%TARGET_ROOT%\%%d\" >nul
        del /s /q "%TARGET_ROOT%\%%d\log.log" 2>nul
        del /s /q "%TARGET_ROOT%\%%d\lastupdate.txt" 2>nul
        echo Copied %%d to %TARGET_ROOT%\%%d
    ) else (
        echo WARNING: directory '%%d' not found, skipping.
    )
)

:: ---------------- COPY ROOT DOCUMENTS ----------------
echo Copying root documentation...
if exist "%REPO_ROOT%\USAGE.txt" copy /y "%REPO_ROOT%\USAGE.txt" "%TARGET_ROOT%\USAGE.txt" >nul

:: ---------------- FINAL CLEANUP ----------------
echo Removing extra runtime artifacts from final package...
for /r "%TARGET_ROOT%" %%f in (log.log lastupdate.txt) do (
    if exist "%%f" del /q "%%f"
)

:: ---------------- APPEND HASHES TO USAGE.TXT ----------------
echo Appending build hashes to USAGE.txt...
powershell -Command "
$usageFile = '%TARGET_ROOT%\USAGE.txt'
$hashes = @{}
foreach ($platform in @('win-x64', 'linux-arm64', 'linux-x64', 'osx-x64')) {
    $hashFile = '%TARGET_ROOT%\csharp\' + $platform + '\hashes.sha256'
    if (Test-Path $hashFile) {
        $content = Get-Content $hashFile -Raw
        $hashes[$platform] = $content.Trim()
    }
}
if ($hashes.Count -gt 0) {
    Add-Content $usageFile \"`nBuild Hashes (Created automatically on 'publish_all')`n============`n\"
    foreach ($platform in $hashes.Keys) {
        Add-Content $usageFile \"`n$platform`:`n\" + $hashes[$platform]
    }
}
"

echo.
echo Published package created at: %TARGET_ROOT%
echo.