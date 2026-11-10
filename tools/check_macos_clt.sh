#!/bin/bash
# Type-checks the macOS app and the widget extension with only the
# Command Line Tools (no Xcode, so no bundles, signing or WidgetKit
# host). Same sources and modules as macOS/project.yml.
# Usage: tools/check_macos_clt.sh
set -euo pipefail
cd "$(dirname "$0")/.."
CLT_DIR=/Library/Developer/CommandLineTools
export DEVELOPER_DIR="${DEVELOPER_DIR:-$CLT_DIR}"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
TARGET_TRIPLE=arm64-apple-macos26.0
swift build --product devwidgets-probe > /dev/null
BIN_PATH="$(swift build --show-bin-path)"

typecheck() {
    local target_name="$1"
    shift
    echo "== $target_name"
    xcrun swiftc -typecheck -parse-as-library -swift-version 6 \
        -sdk "$SDK_PATH" -target "$TARGET_TRIPLE" \
        -I "$BIN_PATH/Modules" -I "$BIN_PATH" "$@"
}

failures=0
typecheck DevWidgetsApp \
    $(find macOS/App macOS/Shared -name '*.swift') \
    || failures=$((failures + 1))
typecheck DevWidgetsWidgets \
    $(find macOS/Widgets macOS/Shared -name '*.swift') \
    || failures=$((failures + 1))
[ "$failures" -eq 0 ] && echo "OK"
exit "$failures"
