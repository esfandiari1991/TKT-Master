#!/bin/bash
# Build the app and package a distributable zip for GitHub Releases.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/build.sh"
APP="$DIR/build/TKT Master.app"
ZIP="$DIR/TKT-Master-macOS.zip"
rm -f "$ZIP"
# ditto preserves the bundle + ad-hoc signature correctly
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
echo "==> Release archive: $ZIP"
ls -lh "$ZIP"
