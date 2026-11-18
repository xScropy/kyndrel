#!/usr/bin/env bash
# Portable AppImage (task 5.6). After `flutter build linux --release`:
#   packaging/linux/make_appimage.sh 1.0.0
# Output: build/installer/Kyndrel-<version>-x86_64.AppImage
#
# Needs linuxdeploy and its AppImage plugin on PATH (CI downloads them):
#   linuxdeploy-x86_64.AppImage, linuxdeploy-plugin-appimage-x86_64.AppImage
# Unlike the .deb, this bundles libmpv, FFmpeg and SQLite, so it runs on
# distributions without libmpv2. Build it on the oldest distribution you
# want to support (glibc is not bundled).
set -euo pipefail
cd "$(dirname "$0")/../.."
VERSION=${1:?version}
BUNDLE=build/linux/x64/release/bundle
OUT=build/installer
LINUXDEPLOY=${LINUXDEPLOY:-linuxdeploy-x86_64.AppImage}
[ -x "$BUNDLE/kyndrel" ] || { echo "missing $BUNDLE; run flutter build linux --release" >&2; exit 1; }
command -v "$LINUXDEPLOY" >/dev/null || { echo "need $LINUXDEPLOY on PATH" >&2; exit 1; }
mkdir -p "$OUT"

APPDIR=$(mktemp -d)/Kyndrel.AppDir
trap 'rm -rf "$(dirname "$APPDIR")"' EXIT
install -d "$APPDIR/usr/lib/kyndrel" "$APPDIR/usr/bin"
cp -a "$BUNDLE/." "$APPDIR/usr/lib/kyndrel/"
# SQLite: ship the runtime library under the name the hook dlopens.
SQLITE=$(ldconfig -p | awk '/libsqlite3\.so\.0 .*x86-64/ {print $NF; exit}')
cp -L "$SQLITE" "$APPDIR/usr/lib/kyndrel/lib/libsqlite3.so"

# Desktop entry's Exec=kyndrel must exist in usr/bin. Flutter finds its
# data/ and lib/ next to the real executable (/proc/self/exe), so a
# symlink is enough.
ln -s ../lib/kyndrel/kyndrel "$APPDIR/usr/bin/kyndrel"

APPRUN="$(dirname "$APPDIR")/AppRun"
cat > "$APPRUN" <<'RUN'
#!/bin/sh
HERE=$(dirname "$(readlink -f "$0")")
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"
exec "$HERE/usr/lib/kyndrel/kyndrel" "$@"
RUN
chmod 755 "$APPRUN"

# Pull in libmpv, FFmpeg and their dependencies (linked from the plugins
# in lib/), with linuxdeploy's exclude list for system libraries.
DEPLOY_ARGS=()
for so in "$APPDIR"/usr/lib/kyndrel/lib/*.so; do
  DEPLOY_ARGS+=(--deploy-deps-only "$so")
done
export OUTPUT="$OUT/Kyndrel-$VERSION-x86_64.AppImage"
export VERSION
"$LINUXDEPLOY" --appdir "$APPDIR" \
  --executable "$APPDIR/usr/lib/kyndrel/kyndrel" \
  "${DEPLOY_ARGS[@]}" \
  --desktop-file linux/kyndrel.desktop \
  --icon-file packaging/linux/icons/256x256/kyndrel.png \
  --custom-apprun "$APPRUN" \
  --output appimage
echo "$OUTPUT"
