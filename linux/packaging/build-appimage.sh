#!/usr/bin/env bash
# Package the Flutter Linux release bundle into a self-contained AppImage.
#
# The AppImage bundles the GTK runtime and every other shared library the
# Flutter engine needs, so the installer runs on distros that don't ship
# GTK3. glibc is the one thing that is NOT bundled (it can't be), so the
# minimum supported glibc equals the build host's. Build on the oldest
# glibc you want to support.
set -euo pipefail

VERSION="${1:?usage: build-appimage.sh <version>}"

RELEASE_DIR="build/linux/x64/release"
BUNDLE_DIR="$RELEASE_DIR/bundle"
APPDIR="$RELEASE_DIR/AppDir"
PKG_DIR="linux/packaging"
TOOLS_DIR="build/linux/appimage-tools"

# CI runners usually can't mount FUSE; run the AppImage tools by extracting
# them instead of mounting.
export APPIMAGE_EXTRACT_AND_RUN=1

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" \
         "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# The Flutter runner finds data/ via its CWD and lib/ via an $ORIGIN/lib
# rpath, so the executable, data/ and lib/ must stay siblings. Keep the
# bundle layout intact under usr/bin.
cp -a "$BUNDLE_DIR/." "$APPDIR/usr/bin/"

cp "$PKG_DIR/librescoot-installer.desktop" \
   "$APPDIR/usr/share/applications/librescoot-installer.desktop"
cp linux/app_icon.png \
   "$APPDIR/usr/share/icons/hicolor/256x256/apps/librescoot-installer.png"

mkdir -p "$TOOLS_DIR"
fetch() {
  local dest="$1" url="$2"
  if [ ! -x "$dest" ]; then
    curl -fsSL --retry 3 --retry-delay 2 -o "$dest" "$url"
    chmod +x "$dest"
  fi
}
# linuxdeploy publishes only a rolling "continuous" release.
fetch "$TOOLS_DIR/linuxdeploy" \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
fetch "$TOOLS_DIR/linuxdeploy-plugin-gtk.sh" \
  https://github.com/linuxdeploy/linuxdeploy-plugin-gtk/releases/download/continuous/linuxdeploy-plugin-gtk.sh

# linuxdeploy discovers plugins by name on PATH.
export PATH="$PWD/$TOOLS_DIR:$PATH"
export OUTPUT="librescoot-installer-linux-x86_64-${VERSION}.AppImage"

"$TOOLS_DIR/linuxdeploy" \
  --appdir "$APPDIR" \
  --executable "$APPDIR/usr/bin/librescoot_installer" \
  --desktop-file "$APPDIR/usr/share/applications/librescoot-installer.desktop" \
  --icon-file "$APPDIR/usr/share/icons/hicolor/256x256/apps/librescoot-installer.png" \
  --plugin gtk \
  --output appimage

mv "$OUTPUT" "$RELEASE_DIR/$OUTPUT"
echo "Built $RELEASE_DIR/$OUTPUT"
