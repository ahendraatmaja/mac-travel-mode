#!/bin/bash
# Build Travel Mode and install it to ~/Applications, plus the `travel-mode` command in ~/.local/bin.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/build.sh"

DEST="$HOME/Applications/Travel Mode.app"
mkdir -p "$HOME/Applications"
WAS_RUNNING=""
if /usr/bin/pgrep -xq TravelMode; then
  WAS_RUNNING=1
  /usr/bin/osascript -e 'quit app id "io.github.ahendraatmaja.mac-travel-mode"' 2>/dev/null || /usr/bin/pkill -x TravelMode || true
  sleep 1
fi
rm -rf "$DEST"
cp -R "$ROOT/build/Travel Mode.app" "$DEST"
touch "$DEST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
/usr/bin/mdimport "$DEST" 2>/dev/null || true

mkdir -p "$HOME/.local/bin"
ln -sfn "$DEST/Contents/Resources/bin/travel-mode" "$HOME/.local/bin/travel-mode"

# If Travel Mode is already on (upgrade), point the watcher at the new copy.
"$DEST/Contents/Resources/bin/travel-mode" _rewatch
[ -n "$WAS_RUNNING" ] && /usr/bin/open "$DEST"

echo
echo "Installed: $DEST"
echo "Open it from Spotlight: Cmd+Space, type \"Travel Mode\"."
case ":$PATH:" in
  *":$HOME/.local/bin:"*) echo "Command line: travel-mode status" ;;
  *) echo "Command line: add ~/.local/bin to your PATH to use \`travel-mode\`." ;;
esac
