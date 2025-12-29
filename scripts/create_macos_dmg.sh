#!/bin/bash

# MixTerm macOS DMG Creator Script
# This script bundles the built .app into a DMG with an Applications folder shortcut.

APP_NAME="mixterm"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_NAME="MixTerm-Installer.dmg"
VOLUME_NAME="MixTerm Installer"

echo "Checking if app exists at ${APP_PATH}..."
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found. Please run 'flutter build macos --release' first."
    exit 1
fi

echo "Cleaning old DMG if exists..."
rm -f "$DMG_NAME"

echo "Creating temporary directory..."
mkdir -p build/dmg_temp
cp -R "$APP_PATH" build/dmg_temp/
ln -s /Applications build/dmg_temp/Applications

echo "Creating DMG..."
hdiutil create -volname "$VOLUME_NAME" -srcfolder build/dmg_temp -ov -format UDZO "$DMG_NAME"

echo "Cleaning up..."
rm -rf build/dmg_temp

echo "Success! DMG created: $DMG_NAME"
echo "You can now open $DMG_NAME to see the 'Drag to Applications' window."
