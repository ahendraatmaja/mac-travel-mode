#!/bin/bash
# Build "build/Travel Mode.app" from src/. Needs the Xcode Command Line Tools (xcode-select --install).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/Travel Mode.app"
VERSION="$(cat "$ROOT/VERSION")"
BUNDLE_ID="io.github.ahendraatmaja.mac-travel-mode"

if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
  echo "Travel Mode needs the Xcode Command Line Tools. Run: xcode-select --install"; exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin"
RES="$APP/Contents/Resources"

# App (window + optional menu bar icon), universal: Apple silicon + Intel
OBJ="$ROOT/build/obj"; mkdir -p "$OBJ"
for arch in arm64 x86_64; do
  /usr/bin/xcrun swiftc -O -swift-version 5 -target "$arch-apple-macos13.0" \
    -o "$OBJ/TravelMode-$arch" "$ROOT/src/app/main.swift"
done
/usr/bin/lipo -create -output "$APP/Contents/MacOS/TravelMode" "$OBJ/TravelMode-arm64" "$OBJ/TravelMode-x86_64"

# Helpers and the script the app drives (also universal)
ARCHS=(-arch arm64 -arch x86_64 -mmacosx-version-min=13.0)
/usr/bin/xcrun clang "${ARCHS[@]}" -O2 -o "$RES/bin/lockscreen" "$ROOT/src/lockscreen.c"
"$RES/bin/lockscreen" --check
/usr/bin/xcrun clang "${ARCHS[@]}" -fobjc-arc -O2 -o "$RES/bin/wifiname" "$ROOT/src/wifiname.m" \
  -framework Foundation -framework SystemConfiguration
cp "$ROOT/src/bin/travel-mode" "$RES/bin/travel-mode"
chmod +x "$RES/bin/travel-mode"
cp "$ROOT/assets/TravelMode.icns" "$RES/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>TravelMode</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Travel Mode</string>
  <key>CFBundleDisplayName</key><string>Travel Mode</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep -s - "$APP" 2>/dev/null
/usr/bin/codesign --verify "$APP"
echo "Built $APP ($VERSION)"
