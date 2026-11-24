#!/bin/bash
# Build a drag-to-Applications disk image: build/Travel-Mode-<version>.dmg
#
# Without an Apple Developer ID the app is ad-hoc signed, so on first launch macOS asks the user
# to approve it once (System Settings > Privacy & Security > Open Anyway). To ship a disk image that
# opens without that step, set both:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE=<profile saved with: xcrun notarytool store-credentials>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(cat "$ROOT/VERSION")"
APP="$ROOT/build/Travel Mode.app"
DMG="$ROOT/build/Travel-Mode-$VERSION.dmg"

"$ROOT/build.sh"

if [ -n "${SIGN_IDENTITY:-}" ]; then
  for f in "$APP/Contents/Resources/bin/lockscreen" "$APP/Contents/Resources/bin/wifiname"; do
    /usr/bin/codesign --force --options runtime --timestamp -s "$SIGN_IDENTITY" "$f"
  done
  /usr/bin/codesign --force --options runtime --timestamp -s "$SIGN_IDENTITY" "$APP"
fi

# dmgbuild (writes the Finder window layout without scripting Finder), in a private venv,
# pinned by hash in requirements-dmg.txt. The venv is rebuilt whenever that file changes.
VENV="$ROOT/build/.venv"
if ! /usr/bin/cmp -s "$ROOT/requirements-dmg.txt" "$VENV/requirements-dmg.txt" 2>/dev/null; then
  rm -rf "$VENV"
  /usr/bin/python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --disable-pip-version-check --require-hashes --only-binary :all: \
    -r "$ROOT/requirements-dmg.txt"
  cp "$ROOT/requirements-dmg.txt" "$VENV/requirements-dmg.txt"
fi

rm -f "$DMG"
"$VENV/bin/dmgbuild" -s "$ROOT/dmg-settings.py" \
  -D app="$APP" -D background="$ROOT/assets/dmg-background.tiff" -D volicon="$ROOT/assets/TravelMode.icns" \
  "Travel Mode" "$DMG"

if [ -n "${SIGN_IDENTITY:-}" ]; then
  /usr/bin/codesign --timestamp -s "$SIGN_IDENTITY" "$DMG"
fi
if [ -n "${NOTARY_PROFILE:-}" ]; then
  /usr/bin/xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  /usr/bin/xcrun stapler staple "$DMG"
fi

/usr/bin/hdiutil verify "$DMG" >/dev/null
echo "Built $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"
/usr/bin/shasum -a 256 "$DMG"
