#!/bin/bash
set -e

echo "🚀 Building Terminas for macOS..."

# Ensure Xcode toolchain is active
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

# Build executable in release mode
swift build -c release

APP_NAME="Terminas"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Packaging ${APP_NAME}.app..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"
cp "Resources/Info.plist" "${CONTENTS_DIR}/"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${RESOURCES_DIR}/"
fi

# Ad-hoc code signing for local macOS execution
codesign --force --deep --sign - "${APP_DIR}"

if [ -d "/Applications/${APP_NAME}.app" ]; then
    echo "🔄 Updating /Applications/${APP_NAME}.app with latest build..."
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "${APP_DIR}" "/Applications/${APP_NAME}.app"
fi

echo "✅ Successfully built ${APP_DIR}!"
echo "💡 You can launch it with: open ${APP_DIR}"
