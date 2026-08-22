#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
APP="$ROOT/outputs/CMQ.app"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/module-cache"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$CLANG_MODULE_CACHE_PATH"
xcrun swiftc "$ROOT/CMQ.swift" -o "$APP/Contents/MacOS/CMQ" -framework AppKit -framework UniformTypeIdentifiers

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Assets/CMQ.icns" "$APP/Contents/Resources/CMQ.icns"
codesign --force --deep --sign - "$APP"

echo "Built $APP"
