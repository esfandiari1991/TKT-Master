#!/bin/bash
# Build TKT Master.app natively with swiftc (no Xcode / no sudo needed).
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/build/TKT Master.app"
BIN="TKT Master"

echo "==> Cleaning"
rm -rf "$DIR/build"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Compiling Swift sources (universal: arm64 + x86_64)"
SRCS=$(find "$DIR/Sources" -name "*.swift")
xcrun --sdk macosx swiftc -parse-as-library -O -target arm64-apple-macos14.0  $SRCS -o "$DIR/build/bin-arm64"
if xcrun --sdk macosx swiftc -parse-as-library -O -target x86_64-apple-macos14.0 $SRCS -o "$DIR/build/bin-x86_64" 2>/dev/null; then
  lipo -create "$DIR/build/bin-arm64" "$DIR/build/bin-x86_64" -o "$APP/Contents/MacOS/$BIN"
  echo "    universal binary created"
else
  echo "    x86_64 slice failed; shipping arm64-only"
  cp "$DIR/build/bin-arm64" "$APP/Contents/MacOS/$BIN"
fi
rm -f "$DIR/build/bin-arm64" "$DIR/build/bin-x86_64"

echo "==> Assembling bundle"
cp "$DIR/Info.plist" "$APP/Contents/Info.plist"
cp "$DIR/Resources/"*.json "$APP/Contents/Resources/"
cp "$DIR/Resources/"*.icns "$APP/Contents/Resources/" 2>/dev/null || true

echo "==> Ad-hoc signing"
codesign --force --deep -s - "$APP" 2>/dev/null || true

echo "==> Built: $APP"
