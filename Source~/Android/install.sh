#!/bin/sh

cd "$(dirname "$0")"

CWD=`dirname $0`

BUILD_DIR="${CWD}/gradle_build"
LIBS_DIR="${BUILD_DIR}/libs"
JAVA_DIR="${BUILD_DIR}/src/main/java"
BIN_DIR="${CWD}/bin"

# options
MODE="Release"
SCRIPTING_BACKEND="il2cpp"
UNITY=$1

echo "Unity Path:"
echo $UNITY

UNITY_JAVA_LIB="${UNITY}/PlaybackEngines/AndroidPlayer/Variations/${SCRIPTING_BACKEND}/${MODE}/Classes/classes.jar"

# Fix SDK issue
export ANDROID_SDK_ROOT="${UNITY}/PlaybackEngines/AndroidPlayer/SDK"

#rm -rf "${CWD}/sdk"
#cp -r "${UNITY}/PlaybackEngines/AndroidPlayer/SDK" "${CWD}/sdk"
#chmod -R 777 "${CWD}/sdk"
#export ANDROID_SDK_ROOT="${CWD}/sdk"

# yes | sdkmanager --licenses

# clean
rm -rf "${JAVA_DIR}"/*
rm -rf "${LIB_DIR}"
rm -rf "${BUILD_DIR}/src"

# build
mkdir -p "${LIBS_DIR}"
mkdir -p "${BIN_DIR}"
mkdir -p "${JAVA_DIR}"

cp "${UNITY_JAVA_LIB}" "${LIBS_DIR}"
#chmod -R 777 "${LIBS_DIR}"

cp -r src/jd "${JAVA_DIR}"
cp AndroidManifest.xml "${BUILD_DIR}/src/main"

./gradlew clean
./gradlew assembleRelease
cp "${BUILD_DIR}/build/outputs/aar/"*.aar "${BIN_DIR}/WebViewPlugins.aar"

# install
DEST_DIR='../../Plugins/Android'
mkdir -p "${DEST_DIR}"
cp "${BIN_DIR}/WebViewPlugins.aar" "${DEST_DIR}/WebViewPlugin.aar"

# cleanup
rm -rf "${CWD}/sdk"
rm -rf "${JAVA_DIR}"/*
rm -rf "${LIB_DIR}"
rm -f "${BUILD_DIR}/src/main/AndroidManifest.xml"