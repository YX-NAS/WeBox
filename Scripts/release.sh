#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build/release"
OUT="$ROOT/Release"
swift build -c release --package-path "$ROOT"
mkdir -p "$OUT/stage"
cp "$BUILD/WeBox" "$OUT/stage/WeBox"
cp "$ROOT/Docs/README.md" "$OUT/stage/README.md"
hdiutil create -volname "WeBox" -srcfolder "$OUT/stage" -ov -format UDZO "$OUT/WeBox.dmg"
