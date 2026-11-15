#!/bin/bash
set -e

APP_NAME="MouseBack"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Menyiapkan direktori bundle..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "🚀 Mengompilasi kode sumber Swift..."
swiftc -O \
    Sources/HUDWindow.swift \
    Sources/EventTapManager.swift \
    Sources/AppDelegate.swift \
    Sources/main.swift \
    -o "${MACOS_DIR}/${APP_NAME}"

echo "📦 Menyalin Info.plist dan AppIcon..."
cp Info.plist "${CONTENTS_DIR}/Info.plist"
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"
fi

echo "🔏 Menandatangani aplikasi dengan Designated Requirement stabil..."
codesign --force --deep --sign - \
    --identifier "com.dany.mouseback" \
    --requirements '=designated => identifier "com.dany.mouseback"' \
    "${BUNDLE_DIR}"

echo "✅ Berhasil! Aplikasi tersedia di: ${BUNDLE_DIR}"
