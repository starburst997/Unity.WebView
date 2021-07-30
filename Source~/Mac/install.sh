#!/bin/bash

cd "$(dirname "$0")"

DSTDIR="../../Plugins/Mac"
rm -rf DerivedData

# -arch arm64
xcode-select -print-path
xcodebuild -version

echo "Building WebView plugin"

xcodebuild -target WebView -configuration Release -arch i386 -arch x86_64 -arch arm64 build CONFIGURATION_BUILD_DIR='DerivedData' #| xcpretty
mkdir -p $DSTDIR

cp -r DerivedData/WebView.bundle $DSTDIR
rm -rf DerivedData
cp *.bundle.meta $DSTDIR
