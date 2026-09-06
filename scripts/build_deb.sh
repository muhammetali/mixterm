#!/bin/bash
# Builds a .deb package from the Flutter Linux release bundle.
# Must run on a Linux host (or CI runner) — Flutter cannot cross-compile
# the Linux target from macOS/Windows.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

VERSION="$(grep '^version:' pubspec.yaml | sed -E 's/version:\s*([0-9.]+).*/\1/')"
ARCH="amd64"
PKG_NAME="mixterm"
STAGING_DIR="build/deb/${PKG_NAME}_${VERSION}_${ARCH}"

echo "Building mixterm ${VERSION} .deb package..."

flutter build linux --release

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/DEBIAN"
mkdir -p "$STAGING_DIR/usr/lib/mixterm"
mkdir -p "$STAGING_DIR/usr/bin"
mkdir -p "$STAGING_DIR/usr/share/applications"

# App bundle
cp -r build/linux/x64/release/bundle/. "$STAGING_DIR/usr/lib/mixterm/"

# Launcher symlink on PATH
ln -sf /usr/lib/mixterm/mixterm "$STAGING_DIR/usr/bin/mixterm"

# Desktop entry (Exec must point at the installed launcher, not a relative path)
sed 's|Exec=mixterm|Exec=/usr/bin/mixterm|' linux/runner/mixterm.desktop \
  > "$STAGING_DIR/usr/share/applications/com.mixterm.mixterm.desktop"

# Icons
for size in 16 24 32 48 64 128 256 512; do
  icon_dir="$STAGING_DIR/usr/share/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$icon_dir"
  cp "assets/icons/linux/mixterm_${size}.png" "$icon_dir/mixterm.png"
done

# Control file with the real version substituted in
sed "s/__VERSION__/${VERSION}/" packaging/debian/control.template \
  > "$STAGING_DIR/DEBIAN/control"

DEB_FILE="build/deb/mixterm_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "$STAGING_DIR" "$DEB_FILE"

echo "Built: $DEB_FILE"
