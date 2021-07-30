#!/bin/sh

cd "$(dirname "$0")"

CWD=`dirname $0`

BUILD_DIR="${CWD}/lib"

# Android SDK read-only fix
echo "ANDROID SDK ROOT:"
echo ${ANDROID_SDK_ROOT}

OLD_ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT}
export ANDROID_SDK_ROOT="./sdk"

echo ${ANDROID_SDK_ROOT}

mkdir -p ${ANDROID_SDK_ROOT}

# Accept license (couldn't find a way to accept them automatically, need to copy the license file)
# yes | sdkmanager --licenses

# Add your license as a ENV vars to your CI (SDK=30, Build Tools=30.0.3)
mkdir -p "${ANDROID_SDK_ROOT}/licenses"
echo -e "\n${ANDROID_LICENSE}" >> "${ANDROID_SDK_ROOT}/licenses/android-sdk-license"

# Build
./gradlew clean
./gradlew assembleRelease

# Revert
export ANDROID_SDK_ROOT="${OLD_ANDROID_SDK_ROOT}"

# Copy build to plugins
DEST_DIR='../../Plugins/Android'
mkdir -p "${DEST_DIR}"
cp "${BUILD_DIR}/build/outputs/aar/"*.aar "${DEST_DIR}/WebViewPlugin.aar"

# Cleanup
rm -rf "${BUILD_DIR}/build"

# Copy meta
cp *.aar.meta ${DEST_DIR}