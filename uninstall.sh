#!/bin/bash
# Remove Travel Mode. If it is on, restores normal sleep first (asks for your password).
set -uo pipefail
TM="$HOME/Applications/Travel Mode.app/Contents/Resources/bin/travel-mode"
LABEL="io.github.ahendraatmaja.mac-travel-mode.lid-lock"
if /usr/bin/pmset -g | /usr/bin/grep -q 'SleepDisabled[[:space:]]*1'; then
  if [ -x "$TM" ]; then "$TM" off; else
    /usr/bin/osascript -e 'do shell script "/usr/bin/pmset -a disablesleep 0" with administrator privileges with prompt "Restore normal sleep before removing Travel Mode."'
  fi
fi
/bin/launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/Travel Mode.app" "$HOME/Library/Application Support/Travel Mode"
rm -f "$HOME/.local/bin/travel-mode" "$HOME/Library/Logs/travel-mode.log" "$HOME/Library/Logs/travel-mode.err.log"
echo "Travel Mode removed. Normal sleep is on."
