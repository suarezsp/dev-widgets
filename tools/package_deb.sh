#!/usr/bin/env bash
# Builds dist/devwidgets_<version>_<arch>.deb from a release build.
# The Swift runtime is linked statically, so the package needs
# only GTK 4, libadwaita and their usual companions.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.6.0}"
ARCH="$(dpkg --print-architecture)"
APP_ID="com.morsetechnologies.DevWidgets"
STAGE=".build-deb/devwidgets_${VERSION}_${ARCH}"
LINUX="packaging/linux"

# Full RELRO, as Debian's hardening flags ask.
swift build -c release --product devwidgets-linux \
    --static-swift-stdlib -Xswiftc -use-ld=lld \
    -Xlinker -z -Xlinker relro \
    -Xlinker -z -Xlinker now
BINARY="$(swift build -c release --show-bin-path)/devwidgets-linux"

rm -rf "$STAGE" && mkdir -p "$STAGE/DEBIAN" dist
install -D -m 755 "$BINARY" "$STAGE/usr/bin/devwidgets"
strip --strip-unneeded "$STAGE/usr/bin/devwidgets"
install -D -m 644 "$LINUX/$APP_ID.desktop" \
    "$STAGE/usr/share/applications/$APP_ID.desktop"
install -D -m 644 "$LINUX/$APP_ID.metainfo.xml" \
    "$STAGE/usr/share/metainfo/$APP_ID.metainfo.xml"
install -D -m 644 \
    "$LINUX/icons/hicolor/scalable/apps/$APP_ID.svg" \
    "$STAGE/usr/share/icons/hicolor/scalable/apps/$APP_ID.svg"
install -D -m 644 "$LINUX/copyright" \
    "$STAGE/usr/share/doc/devwidgets/copyright"
gzip -9n -c "$LINUX/changelog.Debian" \
    > "$STAGE/usr/share/doc/devwidgets/changelog.gz"
install -D -m 644 "$LINUX/devwidgets.1" "$STAGE/tmp-man"
gzip -9n -c "$STAGE/tmp-man" > "$STAGE/devwidgets.1.gz"
install -D -m 644 "$STAGE/devwidgets.1.gz" \
    "$STAGE/usr/share/man/man1/devwidgets.1.gz"
rm "$STAGE/tmp-man" "$STAGE/devwidgets.1.gz"

# dpkg-shlibdeps reads the libraries the binary links.
mkdir -p "$STAGE/debian" && touch "$STAGE/debian/control"
LIBRARY_DEPENDS="$(cd "$STAGE" && dpkg-shlibdeps -O \
    usr/bin/devwidgets | sed 's/^shlibs:Depends=//')"
rm -rf "$STAGE/debian"

INSTALLED_KB="$(du -sk "$STAGE/usr" | cut -f1)"
sed -e "s/@VERSION@/$VERSION/" -e "s/@ARCH@/$ARCH/" \
    -e "s/@DEPENDS@/$LIBRARY_DEPENDS/" \
    -e "s/@SIZE@/$INSTALLED_KB/" \
    "$LINUX/control.in" > "$STAGE/DEBIAN/control"

dpkg-deb --root-owner-group --build "$STAGE" dist/
echo "Built dist/devwidgets_${VERSION}_${ARCH}.deb"
