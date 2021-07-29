#!/bin/bash

cd "$(dirname "$0")"

DSTDIR="../Plugins"
rm -rf DerivedData

# -arch arm64
xcode-select -print-path
xcodebuild -version

TEST="$(xcode-select -print-path)"
echo $TEST
echo $APPLICATION_PATH

ls -la "$TEST"
ls -la "$TEST/../../.."

#xcode-select -switch /APPLICATION_PATH/Xcode12_4_0.app/Contents/Developer
#/APPLICATION_PATH/Xcode12_4_0.app/Contents/Developer/usr/bin/xcodebuild

#xcode-select -print-path
#xcodebuild -version

echo "Building WebView plugin"

xcodebuild -target WebView -configuration Release -arch i386 -arch x86_64 -arch arm64 build CONFIGURATION_BUILD_DIR='DerivedData' #| xcpretty
mkdir -p $DSTDIR

cp -r DerivedData/WebView.bundle $DSTDIR
rm -rf DerivedData
cp *.bundle.meta $DSTDIR
