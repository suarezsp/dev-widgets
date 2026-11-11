#!/usr/bin/env bash
# Builds dist/devwidgets_<version>_<arch>.deb from a release build.
# The Swift runtime is linked statically, so the package needs
# only GTK 4, libadwaita and their usual companions.
set -euo pipefail
cd "$(dirname "$0")/.."

# The version lives in macOS/project.yml (MARKETING_VERSION).
APP_VERSION="$(sed -n \
    's/^ *MARKETING_VERSION: "\(.*\)"$/\1/p' macOS/project.yml)"
VERSION="${VERSION:-$APP_VERSION}"
ARCH="$(dpkg --print-architecture)"
STAGE=".build-deb/devwidgets_${VERSION}_${ARCH}"
LINUX="packaging/linux"

tools/stage_linux.sh "$STAGE"
mkdir -p "$STAGE/DEBIAN" dist
gzip -9n -c "$LINUX/changelog.Debian" \
    > "$STAGE/usr/share/doc/devwidgets/changelog.gz"

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
