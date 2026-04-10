@echo off
setlocal

:: ---------------- CONFIG ----------------
set OUT=.\publish
set SELF_CONTAINED=true
set ARGS=-c Release -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:PublishTrimmed=true -p:TrimMode=link -p:PublishReadyToRun=false

:: Set which platforms to build
set BUILD_WIN_X64=true
set BUILD_LINUX_X64=true
set BUILD_LINUX_ARM64=true
set BUILD_OSX_X64=true

:: ---------------- FIND PROJECT FILE ----------------
set PROJ=
for %%f in (*.csproj) do set PROJ=%%f
if not defined PROJ (
    echo ERROR: No .csproj file found in the current directory.
    pause & exit /b 1
)
echo Using project file: %PROJ%

:: ---------------- CLEAN ----------------
if exist "%OUT%" rd /s /q "%OUT%"
mkdir "%OUT%"
echo.

:: ---------------- BUILD ----------------
if "%BUILD_WIN_X64%"=="true" (
    echo Building win-x64...
    dotnet publish "%PROJ%" --output "%OUT%\win-x64" --runtime win-x64 --self-contained %SELF_CONTAINED% %ARGS%
    if errorlevel 1 ( echo ERROR: win-x64 build failed! & pause & exit /b 1 )
    echo.
)

if "%BUILD_LINUX_ARM64%"=="true" (
    echo Building linux-arm64...
    dotnet publish "%PROJ%" --output "%OUT%\linux-arm64" --runtime linux-arm64 --self-contained %SELF_CONTAINED% %ARGS%
    if errorlevel 1 ( echo ERROR: linux-arm64 build failed! & pause & exit /b 1 )
    echo.
)

if "%BUILD_LINUX_X64%"=="true" (
    echo Building linux-x64...
    dotnet publish "%PROJ%" --output "%OUT%\linux-x64" --runtime linux-x64 --self-contained %SELF_CONTAINED% %ARGS%
    if errorlevel 1 ( echo ERROR: linux-x64 build failed! & pause & exit /b 1 )
    echo.
)

if "%BUILD_OSX_X64%"=="true" (
    echo Building osx-x64...
    dotnet publish "%PROJ%" --output "%OUT%\osx-x64" --runtime osx-x64 --self-contained %SELF_CONTAINED% %ARGS%
    if errorlevel 1 ( echo ERROR: osx-x64 build failed! & pause & exit /b 1 )
    echo.
)

:: ---------------- Copy settings.json ----------------
if not exist ".\settings.json" (
    echo ERROR: settings.json not found, cannot continue!
    pause & exit /b 1
)

echo Copying settings.json...
if "%BUILD_WIN_X64%"=="true"     copy /y ".\settings.json" "%OUT%\win-x64\settings.json"
if "%BUILD_LINUX_ARM64%"=="true" copy /y ".\settings.json" "%OUT%\linux-arm64\settings.json"
if "%BUILD_LINUX_X64%"=="true"   copy /y ".\settings.json" "%OUT%\linux-x64\settings.json"
if "%BUILD_OSX_X64%"=="true"     copy /y ".\settings.json" "%OUT%\osx-x64\settings.json"

echo.
echo PUBLISH DONE!
cd "%OUT%"
echo BUILD DIR: %CD%
echo.
pause