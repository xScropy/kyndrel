#!/usr/bin/env bash
# Debian/Ubuntu package (task 5.6). After `flutter build linux --release`:
#   packaging/linux/make_deb.sh 1.0.0
# Output: build/installer/kyndrel_<version>_amd64.deb
#
# The app goes to /opt/kyndrel with /usr/bin/kyndrel, a desktop entry
# (so it shows up in "Open with") and icons. libmpv and SQLite come from
# the system: Debian 12+, Ubuntu 23.04+ (libmpv2).
set -euo pipefail
cd "$(dirname "$0")/../.."
VERSION=${1:?version}
BUNDLE=build/linux/x64/release/bundle
OUT=build/installer
[ -x "$BUNDLE/kyndrel" ] || { echo "missing $BUNDLE; run flutter build linux --release" >&2; exit 1; }
mkdir -p "$OUT"

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
install -d "$ROOT/opt/kyndrel" "$ROOT/usr/bin" "$ROOT/usr/share/applications" \
  "$ROOT/usr/share/doc/kyndrel" "$ROOT/DEBIAN"
cp -a "$BUNDLE/." "$ROOT/opt/kyndrel/"
# The SQLite hook dlopens "libsqlite3.so" (normally only in -dev); point it
# at the runtime library. The bundle's lib/ is searched first.
MULTIARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo x86_64-linux-gnu)
ln -s "/usr/lib/$MULTIARCH/libsqlite3.so.0" "$ROOT/opt/kyndrel/lib/libsqlite3.so"
ln -s /opt/kyndrel/kyndrel "$ROOT/usr/bin/kyndrel"
install -m 644 linux/kyndrel.desktop "$ROOT/usr/share/applications/kyndrel.desktop"
for dir in packaging/linux/icons/*/; do
  size=$(basename "$dir")
  install -D -m 644 "$dir/kyndrel.png" \
    "$ROOT/usr/share/icons/hicolor/$size/apps/kyndrel.png"
done
install -m 644 LICENSE "$ROOT/usr/share/doc/kyndrel/copyright"
[ -f ATTRIBUTION.md ] && install -m 644 ATTRIBUTION.md "$ROOT/usr/share/doc/kyndrel/"

SIZE=$(du -sk "$ROOT" | cut -f1)
cat > "$ROOT/DEBIAN/control" <<CONTROL
Package: kyndrel
Version: $VERSION
Section: video
Priority: optional
Architecture: amd64
Installed-Size: $SIZE
Depends: libmpv2, libsqlite3-0, libgtk-3-0t64 | libgtk-3-0, libepoxy0, libdbus-1-3
Maintainer: Kyndrel contributors <https://github.com/xScropy/kyndrel/issues>
Homepage: https://github.com/xScropy/kyndrel
Description: Video player built on mpv
 Kyndrel plays local files, network streams and shares with a minimal
 dark interface: subtitles (search, sync, styling, translation), audio
 boost to 400 %, picture-in-picture, casting and a resume-where-you-left
 library.
CONTROL
cat > "$ROOT/DEBIAN/postinst" <<'POST'
#!/bin/sh
set -e
command -v update-desktop-database >/dev/null && update-desktop-database -q || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t /usr/share/icons/hicolor || true
POST
cp "$ROOT/DEBIAN/postinst" "$ROOT/DEBIAN/postrm"
chmod 755 "$ROOT/DEBIAN/postinst" "$ROOT/DEBIAN/postrm"

DEB="$OUT/kyndrel_${VERSION}_amd64.deb"
dpkg-deb --root-owner-group --build "$ROOT" "$DEB" >/dev/null
echo "$DEB"
