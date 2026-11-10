#!/bin/bash
# swift test on a Mac with only the Command Line Tools (no Xcode).
# SwiftPM does not add the CLT's Testing.framework to the search
# and run paths, so Swift Testing reports "no such module
# 'Testing'". Usage: tools/swift_test_clt.sh [swift test options]
set -euo pipefail
CLT_DIR=/Library/Developer/CommandLineTools
export DEVELOPER_DIR="${DEVELOPER_DIR:-$CLT_DIR}"
FRAMEWORKS="$DEVELOPER_DIR/Library/Developer/Frameworks"
LIBRARIES="$DEVELOPER_DIR/Library/Developer/usr/lib"
exec swift test \
    -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
    -Xlinker -F -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$LIBRARIES" \
    "$@"
