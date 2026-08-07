#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build/manual-release"
OUT="$ROOT/Release"
STAGE="$OUT/stage"
APP="$STAGE/WeBox.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/WeBoxApp/Info.plist")"
DMG="$OUT/WeBox-v${VERSION}-arm64-macos13.dmg"

rm -rf "$BUILD" "$STAGE"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"

CORE_SOURCES=(
  "$ROOT"/Core/*.swift
  "$ROOT"/Models/*.swift
  "$ROOT"/Database/Database.swift
  "$ROOT"/Database/InstanceRepository.swift
)
APP_SOURCES=(
  "$ROOT/WeBoxApp/AppLanguage.swift"
  "$ROOT/WeBoxApp/WeBoxApp.swift"
  "$ROOT/WeBoxApp/ContentView.swift"
  "$ROOT/WeBoxApp/Views/InstanceListView.swift"
  "$ROOT/WeBoxApp/Views/CompatibilityView.swift"
)

swiftc -target arm64-apple-macosx13.0 \
  -emit-library -emit-module -module-name WeBoxCore \
  "${CORE_SOURCES[@]}" -o "$BUILD/libWeBoxCore.dylib" -lsqlite3
swiftc -target arm64-apple-macosx13.0 \
  -o "$BUILD/WeBox" -I "$BUILD" -L "$BUILD" -lWeBoxCore \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  "${APP_SOURCES[@]}"

cp "$BUILD/WeBox" "$APP/Contents/MacOS/WeBox"
cp "$BUILD/libWeBoxCore.dylib" "$APP/Contents/Frameworks/libWeBoxCore.dylib"
cp "$ROOT/WeBoxApp/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/WeBoxApp/Assets/WeBox.icns" "$APP/Contents/Resources/WeBox.icns"
cp "$ROOT/WeBoxApp/Assets/WeBoxIcon.png" "$APP/Contents/Resources/WeBoxIcon.png"
cp "$ROOT/Docs/README.md" "$STAGE/README.md"
codesign --force --deep --sign - "$APP"
hdiutil create -volname "WeBox" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
shasum -a 256 "$DMG" > "$DMG.sha256"
echo "Created $DMG"
