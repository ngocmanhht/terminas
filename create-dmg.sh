#!/bin/bash
set -e

echo "📦 Generating professional Terminas.dmg installer..."

# Ensure Terminas.app is built
if [ ! -d "Terminas.app" ]; then
    echo "🔨 Terminas.app not found. Running build-app.sh first..."
    ./build-app.sh
fi

DMG_NAME="Terminas.dmg"
VOL_NAME="Terminas"
TEMP_DIR=".dmg_staging"

rm -rf "${TEMP_DIR}"
rm -f "${DMG_NAME}"
mkdir -p "${TEMP_DIR}"

echo "📁 Copying Terminas.app and Applications shortcut..."
cp -R "Terminas.app" "${TEMP_DIR}/"
ln -s /Applications "${TEMP_DIR}/Applications"

echo "💿 Creating compressed disk image (UDZO)..."
hdiutil create \
    -volname "${VOL_NAME}" \
    -srcfolder "${TEMP_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_NAME}"

rm -rf "${TEMP_DIR}"

echo "✅ Successfully generated: ${DMG_NAME}!"
ls -lh "${DMG_NAME}"
