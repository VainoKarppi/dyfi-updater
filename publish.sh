#!/bin/bash

# ---------------- CONFIG ----------------
path=./publish
selfContained=true

# Set which platforms to build
buildWinX64=true
buildLinuxX64=true
buildLinuxArm64=true

# ---------------- FIND PROJECT FILE ----------------
projFile=$(find . -maxdepth 1 -name "*.csproj" | head -n 1)
if [ -z "$projFile" ]; then
    echo "ERROR: No .csproj file found in the current directory."
    exit 1
fi
echo "Using project file: $projFile"

# ---------------- CLEAN ----------------
rm -rf $path
echo ""

# ---------------- Windows x64 ----------------
if [ "$buildWinX64" = true ]; then
    echo "Building win-x64 version..."
    dotnet publish "$projFile" --output $path/win-x64 --runtime win-x64 --self-contained $selfContained
    if [ $? -ne 0 ]; then
        echo "ERROR: Windows Build failed!"
        sleep 3
        exit 1
    fi
    echo ""
fi

# ---------------- Linux ARM64 ----------------
if [ "$buildLinuxArm64" = true ]; then
    echo "Building linux-arm64 version..."
    dotnet publish "$projFile" --output $path/linux-arm64 --runtime linux-arm64 --self-contained $selfContained
    if [ $? -ne 0 ]; then
        echo "ERROR: Linux-arm64 Build failed!"
        sleep 3
        exit 1
    fi
    echo ""
fi

# ---------------- Linux x64 ----------------
if [ "$buildLinuxX64" = true ]; then
    echo "Building linux-x64 version..."
    dotnet publish "$projFile" --output $path/linux-x64 --runtime linux-x64 --self-contained $selfContained
    if [ $? -ne 0 ]; then
        echo "ERROR: Linux-x64 Build failed!"
        sleep 3
        exit 1
    fi
    echo ""
fi

echo "Build success!"
echo ""
sleep 1

# ---------------- Copy settings.json ----------------
if [ -f "./settings.json" ]; then
    echo "Copying settings.json..."
    $buildWinX64 && cp ./settings.json $path/win-x64/settings.json
    $buildLinuxArm64 && cp ./settings.json $path/linux-arm64/settings.json
    $buildLinuxX64 && cp ./settings.json $path/linux-x64/settings.json
else
    echo "ERROR: settings.json not found, cannot continue!"
    exit 1
fi

echo ""
echo "PUBLISH DONE!"
cd $path
echo "BUILD DIR: $PWD"
echo ""
read -p "Press enter to continue"
