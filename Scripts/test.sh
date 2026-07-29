#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build/acceptance"
rm -rf "$BUILD"
mkdir -p "$BUILD"

CORE_SOURCES=(
  "$ROOT"/Core/*.swift
  "$ROOT"/Models/*.swift
  "$ROOT"/Database/Database.swift
  "$ROOT"/Database/InstanceRepository.swift
)

swiftc -target arm64-apple-macosx13.0 \
  -emit-library -emit-module -module-name WeBoxCore \
  "${CORE_SOURCES[@]}" -o "$BUILD/libWeBoxCore.dylib" -lsqlite3
swiftc -target arm64-apple-macosx13.0 \
  "$ROOT/Tests/AcceptanceTests.swift" -I "$BUILD" -L "$BUILD" -lWeBoxCore \
  -Xlinker -rpath -Xlinker @executable_path \
  -o "$BUILD/WeBoxAcceptanceTests"
"$BUILD/WeBoxAcceptanceTests"
