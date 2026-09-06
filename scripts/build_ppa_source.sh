#!/bin/bash
# Assembles a Debian *native* source package for uploading to a Launchpad
# PPA. Must run on Linux (needs `flutter build linux`) with `devscripts`
# and `debhelper` installed, and a GPG key registered with your Launchpad
# account for the final `debuild -S -sa` signing step.
#
# This does NOT upload anything — that's a separate, deliberate step:
#   dput ppa:<your-launchpad-id>/mixterm ../mixterm_<version>_source.changes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

VERSION="$(grep '^version:' pubspec.yaml | sed -E 's/version:\s*([0-9.]+).*/\1/')"
PKG_DIR="build/ppa/mixterm-${VERSION}"

echo "Assembling mixterm ${VERSION} PPA source package..."

flutter build linux --release

rm -rf "build/ppa"
mkdir -p "$PKG_DIR"

cp -r build/linux/x64/release/bundle "$PKG_DIR/bundle"
cp -r linux "$PKG_DIR/linux"
cp -r assets "$PKG_DIR/assets"
cp -r packaging/debian-source/debian "$PKG_DIR/debian"

echo
echo "Source tree ready at: $PKG_DIR"
echo "Next steps (run manually, on Linux, with your own Launchpad GPG key):"
echo "  cd $PKG_DIR"
echo "  debuild -S -sa"
echo "  dput ppa:<your-launchpad-id>/mixterm ../mixterm_${VERSION}-1_source.changes"
echo
echo "Repeat with the changelog's distribution field changed (e.g. jammy,"
echo "noble) for each Ubuntu series you want to support — a PPA build is"
echo "per-series."
