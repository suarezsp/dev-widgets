#!/usr/bin/env bash
# Builds dist/devwidgets-<version>-1.<arch>.rpm from a release
# build, for Fedora and other RPM distributions. rpmbuild adds the
# GTK 4 and libadwaita library requirements it finds in the binary.
set -euo pipefail
cd "$(dirname "$0")/.."

# The version lives in macOS/project.yml (MARKETING_VERSION).
APP_VERSION="$(sed -n \
    's/^ *MARKETING_VERSION: "\(.*\)"$/\1/p' macOS/project.yml)"
VERSION="${VERSION:-$APP_VERSION}"
TOP="$PWD/.build-rpm"
NAME_FORMAT="%%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm"
STAGE="$TOP/stage"

tools/stage_linux.sh "$STAGE"
mkdir -p "$TOP/SPECS" dist
sed -e "s/@VERSION@/$VERSION/" -e "s|@STAGE@|$STAGE|" \
    packaging/linux/devwidgets.spec.in > "$TOP/SPECS/devwidgets.spec"

rpmbuild -bb --define "_topdir $TOP" \
    --define "_rpmdir $PWD/dist" \
    --define "_build_name_fmt $NAME_FORMAT" \
    "$TOP/SPECS/devwidgets.spec"
echo "Built dist/devwidgets-${VERSION}-1.$(uname -m).rpm"
