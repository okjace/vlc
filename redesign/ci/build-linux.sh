#!/usr/bin/env bash
# Build VLC Redesign for Linux x86_64 and package it as an AppImage.
#
# VLC 3.0 branch. Runs on Ubuntu 24.04 (GitHub Actions ubuntu-24.04) using the
# distribution's own VLC 3 build dependencies (Qt 5).
#
# Output: VLC-Redesign-<version>-Linux-x86_64.AppImage in $OUT_DIR (default: ./out)

set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORK_DIR="${WORK_DIR:-$SRC_DIR/build-linux}"
OUT_DIR="${OUT_DIR:-$SRC_DIR/out}"
QT_DIR=/usr/lib/x86_64-linux-gnu/qt5
JOBS="$(nproc)"

mkdir -p "$WORK_DIR" "$OUT_DIR"

step() { echo "::group::$*"; }
endstep() { echo "::endgroup::"; }

step "Install build dependencies"
export DEBIAN_FRONTEND=noninteractive
# VLC 3's own build dependencies from Ubuntu's vlc source package
sudo sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
sudo apt-get update -qq
sudo apt-get build-dep -y vlc
sudo apt-get install -y --no-install-recommends \
    qtbase5-dev qtbase5-private-dev libqt5svg5-dev libqt5x11extras5-dev qtwayland5 \
    qt5-qmake qtbase5-dev-tools libqt5waylandclient5 \
    build-essential autoconf automake libtool autopoint gettext pkg-config \
    bison flex meson ninja-build cmake git wget file desktop-file-utils \
    python3 python3-pip python3-venv patchelf \
    lua5.2 liblua5.2-dev \
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev \
    liba52-0.7.4-dev libmad0-dev libmpeg2-4-dev libdvbpsi-dev libebml-dev libmatroska-dev \
    libass-dev libfreetype-dev libfribidi-dev libharfbuzz-dev libfontconfig-dev \
    libxcb1-dev libxcb-shm0-dev libxcb-composite0-dev libxcb-xv0-dev libxcb-randr0-dev \
    libxcb-keysyms1-dev libxcb-xkb-dev libxcb-cursor-dev libx11-dev libx11-xcb-dev \
    libxext-dev libxi-dev libxinerama-dev libxpm-dev libxkbcommon-dev libxkbcommon-x11-dev \
    libwayland-dev wayland-protocols libdbus-1-dev \
    libpulse-dev libasound2-dev libpipewire-0.3-dev \
    libva-dev libvdpau-dev libegl-dev libgl-dev libgles-dev libdrm-dev libvulkan-dev \
    libplacebo-dev libdav1d-dev libvpx-dev libopus-dev libvorbis-dev libogg-dev \
    libflac-dev libtheora-dev libspeex-dev libspeexdsp-dev libsamplerate0-dev \
    libmpg123-dev libtag1-dev libxml2-dev libgcrypt20-dev libgnutls28-dev \
    libdvdread-dev libdvdnav-dev libbluray-dev libcddb2-dev libcdio-dev \
    libjpeg-dev libpng-dev libarchive-dev libsoxr-dev libsqlite3-dev libxxhash-dev \
    libfuse2t64 libgl1-mesa-dri libfontconfig1 libxrender1 \
    libxcb-icccm4 libxcb-image0 libxcb-render-util0 libxcb-xinerama0 libxcb-cursor0 \
    libxcb-shape0 libxcb-sync1 libxcb-xfixes0 libxcb-util1 libxcb-glx0 libxcb-xinput0 \
    libxcb-randr0 libxcb-keysyms1 libxcb-xkb1 libxkbcommon-x11-0 libxkbcommon0 \
    libwayland-client0 libwayland-cursor0 libwayland-egl1 libdecor-0-0 \
    libopengl0 libegl1 libsm6 libice6 libxext6 libxi6
endstep

step "Configure VLC"
cd "$SRC_DIR"
[ -x configure ] || ./bootstrap
mkdir -p "$WORK_DIR/vlc" && cd "$WORK_DIR/vlc"
"$SRC_DIR/configure" \
    --prefix=/usr \
    --disable-static \
    --disable-debug \
    --enable-qt \
    --disable-update-check \
    --disable-skins2 \
    --disable-ncurses \
    --disable-vnc \
    --disable-freerdp \
    --disable-chromecast
grep -E "^(have_qt|QT_VERSION)" config.log | head || true
grep -q "define HAVE_QT 1\|ENABLE_QT" config.h || true
endstep

step "Build VLC"
make -j"$JOBS"
endstep

step "Install into AppDir"
APPDIR="$WORK_DIR/AppDir"
rm -rf "$APPDIR"
make install DESTDIR="$APPDIR"
# headers, static archives and libtool files are not needed at runtime
rm -rf "$APPDIR/usr/include" "$APPDIR/usr/lib/pkgconfig"
find "$APPDIR" -name '*.la' -delete
# (make install already generated the plugin cache via vlc-cache-gen)
VERSION="$(sed -n 's/^#define PACKAGE_VERSION "\(.*\)"/\1/p' config.h)"
endstep

step "Add VLC Redesign desktop integration"
install -Dm644 "$SRC_DIR/redesign/linux/vlc-redesign.desktop" \
    "$APPDIR/usr/share/applications/io.github.okjace.vlc_redesign.desktop"
install -Dm644 "$SRC_DIR/redesign/linux/io.github.okjace.vlc_redesign.metainfo.xml" \
    "$APPDIR/usr/share/metainfo/io.github.okjace.vlc_redesign.metainfo.xml"
install -Dm644 "$SRC_DIR/redesign/branding/vlc-redesign.png" \
    "$APPDIR/usr/share/icons/hicolor/256x256/apps/vlc-redesign.png"
install -Dm644 "$SRC_DIR/redesign/branding/vlc-redesign-512.png" \
    "$APPDIR/usr/share/icons/hicolor/512x512/apps/vlc-redesign.png"
# setup wizard (installs the AppImage like Jace Launcher does) and its assets
cmake -S "$SRC_DIR/redesign/setup" -B "$WORK_DIR/setup" -DCMAKE_BUILD_TYPE=Release \
    -DQT_DEFAULT_MAJOR_VERSION=5
cmake --build "$WORK_DIR/setup" -j"$JOBS"
install -Dm755 "$WORK_DIR/setup/vlc-redesign-setup" "$APPDIR/usr/bin/vlc-redesign-setup"
install -Dm644 "$SRC_DIR/redesign/branding/previews/nsis-welcome.png" \
    "$APPDIR/usr/share/vlc-redesign/setup-side.png"
echo "$VERSION" > "$APPDIR/usr/share/vlc-redesign/VERSION"
# drop VLC's own desktop file so only ours is picked up by appimagetool
rm -f "$APPDIR/usr/share/applications/vlc.desktop"
endstep

step "Bundle libraries and Qt with linuxdeploy"
cd "$WORK_DIR"
for tool in linuxdeploy-x86_64.AppImage linuxdeploy-plugin-qt-x86_64.AppImage appimagetool-x86_64.AppImage; do
    [ -f "$tool" ] && continue
    case $tool in
        linuxdeploy-x86_64.AppImage) url=https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/$tool ;;
        linuxdeploy-plugin-qt-x86_64.AppImage) url=https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/$tool ;;
        appimagetool-x86_64.AppImage) url=https://github.com/AppImage/appimagetool/releases/download/continuous/$tool ;;
    esac
    wget -q "$url" -O "$tool"
    chmod +x "$tool"
done

# VLC loads its modules with dlopen(), so linuxdeploy cannot see them through
# the executable; pass every plugin explicitly so their dependencies get bundled.
plugin_args=()
while IFS= read -r so; do
    plugin_args+=(--library "$so")
done < <(find "$APPDIR/usr/lib/vlc/plugins" -name '*.so')

# fail early (with the full list) if a Qt plugin we deploy has unresolved deps
missing="$(for so in "$QT_DIR"/plugins/platforms/libqxcb.so "$QT_DIR"/plugins/platforms/libqwayland*.so \
                     "$QT_DIR"/plugins/xcbglintegrations/*.so "$QT_DIR"/plugins/imageformats/*.so; do
               [ -f "$so" ] || continue
               ldd "$so" | grep "not found" || true
           done | sort -u)"
if [ -n "$missing" ]; then
    echo "Qt plugins have unresolved dependencies:"; echo "$missing"; exit 1
fi

# let linuxdeploy resolve libvlc/libvlccore from the AppDir itself
export LD_LIBRARY_PATH="$APPDIR/usr/lib:$APPDIR/usr/lib/vlc${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QMAKE=/usr/lib/qt5/bin/qmake
export EXTRA_QT_MODULES="svg"
export EXTRA_PLATFORM_PLUGINS="libqwayland-generic.so;libqwayland-egl.so;libqoffscreen.so"
export LINUXDEPLOY_OUTPUT_VERSION="$VERSION"
export APPIMAGE_EXTRACT_AND_RUN=1
export NO_STRIP=1

./linuxdeploy-x86_64.AppImage \
    --appdir "$APPDIR" \
    --executable "$APPDIR/usr/bin/vlc" \
    --executable "$APPDIR/usr/bin/vlc-redesign-setup" \
    --desktop-file "$APPDIR/usr/share/applications/io.github.okjace.vlc_redesign.desktop" \
    --icon-file "$APPDIR/usr/share/icons/hicolor/256x256/apps/vlc-redesign.png" \
    --custom-apprun "$SRC_DIR/redesign/linux/AppRun" \
    "${plugin_args[@]}" \
    --plugin qt
endstep

step "Fix up AppDir"
# --library copied every plugin into usr/lib only so its dependencies got
# deployed; VLC loads them from usr/lib/vlc/plugins, so drop the copies.
rm -f "$APPDIR"/usr/lib/*_plugin.so
find "$APPDIR/usr/lib" -name '*.a' -delete
# linuxdeploy rewrote the plugins' rpaths, so rebuild the plugin cache
LD_LIBRARY_PATH="$APPDIR/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$APPDIR/usr/lib/vlc/vlc-cache-gen" "$APPDIR/usr/lib/vlc/plugins"
endstep

step "Create AppImage"
# linuxdeploy can deploy Qt but older glibc-sensitive libs must stay on the host
for lib in libGL.so.1 libEGL.so.1 libGLX.so.0 libGLdispatch.so.0 libdrm.so.2 libgbm.so.1 \
           libva.so.2 libva-drm.so.2 libva-x11.so.2 libva-wayland.so.2 libvdpau.so.1 \
           libvulkan.so.1 libpulse.so.0 libasound.so.2 libpipewire-0.3.so.0 libwayland-client.so.0 \
           libwayland-egl.so.1 libwayland-cursor.so.0 libX11.so.6 libxcb.so.1 libfontconfig.so.1 \
           libfreetype.so.6; do
    rm -f "$APPDIR/usr/lib/$lib"
done
VERSION="$VERSION" ARCH=x86_64 ./appimagetool-x86_64.AppImage --no-appstream \
    "$APPDIR" "$OUT_DIR/VLC-Redesign-$VERSION-Linux-x86_64.AppImage"
# Keep the AppImage magic bytes: Nautilus and other file managers open
# *.AppImage files with AppImageLauncher when it's installed, and it only
# accepts files that carry them (same as Jace Launcher's AppImage). Our own
# launchers start the installed copy with APPIMAGELAUNCHER_DISABLE=1.
ls -la "$OUT_DIR"
endstep
