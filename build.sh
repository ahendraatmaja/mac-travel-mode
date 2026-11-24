#!/bin/bash
# Build "build/Travel Mode.app" from src/. Needs only built-in macOS tools, plus clang
# (Xcode Command Line Tools) for the small lock-screen helper.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/Travel Mode.app"
VERSION="$(cat "$ROOT/VERSION")"

rm -rf "$APP"; mkdir -p "$ROOT/build"
/usr/bin/osacompile -o "$APP" "$ROOT/src/TravelMode.applescript"

RES="$APP/Contents/Resources"
mkdir -p "$RES/bin"
cp "$ROOT/src/bin/travel-mode" "$RES/bin/travel-mode"
chmod +x "$RES/bin/travel-mode"
if /usr/bin/xcrun --find clang >/dev/null 2>&1; then
  /usr/bin/xcrun clang -O2 -o "$RES/bin/lockscreen" "$ROOT/src/lockscreen.c"
  "$RES/bin/lockscreen" --check
else
  echo "Note: clang not found (run: xcode-select --install). Lid lock will fall back to display sleep."
fi

cp "$ROOT/assets/TravelMode.icns" "$RES/applet.icns"
rm -f "$RES/Assets.car"
PL="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$PL" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier io.github.ahendraatmaja.mac-travel-mode" "$PL" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string io.github.ahendraatmaja.mac-travel-mode" "$PL"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PL" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$PL"

/usr/bin/codesign --force --deep -s - "$APP" 2>/dev/null
/usr/bin/codesign --verify "$APP"
echo "Built $APP ($VERSION)"
