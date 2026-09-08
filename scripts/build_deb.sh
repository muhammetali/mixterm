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

# Strip build-host paths out of RUNPATH.
#
# Flutter leaves the paths of the machine that built the code inside the
# shipped libraries — lintian reports them as errors, and it is right to:
#
#   RUNPATH /home/runner/work/mixterm/mixterm/linux/flutter/ephemeral
#   RUNPATH /usr/lib/jvm/temurin-11-jdk-amd64/lib/server
#
# Neither exists on anyone else's computer. They are harmless only because
# the loader finds the libraries by another route first; as instructions to
# the loader they are wrong, and they tell a reader of the package where it
# happened to be built.
#
# Relative entries — $ORIGIN and friends — are how the app finds its own
# libraries, so only absolute ones are removed.
for lib in "$STAGING_DIR"/usr/lib/mixterm/lib/*.so "$STAGING_DIR/usr/lib/mixterm/mixterm"; do
  [ -f "$lib" ] || continue

  current="$(patchelf --print-rpath "$lib" 2>/dev/null || true)"
  [ -n "$current" ] || continue

  kept=""
  IFS=':' read -ra entries <<< "$current"
  for entry in "${entries[@]}"; do
    case "$entry" in
      /*) continue ;;
      "") continue ;;
      *) kept="${kept:+$kept:}$entry" ;;
    esac
  done

  if [ "$kept" = "$current" ]; then
    continue
  elif [ -n "$kept" ]; then
    patchelf --set-rpath "$kept" "$lib"
    echo "  rpath trimmed: $(basename "$lib") -> $kept"
  else
    patchelf --remove-rpath "$lib"
    echo "  rpath removed: $(basename "$lib")"
  fi
done

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

# Copyright file.
#
# Debian policy requires one, and requires it to cover everything the
# package redistributes — which here is not only the app. The bundle
# carries eight typefaces and a vendored fork of xterm.dart, all under
# licences that ask to travel with the software. A copyright file naming
# only MixTerm would be a package that ships eight fonts and mentions none
# of them.
#
# Assembled from the licence files themselves rather than retyped, so it
# cannot drift from what is actually bundled. DEP-5 wants each licence
# body indented by one space, with blank lines written as " .".
indent_licence() {
  # CR has to go first. Three of these files are CRLF, so an empty line
  # arrives as "\r"; indented it becomes " \r", which `s/^ $/ ./` does not
  # match. The result was a body containing bare " " lines, which ends the
  # stanza as far as a DEP-5 parser is concerned — a copyright file that
  # looks right in a terminal and is malformed to anything reading it.
  tr -d '\r' < "$1" | sed -e 's/^/ /' -e 's/^ $/ ./'
}

copyright="$STAGING_DIR/usr/share/doc/${PKG_NAME}/copyright"
mkdir -p "$(dirname "$copyright")"

# Each bundled typeface gets its own licence stanza, taken from its own
# file. They are not interchangeable: the seven OFL texts here reduce to
# five distinct documents even after normalising line endings — they differ
# in the reserved font name, the FAQ URL and the preamble — so quoting one
# of them for all seven would attribute terms to fonts that do not carry
# them.
#
# Columns: file-pattern | copyright holder | licence id | licence file.
FONT_LICENCES=(
  "assets/fonts/CascadiaMono*|2019-present Microsoft Corporation|OFL-1.1-CascadiaMono|CascadiaMono-OFL.txt"
  "assets/fonts/FiraCode*|2014-2020 The Fira Code Project Authors|OFL-1.1-FiraCode|FiraCode-OFL.txt"
  "assets/fonts/GeistMono*|2024 The Geist Project Authors|OFL-1.1-GeistMono|GeistMono-OFL.txt"
  "assets/fonts/IBMPlexMono*|2017 IBM Corp.|OFL-1.1-IBMPlexMono|IBMPlexMono-OFL.txt"
  "assets/fonts/Inter*|2020 The Inter Project Authors|OFL-1.1-Inter|Inter-OFL.txt"
  "assets/fonts/JetBrainsMono*|2020 The JetBrains Mono Project Authors|OFL-1.1-JetBrainsMono|JetBrainsMono-OFL.txt"
  "assets/fonts/SourceCodePro*|2010, 2012 Adobe Systems Incorporated|OFL-1.1-SourceCodePro|SourceCodePro-OFL.txt"
  "assets/fonts/Ubuntu*|2010-2011 Canonical Ltd.|UFL-1.0|UbuntuMono-LICENCE.txt"
)

# Fail loudly if a font is added without a licence entry, rather than
# shipping it unattributed.
for licence in assets/fonts/LICENSES/*; do
  name="$(basename "$licence")"
  if ! printf '%s\n' "${FONT_LICENCES[@]}" | grep -q "|${name}\$"; then
    echo "error: $name is bundled but has no entry in FONT_LICENCES" >&2
    exit 1
  fi
done

{
  cat <<'HEADER'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: mixterm
Source: https://github.com/muhammetali/mixterm

Files: *
Copyright: 2025-2026 Muhammet Ali Özçelik
License: MIT

Files: packages/xterm/*
Copyright: 2020 xuty
License: MIT

HEADER

  # One Files stanza per typeface, naming the licence it actually carries.
  for entry in "${FONT_LICENCES[@]}"; do
    IFS='|' read -r pattern holder licence_id _ <<< "$entry"
    printf 'Files: %s\nCopyright: %s\nLicense: %s\n\n' \
      "$pattern" "$holder" "$licence_id"
  done

  echo "License: MIT"
  indent_licence LICENSE

  # And one licence body per typeface, from that typeface's own file.
  for entry in "${FONT_LICENCES[@]}"; do
    IFS='|' read -r _ _ licence_id licence_file <<< "$entry"
    echo
    echo "License: $licence_id"
    indent_licence "assets/fonts/LICENSES/$licence_file"
  done
} > "$copyright"

# Changelog. Debian requires one for a native package, and lintian reports
# its absence as an error. The release notes live on GitHub rather than in
# the tree, so this points at them instead of duplicating them badly.
#
# gzip -9n: -n leaves the timestamp out, so building the same version twice
# produces the same bytes.
changelog_dir="$STAGING_DIR/usr/share/doc/${PKG_NAME}"
mkdir -p "$changelog_dir"
{
  echo "${PKG_NAME} (${VERSION}) unstable; urgency=medium"
  echo
  echo "  * Release notes: https://github.com/muhammetali/mixterm/releases/tag/v${VERSION}"
  echo
  echo " -- Muhammet Ali Özçelik <noreply@mixterm.app>  $(date -R)"
} | gzip -9n > "$changelog_dir/changelog.gz"

# Dependencies, computed from the binaries rather than declared by hand.
#
# The control template used to say `Depends: libgtk-3-0` and nothing else.
# That is not a description of what the package needs: the app and its
# bundled Flutter libraries are linked against whatever glibc the build host
# had, and saying nothing about it means apt installs the package on a system
# that cannot run it. The snap hit the same wall from the other direction and
# refused to start with "libgtk-3.so.0: version `GLIBC_2.38' not found".
#
# dpkg-shlibdeps reads the ELF symbols and produces the real answer,
# including the libc6 floor, so this cannot drift when the build host moves.
DEPENDS_DIR="build/deb/shlibdeps"
rm -rf "$DEPENDS_DIR"
mkdir -p "$DEPENDS_DIR/debian"

# dpkg-shlibdeps insists on a debian/control to take the package name from,
# even with -O printing to stdout.
cat > "$DEPENDS_DIR/debian/control" <<EOF
Source: ${PKG_NAME}
Package: ${PKG_NAME}
Architecture: ${ARCH}
EOF

# --ignore-missing-info because the bundled Flutter libraries belong to no
# package; their own dependencies still get read from their symbols.
DEPENDS="$(
  cd "$DEPENDS_DIR" && dpkg-shlibdeps -O --ignore-missing-info \
    "$PROJECT_DIR/$STAGING_DIR/usr/lib/mixterm/mixterm" \
    "$PROJECT_DIR/$STAGING_DIR"/usr/lib/mixterm/lib/*.so 2>/dev/null \
    | sed -n 's/^shlibs:Depends=//p'
)"

if [ -z "$DEPENDS" ]; then
  echo "error: dpkg-shlibdeps produced no dependencies — refusing to ship a" >&2
  echo "       package that does not say what it needs" >&2
  exit 1
fi

# libc6 is the one that matters here, and its absence is what made the
# previous package installable on systems it could not run on.
case "$DEPENDS" in
  *libc6*) : ;;
  *) echo "error: computed dependencies name no libc6: $DEPENDS" >&2; exit 1 ;;
esac

echo "Computed dependencies: $DEPENDS"

# Control file with the real version and dependencies substituted in
sed -e "s/__VERSION__/${VERSION}/" \
    -e "s|__DEPENDS__|${DEPENDS}|" \
    packaging/debian/control.template \
  > "$STAGING_DIR/DEBIAN/control"

# Written as an `if` rather than `grep && { }`: under `set -e` the latter's
# exit status depends on a bash subtlety nobody should have to recall.
if grep -q '__' "$STAGING_DIR/DEBIAN/control"; then
  echo "error: unsubstituted placeholder left in control:" >&2
  grep '__' "$STAGING_DIR/DEBIAN/control" >&2
  exit 1
fi

DEB_FILE="build/deb/mixterm_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "$STAGING_DIR" "$DEB_FILE"

echo "Built: $DEB_FILE"
