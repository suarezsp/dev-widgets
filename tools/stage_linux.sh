#!/usr/bin/env bash
# Builds the release binary and installs it with the desktop file,
# metadata, icon and man page under $1/usr, the layout both the
# .deb and the .rpm ship. The Swift runtime is linked statically.
set -euo pipefail
cd "$(dirname "$0")/.."
STAGE="$1"
APP_ID="com.morsetechnologies.DevWidgets"
LINUX="packaging/linux"
DOC="$STAGE/usr/share/doc/devwidgets"

# Full RELRO, as Debian's and Fedora's hardening flags ask.
swift build -c release --product devwidgets-linux \
    --static-swift-stdlib -Xswiftc -use-ld=lld \
    -Xlinker -z -Xlinker relro \
    -Xlinker -z -Xlinker now
BINARY="$(swift build -c release --show-bin-path)/devwidgets-linux"

rm -rf "$STAGE" && mkdir -p "$DOC" "$STAGE/usr/share/man/man1"
install -D -m 755 "$BINARY" "$STAGE/usr/bin/devwidgets"
strip --strip-unneeded "$STAGE/usr/bin/devwidgets"
install -D -m 644 "$LINUX/$APP_ID.desktop" \
    "$STAGE/usr/share/applications/$APP_ID.desktop"
install -D -m 644 "$LINUX/$APP_ID.metainfo.xml" \
    "$STAGE/usr/share/metainfo/$APP_ID.metainfo.xml"
install -D -m 644 \
    "$LINUX/icons/hicolor/scalable/apps/$APP_ID.svg" \
    "$STAGE/usr/share/icons/hicolor/scalable/apps/$APP_ID.svg"
install -m 644 "$LINUX/copyright" "$DOC/copyright"
gzip -9n -c "$LINUX/devwidgets.1" \
    > "$STAGE/usr/share/man/man1/devwidgets.1.gz"
