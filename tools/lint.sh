#!/usr/bin/env bash
# Runs every quality gate. Exit status is non-zero on any failure.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== swift-format (layout, 70 columns)"
swift format lint --strict -r Package.swift Sources Tests macOS

echo "== SwiftLint (Swift hygiene, length, complexity)"
swiftlint lint --strict --quiet

echo "== check_style.py (house naming and size rules)"
python3 tools/check_style.py
python3 tools/test_check_style.py 2>&1 | tail -n 1
