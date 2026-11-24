#!/bin/bash
# Replays Wi-Fi state sequences through the watcher with a simulated clock and checks what it
# decides. Touches nothing real: no pmset, no networksetup, settings in a temp folder.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
TM="$ROOT/src/bin/travel-mode"
pass=0; fail=0

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

run() { # $1 = name, $2 = comma list of states (one per 10 s check), $3 = network name while on hotspot,
        # $4 = preset hotspot name, $5 = what a scan for the hotspot finds (secure | open | absent)
  local dir="$TMP/$1"; mkdir -p "$dir"
  [ -n "${4:-}" ] && printf '%s\n' "$4" > "$dir/hotspot-name"
  local n; n=$(echo "$2" | awk -F, '{print NF}')
  TM_TEST=1 TM_TEST_WIFI="$2" TM_TEST_NAME="${3:-}" TM_TEST_SCAN="${5:-secure}" TM_TEST_TICKS=$((n * 5)) \
    TM_CONF_DIR="$dir" TM_LOG="$dir/log" "$TM" _watch
  LOGFILE="$dir/log"; CONF="$dir"
}

ok() { if eval "$2"; then pass=$((pass + 1)); echo "  ok   $1"; else fail=$((fail + 1)); echo "  FAIL $1"; fi; }

check() { # $1 = description, $2 = expected count, $3 = pattern
  local got; got=$(grep -c -- "$3" "$LOGFILE" 2>/dev/null || true)
  if [ "$got" = "$2" ]; then pass=$((pass + 1)); echo "  ok   $1"
  else fail=$((fail + 1)); echo "  FAIL $1 (expected $2, got $got)"; sed 's/^/       | /' "$LOGFILE" 2>/dev/null; fi
}

seq_of() { local out="" i; for i in $(seq 1 "$2"); do out="$out,$1"; done; echo "${out#,}"; }

echo "1. Hotspot drops (iPhone stops broadcasting), then comes back after 5 minutes"
run drop "hotspot,hotspot,$(seq_of none 30),hotspot" "MyPhone"
check "learns the hotspot name"            1 "remembered hotspot: MyPhone"
check "logs the disconnect once"           1 "Wi-Fi disconnected (was: hotspot)"
check "retries every 30 s (10 tries)"      10 "would join MyPhone"
check "logs the recovery"                  1 "back on the hotspot after 300 s"
ok "saves the name" '[ "$(cat "$CONF/hotspot-name")" = "MyPhone" ]'

echo "2. Long outage backs off to every 2 minutes after 10 tries"
run long "hotspot,$(seq_of none 60)" "MyPhone"
# lost at check 2; tries at +10 s then every 30 s up to try 10 (+280 s), then every 120 s until +590 s: tries 11-12
check "12 tries in 10 minutes"             12 "would join MyPhone"

echo "3. User moves to another network: leave it alone"
run other "hotspot,other,other,other" "MyPhone"
check "no reconnect attempts"              0 "would join"
check "notes the switch"                   1 "now on: other (not reconnecting)"

echo "4. User turns Wi-Fi off: leave it alone"
run off "hotspot,off,off,off" "MyPhone"
check "no reconnect attempts"              0 "would join"

echo "5. No hotspot known yet: nothing to rejoin"
run unknown "other,none,none,none,none" ""
check "logs the disconnect"                1 "Wi-Fi disconnected"
check "no reconnect attempts"              0 "would join"

echo "6. Remembered from an earlier trip: rejoins after a drop on another network"
run earlier "other,none,none,none,none" "" "OldPhone"
check "tries the remembered hotspot"       1 "would join OldPhone"

echo "7. An open network copies the hotspot's name while the hotspot is down: never join it"
run lookalike "other,$(seq_of none 6)" "" "MyPhone" open
check "refuses every attempt"              2 "not joining MyPhone, an open network is using that name"
check "no joins"                           0 "would join"

echo "8. Hotspot out of range: say so instead of trying"
run absent "hotspot,$(seq_of none 6)" "MyPhone" "" absent
check "logs not in range"                  2 "MyPhone is not in range"
check "no joins"                           0 "would join"

echo "9. An open network that hands out the hotspot address is never remembered"
run fake "hotspot,hotspot,hotspot" "Free_WiFi" "" open
check "logs it once"                       1 "not remembering Free_WiFi"
ok "saves nothing" '[ ! -s "$CONF/hotspot-name" ]'

echo "10. Control characters in a network name never reach the log or the saved name"
run ctl "hotspot,none,none" $'Evil\e]0;owned\a\e[2JPhone'
ok "saved name is clean" '[ "$(cat "$CONF/hotspot-name")" = "Evil]0;owned[2JPhone" ]'
ok "log has no control characters" '! LC_ALL=C grep -q "[[:cntrl:]]" "$LOGFILE"'

echo "11. The launchd file stays valid when the app sits in a folder with & < > in its name"
mkdir -p "$TMP/R&D <Tools>" "$TMP/home"
cp "$TM" "$TMP/R&D <Tools>/travel-mode"
HOME="$TMP/home" TM_TEST=1 /bin/bash "$TMP/R&D <Tools>/travel-mode" _plist >/dev/null
P="$TMP/home/Library/LaunchAgents/io.github.ahendraatmaja.mac-travel-mode.lid-lock.plist"
ok "plist is valid" '/usr/bin/plutil -lint -s "$P"'
ok "plist runs the right file" '[ "$(/usr/bin/plutil -extract ProgramArguments.1 raw -o - "$P")" = "$(cd "$TMP/R&D <Tools>" && pwd -P)/travel-mode" ]'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
