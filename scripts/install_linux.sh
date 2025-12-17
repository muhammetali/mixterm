#!/bin/bash
# MixTerm Linux Installer

set -e

APP_NAME="mixterm"
APP_ID="com.mixterm.mixterm"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== MixTerm Linux Installer ==="
echo ""

# Build release version
echo "Building release version..."
cd "$PROJECT_DIR"
flutter build linux --release

BUNDLE_DIR="$PROJECT_DIR/build/linux/x64/release/bundle"

# Install icons
echo "Installing icons..."
ICON_DIR="$HOME/.local/share/icons/hicolor"
for size in 16 24 32 48 64 128 256 512; do
    mkdir -p "$ICON_DIR/${size}x${size}/apps"
    cp "$PROJECT_DIR/assets/icons/linux/mixterm_${size}.png" \
       "$ICON_DIR/${size}x${size}/apps/mixterm.png" 2>/dev/null || true
done

# Update icon cache
gtk-update-icon-cache -f -t "$ICON_DIR" 2>/dev/null || true

# Create desktop file
echo "Creating desktop entry..."
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/$APP_ID.desktop" << EOF
[Desktop Entry]
Name=MixTerm
Comment=Professional SSH/SFTP Client
Exec=$BUNDLE_DIR/mixterm
Icon=mixterm
Terminal=false
Type=Application
Categories=Network;RemoteAccess;System;Utility;
Keywords=ssh;sftp;terminal;remote;server;connection;
StartupWMClass=$APP_ID
EOF

# Update desktop database
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo ""
echo "=== Installation Complete ==="
echo ""
echo "MixTerm has been installed!"
echo "You can now find it in your applications menu."
echo ""
echo "To run: $BUNDLE_DIR/mixterm"
echo "Or search for 'MixTerm' in your applications."
