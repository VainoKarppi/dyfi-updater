#!/bin/bash

path=../publish
selfContained=true

rm -r $path

echo "Building win-x64 version..."
dotnet publish --output $path/win-x64 --runtime win-x64 --self-contained $selfContained
if [ $? -ne 0 ]; then
    echo "Windows Build failed!"
    sleep 3
    exit
fi
echo ""

echo "Building linux-arm64 version..."
dotnet publish --output $path/linux-arm64 --runtime linux-arm64 --self-contained $selfContained
if [ $? -ne 0 ]; then
    echo "linux-arm64 Build failed!"
    sleep 3
    exit
fi
echo ""

echo "Building linux-x64 version..."
dotnet publish --output $path/linux-x64 --runtime linux-x64 --self-contained $selfContained
if [ $? -ne 0 ]; then
    echo "Linux-x64 Build failed!"
    sleep 3
    exit
fi
echo ""


echo "Build success!"
echo ""

sleep 1

if test -f "./settings.json"; then
    echo "Copying files..."
    cp ./settings.json $path/win-x64/settings.json
    cp ./settings.json $path/linux-arm64/settings.json
    cp ./settings.json $path/linux-x64/settings.json
fi

echo ""
echo "PUBLISH DONE!"

cd $path
echo "BUILD DIR: $PWD"
echo ""

read -p "Press enter to continue"
