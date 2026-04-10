#!/bin/bash

# ---------------- CONFIG ----------------
path=./publish
selfContained=true
publishArgs=(
  -c Release
  -p:PublishSingleFile=true
  -p:EnableCompressionInSingleFile=true
  -p:PublishTrimmed=true
  -p:TrimMode=link
  -p:PublishReadyToRun=false
)

# Set which platforms to build
buildWinX64=true
buildLinuxX64=true
buildLinuxArm64=true
buildOsxX64=true

# ---------------- FIND PROJECT FILE ----------------
projFile=$(find . -maxdepth 1 -name "*.csproj" | head -n 1)
if [ -z "$projFile" ]; then
    echo "ERROR: No .csproj file found in the current directory."
    exit 1
fi
echo "Using project file: $projFile"

# ---------------- CLEAN ----------------
rm -rf "$path"
mkdir -p "$path"
echo ""

# ---------------- BUILD FUNCTION ----------------
build() {
    local rid=$1
    local label=$2
    echo "Building $label..."
    dotnet publish "$projFile" --output "$path/$rid" --runtime "$rid" --self-contained "$selfContained" "${publishArgs[@]}"
    if [ $? -ne 0 ]; then
        echo "ERROR: $label build failed!"
        exit 1
    fi
    echo ""
}

[ "$buildWinX64" = true ]     && build "win-x64"     "win-x64"
[ "$buildLinuxArm64" = true ] && build "linux-arm64" "linux-arm64"
[ "$buildLinuxX64" = true ]   && build "linux-x64"   "linux-x64"
[ "$buildOsxX64" = true ]     && build "osx-x64"     "osx-x64"

# ---------------- Copy settings.json ----------------
if [ -f "./settings.json" ]; then
    echo "Copying settings.json..."
    [ "$buildWinX64" = true ]     && cp ./settings.json "$path/win-x64/settings.json"
    [ "$buildLinuxArm64" = true ] && cp ./settings.json "$path/linux-arm64/settings.json"
    [ "$buildLinuxX64" = true ]   && cp ./settings.json "$path/linux-x64/settings.json"
    [ "$buildOsxX64" = true ]     && cp ./settings.json "$path/osx-x64/settings.json"
else
    echo "ERROR: settings.json not found, cannot continue!"
    exit 1
fi

echo ""
echo "PUBLISH DONE!"
cd "$path"
echo "BUILD DIR: $PWD"