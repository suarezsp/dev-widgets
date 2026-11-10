#!/bin/bash
# Renders every widget, size and presentation to PNG with SwiftUI's
# ImageRenderer (macOS/Render). Works with only the Command Line
# Tools: the widget sources are compiled into a small program
# instead of the extension. Usage: tools/render_widgets_clt.sh [dir]
set -euo pipefail
cd "$(dirname "$0")/.."
CLT_DIR=/Library/Developer/CommandLineTools
export DEVELOPER_DIR="${DEVELOPER_DIR:-$CLT_DIR}"
OUTPUT_DIR="${1:-.build/widget-renders}"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
swift build --product devwidgets-probe > /dev/null
BIN_PATH="$(swift build --show-bin-path)"
RENDER_BINARY=.build/devwidgets-render

# The extension's entry point is replaced by the renderer's.
xcrun swiftc -parse-as-library -swift-version 6 \
    -sdk "$SDK_PATH" -target arm64-apple-macos26.0 \
    -I "$BIN_PATH/Modules" -I "$BIN_PATH" \
    $(find macOS/Widgets macOS/Shared macOS/Render -name '*.swift' \
        ! -name DevWidgetsBundle.swift) \
    $(find "$BIN_PATH/DevWidgetsCore.build" -name '*.o') \
    -o "$RENDER_BINARY"
"$RENDER_BINARY" "$OUTPUT_DIR"
