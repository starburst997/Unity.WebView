#!/bin/sh

cd "$(dirname "$0")"

# Android SDK read-only fix
echo "ANDROID SDK HOME:"
echo ${ANDROID_HOME}

OLD_ANDROID_HOME=${ANDROID_HOME}
export ANDROID_HOME="./sdk"

echo ${ANDROID_HOME}

mkdir -p ${ANDROID_HOME}

# Accept license (couldn't find a way to accept them automatically, need to copy the license file)
# yes | sdkmanager --licenses

# Add your license as a ENV vars to your CI (SDK=30, Build Tools=30.0.3)
mkdir -p "${ANDROID_HOME}/licenses"
echo -e "\n${ANDROID_LICENSE}" >> "${ANDROID_HOME}/licenses/android-sdk-license"

# Build
ANDROID_HOME="./sdk" ./gradlew clean
ANDROID_HOME="./sdk" ./gradlew assembleRelease

# Revert
export ANDROID_HOME="${OLD_ANDROID_HOME}"

# Copy build to plugins
DEST_DIR='../../Plugins/Android'
mkdir -p "${DEST_DIR}"

ls -la "./lib/build"
ls -la "./lib/build/outputs"
ls -la "./lib/build/outputs/aar"

ls -la "./build"
ls -la "./build/outputs"
ls -la "./build/outputs/aar"

cp "./lib/build/outputs/aar/"*.aar "${DEST_DIR}/WebViewPlugin.aar"
cp "./build/outputs/aar/"*.aar "${DEST_DIR}/WebViewPlugin.aar"

# Cleanup
rm -rf "${BUILD_DIR}/build"

# Copy meta
cp *.aar.meta ${DEST_DIR}