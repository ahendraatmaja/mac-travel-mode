#!/bin/bash
# Remove Travel Mode. If it is on, restores normal sleep first (asks for your password).
set -uo pipefail
TM="$HOME/Applications/Travel Mode.app/Contents/Resources/bin/travel-mode"
LABEL="io.github.ahendraatmaja.mac-travel-mode.lid-lock"
/usr/bin/osascript -e 'quit app id "io.github.ahendraatmaja.mac-travel-mode"' 2>/dev/null || /usr/bin/pkill -x TravelMode || true
if /usr/bin/pmset -g | /usr/bin/grep -q 'SleepDisabled[[:space:]]*1'; then
  if [ -x "$TM" ]; then "$TM" off; else
    /usr/bin/osascript -e 'do shell script "/usr/bin/pmset -a disablesleep 0" with administrator privileges with prompt "Restore normal sleep before removing Travel Mode."'
  fi
fi
/bin/launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/Travel Mode.app" "$HOME/Library/Application Support/Travel Mode"
/usr/bin/defaults delete io.github.ahendraatmaja.mac-travel-mode 2>/dev/null || true
# The command link, only if it is ours (a link into a Travel Mode app)
LINK="$HOME/.local/bin/travel-mode"
case "$(/usr/bin/readlink "$LINK" 2>/dev/null)" in
  *"/Travel Mode.app/Contents/Resources/bin/travel-mode") rm -f "$LINK" ;;
esac
rm -f "$HOME/Library/Logs/travel-mode.log" "$HOME/Library/Logs/travel-mode.log.tmp" "$HOME/Library/Logs/travel-mode.err.log"
echo "Travel Mode removed. Normal sleep is on."
