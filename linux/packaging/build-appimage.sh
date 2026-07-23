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
# The GTK plugin has no releases; its script lives on master. Pin to a
# commit so the build is reproducible instead of tracking the branch tip.
GTK_PLUGIN_REF=3b67a1d1c1b0c8268f57f2bce40fe2d33d409cea
fetch "$TOOLS_DIR/linuxdeploy-plugin-gtk.sh" \
  "https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/${GTK_PLUGIN_REF}/linuxdeploy-plugin-gtk.sh"

# linuxdeploy discovers plugins by name on PATH.
export PATH="$PWD/$TOOLS_DIR:$PATH"
OUTPUT="librescoot-installer-linux-x86_64-${VERSION}.AppImage"

# Populate the AppDir (bundle the Flutter libs + GTK runtime, write AppRun,
# the root desktop file and icon) but stop short of the final packaging.
# We invoke appimagetool ourselves below so we can supply the runtime.
"$TOOLS_DIR/linuxdeploy" \
  --appdir "$APPDIR" \
  --executable "$APPDIR/usr/bin/librescoot_installer" \
  --desktop-file "$APPDIR/usr/share/applications/librescoot-installer.desktop" \
  --icon-file "$APPDIR/usr/share/icons/hicolor/256x256/apps/librescoot-installer.png" \
  --plugin gtk

# AppImageKit is archived; appimagetool is now the rewrite that downloads the
# AppImage runtime at package time instead of embedding it. Its built-in
# fetch doesn't follow GitHub's 302 redirect to the asset CDN and fails the
# build. Our fetch() uses curl -L (which does follow redirects), so pre-fetch
# both the tool and the runtime and hand the runtime over with --runtime-file
# so appimagetool never downloads anything itself.
fetch "$TOOLS_DIR/appimagetool" \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
fetch "$TOOLS_DIR/runtime-x86_64" \
  https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64

"$TOOLS_DIR/appimagetool" \
  --runtime-file "$TOOLS_DIR/runtime-x86_64" \
  "$APPDIR" "$RELEASE_DIR/$OUTPUT"

echo "Built $RELEASE_DIR/$OUTPUT"
