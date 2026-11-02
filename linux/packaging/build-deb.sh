#!/usr/bin/env bash
# Packages `flutter build linux --release` as a .deb.
#
#   linux/packaging/build-deb.sh <version> <release|dev> <output.deb>
#
# Run from the app root on a Debian/Ubuntu host with dpkg-dev installed.
#
# The bundle goes to /opt/<package> whole — the executable finds lib/ and
# data/ beside itself — with a launcher on PATH, the .desktop entry and the
# hicolor icons in their usual places.
#
# A dev build is a separate package (`mplayer-dev`) with its own folder,
# command, .desktop entry and icon names, so it installs beside a release
# build rather than over it, as the `.canary` application id does on
# Android. The icon names matter as much as the rest: two packages shipping
# one path is a dpkg error, not an overwrite.
#
# Depends is worked out by dpkg-shlibdeps from what the binaries actually
# link, rather than written by hand: libmpv's package name follows its
# soname (libmpv1 on Ubuntu 22.04, libmpv2 after), and a hand-written list
# would name whichever one was current when it was written.
set -euo pipefail

VERSION="$1"
CHANNEL="$2"
OUTPUT="$3"

BUNDLE="build/linux/x64/release/bundle"
PACKAGING="linux/packaging"
BINARY="mPlayer"

if [ "$CHANNEL" = "dev" ]; then
  PACKAGE="mplayer-dev"
  APP_ID="dev.icedtea.mplayer.canary"
  NAME="mPlayer (Dev)"
else
  PACKAGE="mplayer"
  APP_ID="dev.icedtea.mplayer"
  NAME="mPlayer"
fi

# A hyphen in a Debian version starts the revision, so the app's own
# `1.2.0-dev-abc1234` becomes `1.2.0+dev.abc1234` for dpkg; the app keeps
# its own. Two dev builds of one version still do not order by commit, which
# is why the updater installs with `dpkg -i` (it takes a "downgrade") rather
# than apt.
DEB_VERSION="$(printf '%s' "$VERSION" | sed 's/-dev-/+dev./; s/-/./g')"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ROOT="$WORK/root"

install -d "$ROOT/opt/$PACKAGE" "$ROOT/usr/bin" \
  "$ROOT/usr/share/applications" "$ROOT/DEBIAN"
cp -a "$BUNDLE/." "$ROOT/opt/$PACKAGE/"
ln -s "/opt/$PACKAGE/$BINARY" "$ROOT/usr/bin/$PACKAGE"

for SRC in "$PACKAGING"/icons/hicolor/*/apps/dev.icedtea.mplayer.*; do
  SIZE="$(basename "$(dirname "$(dirname "$SRC")")")"
  EXT="${SRC##*.}"
  install -D -m 644 "$SRC" \
    "$ROOT/usr/share/icons/hicolor/$SIZE/apps/$APP_ID.$EXT"
done

# StartupWMClass stays the compiled-in GTK application id, which the dev
# build shares: it is what the window really reports.
sed -e "s|^Name=.*|Name=$NAME|" \
    -e "s|^Exec=.*|Exec=$PACKAGE %U|" \
    -e "s|^Icon=.*|Icon=$APP_ID|" \
    "$PACKAGING/dev.icedtea.mplayer.desktop" \
  > "$ROOT/usr/share/applications/$APP_ID.desktop"
chmod 644 "$ROOT/usr/share/applications/$APP_ID.desktop"

# dpkg-shlibdeps insists on a debian/control to read, even with -O. The
# bundle's own libraries (Flutter's engine, the plugins) belong to no
# package; -l lets it find them and --ignore-missing-info stops it failing
# over them, while everything they link from the system still counts.
mkdir -p "$WORK/shlibs/debian"
printf 'Source: %s\n\nPackage: %s\nArchitecture: amd64\n' "$PACKAGE" "$PACKAGE" \
  > "$WORK/shlibs/debian/control"
mapfile -t ELF < <(find "$ROOT/opt/$PACKAGE" -type f \( -name '*.so*' -o -name "$BINARY" \))
ARGS=()
for F in "${ELF[@]}"; do ARGS+=("-e$F"); done
DEPENDS="$(cd "$WORK/shlibs" && dpkg-shlibdeps -O --ignore-missing-info \
  "-l$ROOT/opt/$PACKAGE/lib" "${ARGS[@]}" | sed -n 's/^shlibs:Depends=//p')"
if [ -z "$DEPENDS" ]; then
  echo "dpkg-shlibdeps found no dependencies; refusing to build a .deb without any." >&2
  exit 1
fi

INSTALLED_SIZE="$(du -sk "$ROOT/opt" | cut -f1)"

cat > "$ROOT/DEBIAN/control" <<EOF
Package: $PACKAGE
Version: $DEB_VERSION
Section: video
Priority: optional
Architecture: amd64
Installed-Size: $INSTALLED_SIZE
Depends: $DEPENDS
Maintainer: Nam <namicedtea@gmail.com>
Homepage: https://github.com/jackedtea/mPlayer
Description: Jellyfin client with a built-in player
 Browse a Jellyfin server's libraries, play them in the app's own player,
 cast them to a television, and administer the server.
EOF

dpkg-deb --build --root-owner-group "$ROOT" "$OUTPUT"
echo "Built $OUTPUT ($PACKAGE $DEB_VERSION)"
echo "Depends: $DEPENDS"
