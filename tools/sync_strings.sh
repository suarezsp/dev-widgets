#!/usr/bin/env bash
# Adds the texts the app and the widgets use to the String Catalog
# (macOS). Build first with the same derived data folder:
#   tools/sync_strings.sh <DerivedData folder>
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED="${1:?usage: tools/sync_strings.sh <DerivedData folder>}"
BUILD="$DERIVED/Build/Intermediates.noindex/DevWidgets.build"
STRINGS_DATA=()
while IFS= read -r -d '' file; do
    STRINGS_DATA+=(--stringsdata "$file")
done < <(find "$BUILD"/*/DevWidgetsApp.build \
    "$BUILD"/*/DevWidgetsWidgets.build \
    -name '*.stringsdata' -print0)
xcrun xcstringstool sync macOS/Shared/Localizable.xcstrings \
    "${STRINGS_DATA[@]}"
echo "Synced macOS/Shared/Localizable.xcstrings"
