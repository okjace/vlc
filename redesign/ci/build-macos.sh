#!/usr/bin/env bash
# Build VLC Redesign for macOS and package it as "VLC Redesign.app" inside a
# custom DMG (dark background with drag-to-Applications arrow), plus a zip.
#
# Usage: redesign/ci/build-macos.sh <x86_64|arm64>
#
# Uses VideoLAN's prebuilt contribs when VLC_PREBUILT_CONTRIBS_URL is set.

set -euo pipefail

ARCH="${1:?usage: $0 <x86_64|arm64>}"
SRC_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$SRC_DIR/build-macos-$ARCH}"
OUT_DIR="${OUT_DIR:-$SRC_DIR/out}"
JOBS="$(sysctl -n hw.ncpu)"

case "$ARCH" in
    x86_64) VLC_ARCH=x86_64 ;;
    arm64|aarch64) VLC_ARCH=aarch64; ARCH=arm64 ;;
    *) echo "unknown arch $ARCH" >&2; exit 1 ;;
esac

mkdir -p "$BUILD_DIR" "$OUT_DIR"

echo "::group::Build VLC ($ARCH)"
cd "$BUILD_DIR"
# No Sparkle: it would "update" this fork to the official VLC.
# No ncurses: a terminal UI is useless in the .app, and the prebuilt ncurses
# references the SDK path of VideoLAN's build machine, which breaks linking.
export VLC_CONFIGURE_ARGS="${VLC_CONFIGURE_ARGS:-} --disable-sparkle --disable-ncurses"
"$SRC_DIR/extras/package/macosx/build.sh" -d -a "$VLC_ARCH" -j "$JOBS"
echo "::endgroup::"

VERSION="$(sed -n 's/^#define PACKAGE_VERSION "\(.*\)"/\1/p' config.h)"
APP="$BUILD_DIR/VLC Redesign.app"

echo "::group::Prepare VLC Redesign.app"
rm -rf "$APP"
cp -Rp "$BUILD_DIR/VLC.app" "$APP"
# Unsigned CI builds: give the bundle an ad-hoc signature so Apple Silicon
# will run it (users still need to right-click > Open the first time).
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP" || true
echo "::endgroup::"

echo "::group::Create DMG"
python3 -m pip install --quiet --break-system-packages dmgbuild 2>/dev/null \
    || python3 -m pip install --quiet dmgbuild

# Volume icon from the redesign icon
ICONSET="$BUILD_DIR/vlc-redesign.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
SRC_ICON="$SRC_DIR/redesign/branding/vlc-redesign-512.png"
for size in 16 32 128 256 512; do
    sips -z $size $size "$SRC_ICON" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    [ $double -le 512 ] && sips -z $double $double "$SRC_ICON" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$BUILD_DIR/vlc-redesign-volume.icns"

DMG="$OUT_DIR/vlc-redesign-$VERSION-macos-$ARCH.dmg"
rm -f "$DMG"
cd "$SRC_DIR/extras/package/macosx/dmg"
dmgbuild -s dmg_settings.py \
    -D app="$APP" \
    -D icon="$BUILD_DIR/vlc-redesign-volume.icns" \
    "VLC Redesign" "$DMG"
echo "::endgroup::"

echo "::group::Create zip"
cd "$BUILD_DIR"
ditto -c -k --sequesterRsrc --keepParent "VLC Redesign.app" \
    "$OUT_DIR/vlc-redesign-$VERSION-macos-$ARCH.app.zip"
echo "::endgroup::"

ls -la "$OUT_DIR"
