#!/bin/sh

cd "$(dirname "$0")"

CWD=`dirname $0`

BUILD_DIR="${CWD}/lib"

# Android SDK read-only fix
echo "ANDROID SDK ROOT:"
echo ${ANDROID_SDK_ROOT}

echo "ANDROID SDK HOME:"
echo ${ANDROID_HOME}

OLD_ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT}
export ANDROID_SDK_ROOT="./sdk"

OLD_ANDROID_HOME=${ANDROID_HOME}
export ANDROID_HOME="./sdk"

echo ${ANDROID_SDK_ROOT}
echo ${ANDROID_HOME}

mkdir -p ${ANDROID_SDK_ROOT}

# Accept license (couldn't find a way to accept them automatically, need to copy the license file)
# yes | sdkmanager --licenses

# Add your license as a ENV vars to your CI (SDK=30, Build Tools=30.0.3)
mkdir -p "${ANDROID_SDK_ROOT}/licenses"
echo -e "\n${ANDROID_LICENSE}" >> "${ANDROID_SDK_ROOT}/licenses/android-sdk-license"

# Build
ANDROID_HOME="./sdk" ./gradlew clean
ANDROID_HOME="./sdk" ./gradlew assembleRelease

# Revert
export ANDROID_SDK_ROOT="${OLD_ANDROID_SDK_ROOT}"
export ANDROID_HOME="${OLD_ANDROID_HOME}"

# Copy build to plugins
DEST_DIR='../../Plugins/Android'
mkdir -p "${DEST_DIR}"

ls -la "${BUILD_DIR}/build"
ls -la "${BUILD_DIR}/build/outputs"
ls -la "${BUILD_DIR}/build/outputs/aar"

ls -la "${CWD}/build"
ls -la "${CWD}/build/outputs"
ls -la "${CWD}/build/outputs/aar"

cp "${BUILD_DIR}/build/outputs/aar/"*.aar "${DEST_DIR}/WebViewPlugin.aar"
cp "${CWD}/build/outputs/aar/"*.aar "${DEST_DIR}/WebViewPlugin.aar"

# Cleanup
rm -rf "${BUILD_DIR}/build"

# Copy meta
cp *.aar.meta ${DEST_DIR}