#!/bin/sh
# Builds build/box4dd.app from the SwiftPM executable (no Xcode project needed).
# Ad-hoc signed: fine for running locally.
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP=build/box4dd.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Box4dd "$APP/Contents/MacOS/box4dd"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"
